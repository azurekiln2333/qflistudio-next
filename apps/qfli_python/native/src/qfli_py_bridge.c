/*
 * QFLIStudio+ Python 版的执行后端（内嵌 MicroPython）。
 *
 * 契约和 C 版对齐：给一段源码 + 一段标准输入，同步跑完，拿回输出、错误和退出码。
 * 所有输出缓冲由本模块 malloc，调用方用 qfli_py_result_free() 释放。
 *
 * 为什么不直接用上游 ports/embed 的 mp_embed_init/mp_embed_exec_str：
 *
 *   1. mp_embed_exec_str 把未捕获异常一律交给 mp_obj_print_exception，包括
 *      SystemExit。于是 `sys.exit(3)` 会打出一段 "SystemExit: 3" 的 traceback
 *      并以 0 退出，而我们要的是「退出码 3、不算错误、不打 traceback」。
 *   2. 它把初始化拆不开，没法做到「一次初始化、多次运行」。每次按 Run 都重新
 *      gc_init + mp_init 会白白付一遍初始化开销。
 *
 * 所以这里自己实现那几件事。语义上仍然严格遵守 MicroPython 的约定。
 */
#include "qfli_py_bridge.h"

#include "qfli_py_hal.h"

#include "py/builtin.h"
#include "py/compile.h"
#include "py/gc.h"
#include "py/lexer.h"
#include "py/mperrno.h"
#include "py/mphal.h"
#include "py/obj.h"
#include "py/parse.h"
#include "py/runtime.h"
#include "py/stackctrl.h"
#include "shared/runtime/gchelper.h"

/*
 * 版本号。py/mpconfig.h 只给 MICROPY_VERSION_STRING，MICROPY_GIT_HASH 在生成头
 * genhdr/mpversion.h 里——上游 py/modsys.c 也是这么单独 include 的，这里照做。
 */
#include "genhdr/mpversion.h"

#include <pthread.h>
#include <stdlib.h>
#include <string.h>

/*
 * GC 堆的默认大小。
 *
 * MicroPython 官方 embed 示例只给 8KB——那是给单片机的。手机上跑教学程序，
 * 随手一个 `[i*i for i in range(100000)]` 就要几 MB，8KB 会立刻 MemoryError。
 * 8MB 对现代手机毫无压力，同时又能让「无限往列表里塞」这种错误程序在
 * 可接受的延迟内撞上 MemoryError，而不是把设备内存吃光。
 */
#define QFLI_PY_DEFAULT_HEAP_KB (8 * 1024)

/* 申请不到默认大小时逐级退让，最低到这个值；再小就跑不动了。 */
#define QFLI_PY_MIN_HEAP_KB (1 * 1024)

/*
 * Python 层能用的栈预算（不是线程栈大小）。
 *
 * MicroPython 用它做两件事：一是把深递归变成 RecursionError 而不是段错误，
 * 二是保护编译器自身的 C 递归（深层嵌套表达式会在 py/parse.c 里递归下去）。
 *
 * 这个值要**明显小于**宿主线程的栈，否则保护还没触发就先撞破线程栈了。
 * NAPI 回调一般跑在平台线程上（OHOS 上默认 1MB 量级），192KB 留了足够余量，
 * 同时对教学程序的递归深度（几十层）绰绰有余。
 */
#define QFLI_PY_STACK_LIMIT_BYTES (192 * 1024)

/* ------------------------------------------------------------------ *
 * VM 生命周期
 * ------------------------------------------------------------------ */

static pthread_mutex_t g_lock = PTHREAD_MUTEX_INITIALIZER;

static void *g_heap = NULL;
static size_t g_heap_size = 0;
static int g_vm_ready = 0;

/*
 * 建立 VM。只做一次，之后反复运行都复用同一个 VM。
 *
 * 为什么不每次运行都重建：MicroPython 的 mp_deinit() 实际上是个空函数
 * （见 py/mpstate.c），真正能回收的只有我们自己的堆，重建并不能换来
 * 「更干净的状态」，只是白白付一遍初始化成本。
 * 运行之间的隔离由「每次编译出一个全新的模块」保证——模块级变量天然是新的，
 * 也不会进 sys.modules，所以上一次运行的全局变量不会泄漏到下一次。
 *
 * 返回 0 成功，-1 表示连最小的堆都申请不到。
 */
static int ensure_vm(int heap_kb)
{
    size_t want;

    if (g_vm_ready)
        return 0;

    want = (size_t)(heap_kb > 0 ? heap_kb : QFLI_PY_DEFAULT_HEAP_KB) * 1024;

    for (;;)
    {
        g_heap = malloc(want);
        if (g_heap != NULL)
            break;
        if (want <= (size_t)QFLI_PY_MIN_HEAP_KB * 1024)
            return -1;
        want /= 2;
    }

    g_heap_size = want;

    /*
     * 注意这里没有 mp_stack_set_top：那件事由调用方 qfli_py_run 每次做，
     * 因为扫栈的顶必须是「当前这一帧」的地址，见那里的注释。
     */
    gc_init(g_heap, (uint8_t *)g_heap + g_heap_size);
    mp_init();

    g_vm_ready = 1;
    return 0;
}

/* ------------------------------------------------------------------ *
 * GC 与致命错误：这两个是 port 必须提供的钩子
 * ------------------------------------------------------------------ */

/*
 * py/gc.c 在需要回收时调这个。
 * 上游 embed 的同名实现，原样照抄——寄存器捕获走
 * shared/runtime/gchelper_generic.c 里的 aarch64 分支（x19-x29）。
 */
void gc_collect(void)
{
    gc_collect_start();
    gc_helper_collect_regs_and_stack();
    gc_collect_end();
}

/*
 * 异常逃出了**所有** nlr 保护时才会走到这里。
 *
 * 这个函数里不能返回（调用方已经假设它不返回），也没有哪个 setjmp 可以跳。
 * 上游 embed 是死循环，我们保持一致，但先往 stderr 写一句，好让「App 卡住」
 * 这件事至少有个可诊断的痕迹。
 *
 * 正常路径下到不了这里：本文件的 execute() 有一层 nlr，print_safely() 还有
 * 一层，两层叠起来覆盖了所有会抛异常的调用。
 */
void nlr_jump_fail(void *val)
{
    static const char message[] = "(fatal: exception escaped all handlers)\n";
    (void)val;
    mp_hal_stdout_tx_strn_cooked(message, sizeof(message) - 1);
    for (;;)
    {
    }
}

/* ------------------------------------------------------------------ *
 * 文件系统钩子：我们一个都不提供，但符号必须存在
 * ------------------------------------------------------------------ */

/*
 * 源码是当字符串喂进来的，没有 VFS，也没有真实文件。
 * 任何路径都报「不存在」，于是 import 只会去找内置模块——正是想要的行为：
 * `import math` 成功，`import mymodule` 得到 ModuleNotFoundError。
 */
mp_import_stat_t mp_import_stat(const char *path)
{
    (void)path;
    return MP_IMPORT_STAT_NO_EXIST;
}

/*
 * py/lexer.c 只在 MICROPY_READER_VFS 或 MICROPY_READER_POSIX 打开时才定义它，
 * 我们两个都关了，所以要自己给一个。走到这里说明有人试图从文件编译——直接
 * 报 ENOENT 比给个空实现更诚实。
 */
mp_lexer_t *mp_lexer_new_from_file(qstr filename)
{
    (void)filename;
    mp_raise_OSError(MP_ENOENT);
}

/*
 * `open()` 和 `io.open()` 都指向这个对象，而它**必须由 port 提供**：
 *
 *   py/builtin.h 第 62 行（MICROPY_VFS 为 0 的那一支）：
 *       // A port can provide this object.
 *       MP_DECLARE_CONST_FUN_OBJ_KW(mp_builtin_open_obj);
 *   py/modio.c 第 207 行：
 *       // Note: mp_builtin_open_obj should be defined by port, it's not
 *       // part of the core.
 *
 * 而且 py/modio.c 里那处引用是**无条件**的（外面没有 MICROPY_PY_* 开关），
 * 所以只要把 io 模块编进来就躲不掉——关掉别的宏也没用。
 *
 * 没有文件系统，所以一律报 ENOENT。这比给个假实现诚实：用户看到的是
 * `OSError: [Errno 2] ENOENT`，而不是「打开成功但读出来是空的」。
 */
mp_obj_t mp_builtin_open(size_t n_args, const mp_obj_t *args, mp_map_t *kwargs)
{
    (void)n_args;
    (void)args;
    (void)kwargs;
    mp_raise_OSError(MP_ENOENT);
}
MP_DEFINE_CONST_FUN_OBJ_KW(mp_builtin_open_obj, 1, mp_builtin_open);

/* ------------------------------------------------------------------ *
 * 执行
 * ------------------------------------------------------------------ */

/*
 * 把东西打到**当前 sink**（调用方负责切到 stderr），并保证「打印过程中又抛
 * 异常」不会逃逸出去。
 *
 * 这层保护不是多余的：如果异常对象的 __str__ 自己抛异常，而我们在异常处理
 * 里裸调打印，二次异常就会一路撞到 nlr_jump_fail——那是个死循环，App 直接
 * 卡死。用户看到的会是「点运行之后没反应」，非常难查。
 */
static void print_safely(mp_obj_t obj, int as_exception)
{
    nlr_buf_t nlr;

    if (nlr_push(&nlr) == 0)
    {
        if (as_exception)
        {
            mp_obj_print_exception(&mp_plat_print, obj);
        }
        else
        {
            /* sys.exit("原因") 这种：按 CPython 的行为当普通文本打出来。 */
            mp_obj_print_helper(&mp_plat_print, obj, PRINT_STR);
            mp_hal_stdout_tx_strn_cooked("\n", 1);
        }
        nlr_pop();
        return;
    }

    {
        static const char fallback[] = "(exception printing failed)\n";
        mp_hal_stdout_tx_strn_cooked(fallback, sizeof(fallback) - 1);
    }
}

/*
 * 编译并执行一段源码。返回 0 表示「跑完了，无论正常还是抛异常」，
 * *exit_code 带回退出码。返回非 0 表示环境级失败（目前只有 OOM）。
 */
static int execute(const char *source, int *exit_code)
{
    nlr_buf_t nlr;

    if (nlr_push(&nlr) == 0)
    {
        mp_lexer_t *lex;
        qstr source_name;
        mp_parse_tree_t parse_tree;
        mp_obj_t module_fun;

        /*
         * 源码名用 <stdin>。MicroPython 自己在 py/builtinevex.c 里也是这么
         * 处理「不在文件里的源码」的，所以 traceback 里会显示 File "<stdin>"。
         * 换成真实文件名会更好看，但那要求 qstr 里得先有这个字符串，而 qstr
         * 是编译期固定下来的——为一个纯装饰性的名字不值得。
         */
        lex = mp_lexer_new_from_str_len(
            MP_QSTR__lt_stdin_gt_, source, strlen(source), 0);
        source_name = lex->source_name;

        parse_tree = mp_parse(lex, MP_PARSE_FILE_INPUT);
        module_fun = mp_compile(&parse_tree, source_name, true);
        mp_call_function_0(module_fun);

        nlr_pop();
        *exit_code = 0;
        return 0;
    }

    {
        mp_obj_t exc = (mp_obj_t)nlr.ret_val;

        /*
         * sys.exit() 走的是 SystemExit 异常，这在 CPython 和 MicroPython 里
         * 都一样（py/objexcept.c 里 MP_DEFINE_EXCEPTION(SystemExit, ...)）。
         * 它代表「程序主动结束」，不是错误——不打 traceback。
         */
        if (mp_obj_is_exception_instance(exc) &&
            mp_obj_get_type(exc) == &mp_type_SystemExit)
        {
            mp_obj_t value = mp_obj_exception_get_value(exc);

            if (value == mp_const_none)
            {
                *exit_code = 0;
            }
            else if (mp_obj_is_int(value))
            {
                *exit_code = mp_obj_get_int(value);
            }
            else
            {
                /* sys.exit("原因")：CPython 会把它打到 stderr 并以 1 退出。 */
                qfli_py_hal_set_sink(QFLI_PY_SINK_STDERR);
                print_safely(value, 0);
                qfli_py_hal_set_sink(QFLI_PY_SINK_STDOUT);
                *exit_code = 1;
            }
            return 0;
        }

        /* 普通未捕获异常：traceback 归到 stderr，退出码 1。 */
        qfli_py_hal_set_sink(QFLI_PY_SINK_STDERR);
        print_safely(exc, 1);
        qfli_py_hal_set_sink(QFLI_PY_SINK_STDOUT);
        *exit_code = 1;
        return 0;
    }
}

/* ------------------------------------------------------------------ *
 * 对外接口
 * ------------------------------------------------------------------ */

static char *duplicate_string(const char *text)
{
    size_t length;
    char *copy;

    if (text == NULL)
        return NULL;

    length = strlen(text);
    copy = (char *)malloc(length + 1);
    if (copy == NULL)
        return NULL;
    memcpy(copy, text, length + 1);
    return copy;
}

static QfliPyRunResult make_result(int exit_code, const char *output, const char *error)
{
    QfliPyRunResult result;

    result.exit_code = exit_code;
    result.truncated = 0;
    result.output = duplicate_string(output == NULL ? "" : output);
    /* error 为 NULL 表示「没有错误」，Dart 侧据此不显示错误区域。 */
    result.error = (error == NULL || error[0] == '\0') ? NULL : duplicate_string(error);
    return result;
}

QfliPyRunResult qfli_py_run(const char *source, const char *stdin_text, int heap_kb)
{
    QfliPyRunResult result;
    int exit_code = 0;

    if (source == NULL)
    {
        result = make_result(1, "", "没有可运行的源码。");
        return result;
    }

    /*
     * 串行化。MicroPython 的 embed 用法是单线程的：它有全局 VM 状态，
     * 两个线程同时跑会互相踩。NAPI 侧可能从不同线程进来（平台线程 /
     * worker），所以这里必须锁。
     */
    pthread_mutex_lock(&g_lock);

    /*
     * 设 GC 扫栈的「顶」。
     *
     * 栈向下长：比这一帧更深的（地址更低的）才是解释器自己的帧。GC 会从
     * 它自己的 &regs 一路扫到 stack_top，所以 stack_top 必须是当前这一帧的
     * 地址，才能既覆盖解释器的帧、又覆盖本函数自己的局部变量。
     *
     * 每次运行都重设，是为了不依赖「第一次是从哪一层调进来的」。如果只在
     * 初始化时设一次、而那次恰好发生在更深的帧里，之后从更浅的帧运行时
     * stack_top 就比 &regs 还低，gc_helper_collect_regs_and_stack 里那句
     * 减法会下溢成一个天文数字，直接崩。
     *
     * 取地址这个动作本身就能保证变量落在栈上——编译器没法把一个「地址被
     * 别人拿走」的局部变量塞进寄存器。
     */
    {
        int stack_anchor = 0;
        mp_stack_set_top((void *)&stack_anchor);
    }

    if (ensure_vm(heap_kb) != 0)
    {
        pthread_mutex_unlock(&g_lock);
        result = make_result(1, "", "内存不足：申请 MicroPython 的 GC 堆失败。");
        return result;
    }

    /* 必须在 mp_init() 之后设：它写的是 VM 状态里的字段。 */
    mp_stack_set_limit(QFLI_PY_STACK_LIMIT_BYTES);

    qfli_py_hal_reset(stdin_text);

    if (execute(source, &exit_code) != 0)
    {
        pthread_mutex_unlock(&g_lock);
        result = make_result(1, qfli_py_hal_stdout(), qfli_py_hal_stderr());
        return result;
    }

    result = make_result(exit_code, qfli_py_hal_stdout(), qfli_py_hal_stderr());
    result.truncated = qfli_py_hal_truncated();

    pthread_mutex_unlock(&g_lock);
    return result;
}

void qfli_py_result_free(QfliPyRunResult *result)
{
    if (result == NULL)
        return;
    free(result->output);
    free(result->error);
    result->output = NULL;
    result->error = NULL;
}

const char *qfli_py_version(void)
{
    /*
     * 字符串字面量拼接，编译期完成——没有分配，也不用管生命周期。
     *
     * 两个宏都是 MicroPython 自己的：
     *   MICROPY_VERSION_STRING  py/mpconfig.h   → "1.24.1"
     *   MICROPY_GIT_HASH        genhdr/mpversion.h → 上游 commit 短 hash
     */
    return MICROPY_VERSION_STRING " (" MICROPY_GIT_HASH ")";
}


/*
 * MicroPython 在 HarmonyOS 上的 HAL 层：标准输出捕获 + 标准输入喂给 + 时钟。
 *
 * 上游 ports/embed 自带的 port/mphalport.c 只干一件事：
 *     void mp_hal_stdout_tx_strn_cooked(const char *str, size_t len) { printf(...); }
 * 也就是把解释器的输出直接写进**进程的 stdout**。在 .so 里这是不能接受的：
 * 宿主是 ArkTS/Flutter 应用，进程 stdout 没人看，我们要的是把输出捞回来交给 Dart。
 * 所以那个文件被排除掉（见 tools/build_embed.py 的说明），换成本文件。
 *
 * py/mphal.h 里声明的那些函数，只要被编译进来的代码引用了就必须有定义。我们开了
 * EXTRA 档特性，所以除了 stdout 之外还要提供：stdin（input() 用）、poll、
 * 四个时钟、两个 delay、以及 mp_hal_time_ns（time.time() 用）。
 */
#include "qfli_py_hal.h"

#include "py/mphal.h"
#include "py/misc.h"
#include "py/stream.h"

#include <string.h>
#include <time.h>

/*
 * 输出上限。教学程序的输出远小于这个数；超了就截断并打标记，免得一个
 * `while True: print(1)` 把设备内存写爆（这个错误在初学阶段出现频率极高，
 * 必须有兜底）。
 */
#define QFLI_PY_MAX_STDOUT (256 * 1024)
#define QFLI_PY_MAX_STDERR (64 * 1024)

static char g_stdout[QFLI_PY_MAX_STDOUT];
static size_t g_stdout_len = 0;
static int g_stdout_truncated = 0;

static char g_stderr[QFLI_PY_MAX_STDERR];
static size_t g_stderr_len = 0;
static int g_stderr_truncated = 0;

static qfli_py_sink_t g_sink = QFLI_PY_SINK_STDOUT;

/* 标准输入：整段一次性给进来，按字节推进。 */
static const char *g_stdin_text = NULL;
static size_t g_stdin_len = 0;
static size_t g_stdin_pos = 0;

/* ------------------------------------------------------------------ *
 * 内部接口（给 qfli_py_bridge.c 用）
 * ------------------------------------------------------------------ */

void qfli_py_hal_reset(const char *stdin_text)
{
    g_stdout_len = 0;
    g_stdout[0] = '\0';
    g_stdout_truncated = 0;

    g_stderr_len = 0;
    g_stderr[0] = '\0';
    g_stderr_truncated = 0;

    g_sink = QFLI_PY_SINK_STDOUT;

    g_stdin_text = stdin_text;
    g_stdin_len = (stdin_text == NULL) ? 0 : strlen(stdin_text);
    g_stdin_pos = 0;
}

void qfli_py_hal_set_sink(qfli_py_sink_t sink)
{
    g_sink = sink;
}

const char *qfli_py_hal_stdout(void)
{
    return g_stdout;
}

const char *qfli_py_hal_stderr(void)
{
    return g_stderr;
}

int qfli_py_hal_truncated(void)
{
    return (g_stdout_truncated || g_stderr_truncated) ? 1 : 0;
}

/* ------------------------------------------------------------------ *
 * 输出：所有 print() / 异常 traceback 最终都汇聚到这里
 * ------------------------------------------------------------------ */

static void emit(const char *str, size_t len)
{
    char *buffer;
    size_t *used;
    size_t capacity;
    int *truncated;

    if (str == NULL || len == 0)
        return;

    if (g_sink == QFLI_PY_SINK_STDERR)
    {
        buffer = g_stderr;
        used = &g_stderr_len;
        capacity = QFLI_PY_MAX_STDERR;
        truncated = &g_stderr_truncated;
    }
    else
    {
        buffer = g_stdout;
        used = &g_stdout_len;
        capacity = QFLI_PY_MAX_STDOUT;
        truncated = &g_stdout_truncated;
    }

    /* 留一个字节给结尾的 NUL。 */
    if (len > capacity - 1 - *used)
    {
        len = capacity - 1 - *used;
        *truncated = 1;
    }

    if (len == 0)
        return;

    memcpy(buffer + *used, str, len);
    *used += len;
    buffer[*used] = '\0';
}

/*
 * 注意这里**不做** \n → \r\n 转换。
 *
 * 上游 embed 的实现用 printf，Windows 上会把换行变成 CRLF——那是为了终端。
 * 我们的输出终点是 Flutter 的 Text 组件，CRLF 会变成多余的空行或乱码字符。
 * 函数名里的 "cooked" 指的是「按终端习惯加工过」，我们这层不做加工，所以
 * 两个函数行为一致。
 */
void mp_hal_stdout_tx_strn_cooked(const char *str, size_t len)
{
    emit(str, len);
}

mp_uint_t mp_hal_stdout_tx_strn(const char *str, size_t len)
{
    emit(str, len);
    return (mp_uint_t)len;
}

void mp_hal_stdout_tx_str(const char *str)
{
    emit(str, strlen(str));
}

/* ------------------------------------------------------------------ *
 * 输入
 * ------------------------------------------------------------------ */

/*
 * input() 的实现，由 port/mphalport.h 里的 mp_hal_readline 宏钩进来。
 *
 * 语义和 CPython 对齐：读到换行为止，**不含**结尾换行；输入耗尽返回 -1，
 * 调用方 py/modbuiltins.c 会据此抛 EOFError。
 */
int qfli_py_hal_readline(vstr_t *vstr)
{
    if (g_stdin_pos >= g_stdin_len)
        return -1;

    while (g_stdin_pos < g_stdin_len)
    {
        char ch = g_stdin_text[g_stdin_pos++];
        if (ch == '\n')
            return 0;
        /* 兼容 CRLF：CR 直接吞掉，不当成内容。 */
        if (ch == '\r')
            continue;
        vstr_add_byte(vstr, (byte)ch);
    }

    /* 最后一行没有换行符结尾，也算读到一行。 */
    return 0;
}

int mp_hal_stdin_rx_chr(void)
{
    if (g_stdin_pos >= g_stdin_len)
        return -1;
    return (int)(unsigned char)g_stdin_text[g_stdin_pos++];
}

uintptr_t mp_hal_stdio_poll(uintptr_t poll_flags)
{
    (void)poll_flags;
    /* 只有「还能读」这一种状态会变。EOF 之后返回 0。 */
    return (g_stdin_pos < g_stdin_len) ? MP_STREAM_POLL_RD : 0;
}

/* ------------------------------------------------------------------ *
 * 时钟与延时
 * ------------------------------------------------------------------ */

static void now_monotonic(struct timespec *ts)
{
    clock_gettime(CLOCK_MONOTONIC, ts);
}

mp_uint_t mp_hal_ticks_ms(void)
{
    struct timespec ts;
    now_monotonic(&ts);
    return (mp_uint_t)ts.tv_sec * 1000u + (mp_uint_t)(ts.tv_nsec / 1000000);
}

mp_uint_t mp_hal_ticks_us(void)
{
    struct timespec ts;
    now_monotonic(&ts);
    return (mp_uint_t)ts.tv_sec * 1000000u + (mp_uint_t)(ts.tv_nsec / 1000);
}

/*
 * 「CPU 周期数」。我们没有便宜的方式读 PMCCNTR（而且 arm64 上默认是关的），
 * 退回微秒。用到它的只有 microbit 那类性能测试代码，教学场景无所谓。
 */
mp_uint_t mp_hal_ticks_cpu(void)
{
    return mp_hal_ticks_us();
}

void mp_hal_delay_us(mp_uint_t us)
{
    struct timespec ts;
    ts.tv_sec = (time_t)(us / 1000000u);
    ts.tv_nsec = (long)((us % 1000000u) * 1000u);
    nanosleep(&ts, NULL);
}

/*
 * time.sleep() 走这里。
 *
 * 上游的 unix port 会在延时里调 mp_handle_pending()，好让 Ctrl-C 能打断
 * sleep。我们没有「随时中断」的通道（MICROPY_KBD_EXCEPTION 是关的），
 * 所以就是一个纯粹的睡。
 */
void mp_hal_delay_ms(mp_uint_t ms)
{
    mp_hal_delay_us(ms * 1000u);
}

uint64_t mp_hal_time_ns(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ull + (uint64_t)ts.tv_nsec;
}

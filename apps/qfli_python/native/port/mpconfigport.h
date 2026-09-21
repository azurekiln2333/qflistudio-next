/*
 * QFLIStudio+ Python 版内嵌的 MicroPython 配置。
 *
 * py/mpconfig.h 第 91 行是 `#include <mpconfigport.h>`——尖括号，所以编译时
 * 必须有一条 -I 指向本目录。这一点很关键：不是「放对位置就行」，是「必须在
 * include path 上」。
 *
 * 这个文件在 mpconfig.h 的默认值之前被包含，所以下面写的每一项都会先落地，
 * mpconfig.h 里那一堆 `#ifndef` 就不会再覆盖它。
 *
 * 取舍：目标不是省 flash，是「入门教程里会出现的 Python 都能跑」。
 */
#ifndef QFLI_PY_MPCONFIGPORT_H
#define QFLI_PY_MPCONFIGPORT_H

#include <stdint.h>
#include <alloca.h>

/* ------------------------------------------------------------------ *
 * 特性档位
 * ------------------------------------------------------------------ */

/*
 * EXTRA_FEATURES 这一档打开的东西正好覆盖入门教程的语法面：
 *   f-string、全套运算符重载（__add__ / __eq__ / __lt__ …）、deque、
 *   描述符、以及 json / random / time / re / binascii / heapq 这些模块。
 *
 * 再上一档 FULL 会拉进 asyncio 的完整调度器、deflate（要 zlib）、
 * memoryview 的 itemsize 等，对教学没用还得配额外依赖，所以停在 EXTRA。
 */
#define MICROPY_CONFIG_ROM_LEVEL (MICROPY_CONFIG_ROM_LEVEL_EXTRA_FEATURES)

#define MICROPY_ENABLE_COMPILER (1)
#define MICROPY_ENABLE_GC       (1)

/*
 * 这个必须显式关掉，而且理由很硬：EXTRA 档默认把它打开，但
 * py/builtinevex.c 里有一句
 *     #error "MICROPY_PY_BUILTINS_EXECFILE requires MICROPY_HAS_FILE_READER"
 * 而文件读取器要 VFS 或 POSIX reader，我们两样都没有——本 App 的模型是
 * 「源码以字符串交给解释器」，根本不走文件。所以 execfile 关掉。
 * compile() 内置函数不受影响（它只要字符串）。
 */
#define MICROPY_PY_BUILTINS_EXECFILE (0)

/*
 * 文件系统：没有 VFS，没有真实文件 IO。
 * MICROPY_VFS 在 mpconfig.h 里默认就是 0，这里写出来是为了明确意图——
 * 一旦以后有人打开它，就会看到这段注释而不是去猜。
 */
#define MICROPY_VFS          (0)
#define MICROPY_VFS_POSIX    (0)
#define MICROPY_READER_VFS   (0)
#define MICROPY_READER_POSIX (0)
#define MICROPY_PY_IO_FILEIO (0)
#define MICROPY_PY_OS        (0)

/*
 * 下面这些模块的实现在 extmod/ 里，我们没有把它们的 .c 编进来：
 *   hashlib  依赖 mbedtls
 *   select   依赖 socket / poll
 *   uctypes  裸内存访问，教学场景反而危险
 *   asyncio  需要调度器 + 线程语义
 *   deflate  需要 zlib
 *   framebuf 给屏幕画的，无关
 * 关掉免得链接期报缺符号。注意这些模块的 .c 本来就没进源码列表，所以
 * 就算开着也只是「模块不存在」，不会编译失败——但显式关掉能让
 * `help()` 和 moduledefs 的输出更干净。
 */
#define MICROPY_PY_HASHLIB  (0)
#define MICROPY_PY_SELECT   (0)
#define MICROPY_PY_UCTYPES  (0)
#define MICROPY_PY_ASYNCIO  (0)
#define MICROPY_PY_DEFLATE  (0)
#define MICROPY_PY_FRAMEBUF (0)
#define MICROPY_PY_PLATFORM (0)

/*
 * 我们跑的是「整段脚本」，没有交互式 REPL，也没有「随时中断」的通道，
 * 所以键盘中断那套不装。少了它 py/runtime.c 里就少一处对
 * mp_hal_set_interrupt_char 的依赖。
 */
#define MICROPY_KBD_EXCEPTION (0)

/*
 * 没有 REPL，py/repl.c 整个编成空文件（它的内容都在
 * `#if MICROPY_HELPER_REPL` 里面）。这样也不用把
 * shared/readline/readline.c 拉进来——那正是「embed 包保持自包含」的前提。
 *
 * 但 input() 要留着（入门教程第一课就是「让用户输入名字」）。
 * 它的实现走 mp_hal_readline 这个 port 钩子，我们在 mphalport.h 里提供，
 * 数据源是喂进来的那段标准输入。见 py/modbuiltins.c 第 217-219 行。
 */
#define MICROPY_HELPER_REPL        (0)
#define MICROPY_PY_BUILTINS_INPUT  (1)

/*
 * time.localtime() / gmtime() / mktime() 这一组。打开它有两个前提，缺一不可：
 *
 * 1. shared/timeutils/timeutils.c 负责日历换算。它是自包含的，已经打进 embed 包。
 *
 * 2. **还必须提供一个 port 钩子** mp_time_localtime_get()。不带参数的
 *    time.localtime() 要拿「当前时间」，MicroPython 把这件事留给 port，
 *    py/ 和 extmod/ 里都没有它的声明。我们把它放在
 *    port/qfli_time_localtime.c，再用下面的 INCLUDEFILE 让 extmod/modtime.c
 *    文本包含进去——这是上游每个 MCU port 的标准做法。
 *    漏了它报的是这两条，看起来完全像别的问题：
 *        error: call to undeclared function 'mp_time_localtime_get'
 *        error: incompatible integer to pointer conversion returning 'int'
 *               from a function with result type 'mp_obj_t' (aka 'void *')
 *
 * （这个宏上游只在 webassembly / samd / mimxrt / esp32 这些 port 里设，
 *   mpconfig.h 里没有默认值，`#if` 未定义标识符求值为 0，也就是默认关闭。）
 */
#define MICROPY_PY_TIME_GMTIME_LOCALTIME_MKTIME (1)

/*
 * 注意这里给的是**裸文件名**，不是上游那种 "ports/xxx/modtime.c" 路径。
 *
 * 因为 `#include "xxx"` 的查找顺序是先看「包含它的那个文件所在目录」，而包含
 * 它的文件就叫 extmod/modtime.c——名字如果跟它重了（比如 "modtime.c"）就会
 * 命中它自己，无限递归。所以用一个唯一名字，靠 -I 找到 port/ 下的文件：
 *
 *     qstr 扫描时   -I<MicroPython 根> -I<build> -I<native/port>
 *     真正编译时    -I<micropython_embed> -I<micropython_embed>/port
 *
 * 两边的 -I 都指向这个文件所在目录，所以两边都能解析。详细说明见
 * port/qfli_time_localtime.c 顶部。
 */
#define MICROPY_PY_TIME_INCLUDEFILE "qfli_time_localtime.c"

/* ------------------------------------------------------------------ *
 * 浮点
 * ------------------------------------------------------------------ */

/*
 * 这一条必须显式给，否则**浮点整个没有**。
 *
 * py/mpconfig.h 第 822-824 行的默认值是 MICROPY_FLOAT_IMPL_NONE，
 * 然后第 826-838 行按它推导出 MICROPY_PY_BUILTINS_FLOAT（NONE 时是 0）。
 * 后果不是「精度差一点」，而是：
 *   - `3.14` 这种字面量用不了；
 *   - `1 / 2` 走整数除法得 0 而不是 0.5；
 *   - py/modmath.c 整个文件被 `#if MICROPY_PY_BUILTINS_FLOAT && MICROPY_PY_MATH`
 *     关掉，`import math` 直接 ModuleNotFoundError。
 * 也就是说入门教程第一页就崩。
 *
 * 上游 ports/embed 自己不管这个（它的 mpconfigport_common.h 不设），
 * 是留给宿主项目决定的。所以这里必须补上。
 *
 * 选 DOUBLE 而不是 FLOAT：教程里的例子都是按 CPython 的语义写的，
 * 用单精度会出现 `0.1 + 0.2` 这种结果的差异，对教学是干扰。
 * 代价是 mp_float_t 从 4 字节变 8 字节，对这个 App 的体量无所谓。
 */
#define MICROPY_FLOAT_IMPL (MICROPY_FLOAT_IMPL_DOUBLE)

/* ------------------------------------------------------------------ *
 * 平台类型
 * ------------------------------------------------------------------ */

/* 必须是指针宽度。aarch64 上 intptr_t 就是 8 字节。 */
typedef intptr_t mp_int_t;
typedef uintptr_t mp_uint_t;
typedef long mp_off_t;

/*
 * py/mphal.h 里写的是 `#include MICROPY_MPHALPORT_H`，所以这个宏要带引号。
 * 不设的话它会去找 <mphalport.h>，那就跑到系统头文件目录去了。
 */
#define MICROPY_MPHALPORT_H "mphalport.h"

/*
 * MP_STATE_PORT 是所有 port 都要给的别名：MicroPython 用它放「port 自己的
 * 状态」。我们没有 port 私有状态，直接指到 VM 状态上，这也是 minimal /
 * unix 这些 port 的做法。
 */
#define MP_STATE_PORT MP_STATE_VM

/* ------------------------------------------------------------------ *
 * 身份标识
 * ------------------------------------------------------------------ */

#define MICROPY_HW_BOARD_NAME "qfli-python"
#define MICROPY_HW_MCU_NAME   "harmonyos"

/*
 * sys.platform 的值。py/modsys.c 第 139 行是 `#ifdef MICROPY_PY_SYS_PLATFORM`，
 * 不定义就没有 sys.platform 这个属性；教程里偶尔会 print 它，给个能认出来的。
 */
#define MICROPY_PY_SYS_PLATFORM "ohos"

#endif /* QFLI_PY_MPCONFIGPORT_H */

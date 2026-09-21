/*
 * MicroPython 的 time 模块 port 钩子：mp_time_localtime_get()。
 *
 * 这个文件**不是**独立的编译单元
 * ------------------------------
 * 它是被 extmod/modtime.c 用 `#include MICROPY_PY_TIME_INCLUDEFILE` **文本包含**
 * 进去的（modtime.c:35-37），由 port/mpconfigport.h 里的
 *
 *     #define MICROPY_PY_TIME_INCLUDEFILE "qfli_time_localtime.c"
 *
 * 指定。所以：
 *   * CMakeLists.txt 里把它从 file(GLOB) 的结果中排除了（见那边的说明）——
 *     当独立 .c 编一遍没有意义。
 *   * 文件名必须**唯一**，而且不能是 "modtime.c" 这种名字。`#include "xxx"`
 *     的查找顺序是先看「包含它的那个文件所在目录」，而包含它的文件就叫
 *     extmod/modtime.c —— 用 "modtime.c" 会命中它自己，无限递归。
 *     用裸文件名 + 唯一名字，靠 -I 找到这里：
 *         qstr 扫描时   -I<MicroPython 根> -I<build> -I<native/port>
 *         真正编译时    -I<micropython_embed> -I<micropython_embed>/port
 *     两边都能命中，所以必须是个不会在 extmod/ 里重名的名字。
 *
 * 为什么需要它
 * ------------
 * `time.localtime()` / `time.gmtime()` / `time.mktime()` 这三个函数在
 * extmod/modtime.c 里由 MICROPY_PY_TIME_GMTIME_LOCALTIME_MKTIME 控制，而其中
 * 「不带参数」的 localtime 要拿**当前时间**，MicroPython 把这件事留给 port：
 *
 *     static mp_obj_t time_localtime(...) {
 *         if (n_args == 0 || args[0] == mp_const_none) {
 *             return mp_time_localtime_get();   // ← 这里
 *         }
 *
 * py/ 和 extmod/ 里都没有它的声明，上游每个 MCU port 都自己实现一份
 * （ports/esp8266/modtime.c、ports/esp32/modtime.c ... 都是这么写的）。
 * 不提供的话报的是这两条，看起来像别的问题：
 *
 *     error: call to undeclared function 'mp_time_localtime_get'
 *     error: incompatible integer to pointer conversion returning 'int'
 *            from a function with result type 'mp_obj_t' (aka 'void *')
 *
 * 实现说明
 * --------
 * 直接问 libc 要本地时间（localtime_r 会套用设备时区），然后按 MicroPython 的
 * 约定拼 8 元组。注意两个约定跟 libc 不一样，必须转换：
 *
 *   tm_wday  libc 周日=0；MicroPython 周一=0（转换方式和 ports/unix/modtime.c 一致）
 *   tm_yday  libc 从 0 开始；MicroPython 从 1 开始
 *
 * 顺带一提：`time.localtime(secs)`（带参数）走的是 shared/timeutils 的纯算术
 * 换算，不经过这里，也不套用时区。这是 MicroPython 本身的行为，不是我们引入的。
 */

#include <time.h>

#include "py/obj.h"
#include "py/runtime.h"

// Return the localtime as an 8-tuple:
// (year, month, mday, hour, minute, second, weekday, yearday)
static mp_obj_t mp_time_localtime_get(void) {
    time_t now = time(NULL);
    struct tm tm;
    localtime_r(&now, &tm);

    // libc 的 tm_wday 是周日=0，MicroPython 要周一=0。
    int wday = tm.tm_wday - 1;
    if (wday < 0) {
        wday = 6;
    }

    mp_obj_t tuple[8] = {
        mp_obj_new_int(tm.tm_year + 1900),
        mp_obj_new_int(tm.tm_mon + 1),
        mp_obj_new_int(tm.tm_mday),
        mp_obj_new_int(tm.tm_hour),
        mp_obj_new_int(tm.tm_min),
        mp_obj_new_int(tm.tm_sec),
        mp_obj_new_int(wday),
        mp_obj_new_int(tm.tm_yday + 1),
    };
    return mp_obj_new_tuple(8, tuple);
}

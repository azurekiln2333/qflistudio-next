/*
 * MicroPython 在 HarmonyOS 上的 HAL 头文件。
 *
 * 这个文件是被 `MICROPY_MPHALPORT_H`（见 mpconfigport.h）点名、再由
 * py/mphal.h 用 `#include MICROPY_MPHALPORT_H` 拉进来的。它和
 * src/qfli_py_hal.c 是一对：头文件放内联的小东西，.c 放真正要链接的函数。
 */
#ifndef QFLI_PY_MPHALPORT_H
#define QFLI_PY_MPHALPORT_H

/*
 * 定义成空的，让 py/mphal.h 跳过 `#include "extmod/virtpin.h"` 那一支。
 * 我们没有 GPIO 这一层，不需要「虚拟引脚」。
 * 上游 ports/embed/port/mphalport.h 就只干这一件事。
 */
#define mp_hal_pin_obj_t

/*
 * input() 的实现钩子。
 *
 * py/modbuiltins.c 第 217-219 行：
 *     // A port can define mp_hal_readline if they want to use a custom function here
 *     #ifndef mp_hal_readline
 *     #define mp_hal_readline readline
 * 也就是说，不定义它就会去链 shared/readline/readline.c 里的 readline()，
 * 而那会连带把整个行编辑器（还有 pyexec）拖进 embed 包。我们不需要行编辑
 * ——App 的模型是「一次性喂一段标准输入」，所以自己实现一个只认换行的版本。
 *
 * 语义跟上游一致：读一行塞进 vstr（不含结尾换行），返回 0；
 * 输入耗尽返回 -1（调用方据此抛 EOFError）。
 *
 * 注意这里必须写成 `#define mp_hal_readline mp_hal_readline` 的形式：
 * 光定义 static inline 函数，`#ifndef` 依然成立，宏会把它覆盖成 readline()。
 * ports/unix/mphalport.h 第 56 行也是这么写的。
 */
#if MICROPY_PY_BUILTINS_INPUT

#include "py/misc.h"

int qfli_py_hal_readline(vstr_t *vstr);

#define mp_hal_readline mp_hal_readline
static inline int mp_hal_readline(vstr_t *vstr, const char *p) {
    /* 提示语由 qfli_py_hal.c 在读取前写到输出流，这里不重复打印。 */
    (void)p;
    return qfli_py_hal_readline(vstr);
}

#endif /* MICROPY_PY_BUILTINS_INPUT */

#endif /* QFLI_PY_MPHALPORT_H */

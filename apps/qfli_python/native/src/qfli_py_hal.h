/*
 * 桥接层（qfli_py_bridge.c）和 HAL 层（qfli_py_hal.c）之间的内部接口。
 *
 * 为什么不学 C 版那样把 extern 声明写在 .c 里：这里要来回用的函数有好几个，
 * 分散声明太容易在改签名时漏掉一处，然后就是「链接期才发现」或者更糟——
 * 参数对不上但类型恰好兼容，运行时才出问题。一个头文件能挡住这类错。
 */
#ifndef QFLI_PY_HAL_H
#define QFLI_PY_HAL_H

#include <stddef.h>

/*
 * 输出有两条去处。Python 程序自己的 print 走 stdout；未捕获异常的 traceback
 * 走 stderr。分开的理由和 C 版一样：App 要把「程序输出」和「报错」显示成两个
 * 不同的区域，混在一条流里就分不开了。
 *
 * 这里比 C 版省事：picoc 把编译诊断和程序输出写进同一条流，所以它得靠
 * 「记下标记点、出错后再截断」把两者摘开；MicroPython 本来就是分开的——
 * 语法错误是抛异常，由桥接层打到 stderr。所以不需要截断接口。
 */
typedef enum {
    QFLI_PY_SINK_STDOUT = 0,
    QFLI_PY_SINK_STDERR = 1,
} qfli_py_sink_t;

/* 清空两条输出流，并把整段标准输入交给 HAL。每次运行前调一次。 */
void qfli_py_hal_reset(const char *stdin_text);

/* 切换后续输出的去向。 */
void qfli_py_hal_set_sink(qfli_py_sink_t sink);

/* 两条输出流的内容，NUL 结尾，永不为 NULL。 */
const char *qfli_py_hal_stdout(void);
const char *qfli_py_hal_stderr(void);

/* 是否发生过截断（输出超过内部上限）。 */
int qfli_py_hal_truncated(void);

#endif /* QFLI_PY_HAL_H */

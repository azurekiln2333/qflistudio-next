/*
 * QFLIStudio+ Python 版的执行后端接口（内嵌 MicroPython）。
 *
 * 这是 Dart 解释器之外的**唯一**执行路径：把 MicroPython 整个编进 .so，进程内
 * 解释执行。之所以不像 C 版那样再留一个纯 Dart 的备选，是因为 Python 的语义
 * 面比 C 大太多——手写子集解释器在「能跑」和「结果对」之间有巨大鸿沟，而错误
 * 的中间地带（看起来跑通了、结果和真 Python 不一样）对教学是最坏的情况。
 *
 * 契约很简单：给一段源码 + 一段标准输入，同步跑完，拿回输出和退出码。
 * 所有输出缓冲由本模块 malloc，调用方用 qfli_py_result_free() 释放。
 */
#ifndef QFLI_PY_BRIDGE_H
#define QFLI_PY_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    /*
     * 退出码。规则和 CPython 一致：
     *   0   正常跑完，或 sys.exit() / sys.exit(0) / sys.exit(None)
     *   n   sys.exit(n) 里的 n
     *   1   有未捕获异常，或 sys.exit("非整数原因")
     */
    int exit_code;
    /* 程序写到 stdout 的全部内容，NUL 结尾。永不为 NULL（可能是空串）。 */
    char *output;
    /*
     * 未捕获异常的 traceback，NUL 结尾。没有错误时为 NULL。
     *
     * 注意语法错误（SyntaxError）也走这里——它在 MicroPython 里同样是异常，
     * 在编译阶段抛出，被同一层 nlr 接住。所以 Dart 侧不需要为「编译失败」
     * 单独开一条路径。
     */
    char *error;
    /* 输出超过内部上限而被截断时为 1（stdout 或 stderr 任一条）。 */
    int truncated;
} QfliPyRunResult;

/*
 * 同步运行一次。
 *
 * source     : Python 源码。UTF-8，NUL 结尾。整个脚本作为一个模块执行。
 * stdin_text : 程序的全部标准输入（input() / sys.stdin 的数据源）。
 *              传 NULL 表示空输入，此时 input() 抛 EOFError。
 * heap_kb    : MicroPython GC 堆的大小（KB）。传 0 用默认值（8MB）。
 *              申请不到时会自动逐级减半，直到 1MB。
 *
 * 返回值的 output 一定非 NULL；error 可能为 NULL。
 */
QfliPyRunResult qfli_py_run(const char *source, const char *stdin_text, int heap_kb);

/* 释放 qfli_py_run 返回的两个缓冲区。可以安全地对 NULL 调用。 */
void qfli_py_result_free(QfliPyRunResult *result);

/*
 * 内嵌的 MicroPython 版本，形如 "1.24.1 (ecfdd5d)"。
 *
 * 返回的是**静态字符串**，调用方不要 free，也不要写。
 *
 * 存在的意义是自证：这个后端到底是上游 MicroPython 编出来的，还是自己拼的
 * 一个「看起来像 Python」的东西，用这个函数就能直接看出来。版本号和 git
 * hash 都是编译期从 py/mpconfig.h 和 genhdr/mpversion.h 里取的真值，
 * 不是我们手写的常量。
 */
const char *qfli_py_version(void);

#ifdef __cplusplus
}
#endif

#endif /* QFLI_PY_BRIDGE_H */

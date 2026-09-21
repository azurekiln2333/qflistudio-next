/*
 * QFLIForge的原生执行后端（picoc）。
 *
 * 这是 Dart 解释器之外的「可选加速路径」：同样是进程内解释执行，只是把
 * 解释器换成 C 写的 picoc，跑得快一些。默认不启用——Dart 解释器不需要
 * NDK、不需要按 ABI 出多个 .so，覆盖面也够教学用；只有当你想压榨性能或
 * 需要 picoc 的某些语义时，才在构建里打开这条路径。
 *
 * 契约很简单：给一组源文件路径 + 一段标准输入，同步跑完，拿回输出和退出码。
 * 所有输出缓冲由本模块 malloc，调用方用 qfli_c_result_free() 释放。
 */
#ifndef QFLI_C_BRIDGE_H
#define QFLI_C_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    /* main() 的返回值；被 exit() 中断时就是 exit 的参数。 */
    int exit_code;
    /* 程序写到 stdout 的全部内容，NUL 结尾。永不为 NULL。 */
    char *output;
    /* 编译/运行时错误的说明，NUL 结尾。没有错误时为 NULL。 */
    char *error;
    /* 输出超过内部缓冲上限而被截断时为 1。 */
    int truncated;
} QfliCRunResult;

/*
 * 同步运行一次。
 *
 * files     : .c 源文件路径数组，按顺序扫描（第一个应当是含 main() 的那个）。
 * count     : 数组长度。
 * work_dir  : 运行前切换到的目录，让 `#include "utils.h"` 能按相对路径找到
 *             同目录的头文件。传 NULL 表示不切换。
 * stdin_text: 程序的全部标准输入。传 NULL 表示空输入。
 * stack_size: picoc 的栈大小（字节）。传 0 用默认值。
 *
 * 返回值的 output 一定非 NULL（可能是空串）；error 可能为 NULL。
 */
QfliCRunResult qfli_c_run(const char *const *files,
                          int count,
                          const char *work_dir,
                          const char *stdin_text,
                          int stack_size);

/* 释放 qfli_c_run 返回的两个缓冲区。可以安全地对 NULL 调用。 */
void qfli_c_result_free(QfliCRunResult *result);

#ifdef __cplusplus
}
#endif

#endif /* QFLI_C_BRIDGE_H */

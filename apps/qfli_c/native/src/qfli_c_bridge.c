/*
 * picoc 驱动：把「一组源文件 + 一段标准输入」跑完，拿回输出和退出码。
 *
 * 调用序列照抄 picoc 自己的 main()（picoc.c），只去掉交互模式：
 *
 *   PicocInitialise
 *   PicocPlatformSetExitPoint      —— 记下 longjmp 落点
 *   逐个 PicocPlatformScanFile     —— 预处理 + 解析 + 执行顶层代码
 *   PicocCallMain                  —— 调用 main()
 *   PicocCleanup
 *
 * 语法错误和程序里调 exit() 都会 longjmp 回同一个落点，所以「有没有进过
 * main」这个信息必须存在跨 setjmp 的变量里；而 C 标准规定这类局部变量必须
 * 声明为 volatile，否则 longjmp 之后它们的值是不确定的。
 */
#include "qfli_c_bridge.h"

#include "../third_party/picoc/picoc.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/* picoc 平台层里的输出/输入缓冲，实现在 platform_ohos.c。 */
void QfliCPlatformReset(const char *stdin_text);
const char *QfliCPlatformOutput(void);
int QfliCPlatformTruncated(void);
size_t QfliCPlatformOutputLength(void);
void QfliCPlatformTruncate(size_t length);

#define QFLI_C_DEFAULT_STACK (256 * 1024)

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

static QfliCRunResult empty_result(void)
{
    QfliCRunResult result;

    result.exit_code = 0;
    result.error = NULL;
    result.truncated = 0;
    result.output = duplicate_string("");
    return result;
}

QfliCRunResult qfli_c_run(const char *const *files,
                          int count,
                          const char *work_dir,
                          const char *stdin_text,
                          int stack_size)
{
    QfliCRunResult result = empty_result();
    Picoc pc;
    char *saved_dir = NULL;
    int index;

    /* 这两个变量跨越 setjmp/longjmp，必须 volatile。 */
    volatile int reached_main = 0;
    volatile size_t mark = 0;

    if (result.output == NULL)
        return result;

    if (files == NULL || count <= 0)
    {
        result.exit_code = 1;
        result.error = duplicate_string("没有可运行的源文件。");
        return result;
    }

    /*
     * `#include "utils.h"` 由 picoc 按进程当前目录解析（它不记录「包含者」
     * 所在的目录），所以先把工作目录切到工程根，跑完再切回来。
     */
    if (work_dir != NULL)
    {
        saved_dir = getcwd(NULL, 0);
        if (chdir(work_dir) != 0)
        {
            free(saved_dir);
            saved_dir = NULL;
        }
    }

    QfliCPlatformReset(stdin_text);

    PicocInitialise(&pc, stack_size > 0 ? stack_size : QFLI_C_DEFAULT_STACK);

    if (PicocPlatformSetExitPoint(&pc))
    {
        /*
         * 从 longjmp 回来了。还没进过 main 就跳出来，说明是编译期错误
         * （语法错误、找不到头文件、没有 main）。picoc 把诊断信息写在了
         * 输出流的末尾，按标记点摘出来当 error，剩下的才是程序输出。
         */
        if (!reached_main && pc.PicocExitValue != 0)
        {
            result.error = duplicate_string(QfliCPlatformOutput() + mark);
            QfliCPlatformTruncate(mark);
        }
        result.exit_code = pc.PicocExitValue;
    }
    else
    {
        for (index = 0; index < count; index++)
        {
            mark = QfliCPlatformOutputLength();
            PicocPlatformScanFile(&pc, files[index]);
        }

        /* 全部扫完，接下来才是 main()。此后 longjmp 都算程序的正常退出。 */
        reached_main = 1;
        mark = QfliCPlatformOutputLength();

        {
            char **argv = (char **)malloc(sizeof(char *) * 2);
            if (argv == NULL)
            {
                result.exit_code = 1;
                result.error = duplicate_string("out of memory\n");
            }
            else
            {
                argv[0] = (char *)files[0];
                argv[1] = NULL;
                PicocCallMain(&pc, 1, argv);
                free(argv);
                result.exit_code = pc.PicocExitValue;
            }
        }
    }

    result.truncated = QfliCPlatformTruncated();

    {
        char *output = duplicate_string(QfliCPlatformOutput());
        if (output != NULL)
        {
            free(result.output);
            result.output = output;
        }
    }

    PicocCleanup(&pc);

    if (saved_dir != NULL)
    {
        chdir(saved_dir);
        free(saved_dir);
    }

    return result;
}

void qfli_c_result_free(QfliCRunResult *result)
{
    if (result == NULL)
        return;
    free(result->output);
    free(result->error);
    result->output = NULL;
    result->error = NULL;
}

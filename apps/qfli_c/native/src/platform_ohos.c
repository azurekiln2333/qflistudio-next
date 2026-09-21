/*
 * picoc 在 HarmonyOS 上的平台层。
 *
 * picoc 把所有「跟操作系统打交道」的部分收敛成 interpreter.h 里的几个
 * Platform* 声明，所以移植到新平台只需要实现这几个函数：
 *
 *   PlatformInit / PlatformCleanup   初始化与收尾
 *   PlatformGetLine / GetCharacter   读标准输入
 *   PlatformPutc                     写标准输出 —— 我们在这里截获输出
 *   PlatformExit                     结束程序（longjmp 回调用点）
 *   PicocPlatformScanFile            读入一个源文件
 *   PlatformLibraryInit              注册平台专有函数（本移植不需要）
 *
 * 刻意不复用 picoc 自带的 platform_unix.c：那个文件依赖 GNU readline，
 * HarmonyOS 的 NDK 里没有这个库。
 */
#include "../third_party/picoc/picoc.h"
#include "../third_party/picoc/interpreter.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* 输出上限。教学程序的输出远小于这个数；超了就截断并打标记，
 * 免得一个死循环把设备内存写爆。 */
#define QFLI_C_MAX_OUTPUT (256 * 1024)

static char g_output[QFLI_C_MAX_OUTPUT];
static size_t g_output_length = 0;
static int g_output_truncated = 0;

/* 标准输入：整段一次性给进来，按字节推进。 */
static const char *g_stdin_text = NULL;
static size_t g_stdin_length = 0;
static size_t g_stdin_pos = 0;

/* ---- 供 qfli_c_bridge.c 使用的内部接口 ---- */

void QfliCPlatformReset(const char *stdin_text)
{
    g_output_length = 0;
    g_output[0] = '\0';
    g_output_truncated = 0;
    g_stdin_text = stdin_text;
    g_stdin_length = (stdin_text == NULL) ? 0 : strlen(stdin_text);
    g_stdin_pos = 0;
}

const char *QfliCPlatformOutput(void)
{
    return g_output;
}

int QfliCPlatformTruncated(void)
{
    return g_output_truncated;
}

size_t QfliCPlatformOutputLength(void)
{
    return g_output_length;
}

/*
 * 把输出截到 Length 字节。
 *
 * picoc 的编译期错误（ProgramFail / LexFail）和程序的正常输出走的是同一个
 * 流，分不开。所以调用方在每一步开始前记下长度，出错后再把标记点之后的内容
 * 摘出来当错误信息 —— 这样 stdout 和诊断信息就分得干干净净。
 */
void QfliCPlatformTruncate(size_t Length)
{
    if (Length >= g_output_length)
        return;
    g_output_length = Length;
    g_output[Length] = '\0';
}

/* ---- picoc 平台接口 ---- */

void PlatformInit(Picoc *pc)
{
    (void)pc;
    /* 不装信号处理器：手机上不该让解释器自己抢 SIGINT。 */
}

void PlatformCleanup(Picoc *pc)
{
    (void)pc;
}

/* 读一整行到 Buf；没有更多输入时返回 NULL。 */
char *PlatformGetLine(char *Buf, int MaxLen, const char *Prompt)
{
    (void)Prompt;
    int written = 0;

    if (Buf == NULL || MaxLen <= 0)
        return NULL;

    while (written < MaxLen - 1)
    {
        char ch;

        if (g_stdin_pos >= g_stdin_length)
        {
            /* 一个字符都没读到就是 EOF；读到半行则当作最后一行返回。 */
            if (written == 0)
                return NULL;
            break;
        }

        ch = g_stdin_text[g_stdin_pos++];
        Buf[written++] = ch;
        if (ch == '\n')
            break;
    }

    Buf[written] = '\0';
    return Buf;
}

/* 读一个字符；输入耗尽返回 EOF。 */
int PlatformGetCharacter()
{
    if (g_stdin_pos >= g_stdin_length)
        return EOF;
    return (int)(unsigned char)g_stdin_text[g_stdin_pos++];
}

/* 写一个字符到控制台。所有 printf/puts 最终都汇聚到这里。 */
void PlatformPutc(unsigned char OutCh, union OutputStreamInfo *Stream)
{
    (void)Stream;
    if (g_output_length + 1 < QFLI_C_MAX_OUTPUT)
    {
        g_output[g_output_length++] = (char)OutCh;
        g_output[g_output_length] = '\0';
    }
    else
    {
        g_output_truncated = 1;
    }
}

/* 结束程序：把返回值交给 longjmp，跳回 qfli_c_run 里的 setjmp 点。 */
void PlatformExit(Picoc *pc, int ExitVal)
{
    pc->PicocExitValue = ExitVal;
    longjmp(pc->PicocExitBuf, 1);
}

/* 读入并执行一个源文件。 */
void PicocPlatformScanFile(Picoc *pc, const char *FileName)
{
    FILE *file;
    long size;
    char *text;
    size_t read_count;

    file = fopen(FileName, "rb");
    if (file == NULL)
    {
        ProgramFailNoParser(pc, "can't read file %s\n", FileName);
        return;
    }

    if (fseek(file, 0, SEEK_END) != 0)
    {
        fclose(file);
        ProgramFailNoParser(pc, "can't read file %s\n", FileName);
        return;
    }
    size = ftell(file);
    if (size < 0)
    {
        fclose(file);
        ProgramFailNoParser(pc, "can't read file %s\n", FileName);
        return;
    }
    rewind(file);

    text = (char *)malloc((size_t)size + 1);
    if (text == NULL)
    {
        fclose(file);
        ProgramFailNoParser(pc, "out of memory\n");
        return;
    }

    read_count = fread(text, 1, (size_t)size, file);
    fclose(file);
    text[read_count] = '\0';

    /*
     * CleanupNow = FALSE：保留这次解析出来的定义，后面才能调用 main()。
     * CleanupSource = TRUE：把 text 的所有权交给 picoc，它在 PicocCleanup
     * 时统一释放 —— 所以这里不要自己 free。
     * EnableDebugger = FALSE：手机上不需要交互式调试器。
     */
    PicocParse(pc, FileName, text, (int)read_count, TRUE, FALSE, TRUE, FALSE);
}

/* 注册平台专有函数。HarmonyOS 上没有要额外暴露给脚本的东西。 */
void PlatformLibraryInit(Picoc *pc)
{
    (void)pc;
}

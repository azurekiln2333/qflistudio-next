/// 内置的「虚拟头文件」。
///
/// 手机上没有 `/usr/include`，所以标准库头文件由运行时内置。内容只包含
/// 类型、宏和函数原型；函数本体在 [CBuiltins] 里以原生实现注册。
/// 原型的作用是让 `double sqrt(double)` 这类调用拿到正确的返回类型，
/// 而不是按隐式声明的 `int` 处理。
library;

const String _stdioHeader = r'''
typedef unsigned long size_t;
typedef struct _IO_FILE FILE;

#define EOF (-1)
#define NULL ((void *)0)
#define SEEK_SET 0
#define SEEK_CUR 1
#define SEEK_END 2
#define BUFSIZ 8192
#define FILENAME_MAX 4096

#define stdin  ((FILE *)0)
#define stdout ((FILE *)1)
#define stderr ((FILE *)2)

int printf(const char *format, ...);
int fprintf(FILE *stream, const char *format, ...);
int sprintf(char *str, const char *format, ...);
int snprintf(char *str, size_t size, const char *format, ...);
int puts(const char *s);
int fputs(const char *s, FILE *stream);
int putchar(int c);
int getchar(void);
int ungetc(int c, FILE *stream);
char *gets(char *s);
char *fgets(char *s, int size, FILE *stream);
int scanf(const char *format, ...);
int sscanf(const char *str, const char *format, ...);
int fscanf(FILE *stream, const char *format, ...);
int fflush(FILE *stream);
int remove(const char *filename);
''';

const String _stdlibHeader = r'''
typedef unsigned long size_t;

#define NULL ((void *)0)
#define EXIT_SUCCESS 0
#define EXIT_FAILURE 1
#define RAND_MAX 2147483647

void *malloc(size_t size);
void *calloc(size_t nmemb, size_t size);
void *realloc(void *ptr, size_t size);
void free(void *ptr);
void exit(int status);
void abort(void);
int atoi(const char *nptr);
long atol(const char *nptr);
double atof(const char *nptr);
long strtol(const char *nptr, char **endptr, int base);
double strtod(const char *nptr, char **endptr);
int abs(int j);
long labs(long j);
int rand(void);
void srand(unsigned int seed);
''';

const String _stringHeader = r'''
typedef unsigned long size_t;

#define NULL ((void *)0)

size_t strlen(const char *s);
char *strcpy(char *dest, const char *src);
char *strncpy(char *dest, const char *src, size_t n);
char *strcat(char *dest, const char *src);
char *strncat(char *dest, const char *src, size_t n);
int strcmp(const char *s1, const char *s2);
int strncmp(const char *s1, const char *s2, size_t n);
char *strchr(const char *s, int c);
char *strrchr(const char *s, int c);
char *strstr(const char *haystack, const char *needle);
void *memset(void *s, int c, size_t n);
void *memcpy(void *dest, const void *src, size_t n);
void *memmove(void *dest, const void *src, size_t n);
int memcmp(const void *s1, const void *s2, size_t n);
char *strdup(const char *s);
''';

const String _mathHeader = r'''
double sqrt(double x);
double cbrt(double x);
double pow(double x, double y);
double fabs(double x);
double floor(double x);
double ceil(double x);
double round(double x);
double trunc(double x);
double fmod(double x, double y);
double sin(double x);
double cos(double x);
double tan(double x);
double asin(double x);
double acos(double x);
double atan(double x);
double atan2(double y, double x);
double sinh(double x);
double cosh(double x);
double tanh(double x);
double log(double x);
double log10(double x);
double log2(double x);
double exp(double x);
double hypot(double x, double y);
double fmin(double x, double y);
double fmax(double x, double y);
double ldexp(double x, int exp);
double modf(double x, double *iptr);

#define M_PI 3.14159265358979323846
#define M_E 2.7182818284590452354
#define M_SQRT2 1.41421356237309504880
#define HUGE_VAL (1.0 / 0.0)
''';

const String _ctypeHeader = r'''
int isalpha(int c);
int isdigit(int c);
int isalnum(int c);
int isspace(int c);
int isupper(int c);
int islower(int c);
int ispunct(int c);
int isxdigit(int c);
int isprint(int c);
int iscntrl(int c);
int toupper(int c);
int tolower(int c);
''';

const String _stdboolHeader = r'''
#define bool _Bool
#define true 1
#define false 0
#define __bool_true_false_are_defined 1
''';

const String _limitsHeader = r'''
#define CHAR_BIT 8
#define SCHAR_MIN (-128)
#define SCHAR_MAX 127
#define UCHAR_MAX 255
#define CHAR_MIN (-128)
#define CHAR_MAX 127
#define SHRT_MIN (-32768)
#define SHRT_MAX 32767
#define USHRT_MAX 65535
#define INT_MIN (-2147483647 - 1)
#define INT_MAX 2147483647
#define UINT_MAX 4294967295U
#define LONG_MIN (-9223372036854775807L - 1)
#define LONG_MAX 9223372036854775807L
#define ULONG_MAX 18446744073709551615UL
#define LLONG_MIN (-9223372036854775807LL - 1)
#define LLONG_MAX 9223372036854775807LL
#define ULLONG_MAX 18446744073709551615ULL
''';

const String _stdintHeader = r'''
typedef signed char int8_t;
typedef unsigned char uint8_t;
typedef short int16_t;
typedef unsigned short uint16_t;
typedef int int32_t;
typedef unsigned int uint32_t;
typedef long int64_t;
typedef unsigned long uint64_t;
typedef long intptr_t;
typedef unsigned long uintptr_t;
typedef long intmax_t;
typedef unsigned long uintmax_t;

#define INT8_MAX 127
#define INT8_MIN (-128)
#define UINT8_MAX 255
#define INT16_MAX 32767
#define INT16_MIN (-32768)
#define UINT16_MAX 65535
#define INT32_MAX 2147483647
#define INT32_MIN (-2147483647 - 1)
#define UINT32_MAX 4294967295U
#define INT64_MAX 9223372036854775807L
#define INT64_MIN (-9223372036854775807L - 1)
#define UINT64_MAX 18446744073709551615UL
''';

const String _stddefHeader = r'''
typedef unsigned long size_t;
typedef long ptrdiff_t;
typedef long intptr_t;
typedef unsigned long uintptr_t;

#define NULL ((void *)0)
#define offsetof(type, member) ((size_t) &(((type *)0)->member))
''';

const String _timeHeader = r'''
typedef long time_t;
typedef long clock_t;

#define CLOCKS_PER_SEC 1000000

time_t time(time_t *tloc);
clock_t clock(void);
''';

const String _assertHeader = r'''
void __assert_fail(const char *expr, const char *file, int line);

#define assert(expr) ((expr) ? (void)0 : __assert_fail(#expr, __FILE__, __LINE__))
''';

/// 头文件名 → 内容。键同时支持 `<...>` 与 `"..."` 两种写法。
const Map<String, String> kVirtualHeaders = {
  'stdio.h': _stdioHeader,
  'stdlib.h': _stdlibHeader,
  'string.h': _stringHeader,
  'math.h': _mathHeader,
  'ctype.h': _ctypeHeader,
  'stdbool.h': _stdboolHeader,
  'limits.h': _limitsHeader,
  'stdint.h': _stdintHeader,
  'stddef.h': _stddefHeader,
  'time.h': _timeHeader,
  'assert.h': _assertHeader,
};

/// 常见的兼容别名，直接映射到已有头文件。
const Map<String, String> kHeaderAliases = {
  'strings.h': 'string.h',
  'memory.h': 'string.h',
  'sys/types.h': 'stddef.h',
  'stdarg.h': 'stddef.h',
};

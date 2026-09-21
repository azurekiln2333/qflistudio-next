import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_c_runtime/qfli_c_runtime.dart';

/// 跑一段 C 源码，断言输出。
///
/// [timeLimit] / [maxSteps] 默认与生产一致；测「跑飞了」的用例会传很短的上限，
/// 免得一个用例就卡住十秒。
Future<CRunResult> run(
  String source, {
  Map<String, String> files = const {},
  List<String> stdinLines = const [],
  Duration timeLimit = kDefaultTimeLimit,
  int maxSteps = kDefaultMaxSteps,
}) => runCSource(
  source: source,
  files: files,
  stdinLines: stdinLines,
  timeLimit: timeLimit,
  maxSteps: maxSteps,
  useIsolate: false,
);

void main() {
  group('基础', () {
    test('Hello World', () async {
      final result = await run('''
#include <stdio.h>

int main(void) {
    printf("Hello, QFLIStudio+!\\n");
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.exitCode, 0);
      expect(result.output, 'Hello, QFLIStudio+!\n');
    });

    test('main 的返回值就是退出码', () async {
      final result = await run('int main(void) { return 42; }');
      expect(result.error, isNull);
      expect(result.exitCode, 42);
    });

    test('注释与续行', () async {
      final result = await run('''
#include <stdio.h>
/* 块注释
   跨行 */
int main(void) {
    // 行注释
    int a = 1 + \\
            2;
    printf("%d", a);
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, '3');
    });
  });

  group('运算与格式化', () {
    test('整数与浮点格式', () async {
      final result = await run('''
#include <stdio.h>
int main(void) {
    printf("%d %5d|%-5d|%05d\\n", 42, 42, 42, 42);
    printf("%x %X %o %u\\n", 255, 255, 8, 4000000000u);
    printf("%.2f %.3e\\n", 3.14159, 1234.5);
    printf("%c%c%c\\n", 'a', 'b', 'c');
    printf("%s|%.3s\\n", "hello", "hello");
    printf("%%\\n");
    return 0;
}
''');
      expect(result.error, isNull);
      final lines = result.output.trim().split('\n');
      expect(lines[0], '42    42|42   |00042');
      expect(lines[1], 'ff FF 10 4000000000');
      expect(lines[2], '3.14 1.235e+03');
      expect(lines[3], 'abc');
      expect(lines[4], 'hello|hel');
      expect(lines[5], '%');
    });

    test('整数除法与取模、自增自减', () async {
      final result = await run('''
#include <stdio.h>
int main(void) {
    int a = 7, b = 2;
    printf("%d %d %d\\n", a / b, a % b, a * b);
    int i = 5;
    printf("%d %d %d\\n", i++, i, ++i);
    int j = 10;
    j += 5; j *= 2; j -= 3; j /= 3;
    printf("%d\\n", j);
    return 0;
}
''');
      expect(result.error, isNull);
      // j = 10 -> +5 = 15 -> *2 = 30 -> -3 = 27 -> /3 = 9
      expect(result.output, '3 1 14\n5 6 7\n9\n');
    });

    test('位运算与移位', () async {
      final result = await run('''
#include <stdio.h>
int main(void) {
    printf("%d %d %d %d\\n", 12 & 10, 12 | 10, 12 ^ 10, ~0);
    printf("%d %d\\n", 1 << 4, 256 >> 2);
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, '8 14 6 -1\n16 64\n');
    });

    test('sizeof 反映 LP64 布局', () async {
      final result = await run('''
#include <stdio.h>
struct Point { int x; int y; };
int main(void) {
    printf("%d %d %d %d %d\\n",
           (int)sizeof(char), (int)sizeof(short), (int)sizeof(int),
           (int)sizeof(long), (int)sizeof(void *));
    int arr[7];
    printf("%d %d\\n", (int)sizeof(arr), (int)(sizeof(arr) / sizeof(arr[0])));
    printf("%d\\n", (int)sizeof(struct Point));
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, '1 2 4 8 8\n28 7\n8\n');
    });
  });

  group('控制流', () {
    test('for / while / do-while', () async {
      final result = await run('''
#include <stdio.h>
int main(void) {
    int sum = 0;
    for (int i = 1; i <= 10; i++) sum += i;
    printf("%d\\n", sum);

    int n = 3;
    while (n > 0) { printf("%d", n); n--; }
    printf("\\n");

    int k = 0;
    do { printf("%d", k); k++; } while (k < 3);
    printf("\\n");
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, '55\n321\n012\n');
    });

    test('break / continue', () async {
      final result = await run('''
#include <stdio.h>
int main(void) {
    for (int i = 0; i < 10; i++) {
        if (i == 5) break;
        if (i % 2 == 0) continue;
        printf("%d", i);
    }
    printf("\\n");
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, '13\n');
    });

    test('switch 含穿透与 default', () async {
      final result = await run('''
#include <stdio.h>
int main(void) {
    for (int i = 0; i < 4; i++) {
        switch (i) {
            case 0: printf("zero "); break;
            case 1:
            case 2: printf("small "); break;
            default: printf("other ");
        }
    }
    printf("\\n");
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, 'zero small small other \n');
    });

    test('goto 跳出多层循环', () async {
      final result = await run('''
#include <stdio.h>
int main(void) {
    for (int i = 0; i < 5; i++) {
        for (int j = 0; j < 5; j++) {
            if (i * j == 6) goto done;
        }
    }
done:
    printf("done\\n");
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, 'done\n');
    });

    test('三元与短路求值', () async {
      final result = await run('''
#include <stdio.h>
int side = 0;
int bump(void) { side++; return 1; }
int main(void) {
    printf("%d\\n", 1 ? 10 : 20);
    if (0 && bump()) {}
    if (1 || bump()) {}
    printf("%d\\n", side);
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, '10\n0\n');
    });
  });

  group('函数', () {
    test('递归：斐波那契', () async {
      final result = await run('''
#include <stdio.h>

int fib(int n) {
    if (n < 2) return n;
    return fib(n - 1) + fib(n - 2);
}

int main(void) {
    for (int i = 0; i < 10; i++) printf("%d ", fib(i));
    printf("\\n");
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, '0 1 1 2 3 5 8 13 21 34 \n');
    });

    test('值传递：被调用者改不动调用者', () async {
      final result = await run('''
#include <stdio.h>
void swap(int a, int b) { int t = a; a = b; b = t; }
int main(void) {
    int x = 1, y = 2;
    swap(x, y);
    printf("%d %d\\n", x, y);
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, '1 2\n');
    });

    test('指针参数可以改调用者', () async {
      final result = await run('''
#include <stdio.h>
void swap(int *a, int *b) { int t = *a; *a = *b; *b = t; }
int main(void) {
    int x = 1, y = 2;
    swap(&x, &y);
    printf("%d %d\\n", x, y);
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, '2 1\n');
    });

    test('函数原型支持先调用后定义', () async {
      final result = await run('''
#include <stdio.h>
double half(double x);
int main(void) {
    printf("%.2f\\n", half(7.0));
    return 0;
}
double half(double x) { return x / 2; }
''');
      expect(result.error, isNull);
      expect(result.output, '3.50\n');
    });

    test('函数指针', () async {
      final result = await run('''
#include <stdio.h>
int add(int a, int b) { return a + b; }
int mul(int a, int b) { return a * b; }
int apply(int (*op)(int, int), int a, int b) { return op(a, b); }
int main(void) {
    printf("%d %d\\n", apply(add, 3, 4), apply(mul, 3, 4));
    int (*f)(int, int) = add;
    printf("%d\\n", f(10, 20));
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, '7 12\n30\n');
    });

    test('静态全局变量跨调用保留', () async {
      final result = await run('''
#include <stdio.h>
static int counter = 0;
int next(void) { counter++; return counter; }
int main(void) {
    next(); next();
    printf("%d\\n", next());
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, '3\n');
    });
  });

  group('数组与指针', () {
    test('数组初始化与遍历', () async {
      final result = await run('''
#include <stdio.h>
int main(void) {
    int a[5] = {1, 2, 3, 4, 5};
    int sum = 0;
    for (int i = 0; i < 5; i++) sum += a[i];
    printf("%d\\n", sum);

    int b[] = {10, 20, 30};
    printf("%d %d\\n", (int)sizeof(b), b[2]);
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, '15\n12 30\n');
    });

    test('指针算术与遍历', () async {
      final result = await run('''
#include <stdio.h>
int main(void) {
    int a[4] = {10, 20, 30, 40};
    int *p = a;
    printf("%d %d %d\\n", *p, *(p + 1), *(p + 3));
    p++;
    printf("%d\\n", *p);
    printf("%d\\n", (int)(&a[3] - &a[0]));
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, '10 20 40\n20\n3\n');
    });

    test('二维数组', () async {
      final result = await run('''
#include <stdio.h>
int main(void) {
    int grid[2][3] = {{1, 2, 3}, {4, 5, 6}};
    int sum = 0;
    for (int i = 0; i < 2; i++)
        for (int j = 0; j < 3; j++)
            sum += grid[i][j];
    printf("%d\\n", sum);
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, '21\n');
    });

    test('字符串字面量与字符数组', () async {
      final result = await run('''
#include <stdio.h>
#include <string.h>
int main(void) {
    const char *s = "hello";
    printf("%d\\n", (int)strlen(s));

    char buf[16] = "abc";
    printf("%d %s\\n", (int)strlen(buf), buf);

    char empty[] = "xyz";
    printf("%d\\n", (int)sizeof(empty));
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, '5\n3 abc\n4\n');
    });

    test('取地址与解引用', () async {
      final result = await run('''
#include <stdio.h>
int main(void) {
    int x = 7;
    int *p = &x;
    *p = 99;
    printf("%d %d\\n", x, *p);
    int **pp = &p;
    printf("%d\\n", **pp);
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, '99 99\n99\n');
    });
  });

  group('结构体与内存', () {
    test('结构体、typedef 与箭头运算符', () async {
      final result = await run('''
#include <stdio.h>

typedef struct {
    int x;
    int y;
} Point;

int main(void) {
    Point p;
    p.x = 3;
    p.y = 4;
    printf("%d,%d\\n", p.x, p.y);

    Point *q = &p;
    q->x = 30;
    printf("%d,%d\\n", q->x, q->y);

    Point r = p;
    r.y = 99;
    printf("%d,%d\\n", p.y, r.y);
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, '3,4\n30,4\n4 99\n'.replaceFirst('4 99', '4,99'));
    });

    test('结构体数组与嵌套', () async {
      final result = await run('''
#include <stdio.h>

struct Inner { int v; };
struct Outer { int id; struct Inner inner; };

int main(void) {
    struct Outer items[2];
    items[0].id = 1;
    items[0].inner.v = 10;
    items[1].id = 2;
    items[1].inner.v = 20;
    printf("%d %d\\n", items[0].id + items[1].inner.v,
           items[1].id + items[0].inner.v);
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, '21 12\n');
    });

    test('自引用结构体与链表', () async {
      final result = await run('''
#include <stdio.h>
#include <stdlib.h>

struct Node {
    int value;
    struct Node *next;
};

int main(void) {
    struct Node *head = malloc(sizeof(struct Node));
    head->value = 1;
    head->next = malloc(sizeof(struct Node));
    head->next->value = 2;
    head->next->next = NULL;

    int sum = 0;
    for (struct Node *p = head; p != NULL; p = p->next) sum += p->value;
    printf("%d\\n", sum);

    free(head->next);
    free(head);
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, '3\n');
    });

    test('malloc / free / memset / memcpy', () async {
      final result = await run('''
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(void) {
    int *p = malloc(10 * sizeof(int));
    memset(p, 0, 10 * sizeof(int));
    for (int i = 0; i < 10; i++) p[i] = i * i;
    printf("%d %d\\n", p[3], p[9]);

    int *q = malloc(10 * sizeof(int));
    memcpy(q, p, 10 * sizeof(int));
    printf("%d\\n", q[9]);
    free(p);
    free(q);
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, '9 81\n81\n');
    });

    test('union 共享存储', () async {
      final result = await run('''
#include <stdio.h>
union Value { int i; char bytes[4]; };
int main(void) {
    union Value v;
    v.i = 0;
    v.bytes[0] = 1;
    printf("%d\\n", v.i);
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, '1\n');
    });

    test('enum 与常量', () async {
      final result = await run('''
#include <stdio.h>
enum Color { RED, GREEN = 5, BLUE };
int main(void) {
    printf("%d %d %d\\n", RED, GREEN, BLUE);
    enum Color c = BLUE;
    printf("%d\\n", c == 6);
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, '0 5 6\n1\n');
    });
  });

  group('预处理', () {
    test('对象式与函数式宏', () async {
      final result = await run('''
#include <stdio.h>
#define PI 3.14
#define SQUARE(x) ((x) * (x))
#define MAX(a, b) ((a) > (b) ? (a) : (b))

int main(void) {
    printf("%.2f\\n", PI);
    printf("%d\\n", SQUARE(5));
    printf("%d\\n", MAX(3, 8));
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, '3.14\n25\n8\n');
    });

    test('条件编译', () async {
      final result = await run('''
#include <stdio.h>
#define DEBUG 1
#define VERSION 2

int main(void) {
#ifdef DEBUG
    printf("debug\\n");
#else
    printf("release\\n");
#endif

#if VERSION >= 2
    printf("v2\\n");
#endif

#ifndef MISSING
    printf("no missing\\n");
#endif
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, 'debug\nv2\nno missing\n');
    });

    test('包含项目内头文件', () async {
      final result = await run(
        '''
#include <stdio.h>
#include "utils.h"

int main(void) {
    printf("%d\\n", add(2, 3));
    printf("%d\\n", DOUBLE(21));
    return 0;
}
''',
        files: {
          'utils.h': '''
#ifndef UTILS_H
#define UTILS_H

#define DOUBLE(x) ((x) * 2)

int add(int a, int b);

#endif
''',
          'utils.c': '''
int add(int a, int b) { return a + b; }
''',
        },
      );
      expect(result.error, isNull);
      expect(result.output, '5\n42\n');
    });

    test('字符串化与 __LINE__', () async {
      final result = await run('''
#include <stdio.h>
#define SHOW(expr) printf("%s = %d\\n", #expr, expr)
int main(void) {
    int value = 7;
    SHOW(value);
    printf("%d\\n", __LINE__);
    return 0;
}
''');
      expect(result.error, isNull);
      // __LINE__ 位于第 6 行（Dart 的 ''' 会吞掉紧跟其后的换行）
      expect(result.output, 'value = 7\n6\n');
    });
  });

  group('标准库', () {
    test('字符串函数', () async {
      final result = await run('''
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

int main(void) {
    char buf[32];
    strcpy(buf, "hello");
    strcat(buf, " world");
    printf("%s %d\\n", buf, (int)strlen(buf));
    printf("%d %d\\n", strcmp("abc", "abd"), strcmp("abc", "abc"));

    char *found = strchr(buf, 'w');
    printf("%s\\n", found);
    printf("%d\\n", atoi("123") + 1);
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, 'hello world 11\n-1 0\nworld\n124\n');
    });

    test('数学函数', () async {
      final result = await run('''
#include <stdio.h>
#include <math.h>
int main(void) {
    printf("%.4f\\n", sqrt(2.0));
    printf("%.1f\\n", pow(2.0, 10.0));
    printf("%.1f %.1f\\n", floor(2.7), ceil(2.1));
    printf("%.4f\\n", fabs(-3.5));
    printf("%.4f\\n", fmod(10.0, 3.0));
    printf("%.4f\\n", M_PI);
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, '1.4142\n1024.0\n2.0 3.0\n3.5000\n1.0000\n3.1416\n');
    });

    test('ctype 与字符判断', () async {
      final result = await run('''
#include <stdio.h>
#include <ctype.h>
int main(void) {
    printf("%d %d %d\\n", isalpha('a'), isdigit('7'), isspace(' '));
    printf("%c %c\\n", toupper('q'), tolower('Q'));
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, '1 1 1\nQ q\n');
    });

    test('rand 可复现', () async {
      final result = await run('''
#include <stdio.h>
#include <stdlib.h>
int main(void) {
    srand(42);
    int a = rand();
    srand(42);
    int b = rand();
    printf("%d\\n", a == b);
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, '1\n');
    });

    test('exit 立即结束程序', () async {
      final result = await run('''
#include <stdio.h>
#include <stdlib.h>
int main(void) {
    printf("before\\n");
    exit(3);
    printf("after\\n");
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.exitCode, 3);
      expect(result.output, 'before\n');
    });

    test('sprintf 写入缓冲区', () async {
      final result = await run('''
#include <stdio.h>
int main(void) {
    char buf[64];
    sprintf(buf, "%d-%s-%.1f", 7, "abc", 1.5);
    printf("%s\\n", buf);
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, '7-abc-1.5\n');
    });
  });

  group('scanf', () {
    test('读十进制整数，多个转换共用一次输入', () async {
      final result = await run(
        '''
#include <stdio.h>
int main(void) {
    int a, b;
    int n = scanf("%d %d", &a, &b);
    printf("%d %d %d\\n", n, a, b);
    return 0;
}
''',
        stdinLines: ['7 35'],
      );
      expect(result.error, isNull);
      expect(result.output, '2 7 35\n');
    });

    test('跨多次 scanf 调用保持输入位置', () async {
      final result = await run(
        '''
#include <stdio.h>
int main(void) {
    int a, b, c;
    scanf("%d", &a);
    scanf("%d", &b);
    scanf("%d", &c);
    printf("%d %d %d\\n", a, b, c);
    return 0;
}
''',
        stdinLines: ['1 2', '3'],
      );
      expect(result.error, isNull);
      expect(result.output, '1 2 3\n');
    });

    test('输入耗尽时返回 EOF', () async {
      final result = await run('''
#include <stdio.h>
int main(void) {
    int a = 99;
    printf("%d %d\\n", scanf("%d", &a), a);
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, '-1 99\n');
    });

    test('字符不匹配时返回 0，不算 EOF', () async {
      final result = await run(
        '''
#include <stdio.h>
int main(void) {
    int a = 99;
    printf("%d %d\\n", scanf("%d", &a), a);
    return 0;
}
''',
        stdinLines: ['abc'],
      );
      expect(result.error, isNull);
      expect(result.output, '0 99\n');
    });

    test('数字后面的字符留在输入流里', () async {
      final result = await run(
        '''
#include <stdio.h>
int main(void) {
    int a = 0;
    char c = 0;
    scanf("%d", &a);
    scanf("%c", &c);
    printf("%d [%c]\\n", a, c);
    return 0;
}
''',
        stdinLines: ['12X'],
      );
      expect(result.error, isNull);
      // %c 不跳过空白，所以读到的是紧跟着的 'X'。
      expect(result.output, '12 [X]\n');
    });

    test('浮点：%lf 写 8 字节，%f 写 4 字节', () async {
      final result = await run(
        '''
#include <stdio.h>
int main(void) {
    double d = 0;
    float f = 0;
    scanf("%lf %f", &d, &f);
    printf("%.2f %.2f %d\\n", d, f, sizeof(d));
    return 0;
}
''',
        stdinLines: ['3.5 1.25'],
      );
      expect(result.error, isNull);
      expect(result.output, '3.50 1.25 8\n');
    });

    test('指数写法与 %s 混用', () async {
      final result = await run(
        '''
#include <stdio.h>
int main(void) {
    double d = 0;
    char name[32];
    scanf("%le %s", &d, name);
    printf("%.1f %s\\n", d, name);
    return 0;
}
''',
        stdinLines: ['1.25e2 hello'],
      );
      expect(result.error, isNull);
      expect(result.output, '125.0 hello\n');
    });

    test('%i 按前缀判断进制，%x 认 0x', () async {
      final result = await run(
        '''
#include <stdio.h>
int main(void) {
    int a = 0, b = 0, c = 0;
    scanf("%i %x %o", &a, &b, &c);
    printf("%d %d %d\\n", a, b, c);
    return 0;
}
''',
        stdinLines: ['0x1f 0x10 17'],
      );
      expect(result.error, isNull);
      expect(result.output, '31 16 15\n');
    });

    test('宽度限制与 * 抑制赋值', () async {
      final result = await run(
        '''
#include <stdio.h>
int main(void) {
    char buf[8];
    // %*d 不消耗参数，所以 %2s 拿的是第一个可变参数 buf。
    int n = scanf("%*d %2s", buf);
    printf("%d %s\\n", n, buf);
    return 0;
}
''',
        stdinLines: ['42 hello'],
      );
      expect(result.error, isNull);
      expect(result.output, '1 he\n');
    });

    test('格式串里的字面量必须匹配', () async {
      final result = await run(
        '''
#include <stdio.h>
int main(void) {
    int a = 0, b = 0;
    int n = scanf("%d,%d", &a, &b);
    printf("%d %d %d\\n", n, a, b);
    return 0;
}
''',
        stdinLines: ['7,35'],
      );
      expect(result.error, isNull);
      expect(result.output, '2 7 35\n');
    });

    test('sscanf 从字符串读且不动 stdin', () async {
      final result = await run(
        '''
#include <stdio.h>
int main(void) {
    int a = 0, b = 0;
    char rest[16];
    sscanf("3-4", "%d-%d", &a, &b);
    scanf("%s", rest);
    printf("%d %d %s\\n", a, b, rest);
    return 0;
}
''',
        stdinLines: ['tail'],
      );
      expect(result.error, isNull);
      expect(result.output, '3 4 tail\n');
    });

    test('fgets 读整行并去掉换行', () async {
      final result = await run(
        '''
#include <stdio.h>
int main(void) {
    char line[64];
    fgets(line, sizeof(line), stdin);
    printf("[%s]\\n", line);
    return 0;
}
''',
        stdinLines: ['hello world'],
      );
      expect(result.error, isNull);
      expect(result.output, '[hello world]\n');
    });

    test('getchar 与 scanf 共用同一个游标', () async {
      final result = await run(
        '''
#include <stdio.h>
int main(void) {
    int a = 0;
    scanf("%d", &a);
    printf("%d %c\\n", a, getchar());
    return 0;
}
''',
        stdinLines: ['9!'],
      );
      expect(result.error, isNull);
      expect(result.output, '9 !\n');
    });

    test('ungetc 退回的字符会被下次读走', () async {
      final result = await run(
        '''
#include <stdio.h>
int main(void) {
    int c = getchar();
    ungetc(c, stdin);
    printf("%c %c\\n", c, getchar());
    return 0;
}
''',
        stdinLines: ['ab'],
      );
      expect(result.error, isNull);
      expect(result.output, 'a a\n');
    });
  });

  group('错误报告', () {
    test('语法错误定位到原始行', () async {
      final result = await run('''
#include <stdio.h>
int main(void) {
    int a = ;
    return 0;
}
''');
      expect(result.error, isNotNull);
      expect(result.error!.kind, '语法');
      expect(result.error!.file, 'main.c');
      // `int a = ;` 在第 3 行
      expect(result.error!.line, 3);
    });

    test('未定义标识符', () async {
      final result = await run('''
int main(void) {
    return undefined_thing;
}
''');
      expect(result.error, isNotNull);
      expect(result.error!.kind, '运行时');
      expect(result.error!.message, contains('undefined_thing'));
    });

    test('除以零', () async {
      final result = await run('''
#include <stdio.h>
int main(void) {
    int a = 0;
    printf("%d\\n", 10 / a);
    return 0;
}
''');
      expect(result.error, isNotNull);
      expect(result.error!.message, contains('零'));
    });

    test('空指针解引用', () async {
      final result = await run('''
#include <stdio.h>
int main(void) {
    int *p = NULL;
    printf("%d\\n", *p);
    return 0;
}
''');
      expect(result.error, isNotNull);
      expect(result.error!.message, contains('空指针'));
    });

    test('找不到头文件', () async {
      final result = await run('''
#include "not_exist.h"
int main(void) { return 0; }
''');
      expect(result.error, isNotNull);
      expect(result.error!.kind, '预处理');
      expect(result.error!.message, contains('not_exist.h'));
    });

    test('没有 main 函数', () async {
      final result = await run('int helper(void) { return 1; }');
      expect(result.error, isNotNull);
      expect(result.error!.message, contains('main'));
    });

    test('死循环被步数兜底上限中止', () async {
      final result = await runCSource(
        source: 'int main(void) { while (1) {} return 0; }',
        useIsolate: false,
        maxSteps: 20000,
      );
      expect(result.error, isNotNull);
      expect(result.error!.message, contains('死循环'));
    });
  });

  group('运行上限', () {
    // 这一组存在的理由：曾经用「800 万步」当唯一的上限，结果把
    // `for (int i = 0; i < 3000000; i++)` 这种正常程序误判成了死循环。
    // 实测紧凑循环约 2800 万步/秒，800 万步只够跑 0.3 秒。
    test('百万级循环不会被误判成死循环', () async {
      final result = await run('''
int main(void) {
    long sum = 0;
    for (int i = 0; i < 3000000; i++) sum += i;
    return (int)(sum % 97);
}
''');
      expect(result.error, isNull, reason: '正常的长循环不该被中止');
      expect(result.steps, greaterThan(8000000));
    });

    test('嵌套循环不会被误判成死循环', () async {
      final result = await run('''
int main(void) {
    long s = 0;
    for (int i = 0; i < 1000; i++) for (int j = 0; j < 1000; j++) s++;
    return (int)(s % 7);
}
''');
      expect(result.error, isNull);
    });

    test('真死循环被时间上限中止，报错说明是超时', () async {
      final result = await run(
        'int main(void) { for (;;) { } return 0; }',
        timeLimit: const Duration(milliseconds: 200),
      );
      expect(result.error, isNotNull);
      expect(result.exitCode, 124);
      expect(result.error!.message, contains('还没结束'));
      // 超时不等于「确定是死循环」，措辞上要留余地。
      expect(result.error!.message, contains('也可能只是算得慢'));
    });

    test('时间上限可配：同样的死循环给足时间就能跑更久', () async {
      final short = await run(
        'int main(void) { for (;;) { } return 0; }',
        timeLimit: const Duration(milliseconds: 150),
      );
      final longer = await run(
        'int main(void) { for (;;) { } return 0; }',
        timeLimit: const Duration(milliseconds: 450),
      );
      expect(longer.steps, greaterThan(short.steps));
    });

    test('步数兜底上限独立生效', () async {
      final result = await run(
        'int main(void) { for (;;) { } return 0; }',
        maxSteps: 1000,
        // 时间给得足够宽，确保是步数先触发。
        timeLimit: const Duration(seconds: 30),
      );
      expect(result.error!.message, contains('执行步数超过 1000 步'));
    });
  });

  group('缺输入的提示', () {
    // 没有 input.txt 时程序会拿着 0 值继续算，给出一个**看起来正常但其实错误**
    // 的结果，或者空转到超时。这两种情况都得让用户知道真正的原因。
    test('没有输入时给出 input.txt 提示', () async {
      final result = await run('''
#include <stdio.h>
int main(void) {
    int n = 0;
    scanf("%d", &n);
    printf("读到 %d\\n", n);
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, '读到 0\n');
      expect(result.warnings, isNotEmpty);
      expect(result.warnings.first, contains('input.txt'));
    });

    test('给了输入就不提示', () async {
      final result = await run(
        '''
#include <stdio.h>
int main(void) {
    int n = 0;
    scanf("%d", &n);
    printf("读到 %d\\n", n);
    return 0;
}
''',
        stdinLines: ['42'],
      );
      expect(result.output, '读到 42\n');
      expect(result.warnings, isEmpty);
    });

    test('「读到 EOF 就停」的正常写法不误报', () async {
      final result = await run(
        '''
#include <stdio.h>
int main(void) {
    int n = 0, count = 0;
    while (scanf("%d", &n) == 1) count++;
    printf("%d\\n", count);
    return 0;
}
''',
        stdinLines: ['1', '2', '3'],
      );
      expect(result.error, isNull);
      expect(result.output, '3\n');
      // 输入是自己给的、程序读完正常收尾，再提示就是噪音。
      expect(result.warnings, isEmpty);
    });

    test('getchar 读到空也要提示', () async {
      final result = await run('''
#include <stdio.h>
int main(void) {
    printf("按回车继续");
    getchar();
    printf("\\n继续了\\n");
    return 0;
}
''');
      // 程序自己不会报错——但「按回车继续」其实根本没等。
      expect(result.error, isNull);
      expect(result.warnings, isNotEmpty);
    });

    test('缺输入导致空转到超时时，报错点明真正的原因', () async {
      final result = await run(
        '''
#include <stdio.h>
int main(void) {
    int target = 42, guess = 0;
    while (guess != target) {
        printf("猜一个数：");
        scanf("%d", &guess);
    }
    return 0;
}
''',
        timeLimit: const Duration(milliseconds: 200),
      );
      expect(result.error, isNotNull);
      expect(result.error!.message, contains('还没结束'));
      // 关键：不能只报「疑似死循环」，那会把用户带偏。
      expect(result.error!.message, contains('缺输入'));
    });
  });

  group('综合', () {
    test('冒泡排序 + 指针输出', () async {
      final result = await run('''
#include <stdio.h>

void sort(int *data, int n) {
    for (int i = 0; i < n - 1; i++) {
        for (int j = 0; j < n - 1 - i; j++) {
            if (data[j] > data[j + 1]) {
                int t = data[j];
                data[j] = data[j + 1];
                data[j + 1] = t;
            }
        }
    }
}

int main(void) {
    int data[] = {5, 2, 9, 1, 7, 3};
    int n = sizeof(data) / sizeof(data[0]);
    sort(data, n);
    for (int i = 0; i < n; i++) printf("%d ", data[i]);
    printf("\\n");
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, '1 2 3 5 7 9 \n');
    });

    test('栈实现', () async {
      final result = await run('''
#include <stdio.h>
#define CAPACITY 8

typedef struct {
    int items[CAPACITY];
    int top;
} Stack;

void init(Stack *s) { s->top = -1; }
int is_empty(Stack *s) { return s->top < 0; }
void push(Stack *s, int value) { s->items[++s->top] = value; }
int pop(Stack *s) { return s->items[s->top--]; }

int main(void) {
    Stack s;
    init(&s);
    for (int i = 1; i <= 5; i++) push(&s, i * i);
    while (!is_empty(&s)) printf("%d ", pop(&s));
    printf("\\n");
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, '25 16 9 4 1 \n');
    });

    test('最大公约数与素数筛选', () async {
      final result = await run('''
#include <stdio.h>

int gcd(int a, int b) {
    while (b != 0) {
        int t = b;
        b = a % b;
        a = t;
    }
    return a;
}

int main(void) {
    printf("%d\\n", gcd(48, 18));

    int limit = 30;
    int sieve[31];
    for (int i = 0; i <= limit; i++) sieve[i] = 1;
    sieve[0] = 0;
    sieve[1] = 0;
    for (int i = 2; i * i <= limit; i++) {
        if (!sieve[i]) continue;
        for (int j = i * i; j <= limit; j += i) sieve[j] = 0;
    }
    int count = 0;
    for (int i = 2; i <= limit; i++) if (sieve[i]) count++;
    printf("%d\\n", count);
    return 0;
}
''');
      expect(result.error, isNull);
      expect(result.output, '6\n10\n');
    });
  });
}

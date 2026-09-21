#!/usr/bin/env python3
"""把 MicroPython 源码加工成可嵌入的 micropython_embed/ 包。

背景
----
上游 ports/embed 是用 make 做这件事的：`embed.mk` 负责生成 genhdr，然后把
py/、extmod/modplatform.h、shared/runtime/gchelper*、genhdr/、port/ 复制到一个
自包含的目录里，之后宿主项目只要编译那一堆 .c 就行。这是上游**推荐**的用法
（见 ports/embed/README.md：「The output is a set of self-contained source
files... These files can be placed outside this repository.」）。

但我们不能直接用那条路：

  1. 开发机（Windows + DevEco）上没有 make。
  2. `py/mkrules.cmake` 虽然用 CMake 重写了同一套流程，但里面用了
     `cat`、`sed`、`touch`，还有 `|` 管道和 `>` 重定向。Ninja 在 Windows 上
     把自定义命令交给 cmd.exe 执行，这些东西一个都不存在（`cat` 在
     PowerShell 里只是 Get-Content 的别名，不是可执行文件）。

所以本脚本用 Python 把同一套流程重做一遍：仍然调用上游那几个生成脚本
（makeversionhdr / makeqstrdefs / makeqstrdata / makemoduledefs /
make_root_pointers），只是把中间的 cat / sed / 重定向换成 Python 自己的
文件读写。生成逻辑一行都没有自己发明，全是照抄 mkrules.mk 的规则。

依赖顺序（不能乱）
------------------
    mpversion.h
        └─ qstr.i.last            （用 C 预处理器扫一遍所有源码）
             ├─ qstr.split → qstrdefs.collected.h → qstrdefs.preprocessed.h
             │                                        → qstrdefs.generated.h
             ├─ moduledefs.split → moduledefs.collected → moduledefs.h
             └─ root_pointers.split → root_pointers.collected → root_pointers.h

关键点：**只有进了源码列表的文件才会被扫 qstr**。也就是说，一个模块光把
.c 编进来还不够，它必须在「扫描列表」里出现过，否则 moduledefs.h 里就不会
有它的注册项，运行时 `import` 会直接 ModuleNotFoundError。

用法
----
    python build_embed.py \
        --micropython-dir <third_party/micropython> \
        --package-dir     <native/micropython_embed> \
        --build-dir       <build/embed> \
        --port-dir        <native/port> \
        --cc              <ndk>/llvm/bin/clang.exe \
        --sysroot         <ndk>/sysroot \
        --target          aarch64-linux-ohos
"""

from __future__ import annotations

import argparse
import glob
import os
import re
import shutil
import subprocess
import sys

# ---------------------------------------------------------------------------
# 要额外编进来的 extmod 模块
# ---------------------------------------------------------------------------
#
# 每加一个，都要同时满足三件事，缺一个模块就不存在（或者更糟：链接失败）：
#   1. .c 出现在下面的列表里（→ 被复制进包 → 被 CMake 的 glob 收走 → 被编译）
#   2. .c 出现在「扫描列表」里（→ 它的 MP_REGISTER_MODULE 被 moduledefs.h 收走）
#   3. 对应的 MICROPY_PY_XXX 是打开的（见 port/mpconfigport.h）
#
# 这里选的都是在 mpconfigport.h 里打开、而且没有额外外部依赖（mbedtls / zlib /
# socket）的模块。
#
# 注意 math 和 cmath **不在这里**：它们在 py/ 下（py/modmath.c、py/modcmath.c），
# 属于 py/py.mk 里那份 PY_CORE_O 核心列表，已经被上面的 py/*.c 覆盖了。
# 别按「模块名带 mod 前缀就在 extmod」的直觉去猜——`import math` 是入门教程
# 第一课就用的东西，漏了会很显眼。
EXTMOD_MODULES = [
    "modjson.c",      # import json      MICROPY_PY_JSON
    "modrandom.c",    # import random    MICROPY_PY_RANDOM
    "modtime.c",      # import time      MICROPY_PY_TIME
    "modbinascii.c",  # import binascii  MICROPY_PY_BINASCII
    "modheapq.c",     # import heapq     MICROPY_PY_HEAPQ
    "modre.c",        # import re        MICROPY_PY_RE
]

# extmod 里被别的文件按「相对仓库根」的路径 #include 的头文件。
#
#   modplatform.h  py/mpconfig.h 用 MICROPY_PLATFORM_COMPILER 拼
#                  sys.implementation 的版本串，那个宏来自这里。
#                  上游 embed.mk 也专门复制它。
#   modtime.h      extmod/modtime.c:31 写的是 `#include "extmod/modtime.h"`。
#                  注意这个路径是**相对仓库根**的，所以它必须按 extmod/ 原样
#                  进包，不能挪位置。它自己只 #include "py/obj.h"，很干净。
EXTMOD_HEADERS = ["modplatform.h", "modtime.h"]

# shared/ 里需要的文件。gchelper 是 GC 扫寄存器用的（aarch64 走 x19-x29 那条分支）；
# timeutils 是 time.localtime()/mktime() 算日历用的。
SHARED_FILES = [
    "shared/runtime/gchelper.h",
    "shared/runtime/gchelper_generic.c",
    "shared/timeutils/timeutils.h",
    "shared/timeutils/timeutils.c",
    # sys.stdin / sys.stdout / sys.stderr 这三个对象。
    #
    # 它们**没有**在 py/ 里定义——py/modsys.c:50-52 只有
    #     extern struct _mp_dummy_t mp_sys_stdout_obj;  // type is irrelevant, just need pointer
    # 这类声明，真正的定义由 port 提供。上游的通用实现就是这个文件：它把
    # stdio 读写接到 mp_hal_stdin_rx_chr / mp_hal_stdout_tx_strn_cooked 上，
    # 而那正是我们 HAL 里已经捕获到缓冲区的那两个钩子——所以 sys.stdout.write()
    # 的输出会跟 print() 一起进同一个缓冲区，不需要额外接线。
    #
    # 不提供的话链接期报 3 个 undefined symbol（mp_sys_stdin_obj /
    # mp_sys_stdout_obj / mp_sys_stderr_obj），而 print() 的 file= 默认值就是
    # &mp_sys_stdout_obj（py/modbuiltins.c:388），所以连 print 都过不了链接。
    #
    # 它需要 MICROPY_PY_SYS_STDFILES（EXTRA 档默认打开）和
    # mp_hal_stdio_poll（我们的 HAL 里有）。
    "shared/runtime/sys_stdio_mphal.c",
    # py/modbuiltins.c:215 在 `#if MICROPY_PY_BUILTINS_INPUT` 里**无条件**
    # #include 它（那个 #include 在 #ifndef mp_hal_readline 之前，躲不掉），
    # 而我们开了 input()，所以这个头文件必须在。
    # 只需要头文件：readline() 本身不会被引用——port/mphalport.h 里
    # `#define mp_hal_readline mp_hal_readline` 把那个分支顶掉了。
    # 它不 include 任何东西，自带 CHAR_CTRL_* 宏和几个函数声明，很干净。
    "shared/readline/readline.h",
]

# 复制进包的目录结构。CMake 侧按 `micropython_embed/*/*.c` 和
# `micropython_embed/*/*/*.c` 两级 glob，所以这里必须保持这个形状。
PACKAGE_SUBDIRS = [
    "py",
    "extmod",
    "shared/runtime",
    "shared/timeutils",
    "shared/readline",
    "lib/re1.5",
    "genhdr",
    "port",
]

# lib/ 里被 extmod 模块「文本包含」进去的源码。
#
# extmod/modre.c 结尾是这么写的（modre.c:482-489）：
#
#     #include "lib/re1.5/compilecode.c"
#     #include "lib/re1.5/recursiveloop.c"
#     #include "lib/re1.5/charclass.c"
#     #include "lib/re1.5/dumpcode.c"   （在调试宏里）
#
# 也就是说它们不是独立的编译单元，而是 modre.c 的一部分。两件事由此决定：
#
#   1. 必须按 `lib/re1.5/...` 这个**原路径**进包——include 写的就是这个路径，
#      而它相对的是 MicroPython 仓库根（也就是我们包的根）。
#   2. **不能**被 CMake 的 glob 当成独立 .c 再编一遍，否则链接期符号重复。
#      CMakeLists.txt 里有一段显式排除，改这里时记得一起改。
#
# 文件名别按直觉猜：这个目录里没有 compile.c / search.c / split.c。
RE1_5_FILES = [
    "lib/re1.5/re1.5.h",
    "lib/re1.5/compilecode.c",
    "lib/re1.5/recursiveloop.c",
    "lib/re1.5/charclass.c",
    "lib/re1.5/dumpcode.c",
]

# 把被 sed 包起来的 qstr 行还原。等价于
#     sed 's/^"\(Q(.*)\)"/\1/'
# 用非贪婪到最后一个引号的语义（跟 sed 一致：`.*` 是贪婪的）。
_UNWRAP_QSTR_RE = re.compile(r'^"(Q\(.*\))"')


# 生成 moduledefs.h 之后要校验这些模块真的注册进去了。
#
# 为什么值得专门写一段校验：模块缺了**不会**报编译错。.c 没进源码列表，
# 就没有 MP_REGISTER_MODULE 被扫到，moduledefs.h 里少一行，链接期也不会有
# 未定义符号——要等真机上跑到 `import math` 才炸。而 `math` 又是入门教程
# 第一课就用的东西，等到那时才发现代价太大。
#
# 这个坑真的踩过：MICROPY_FLOAT_IMPL 没设 → MICROPY_PY_BUILTINS_FLOAT=0
# → py/modmath.c 整个文件被 #if 关掉 → math 悄悄消失。有了这段校验，
# 那种情况会在生成阶段直接失败并说明原因。
REQUIRED_MODULES = [
    "math",       # py/modmath.c，依赖 MICROPY_PY_BUILTINS_FLOAT
    "cmath",      # py/modcmath.c，同上 + MICROPY_PY_BUILTINS_COMPLEX
    "json",
    "random",
    "time",
    "re",
    "binascii",
    "heapq",
    "sys",
    "gc",
    "micropython",
    "struct",
    "io",
    "collections",
    "array",
]

# 生成 qstrdefs.generated.h 之后要校验 qstr 表不是「空壳」。
#
# 为什么值得专门校验：qstr 丢失是**静默**的。makeqstrdata.py 会把它自带的
# static_qstr_list（约 165 条）照常输出，所以 qstrdefs.generated.h 永远
# 「有内容、看起来正常」，要真去编才炸出一堆 MP_QSTR_xxx undeclared。
#
# 这个坑真的踩过：qstrdefs.collected.h 在 Windows 上被写成 CRLF，预处理器把
# 单独的 \r 也当换行，于是 `"Q(array)"` 被从中间劈成两行，解引号失败，
# **输入侧的 qstr 一条不剩**，只剩那 165 条静态的。
REQUIRED_QSTRS = [
    # 下面这些来自**源码扫描**（qstr.i.last → split → cat 这条链）。它们都不在
    # makeqstrdata.py 的 static_qstr_list 里，所以只能靠「扫到了源码里的
    # MP_QSTR_xxx」才会出现——是这条链路的强探测器。
    "MP_QSTR_array",        # py/modarray.c
    "MP_QSTR_hexlify",      # extmod/modbinascii.c
    "MP_QSTR_getrandbits",  # extmod/modrandom.c
    "MP_QSTR_math",         # py/modmath.c 的 MP_REGISTER_MODULE
    "MP_QSTR_json",         # extmod/modjson.c，代表 extmod 也在扫描列表里
    # 下面这个来自 static_qstr_list：证明 makeqstrdata.py 本身跑起来了。
    "MP_QSTR_print",
]

# 条数下限。
#
# static_qstr_list 自己就有约 165 条，所以这个下限只能抓「输入侧整条链路全丢」
# 这种崩法，抓不了「只丢了一部分」——后者要靠上面的 REQUIRED_QSTRS。
#
# 实测：本配置（ROM_LEVEL=EXTRA_FEATURES + py/ 全部 + 6 个 extmod）生成 477 条，
# 其中 776 条输入行去重后贡献约 311 条。留出余量取 300。
QSTR_COUNT_FLOOR = 300


class BuildError(Exception):
    """生成过程中的可读错误。调用方直接打印它，不要打 traceback。"""


# ---------------------------------------------------------------------------
# 小工具
# ---------------------------------------------------------------------------


def _log(message: str) -> None:
    print("[build_embed] " + message, flush=True)


def _run_python(script: str, args: list[str], cwd: str | None = None) -> None:
    """跑一个上游生成脚本，要求成功。"""
    if not os.path.isfile(script):
        raise BuildError("找不到上游脚本：%s" % script)
    cmd = [sys.executable, script] + args
    proc = subprocess.run(cmd, cwd=cwd)
    if proc.returncode != 0:
        raise BuildError(
            "生成脚本失败（退出码 %d）：\n  %s\n  %s"
            % (proc.returncode, script, " ".join(args))
        )


def _run_python_capture(script: str, args: list[str], out_path: str) -> None:
    """跑一个「打印到 stdout」的生成脚本，把 stdout 写进文件。

    对应 mkrules.mk 里的 `$(PYTHON) xxx.py ... > $@`。这里不能用 shell 重定向，
    所以直接抓 stdout。
    """
    if not os.path.isfile(script):
        raise BuildError("找不到上游脚本：%s" % script)
    proc = subprocess.run([sys.executable, script] + args, stdout=subprocess.PIPE)
    if proc.returncode != 0:
        raise BuildError(
            "生成脚本失败（退出码 %d）：\n  %s\n  %s"
            % (proc.returncode, script, " ".join(args))
        )
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "wb") as handle:
        handle.write(proc.stdout)


def _ensure_dir(path: str) -> None:
    """确保目录存在。

    这里刻意**不**清空目录。`makeqstrdefs.py split` 是按源文件往目录里写碎片的，
    `cat` 再 glob 整个目录，所以理论上「某个源文件被移出列表」时它的旧碎片会
    残留下来。但那需要源码列表发生变化——真发生了就手动删掉 build/embed 重来一次
    即可，没必要为了这个在每次构建里做破坏性操作。
    """
    os.makedirs(path, exist_ok=True)


def _collect_sources(mp_dir: str) -> list[str]:
    """要编译、也要扫 qstr 的全部源文件，路径相对于 MicroPython 根目录。

    顺序不影响正确性（makeqstrdefs 内部会按 c/cxx 分组并排序），但保持稳定
    能让输出可复现。
    """
    sources: list[str] = []

    # py/ 整个目录。上游 examples/embedding/Makefile 就是 glob 全部 py/*.c 的，
    # 因为 py/py.mk 里那份 PY_CORE_O 列表跟目录内容一一对应，没有多余文件。
    py_dir = os.path.join(mp_dir, "py")
    sources += sorted(
        os.path.relpath(path, mp_dir).replace("\\", "/")
        for path in glob.glob(os.path.join(py_dir, "*.c"))
    )

    # 手工挑的 extmod 模块。
    for name in EXTMOD_MODULES:
        path = os.path.join(mp_dir, "extmod", name)
        if not os.path.isfile(path):
            raise BuildError(
                "extmod/%s 不存在。MicroPython 版本可能变了，请核对 EXTMOD_MODULES。" % name
            )
        sources.append("extmod/" + name)

    # shared/ 里的 .c。
    for rel in SHARED_FILES:
        if rel.endswith(".c"):
            sources.append(rel)

    return sources


# ---------------------------------------------------------------------------
# genhdr 生成
# ---------------------------------------------------------------------------


def _preprocess_qstr_file(
    py_qstrdefs: str,
    port_qstrdefs: str,
    collected: str,
    out_path: str,
    cc: str,
    cpp_flags: list[str],
    cwd: str,
) -> None:
    """生成 qstrdefs.preprocessed.h。

    对应 mkrules.mk 的这一行：

        cat py/qstrdefs.h <port qstrdefs> <collected> \\
            | sed 's/^Q(.*)/"&"/' \\
            | $(CPP) $(CFLAGS) - \\
            | sed 's/^"\\\\(Q(.*)\\\\)"/\\\\1/' > qstrdefs.preprocessed.h

    为什么要把 Q(...) 行包进引号：这些行长这样

        Q(foo)

    直接喂给预处理器会被当成函数调用宏，而 `Q` 没定义，展开出来就没了。
    包成 `"Q(foo)"` 之后它是个字符串字面量，预处理器原样保留；同时 #include
    进来的其他 qstr 定义又能正常展开。跑完再剥掉引号。
    """
    chunks = []
    for path in (py_qstrdefs, port_qstrdefs, collected):
        if not os.path.isfile(path):
            raise BuildError("qstr 预处理缺输入文件：%s" % path)
        with open(path, "rb") as handle:
            chunks.append(handle.read())

    text = b"\n".join(chunks).decode("utf-8", "replace")

    # 换行必须归一化成 \n。这一步不是洁癖，是正确性问题。
    #
    # `makeqstrdefs.py cat` 写 qstrdefs.collected.h 时用的是 Python 文本模式，
    # 在 Windows 上 \n 会被翻译成 \r\n。于是这里拿到的行是 `Q(array)\r`，
    # 包上引号变成 `"Q(array)\r"` —— 而 clang 的词法器把**单独的 \r** 也当换行，
    # 这个字符串字面量就被从中间劈成两行：
    #
    #     "Q(array)
    #     "
    #
    # 后果：下面的解引号正则匹配不上（行尾不是引号），这些行原样留在
    # qstrdefs.preprocessed.h 里；makeqstrdata.py 的 ^Q\((.*)\)$ 也匹配不上，
    # 于是**静默丢掉**。表现是 MP_QSTR_array 之类全部 undeclared，而生成出来的
    # qstrdefs.generated.h 里只剩 static_qstr_list 那约 165 条，看起来「有内容」，
    # 很容易误判成别的问题。
    #
    # 下游对 \r 是有免疫力的（makeqstrdata.py 用 open(..., "rt") 读，还会
    # line.strip()），唯一不能容忍 \r 的就是预处理器这一步。
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    wrapped = "\n".join(
        ('"' + line + '"') if line.startswith("Q(") else line for line in text.split("\n")
    )

    proc = subprocess.run(
        [cc, "-E"] + cpp_flags + ["-"],
        cwd=cwd,
        input=wrapped.encode("utf-8"),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if proc.returncode != 0:
        tail = proc.stderr.decode("utf-8", "replace")[-4000:]
        raise BuildError("qstr 预处理失败（%s -E）：\n%s" % (cc, tail))

    lines = []
    cpp_out = proc.stdout.decode("utf-8", "replace").replace("\r\n", "\n")
    for line in cpp_out.split("\n"):
        lines.append(_UNWRAP_QSTR_RE.sub(r"\1", line.rstrip("\r")))

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "wb") as handle:
        handle.write("\n".join(lines).encode("utf-8"))


def _generate_genhdr(
    mp_dir: str,
    build_dir: str,
    cc: str,
    cpp_flags: list[str],
    sources: list[str],
    port_qstrdefs: str,
) -> str:
    """跑完整套 genhdr 生成，返回 genhdr 目录。"""
    py_dir = os.path.join(mp_dir, "py")
    genhdr = os.path.join(build_dir, "genhdr")
    os.makedirs(genhdr, exist_ok=True)

    # 每一步之间不能并行：qstr.i.last 是所有后续步骤的公共输入。

    # 1) mpversion.h —— sys.implementation 里的版本号来源。
    _log("genhdr: mpversion.h")
    _run_python(
        os.path.join(py_dir, "makeversionhdr.py"), [os.path.join(genhdr, "mpversion.h")]
    )

    # 2) qstr.i.last —— 用 C 预处理器扫一遍所有源码，抓出 MP_QSTR_xxx。
    #    这里给的是**编译器**（交叉编译的 clang），不是本机编译器：上游也是
    #    这么做的（mkrules.cmake 传 ${CMAKE_C_COMPILER}）。反正只用 -E，
    #    能解析 include 就行。
    _log("genhdr: qstr.i.last（扫描 %d 个源文件）" % len(sources))
    qstr_last = os.path.join(genhdr, "qstr.i.last")
    _run_python(
        os.path.join(py_dir, "makeqstrdefs.py"),
        ["pp", cc, "-E", "output", qstr_last,
         "cflags"] + cpp_flags + ["-DNO_QSTR",
         "cxxflags"] + cpp_flags + ["-DNO_QSTR",
         "sources"] + sources,
        cwd=mp_dir,
    )

    # 3) 按文件切分 / 汇总 qstr。
    qstr_dir = os.path.join(genhdr, "qstr")
    collected = os.path.join(genhdr, "qstrdefs.collected.h")
    _log("genhdr: qstrdefs.collected.h")
    _ensure_dir(qstr_dir)
    _run_python(
        os.path.join(py_dir, "makeqstrdefs.py"),
        ["split", "qstr", qstr_last, qstr_dir, "_"],
        cwd=mp_dir,
    )
    _run_python(
        os.path.join(py_dir, "makeqstrdefs.py"),
        ["cat", "qstr", "_", qstr_dir, collected],
        cwd=mp_dir,
    )

    # 4) 预处理 → 生成 qstr 表。
    #    这一步的 include 要能解析 genhdr/ 和 port 的头文件，所以 cpp_flags
    #    里同时有 -I<build_dir> 和 -I<port_dir>（见 main）。
    preprocessed = os.path.join(genhdr, "qstrdefs.preprocessed.h")
    _log("genhdr: qstrdefs.preprocessed.h")
    _preprocess_qstr_file(
        os.path.join(py_dir, "qstrdefs.h"),
        port_qstrdefs,
        collected,
        preprocessed,
        cc,
        cpp_flags,
        cwd=mp_dir,
    )

    _log("genhdr: qstrdefs.generated.h")
    generated = os.path.join(genhdr, "qstrdefs.generated.h")
    _run_python_capture(
        os.path.join(py_dir, "makeqstrdata.py"),
        [preprocessed],
        generated,
    )
    _verify_qstrs(generated)

    # 5) 模块注册表。没进这一步的模块，运行时 import 不到。
    module_dir = os.path.join(genhdr, "module")
    moduledefs_collected = os.path.join(genhdr, "moduledefs.collected")
    _log("genhdr: moduledefs.h")
    _ensure_dir(module_dir)
    _run_python(
        os.path.join(py_dir, "makeqstrdefs.py"),
        ["split", "module", qstr_last, module_dir, "_"],
        cwd=mp_dir,
    )
    _run_python(
        os.path.join(py_dir, "makeqstrdefs.py"),
        ["cat", "module", "_", module_dir, moduledefs_collected],
        cwd=mp_dir,
    )
    _run_python_capture(
        os.path.join(py_dir, "makemoduledefs.py"),
        [moduledefs_collected],
        os.path.join(genhdr, "moduledefs.h"),
    )
    _verify_modules(os.path.join(genhdr, "moduledefs.h"))

    # 6) GC 根指针表。py/mpstate.h 里的 struct _mp_state_vm_t 靠它填。
    root_dir = os.path.join(genhdr, "root_pointer")
    root_collected = os.path.join(genhdr, "root_pointers.collected")
    _log("genhdr: root_pointers.h")
    _ensure_dir(root_dir)
    _run_python(
        os.path.join(py_dir, "makeqstrdefs.py"),
        ["split", "root_pointer", qstr_last, root_dir, "_"],
        cwd=mp_dir,
    )
    _run_python(
        os.path.join(py_dir, "makeqstrdefs.py"),
        ["cat", "root_pointer", "_", root_dir, root_collected],
        cwd=mp_dir,
    )
    _run_python_capture(
        os.path.join(py_dir, "make_root_pointers.py"),
        [root_collected],
        os.path.join(genhdr, "root_pointers.h"),
    )

    return genhdr


# ---------------------------------------------------------------------------
# 打包
# ---------------------------------------------------------------------------


def _verify_modules(moduledefs_path: str) -> None:
    """确认该有的模块都注册上了（见 REQUIRED_MODULES 上面的说明）。"""
    with open(moduledefs_path, encoding="utf-8") as handle:
        text = handle.read()
    missing = [name for name in REQUIRED_MODULES if ("MODULE_DEF_" + name.upper()) not in text]
    if not missing:
        return
    raise BuildError(
        "这些模块没被注册进 moduledefs.h：%s\n"
        "常见原因：\n"
        "  * 模块的 .c 不在 build_embed.py 的源码列表里（EXTMOD_MODULES）\n"
        "  * 对应的 MICROPY_PY_XXX 在 port/mpconfigport.h 里被关掉了\n"
        "  * math/cmath 还额外要求 MICROPY_FLOAT_IMPL != NONE（即浮点没被关掉）\n"
        "生成出来的文件在：%s" % (", ".join(missing), moduledefs_path)
    )


def _verify_qstrs(qstrdefs_path: str) -> None:
    """确认 qstr 表不是空壳（见 REQUIRED_QSTRS 上面的说明）。"""
    with open(qstrdefs_path, encoding="utf-8") as handle:
        text = handle.read()
    total = text.count("QDEF")
    missing = [name for name in REQUIRED_QSTRS if name not in text]
    if total >= QSTR_COUNT_FLOOR and not missing:
        _log("qstr 表：%d 条" % total)
        return
    raise BuildError(
        "qstr 表不完整：只有 %d 条（下限 %d），缺少 %s\n"
        "常见原因：\n"
        "  * qstrdefs.preprocessed.h 里的行没被解引号（换行符 / 引号处理不对），\n"
        "    表现是那一行仍然是 `\"Q(xxx)` 或 `\"Q(xxx)\"`，makeqstrdata.py 认不出来\n"
        "  * 源码扫描列表（sources）漏了文件，MP_QSTR_xxx 根本没进 collected\n"
        "生成出来的文件在：%s" % (total, QSTR_COUNT_FLOOR, ", ".join(missing) or "（无）", qstrdefs_path)
    )


def _copy(src: str, dst: str) -> None:
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(src, dst)


def _assemble_package(mp_dir: str, package_dir: str, genhdr: str, port_dir: str) -> int:
    """把源码铺成自包含的 micropython_embed/ 包。返回复制的文件数。"""
    for sub in PACKAGE_SUBDIRS:
        os.makedirs(os.path.join(package_dir, sub), exist_ok=True)

    count = 0

    # py/：头文件和实现都要（.h 会被 #include）。
    for name in os.listdir(os.path.join(mp_dir, "py")):
        if not name.endswith((".c", ".h")):
            continue
        _copy(os.path.join(mp_dir, "py", name), os.path.join(package_dir, "py", name))
        count += 1

    # extmod/：只有挑中的模块和 modplatform.h。
    for name in EXTMOD_HEADERS + EXTMOD_MODULES:
        _copy(
            os.path.join(mp_dir, "extmod", name),
            os.path.join(package_dir, "extmod", name),
        )
        count += 1

    # shared/：按相对路径原样保留目录形状。
    for rel in SHARED_FILES:
        _copy(os.path.join(mp_dir, rel), os.path.join(package_dir, rel))
        count += 1

    # lib/re1.5/：modre.c 文本包含的那些文件（见 RE1_5_FILES 的说明）。
    for rel in RE1_5_FILES:
        _copy(os.path.join(mp_dir, rel), os.path.join(package_dir, rel))
        count += 1

    # genhdr/：四个生成出来的头文件。
    for name in ("mpversion.h", "qstrdefs.generated.h", "moduledefs.h", "root_pointers.h"):
        _copy(os.path.join(genhdr, name), os.path.join(package_dir, "genhdr", name))
        count += 1

    # port/：**只有我们自己的头文件**。
    #
    # 这里刻意不复制上游 ports/embed/port/ 里的两个文件：
    #   embed_util.c    提供 mp_embed_init/exec_str + gc_collect + nlr_jump_fail。
    #                   我们不用它——exec_str 会把 SystemExit 当普通异常打印出
    #                   traceback，而我们需要把 sys.exit(n) 的 n 当退出码。
    #                   这几个函数改在 src/qfli_py_bridge.c 里自己实现，
    #                   顺便把初始化拆开以便做「多次运行、每次一个干净 VM」。
    #   mphalport.c     用 printf 直接写进程 stdout，会污染宿主进程的输出；
    #                   换成 src/qfli_py_hal.c 的捕获实现。
    #   mphalport.h     只定义了 mp_hal_pin_obj_t；我们的 port/mphalport.h
    #                   额外提供了 input() 要用的 mp_hal_readline 钩子。
    for name in os.listdir(port_dir):
        if not name.endswith((".c", ".h")):
            continue
        _copy(os.path.join(port_dir, name), os.path.join(package_dir, "port", name))
        count += 1

    return count


# ---------------------------------------------------------------------------
# 入口
# ---------------------------------------------------------------------------


def _default_cpp_flags(
    mp_dir: str,
    build_dir: str,
    port_dir: str,
    target: str | None,
    sysroot: str | None,
) -> list[str]:
    """给 qstr 预处理器用的 -I / -D。

    三个 -I 各有分工：
      -I<mp_dir>     源码在 MicroPython 树里，`#include "py/mpconfig.h"` 靠它
      -I<build_dir>  genhdr 还在 build 目录里，`#include "genhdr/..."` 靠它
      -I<port_dir>   mpconfigport.h 是 `<mpconfigport.h>` 尖括号包含，靠它

    --target 不能省。DevEco 里的 clang.exe 是个通用的 LLVM 驱动，不指定 target
    时它按**宿主**三元组走（Windows 上是 x86_64-w64-windows-gnu），于是拿着
    `--sysroot=<OHOS sysroot>` 去找 `x86_64-w64-mingw32/.../include`，一个头文件
    都找不到，满屏 `'stdio.h' file not found`。
    ohos.toolchain.cmake 里对应的是 `CMAKE_C_COMPILER_TARGET = aarch64-linux-ohos`
    （arm64-v8a 时由 OHOS_LLVM 推出来）。
    """
    flags: list[str] = []
    if target:
        flags.append("--target=" + target)
    flags += [
        "-I" + mp_dir,
        "-I" + build_dir,
        "-I" + port_dir,
        # 和工具链保持一致：ohos.toolchain.cmake 里 CMAKE_C_FLAGS 带了 -D__MUSL__。
        # 预处理阶段最好用同一套宏，免得 mpconfig.h 走出不同分支。
        "-D__MUSL__",
    ]
    if sysroot:
        flags.append("--sysroot=" + sysroot)
    return flags


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="生成自包含的 micropython_embed/ 包（不需要 make）",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--micropython-dir", required=True, help="MicroPython 源码根目录")
    parser.add_argument("--package-dir", required=True, help="输出：micropython_embed/ 目录")
    parser.add_argument("--build-dir", required=True, help="中间产物目录（genhdr 放这里）")
    parser.add_argument("--port-dir", required=True, help="本项目的 port/ 目录（mpconfigport.h 所在处）")
    parser.add_argument("--cc", required=True, help="C 编译器（只用它的 -E）")
    parser.add_argument(
        "--target",
        default="aarch64-linux-ohos",
        help="交叉编译三元组；不指定 target 时 clang 会按宿主走（Windows 上必然失败）",
    )
    parser.add_argument("--sysroot", default=None, help="交叉编译 sysroot（传给 -E）")
    parser.add_argument(
        "--cpp-flag",
        action="append",
        default=[],
        help="追加给预处理器的参数，可重复",
    )
    args = parser.parse_args(argv)

    mp_dir = os.path.abspath(args.micropython_dir)
    package_dir = os.path.abspath(args.package_dir)
    build_dir = os.path.abspath(args.build_dir)
    port_dir = os.path.abspath(args.port_dir)

    # 先做输入校验，让报错指向真正缺的东西，而不是在中途某个脚本里炸开。
    for path, what in (
        (os.path.join(mp_dir, "py", "makeqstrdefs.py"), "MicroPython 源码"),
        (os.path.join(port_dir, "mpconfigport.h"), "port/mpconfigport.h"),
        (os.path.join(port_dir, "mphalport.h"), "port/mphalport.h"),
        (os.path.join(port_dir, "qstrdefsport.h"), "port/qstrdefsport.h"),
    ):
        if not os.path.isfile(path):
            raise BuildError("%s 不存在：%s" % (what, path))

    if not os.path.isfile(args.cc):
        raise BuildError("C 编译器不存在：%s" % args.cc)

    sources = _collect_sources(mp_dir)
    if not sources:
        raise BuildError("没扫到任何源文件，检查 --micropython-dir 指向对不对")

    cpp_flags = _default_cpp_flags(
        mp_dir, build_dir, port_dir, args.target, args.sysroot
    ) + list(args.cpp_flag)

    _log("MicroPython 根目录：%s" % mp_dir)
    _log("源文件 %d 个" % len(sources))

    genhdr = _generate_genhdr(
        mp_dir,
        build_dir,
        args.cc,
        cpp_flags,
        sources,
        os.path.join(port_dir, "qstrdefsport.h"),
    )

    copied = _assemble_package(mp_dir, package_dir, genhdr, port_dir)
    _log("已生成 %s（%d 个文件）" % (package_dir, copied))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except BuildError as error:
        print("\n[build_embed] 失败：" + str(error), file=sys.stderr)
        sys.exit(1)

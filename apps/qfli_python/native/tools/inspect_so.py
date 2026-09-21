#!/usr/bin/env python3
"""查一个 .so：动态依赖 + 引擎身份 + 未定义的 C++ 符号。

用法：
    python tools/inspect_so.py [path-to-so]

不带参数时默认查 ohos/entry/libs/arm64-v8a/libqfli_py.so。

这个脚本回答两个问题，都曾经把人坑过：

1. **这个 .so 在真机上打得开吗？**
   `DT_NEEDED` 里凡是出现 `libc++_shared.so` / `libstdc++.so` 这类
   「HAP 里不会带的库」，dlopen 就会失败，而**编译期一点提示都没有**。
   完整的事故现场见 native/README.md 的「⚠️ 最大的一个坑」。
   `check_so_deps.py` 是构建期的守门人（不通过就让构建失败），本脚本是
   事后复查用的，信息更全。

2. **里面跑的到底是不是真的 MicroPython？**
   直接扫文件里的 `MICROPY_VERSION_STRING` / `MICROPY_GIT_HASH` 字符串，
   以及上游的特征符号。版本号取自 MicroPython 自己的头文件，不是我们写的常量，
   所以「有没有瞎搞」这件事是可以自己验的，不用信任何人的说法。

退出码：0 = 一切正常；1 = 有不该出现的动态依赖。
"""
from __future__ import annotations

import os
import re
import struct
import sys

# HAP 里一定不会带的库：出现任何一个，dlopen 就会在真机上失败。
BAD_NEEDED_HINT = {
    "libc++_shared.so": "C++ 标准库动态版。加 -static-libstdc++ 静态链进来。",
    "libstdc++.so": "同上，加 -static-libstdc++。",
    "libc++abi.so": "同上，加 -static-libstdc++。",
}

# 上游 MicroPython 里一定会有的符号。缺了就说明跑的不是那个实现。
UPSTREAM_MARKERS = (
    b"mp_hal_stdout_tx_strn",
    b"mp_lexer_new_from_str_len",
    b"mp_execute_bytecode",
    b"nlr_push",
    b"gc_alloc",
)

# tools/ → native/ → apps/qfli_python/，再往下就是 App 的 ohos 工程。
DEFAULT_SO = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "ohos", "entry", "libs", "arm64-v8a", "libqfli_py.so",
)


def _load(path):
    with open(path, "rb") as fh:
        return fh.read()


def _phdrs(data):
    """返回 [(p_type, p_offset, p_vaddr, p_filesz), ...]。只支持 ELF64。"""
    if data[:4] != b"\x7fELF":
        raise SystemExit(f"不是 ELF 文件：{data[:4]!r}")
    if data[4] != 2:
        raise SystemExit("只支持 64 位 ELF")
    e_phoff = struct.unpack_from("<Q", data, 0x20)[0]
    e_phentsize = struct.unpack_from("<H", data, 0x36)[0]
    e_phnum = struct.unpack_from("<H", data, 0x38)[0]
    out = []
    for i in range(e_phnum):
        off = e_phoff + i * e_phentsize
        out.append((
            struct.unpack_from("<I", data, off)[0],          # p_type
            struct.unpack_from("<Q", data, off + 0x08)[0],   # p_offset
            struct.unpack_from("<Q", data, off + 0x10)[0],   # p_vaddr
            struct.unpack_from("<Q", data, off + 0x20)[0],   # p_filesz
        ))
    return out


def _vaddr_to_off(phdrs, vaddr):
    for p_type, p_offset, p_vaddr, p_filesz in phdrs:
        if p_type == 1 and p_vaddr <= vaddr < p_vaddr + p_filesz:  # PT_LOAD
            return p_offset + (vaddr - p_vaddr)
    return None


def read_needed(data):
    """从 PT_DYNAMIC 里读出 DT_NEEDED 列表。"""
    phdrs = _phdrs(data)
    dyn = [p for p in phdrs if p[0] == 2]  # PT_DYNAMIC
    if not dyn:
        return []
    _, d_off, _, d_size = dyn[0]

    strtab_vaddr = None
    needed_name_offsets = []
    i = 0
    while i < d_size:
        d_tag, d_val = struct.unpack_from("<QQ", data, d_off + i)
        if d_tag == 0:  # DT_NULL
            break
        if d_tag == 5:  # DT_STRTAB
            strtab_vaddr = d_val
        elif d_tag == 1:  # DT_NEEDED
            needed_name_offsets.append(d_val)
        i += 16

    if strtab_vaddr is None:
        return []
    strtab_off = _vaddr_to_off(phdrs, strtab_vaddr)
    if strtab_off is None:
        return []

    out = []
    for name_off in needed_name_offsets:
        end = data.index(b"\x00", strtab_off + name_off)
        out.append(data[strtab_off + name_off:end].decode("ascii", "replace"))
    return out


def read_undefined_cxx(data):
    """从 .dynsym 里挑出 SHN_UNDEF 的 C++（_Z 开头）符号。

    这些才是 dlopen 会去外部找的。DT_NEEDED 干净 + 这里为 0，就说明
    C++ 标准库确实整个静态链进来了（文件里当然还是有一堆 _Z 符号——
    那是**定义在 .so 内部**的，不是依赖）。
    """
    e_shoff = struct.unpack_from("<Q", data, 0x28)[0]
    e_shentsize = struct.unpack_from("<H", data, 0x3A)[0]
    e_shnum = struct.unpack_from("<H", data, 0x3C)[0]
    e_shstrndx = struct.unpack_from("<H", data, 0x3E)[0]

    def section(i):
        off = e_shoff + i * e_shentsize
        return (
            struct.unpack_from("<I", data, off)[0],           # sh_name
            struct.unpack_from("<I", data, off + 0x04)[0],    # sh_type
            struct.unpack_from("<Q", data, off + 0x18)[0],    # sh_offset
            struct.unpack_from("<Q", data, off + 0x20)[0],    # sh_size
            struct.unpack_from("<Q", data, off + 0x38)[0],    # sh_entsize
        )

    _, _, shstr_off, _, _ = section(e_shstrndx)
    by_name = {}
    for i in range(e_shnum):
        name_off, sh_type, sh_offset, sh_size, sh_entsize = section(i)
        end = data.index(b"\x00", shstr_off + name_off)
        by_name[data[shstr_off + name_off:end].decode()] = (
            sh_type, sh_offset, sh_size, sh_entsize)

    if ".dynsym" not in by_name or ".dynstr" not in by_name:
        return []
    _, sym_off, sym_size, sym_entsize = by_name[".dynsym"]
    _, str_off, _, _ = by_name[".dynstr"]
    if sym_entsize == 0:
        return []

    out = []
    for i in range(sym_size // sym_entsize):
        base = sym_off + i * sym_entsize
        st_name = struct.unpack_from("<I", data, base)[0]
        st_shndx = struct.unpack_from("<H", data, base + 0x06)[0]
        if st_shndx != 0:  # 0 == SHN_UNDEF
            continue
        end = data.index(b"\x00", str_off + st_name)
        name = data[str_off + st_name:end].decode("ascii", "replace")
        if name.startswith("_Z"):
            out.append(name)
    return out


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SO
    if not os.path.exists(path):
        raise SystemExit(f"找不到文件：{path}\n先跑 build.ps1。")

    data = _load(path)
    print(f"文件 : {path}")
    print(f"大小 : {len(data):,} 字节")

    print("\n[1] DT_NEEDED（动态依赖）")
    needed = read_needed(data)
    if not needed:
        print("    （无）")
    bad = []
    for name in needed:
        hint = BAD_NEEDED_HINT.get(name)
        print(f"    {'BAD ' if hint else 'OK  '}{name}" + (f"   ← {hint}" if hint else ""))
        if hint:
            bad.append(name)

    print("\n[2] 引擎身份（直接扫文件里的字符串，不是读配置）")
    for label, pattern in (
        ("版本号 1.24.1", rb"1\.24\.1"),
        ("git hash ecfdd5d", rb"ecfdd5d"),
        ("MicroPython 字样", rb"MicroPython"),
    ):
        hits = len(re.findall(pattern, data))
        print(f"    {'OK ' if hits else 'BAD'} {label:20s} 命中 {hits} 处")

    print("\n[3] 上游 MicroPython 特征符号")
    missing = []
    for marker in UPSTREAM_MARKERS:
        found = marker in data
        print(f"    {'OK ' if found else 'BAD'} {marker.decode()}")
        if not found:
            missing.append(marker)

    print("\n[4] 我们自己的导出")
    for name in (b"qfli_py_run", b"qfli_py_result_free", b"qfli_py_version",
                 b"RegisterQfliPyNativeModule"):
        found = name in data
        print(f"    {'OK ' if found else 'BAD'} {name.decode()}")

    print("\n[5] .dynsym 里未定义的 C++ 符号（SHN_UNDEF）")
    undef = read_undefined_cxx(data)
    for name in undef[:40]:
        print(f"    UND {name}")
    print(f"    数量：{len(undef)}")

    print()
    if bad:
        print(f"结论：不合格。有 {len(bad)} 个 HAP 里不会带的动态依赖：{', '.join(bad)}")
        print("      这个 .so 装到真机上会 dlopen 失败，ArkTS 的 import 拿到 undefined。")
        return 1
    if missing:
        print(f"结论：依赖没问题，但少了 {len(missing)} 个上游符号——引擎可能不是完整的 MicroPython。")
        return 1
    if undef:
        print(f"结论：有 {len(undef)} 个未定义的 C++ 符号，链接不完整。")
        return 1
    print("结论：通过。依赖全是设备上一定有的系统库，引擎是上游 MicroPython。")
    return 0


if __name__ == "__main__":
    sys.exit(main())

"""校验 libqfli_py.so 的动态依赖：只允许出现设备上一定有的系统库。

为什么需要这个检查
------------------
这个 .so 是**我们自己**用 CMake 编的，绕过了 hvigor 的 CMake 集成。hvigor
只负责把 ``ohos/entry/libs/<abi>/`` 下的文件原样打进 HAP，它既不知道也不需要
知道这个 .so 依赖了什么——**没有任何一步会去补齐它的依赖**。

于是只要链接时带上了一个非系统库，就会在真机上炸，而且编译期一切正常：

    W MUSL-LDSO: load libc++_shared.so failed, namespace=ndk no inherits, errno=2
    W MUSL-LDSO: Error loading shared library libc++_shared.so:
                 (needed by /data/storage/el1/bundle/libs/arm64/libqfli_py.so)
    W MMG: [NMM:1439]key:default/qfli_py ... load module default/qfli_py failed
    E ArkCompiler: export objects of native so is undefined, so name is .../qfli_py

最后那条的直接后果是 ArkTS 里 ``import qfliPyNative from 'libqfli_py.so'`` 拿到
``undefined``，用户看到的是 "Cannot read property run of undefined"。从这条报错
反推到「少了个 .so」要花掉一整个晚上，所以这里在构建期就拦下来。

不依赖 llvm-readelf：自己解析 ELF 就够了，省掉在 CMake 里找工具链路径的麻烦，
也避免 Windows/Linux 路径差异。只支持小端 ELF（OHOS 的 aarch64 / x86_64 都是）。
"""

import os
import struct
import sys

# 允许出现的 DT_NEEDED。判断标准是「设备上一定存在、且在任何 linker namespace
# 里都能解析到」，而不是「我们链接时用到了」。
#
#   libc.so / libm.so / libdl.so / libpthread.so / librt.so
#       musl 的基础库，由 /system/lib64 提供。
#   libace_napi.z.so     NAPI 本体（napi_module_register 等）。
#   libhilog_ndk.z.so    NDK 日志接口。
#   libunwind.so         工具链的 OHOS_COMMON_LINKER_FLAGS 里带 -lunwind。
#   libz.so              OHOS 的 zlib。
#
# 刻意**不**允许 libc++_shared.so：设备上确实有 /system/lib64/libc++_shared.so，
# 但它不在应用的 linker namespace 里，实测 errno=2。C++ 标准库必须静态链进去
# （见 CMakeLists 里的 -static-libstdc++）。
ALLOWED_NEEDED = {
    "libc.so",
    "libm.so",
    "libdl.so",
    "libpthread.so",
    "librt.so",
    "libace_napi.z.so",
    "libhilog_ndk.z.so",
    "libunwind.so",
    "libz.so",
}

# 明确点名、给出更具体建议的库。
KNOWN_BAD = {
    "libc++_shared.so": (
        "C++ 标准库被动态链接了。加上 -static-libstdc++（CMakeLists 里已有），"
        "或者把 NDK 的 libc++_shared.so 一起放进 ohos/entry/libs/<abi>/。"
    ),
    "libstdc++.so": (
        "同上：用 -static-libstdc++ 静态链，不要依赖设备上的 libstdc++。"
    ),
}

PT_LOAD = 1
PT_DYNAMIC = 2

DT_NEEDED = 1
DT_STRTAB = 5
DT_STRSZ = 10


class ElfError(Exception):
    pass


def _parse_phdrs(data):
    """返回 (loads, dynamic)，loads 是 [(vaddr, offset, filesz)]。"""
    if data[:4] != b"\x7fELF":
        raise ElfError("不是 ELF 文件")
    ei_class = data[4]
    ei_data = data[5]
    if ei_data != 1:
        raise ElfError("只支持小端 ELF")

    if ei_class == 2:
        e_phoff, = struct.unpack_from("<Q", data, 0x20)
        e_phentsize, e_phnum = struct.unpack_from("<HH", data, 0x36)
        fmt = "<IIQQQQQQ"
    elif ei_class == 1:
        e_phoff, = struct.unpack_from("<I", data, 0x1C)
        e_phentsize, e_phnum = struct.unpack_from("<HH", data, 0x2A)
        fmt = "<IIIIIIII"
    else:
        raise ElfError("无法识别的 EI_CLASS=%d" % ei_class)

    loads = []
    dynamic = None
    for i in range(e_phnum):
        off = e_phoff + i * e_phentsize
        if off + struct.calcsize(fmt) > len(data):
            raise ElfError("程序头越界")
        fields = struct.unpack_from(fmt, data, off)
        p_type = fields[0]
        p_offset = fields[2]
        p_vaddr = fields[3]
        p_filesz = fields[5]
        if p_type == PT_LOAD:
            loads.append((p_vaddr, p_offset, p_filesz))
        elif p_type == PT_DYNAMIC:
            dynamic = (p_vaddr, p_offset, p_filesz)

    if dynamic is None:
        raise ElfError("没有 PT_DYNAMIC：这不是动态链接的库？")
    return ei_class, loads, dynamic


def _vaddr_to_offset(loads, vaddr):
    for seg_vaddr, seg_offset, seg_filesz in loads:
        if seg_vaddr <= vaddr < seg_vaddr + seg_filesz:
            return seg_offset + (vaddr - seg_vaddr)
    return None


def read_needed(path):
    """读出 DT_NEEDED 列表（顺序与链接顺序一致）。"""
    with open(path, "rb") as handle:
        data = handle.read()

    ei_class, loads, (dyn_vaddr, dyn_offset, dyn_filesz) = _parse_phdrs(data)

    if ei_class == 2:
        entry_fmt, entry_size = "<qQ", 16
    else:
        entry_fmt, entry_size = "<iI", 8

    needed_offsets = []
    strtab_vaddr = None
    strsz = 0

    count = dyn_filesz // entry_size
    for i in range(count):
        off = dyn_offset + i * entry_size
        if off + entry_size > len(data):
            break
        d_tag, d_val = struct.unpack_from(entry_fmt, data, off)
        if d_tag == 0:  # DT_NULL
            break
        if d_tag == DT_NEEDED:
            needed_offsets.append(d_val)
        elif d_tag == DT_STRTAB:
            strtab_vaddr = d_val
        elif d_tag == DT_STRSZ:
            strsz = d_val

    if strtab_vaddr is None:
        raise ElfError("动态段里没有 DT_STRTAB")
    strtab_off = _vaddr_to_offset(loads, strtab_vaddr)
    if strtab_off is None:
        raise ElfError("DT_STRTAB 的地址不在任何 PT_LOAD 里")
    strtab = data[strtab_off:strtab_off + (strsz or 0)]

    names = []
    for name_off in needed_offsets:
        end = strtab.find(b"\x00", name_off)
        if end < 0:
            raise ElfError("字符串表里找不到 NUL 结尾")
        names.append(strtab[name_off:end].decode("utf-8", "replace"))
    return names


def main(argv):
    if len(argv) < 2:
        print("用法: check_so_deps.py <libqfli_py.so> [--quiet]", file=sys.stderr)
        return 2
    path = argv[1]
    quiet = "--quiet" in argv

    if not os.path.exists(path):
        print("找不到 %s" % path, file=sys.stderr)
        return 2

    try:
        needed = read_needed(path)
    except ElfError as error:
        print("解析 %s 失败：%s" % (path, error), file=sys.stderr)
        return 2

    problems = []
    for name in needed:
        if name in ALLOWED_NEEDED:
            continue
        hint = KNOWN_BAD.get(name, "HAP 里不会带这个库，设备上不一定解析得到。")
        problems.append((name, hint))

    if not quiet:
        print("libqfli_py.so 的动态依赖（%d 个）：" % len(needed))
        for name in needed:
            mark = "OK " if name in ALLOWED_NEEDED else "!! "
            print("  %s %s" % (mark, name))

    if problems:
        print("", file=sys.stderr)
        print("这些依赖不能带进 HAP：", file=sys.stderr)
        for name, hint in problems:
            print("  * %s —— %s" % (name, hint), file=sys.stderr)
        print("", file=sys.stderr)
        print(
            "带上它们的后果是：真机上 dlopen 失败 → ArkTS 侧 import 得到 "
            "undefined → 运行时报 \"Cannot read property run of undefined\"，"
            "而编译期完全正常。",
            file=sys.stderr,
        )
        return 1

    if not quiet:
        print("依赖检查通过：全是设备上一定有的系统库。")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

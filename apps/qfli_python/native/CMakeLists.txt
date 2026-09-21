# libqfli_py.so：内嵌 MicroPython + NAPI 外壳。
#
# 和 C 版那个 CMakeLists 的最大区别：这里要**先把 MicroPython 加工成一个自包含的
# 源码包**，再编译它。上游 ports/embed 用 make 做这件事，我们用的是
# tools/build_embed.py（原因见那个文件顶部的说明：Windows 上没有 make，而
# py/mkrules.cmake 依赖 cat/sed/touch 和 shell 重定向，cmd.exe 里都没有）。
#
# 目录约定：
#   native/third_party/micropython/   MicroPython 源码（clone 进来，不提交）
#   native/port/                      MicroPython 配置（mpconfigport.h 等）
#   native/tools/build_embed.py       生成器
#   native/micropython_embed/         生成物：自包含的源码包（不提交）
#   native/src/                       桥接层、HAL、NAPI 外壳

cmake_minimum_required(VERSION 3.5.0)
project(qfli_py C CXX)

set(CMAKE_C_STANDARD 99)
set(CMAKE_CXX_STANDARD 17)

set(QFLI_PY_NATIVE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
set(QFLI_PY_MICROPYTHON_DIR ${QFLI_PY_NATIVE_DIR}/third_party/micropython)
set(QFLI_PY_EMBED_DIR ${QFLI_PY_NATIVE_DIR}/micropython_embed)
set(QFLI_PY_EMBED_STAMP ${QFLI_PY_EMBED_DIR}/genhdr/moduledefs.h)

# ---------------------------------------------------------------------------
# 找宿主 Python
# ---------------------------------------------------------------------------
#
# 生成器需要 Python 3，但**它不在 PATH 上**——这台开发机根本没装系统 Python。
# DevEco Studio 自己带了一个（plugins/app-analyzer/lib/python），我们优先用它。
# 顺序：用户显式指定 → CMake 已找到的 → PATH 上的 → DevEco 自带的。
set(QFLI_PY_PYTHON "" CACHE FILEPATH "宿主 Python 3，用于生成 micropython_embed 包")

if(NOT QFLI_PY_PYTHON AND Python3_EXECUTABLE)
    set(QFLI_PY_PYTHON "${Python3_EXECUTABLE}")
endif()

if(NOT QFLI_PY_PYTHON)
    find_program(QFLI_PY_PYTHON_PATH NAMES python3 python)
    if(QFLI_PY_PYTHON_PATH)
        set(QFLI_PY_PYTHON "${QFLI_PY_PYTHON_PATH}")
    endif()
endif()

if(NOT QFLI_PY_PYTHON)
    # DevEco 自带的那个。<OHOS_SDK_NATIVE> 是 <DevEco>/sdk/default/openharmony/native，
    # 往上四层才是安装根目录。
    foreach(_cand
            "${OHOS_SDK_NATIVE}/../../../..//plugins/app-analyzer/lib/python/python.exe"
            "$ENV{DEVECO_HOME}/plugins/app-analyzer/lib/python/python.exe"
            "$ENV{DEVECO_SDK_HOME}/../plugins/app-analyzer/lib/python/python.exe")
        if(EXISTS "${_cand}")
            set(QFLI_PY_PYTHON "${_cand}")
            break()
        endif()
    endforeach()
endif()

if(NOT QFLI_PY_PYTHON)
    message(FATAL_ERROR
        "找不到 Python 3。生成 MicroPython 源码包需要它。\n"
        "请用 -DQFLI_PY_PYTHON=<python 可执行文件路径> 指定。")
endif()

message(STATUS "qfli_py: 用 Python ${QFLI_PY_PYTHON} 生成 MicroPython 源码包")

# ---------------------------------------------------------------------------
# 生成 / 更新 micropython_embed
# ---------------------------------------------------------------------------
#
# 这里必须用 execute_process 在**配置期**做，而不是 add_custom_command：
# 下面那个 file(GLOB) 需要文件真实存在才能列出来。CMake 的 glob 不会「等到
# 构建时再展开」。
#
# 只在两种情况下生成：
#   1. 包还不存在（新克隆的仓库、或第一次构建）；
#   2. 包比它的输入旧（改了 port/mpconfigport.h 之类）。
# 判据用 mtime 就够了，而且很便宜；不这样做的话，改了配置却不重新生成，
# 会出现「模块在源码里、但运行时 import 不到」这种很难查的现象。

set(_qfli_py_stale FALSE)

if(NOT EXISTS ${QFLI_PY_EMBED_STAMP})
    set(_qfli_py_stale TRUE)
else()
    file(GLOB _qfli_py_config_files
        ${QFLI_PY_NATIVE_DIR}/port/*.h
        ${QFLI_PY_NATIVE_DIR}/tools/*.py)
    foreach(_dep ${_qfli_py_config_files}
            ${QFLI_PY_MICROPYTHON_DIR}/py/mpconfig.h
            ${QFLI_PY_MICROPYTHON_DIR}/py/py.mk
            ${QFLI_PY_MICROPYTHON_DIR}/extmod/modplatform.h)
        if(EXISTS "${_dep}" AND "${_dep}" IS_NEWER_THAN "${QFLI_PY_EMBED_STAMP}")
            set(_qfli_py_stale TRUE)
        endif()
    endforeach()
endif()

if(NOT EXISTS ${QFLI_PY_MICROPYTHON_DIR}/py/makeqstrdefs.py)
    message(FATAL_ERROR
        "找不到 MicroPython 源码：${QFLI_PY_MICROPYTHON_DIR}\n"
        "先按 native/README.md 里的命令把它 clone 进来。")
endif()

# 交叉编译三元组：CMake 实际编译时用的是 CMAKE_C_COMPILER_TARGET，生成器的
# qstr 预处理器也要用同一个，否则两边看到的宏不一样，可能漏掉 qstr。
set(_qfli_py_target "${CMAKE_C_COMPILER_TARGET}")
if(NOT _qfli_py_target)
    if(OHOS_ARCH STREQUAL "armeabi-v7a")
        set(_qfli_py_target "arm-linux-ohos")
    elseif(OHOS_ARCH STREQUAL "x86_64")
        set(_qfli_py_target "x86_64-linux-ohos")
    else()
        set(_qfli_py_target "aarch64-linux-ohos")
    endif()
endif()

set(_qfli_py_generate_cmd
    "${QFLI_PY_PYTHON}"
    "${QFLI_PY_NATIVE_DIR}/tools/build_embed.py"
    --micropython-dir "${QFLI_PY_MICROPYTHON_DIR}"
    --package-dir "${QFLI_PY_EMBED_DIR}"
    --build-dir "${CMAKE_BINARY_DIR}/embed"
    --port-dir "${QFLI_PY_NATIVE_DIR}/port"
    --cc "${CMAKE_C_COMPILER}"
    --target "${_qfli_py_target}"
    --sysroot "${CMAKE_SYSROOT}")

if(_qfli_py_stale)
    message(STATUS "qfli_py: 生成 MicroPython 源码包（首次或配置已变）")
    execute_process(COMMAND ${_qfli_py_generate_cmd}
        RESULT_VARIABLE _qfli_py_result)
    if(NOT _qfli_py_result EQUAL 0)
        message(FATAL_ERROR
            "生成 MicroPython 源码包失败（退出码 ${_qfli_py_result}）。\n"
            "手动跑一遍能看到完整报错：\n"
            "  ${_qfli_py_generate_cmd}")
    endif()
else()
    message(STATUS "qfli_py: MicroPython 源码包是最新的，跳过生成")
endif()

# 手动强制重新生成用。改了 port/ 下的配置但没动 mtime（比如 git checkout）
# 时可以跑这个目标。
add_custom_target(qfli_py_regen
    COMMAND ${_qfli_py_generate_cmd}
    COMMENT "重新生成 micropython_embed 包")

# ---------------------------------------------------------------------------
# 源码
# ---------------------------------------------------------------------------
#
# 两级 glob 是照抄上游 examples/embedding/Makefile 的写法：
#   micropython_embed/*/*.c     → py/、extmod/、port/
#   micropython_embed/*/*/*.c   → shared/runtime/、shared/timeutils/、lib/re1.5/
# 这个形状是 tools/build_embed.py 保证的，改那边的话这里要一起改。
file(GLOB QFLI_PY_EMBED_SOURCES
    ${QFLI_PY_EMBED_DIR}/*/*.c
    ${QFLI_PY_EMBED_DIR}/*/*/*.c)

# 有些 .c 不是独立的编译单元，而是被**文本包含**进别的文件里的，必须从 glob
# 结果里排除掉。不排除的后果分两种：
#
#   lib/re1.5/*.c                extmod/modre.c 直接 #include 了它们
#                                （modre.c:482-489）。再单独编一份就是链接期
#                                符号重复（multiple definition）。
#   port/qfli_time_localtime.c   port/mpconfigport.h 用 MICROPY_PY_TIME_INCLUDEFILE
#                                把它包含进 extmod/modtime.c。里面只有一个
#                                static 函数，单独编只是白编加一条
#                                -Wunused-function 警告，但同样不该编。
#
# 用 foreach 而不是 list(FILTER ...)：后者要 CMake 3.6+，而本文件声明的是 3.5。
set(_qfli_py_not_compiled "")
set(_qfli_py_embed_sources_kept "")
foreach(_qfli_py_src ${QFLI_PY_EMBED_SOURCES})
    if(_qfli_py_src MATCHES "/lib/re1\\.5/"
       OR _qfli_py_src MATCHES "/port/qfli_time_localtime\\.c$")
        list(APPEND _qfli_py_not_compiled "${_qfli_py_src}")
    else()
        list(APPEND _qfli_py_embed_sources_kept "${_qfli_py_src}")
    endif()
endforeach()
set(QFLI_PY_EMBED_SOURCES ${_qfli_py_embed_sources_kept})
list(LENGTH _qfli_py_not_compiled _qfli_py_not_compiled_count)
message(STATUS
    "qfli_py: 排除 ${_qfli_py_not_compiled_count} 个「只被文本包含」的源文件，不单独编译")

list(LENGTH QFLI_PY_EMBED_SOURCES _qfli_py_embed_count)
if(_qfli_py_embed_count LESS 100)
    message(FATAL_ERROR
        "MicroPython 源码包里的 .c 只有 ${_qfli_py_embed_count} 个，明显不对"
        "（正常是一百多个）。先跑一次 qfli_py_regen 目标看看生成器的报错。")
endif()
message(STATUS "qfli_py: 编译 ${_qfli_py_embed_count} 个 MicroPython 源文件")

add_library(qfli_py SHARED
    ${QFLI_PY_EMBED_SOURCES}
    src/qfli_py_hal.c
    src/qfli_py_bridge.c
    src/qfli_py_napi.cpp)

target_include_directories(qfli_py PRIVATE
    # MicroPython 源码包的根：`#include "py/xxx.h"` 和 `#include "genhdr/xxx.h"` 靠它。
    ${QFLI_PY_EMBED_DIR}
    # port/：py/mpconfig.h 里是 `#include <mpconfigport.h>`（尖括号），
    # 而 MICROPY_MPHALPORT_H 指向的 mphalport.h 也在这里。
    ${QFLI_PY_EMBED_DIR}/port
    ${QFLI_PY_NATIVE_DIR}/src
    ${NATIVERENDER_ROOT_PATH}
    ${NATIVERENDER_ROOT_PATH}/include)

# NDEBUG：把 assert() 编掉。
#
# 这不只是「发布版惯例」——musl 的 assert 走 __assert_fail，而 MicroPython 的
# 内部断言一旦触发就是进程级失败，在 App 里等于闪退。我们宁愿它继续跑（
# MicroPython 自己该抛的异常都会正常抛，assert 只覆盖内部不变量）。
target_compile_definitions(qfli_py PRIVATE NDEBUG)

# -Wno-error=format-security：工具链的 CMAKE_C_FLAGS 里带了
# `-Wformat -Werror=format-security`，而 MicroPython 里有不少
# `mp_printf(fmt, ...)` 这种非字面量格式串的用法，会被判成错误。
# 关掉这个「错误」级别（警告保留），免得为上游代码风格卡住构建。
target_compile_options(qfli_py PRIVATE
    -Wall
    -Wno-unused-parameter
    -Wno-error=format-security)

# ---------------------------------------------------------------------------
# 链接
# ---------------------------------------------------------------------------

# -static-libstdc++ **不是可选项**，缺了它这个 App 在真机上跑不起来。
#
# 等价于工具链的 OHOS_STL=c++_static（见 ohos.toolchain.cmake 第 239-240 行）。
# 不能用 -DOHOS_STL=c++_static 代替：那个文件里是 `set(OHOS_STL c++_shared)`，
# 普通变量会盖住命令行传进来的同名缓存变量，所以只能在自己的 CMakeLists 里补。
#
# 不加会怎样：链接器给 libqfli_py.so 打上 DT_NEEDED libc++_shared.so，然后
#
#   1. HAP 里没有它。hvigor 只把 ohos/entry/libs/<abi>/ 下的文件原样打包，
#      而我们绕过了它的 CMake 集成，没有任何一步会去补齐 .so 的依赖。
#   2. 设备上 /system/lib64/libc++_shared.so 确实存在，但**不在应用的 linker
#      namespace 里**。实测 hilog：
#
#        W MUSL-LDSO: load libc++_shared.so failed, namespace=ndk no inherits, errno=2
#        W MUSL-LDSO: load libc++_shared.so failed, namespace=moduleNs_default, errno=2
#        W MUSL-LDSO: Error loading shared library libc++_shared.so:
#                     (needed by /data/storage/el1/bundle/libs/arm64/libqfli_py.so)
#        W MMG: [NMM:1439]key:default/qfli_py First: failed ...
#        E ArkCompiler: export objects of native so is undefined, so name is .../qfli_py
#
#      最后那条的直接后果是 ArkTS 侧 `import qfliPyNative from 'libqfli_py.so'`
#      拿到 undefined，用户看到 "Cannot read property run of undefined"。
#
# 整条链路编译期完全正常，只有装到真机才炸。所以这里必须静态链，并且下面
# 加了 POST_BUILD 检查，让「又多了一个非系统依赖」这种事在构建期就失败。
target_link_libraries(qfli_py PUBLIC -static-libstdc++)

# libace_napi.z.so 提供 NAPI；libhilog_ndk.z.so 是日志；m 是 MicroPython 的
# math/cmath 模块要的数学库（工具链已经把 -lm 放进默认库，写出来更明确）。
target_link_libraries(qfli_py PUBLIC libace_napi.z.so libhilog_ndk.z.so m)

# ---------------------------------------------------------------------------
# 构建期校验动态依赖
# ---------------------------------------------------------------------------
#
# 编完立刻验一遍 DT_NEEDED：只要出现一个「设备上不一定解析得到」的库就直接
# 失败。理由见上面那段——这类问题的反馈周期是「装到真机上才发现」，太贵了。
#
# 用的是纯 Python 解析 ELF（tools/check_so_deps.py），不依赖 llvm-readelf，
# 省掉在 CMake 里定位工具链路径的麻烦。
add_custom_command(TARGET qfli_py POST_BUILD
    COMMAND ${QFLI_PY_PYTHON} ${QFLI_PY_NATIVE_DIR}/tools/check_so_deps.py
            "$<TARGET_FILE:qfli_py>"
    COMMENT "校验 libqfli_py.so 的动态依赖（HAP 里不会带的库必须静态链）"
    VERBATIM)

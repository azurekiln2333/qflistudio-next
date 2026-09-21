# libqfli_c.so：picoc 解释器 + NAPI 外壳。
#
# 这条路径是**可选**的。默认的 C 版 App 用 Dart 解释器跑 C 代码，不需要 NDK、
# 不需要按 ABI 出多个 .so，覆盖面也够教学用。只有当你想换性能更好的 picoc、
# 或者需要 picoc 的某些语义时，才按 native/README.md 打开这条路径。
#
# 目录约定：
#   native/third_party/picoc/    picoc 源码（按 README 里的命令 clone 进来）
#   native/src/                  桥接层与 HarmonyOS 平台层

cmake_minimum_required(VERSION 3.5.0)
project(qfli_c)

set(CMAKE_C_STANDARD 99)
set(CMAKE_CXX_STANDARD 17)

set(PICOC_DIR ${CMAKE_CURRENT_SOURCE_DIR}/third_party/picoc)

if(NOT EXISTS ${PICOC_DIR}/picoc.h)
    message(FATAL_ERROR
        "找不到 picoc 源码：${PICOC_DIR}\n"
        "先按 native/README.md 里的命令把 picoc clone 进来。")
endif()

# picoc 本体。
#
# 刻意不含这两个文件：
#   picoc.c                 自带 main()，我们的入口是 qfli_c_bridge.c
#   platform/platform_unix.c 依赖 GNU readline，HarmonyOS 没有这个库
# 平台层换成 src/platform_ohos.c。
set(PICOC_SOURCES
    ${PICOC_DIR}/table.c
    ${PICOC_DIR}/lex.c
    ${PICOC_DIR}/parse.c
    ${PICOC_DIR}/expression.c
    ${PICOC_DIR}/heap.c
    ${PICOC_DIR}/type.c
    ${PICOC_DIR}/variable.c
    ${PICOC_DIR}/clibrary.c
    ${PICOC_DIR}/platform.c
    ${PICOC_DIR}/include.c
    ${PICOC_DIR}/debug.c
    ${PICOC_DIR}/cstdlib/stdio.c
    ${PICOC_DIR}/cstdlib/math.c
    ${PICOC_DIR}/cstdlib/string.c
    ${PICOC_DIR}/cstdlib/stdlib.c
    ${PICOC_DIR}/cstdlib/time.c
    ${PICOC_DIR}/cstdlib/errno.c
    ${PICOC_DIR}/cstdlib/ctype.c
    ${PICOC_DIR}/cstdlib/stdbool.c
    ${PICOC_DIR}/cstdlib/unistd.c
)

add_library(qfli_c SHARED
    ${PICOC_SOURCES}
    src/platform_ohos.c
    src/qfli_c_bridge.c
    src/qfli_c_napi.cpp
)

target_compile_definitions(qfli_c PRIVATE
    # picoc 靠这个宏挑平台分支：决定用 setjmp 做退出跳转，并启用 math 库。
    # HarmonyOS 的 libc 与 Linux 同源，这一支可以直接用。
    UNIX_HOST
    VER=\"2.2\"
)

target_include_directories(qfli_c PRIVATE
    ${PICOC_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${NATIVERENDER_ROOT_PATH}
    ${NATIVERENDER_ROOT_PATH}/include
)

target_compile_options(qfli_c PRIVATE -Wall -Wno-unused-parameter)

# libace_napi.z.so 提供 NAPI；libhilog_ndk.z.so 是日志（排查用得上）；
# m 是 picoc 开了 PICOC_MATH_LIBRARY 之后要的数学库。
target_link_libraries(qfli_c PUBLIC libace_napi.z.so libhilog_ndk.z.so m)

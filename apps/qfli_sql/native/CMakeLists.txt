cmake_minimum_required(VERSION 3.5.0)
project(qfli_sql C CXX)

set(CMAKE_C_STANDARD 99)
set(CMAKE_CXX_STANDARD 17)

set(QFLI_SQL_DIR ${CMAKE_CURRENT_SOURCE_DIR})
set(QFLI_SQLITE_DIR ${QFLI_SQL_DIR}/third_party/sqlite)

add_library(qfli_sql SHARED
    ${QFLI_SQLITE_DIR}/sqlite3.c
    src/qfli_sql_bridge.c
    src/qfli_sql_napi.cpp)

target_include_directories(qfli_sql PRIVATE
    ${QFLI_SQLITE_DIR}
    ${QFLI_SQL_DIR}/src
    ${NATIVERENDER_ROOT_PATH}
    ${NATIVERENDER_ROOT_PATH}/include)

target_compile_definitions(qfli_sql PRIVATE
    SQLITE_THREADSAFE=1
    SQLITE_DEFAULT_MEMSTATUS=0
    SQLITE_DQS=0
    SQLITE_OMIT_LOAD_EXTENSION)

target_compile_options(qfli_sql PRIVATE
    -Wall
    -Wextra
    -Wno-unused-parameter
    -Wno-error=format-security)

target_link_libraries(qfli_sql PUBLIC
    -static-libstdc++
    libace_napi.z.so
    libhilog_ndk.z.so
    m)

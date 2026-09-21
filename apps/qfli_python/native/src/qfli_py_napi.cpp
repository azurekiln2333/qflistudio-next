/*
 * NAPI 外壳：把 qfli_py_run() 暴露给 ArkTS。
 *
 * 这一层刻意做得很薄——只负责在 ArkTS 和纯 C 之间搬数据，不掺任何逻辑，
 * 因为它是整条链路里唯一没法用 Dart 测试覆盖的部分。任何「聪明」的处理
 * 放在这里都会变成上真机才能发现的问题。
 *
 * ArkTS 侧的用法：
 *
 *   import qfliPy from 'libqfli_py.so';
 *   const r = qfliPy.run('print("hi")', '', 0);
 *   // r = { exitCode, output, error, truncated }
 *   const v = qfliPy.version();          // "1.24.1 (ecfdd5d)"
 *
 * 注意 Flutter 的 Dart 代码不能直接调 NAPI，中间必须过一层 ArkTS：
 * Dart → MethodChannel → ArkTS → 本模块 → MicroPython。
 * 具体接线见 native/README.md。
 */
#include "napi/native_api.h"

#include <cstdlib>
#include <cstring>
#include <string>

#include "qfli_py_bridge.h"

namespace {

/* 读一个字符串参数；不是字符串或不存在时返回 false。 */
bool GetStringArg(napi_env env, napi_value value, std::string *out)
{
    napi_valuetype type = napi_undefined;
    if (napi_typeof(env, value, &type) != napi_ok)
        return false;
    if (type != napi_string)
        return false;

    size_t length = 0;
    if (napi_get_value_string_utf8(env, value, nullptr, 0, &length) != napi_ok)
        return false;

    std::string buffer(length, '\0');
    if (length > 0)
    {
        if (napi_get_value_string_utf8(env, value, &buffer[0], length + 1, &length) != napi_ok)
            return false;
    }
    *out = buffer;
    return true;
}

bool GetIntArg(napi_env env, napi_value value, int *out)
{
    napi_valuetype type = napi_undefined;
    if (napi_typeof(env, value, &type) != napi_ok)
        return false;
    if (type != napi_number)
        return false;
    int32_t number = 0;
    if (napi_get_value_int32(env, value, &number) != napi_ok)
        return false;
    *out = number;
    return true;
}

napi_value MakeString(napi_env env, const char *text)
{
    napi_value value = nullptr;
    if (text == nullptr)
    {
        napi_get_null(env, &value);
        return value;
    }
    napi_create_string_utf8(env, text, NAPI_AUTO_LENGTH, &value);
    return value;
}

/*
 * run(source: string, stdin: string, heapKb?: number)
 *   -> { exitCode: number, output: string, error: string | null, truncated: boolean }
 */
napi_value Run(napi_env env, napi_callback_info info)
{
    size_t argc = 3;
    napi_value argv[3] = {nullptr, nullptr, nullptr};
    napi_value thisArg = nullptr;

    if (napi_get_cb_info(env, info, &argc, argv, &thisArg, nullptr) != napi_ok)
        return nullptr;

    // ---- source ----
    std::string source;
    if (argc < 1 || !GetStringArg(env, argv[0], &source))
    {
        napi_throw_type_error(env, nullptr, "run(): 第一个参数必须是源码字符串");
        return nullptr;
    }

    // ---- stdin ----
    std::string stdinText;
    if (argc >= 2)
        GetStringArg(env, argv[1], &stdinText);

    // ---- heapKb ----
    int heapKb = 0;
    if (argc >= 3)
        GetIntArg(env, argv[2], &heapKb);

    // ---- 跑 ----
    QfliPyRunResult raw = qfli_py_run(
        source.c_str(),
        stdinText.empty() ? nullptr : stdinText.c_str(),
        heapKb);

    napi_value result = nullptr;
    napi_create_object(env, &result);

    napi_value exitCode = nullptr;
    napi_create_int32(env, raw.exit_code, &exitCode);
    napi_set_named_property(env, result, "exitCode", exitCode);

    napi_set_named_property(env, result, "output", MakeString(env, raw.output));
    napi_set_named_property(env, result, "error", MakeString(env, raw.error));

    napi_value truncated = nullptr;
    napi_get_boolean(env, raw.truncated != 0, &truncated);
    napi_set_named_property(env, result, "truncated", truncated);

    qfli_py_result_free(&raw);
    return result;
}

/*
 * version() -> string
 *
 * 返回内嵌 MicroPython 的版本，形如 "1.24.1 (ecfdd5d)"。
 *
 * 这个函数不需要初始化 VM，也不碰 GC 堆——纯粹把编译期常量搬出去，所以可以
 * 在任何时候安全地调，包括 App 刚起来、还没跑过任何 Python 代码的时候。
 * 用途是自证后端身份：版本号和 commit hash 来自上游头文件，改不了。
 */
napi_value Version(napi_env env, napi_callback_info info)
{
    (void)info;
    return MakeString(env, qfli_py_version());
}

napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor properties[] = {
        {"run", nullptr, Run, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"version", nullptr, Version, nullptr, nullptr, nullptr, napi_default,
         nullptr},
    };
    napi_define_properties(
        env, exports, sizeof(properties) / sizeof(properties[0]), properties);
    return exports;
}

}  // namespace

static napi_module qfliPyNativeModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "qfli_py",
    .nm_priv = nullptr,
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterQfliPyNativeModule(void)
{
    napi_module_register(&qfliPyNativeModule);
}

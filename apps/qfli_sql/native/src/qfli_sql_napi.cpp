#include "napi/native_api.h"

#include <string>

#include "qfli_sql_bridge.h"

namespace {

bool read_string(napi_env env, napi_value value, std::string *out)
{
    napi_valuetype type = napi_undefined;
    if (napi_typeof(env, value, &type) != napi_ok || type != napi_string) {
        return false;
    }
    size_t length = 0;
    if (napi_get_value_string_utf8(env, value, nullptr, 0, &length) != napi_ok) {
        return false;
    }
    std::string buffer(length, '\0');
    if (length > 0 && napi_get_value_string_utf8(
            env, value, &buffer[0], length + 1, &length) != napi_ok) {
        return false;
    }
    *out = buffer;
    return true;
}

napi_value make_string(napi_env env, const char *value)
{
    napi_value result = nullptr;
    napi_create_string_utf8(env, value == nullptr ? "" : value, NAPI_AUTO_LENGTH, &result);
    return result;
}

napi_value execute(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value argv[2] = {nullptr, nullptr};
    napi_value this_arg = nullptr;
    std::string source;
    std::string database_path;
    QfliSqlResult raw;
    napi_value result = nullptr;
    napi_value value = nullptr;

    if (napi_get_cb_info(env, info, &argc, argv, &this_arg, nullptr) != napi_ok ||
        argc < 2 || !read_string(env, argv[0], &source) ||
        !read_string(env, argv[1], &database_path)) {
        napi_throw_type_error(env, nullptr, "execute(source, databasePath) expects two strings");
        return nullptr;
    }
    if (!qfli_sql_execute(source.c_str(), database_path.c_str(), 1024 * 1024, &raw)) {
        napi_throw_error(env, nullptr, "SQLite bridge could not create a result");
        return nullptr;
    }

    napi_create_object(env, &result);
    napi_get_boolean(env, raw.available != 0, &value);
    napi_set_named_property(env, result, "available", value);
    napi_create_int32(env, raw.exit_code, &value);
    napi_set_named_property(env, result, "exitCode", value);
    napi_set_named_property(env, result, "output", make_string(env, raw.output));
    napi_set_named_property(env, result, "error", make_string(env, raw.error));
    napi_get_boolean(env, raw.truncated != 0, &value);
    napi_set_named_property(env, result, "truncated", value);
    qfli_sql_result_free(&raw);
    return result;
}

napi_value version(napi_env env, napi_callback_info info)
{
    (void)info;
    return make_string(env, qfli_sql_version());
}

napi_value init(napi_env env, napi_value exports)
{
    napi_property_descriptor properties[] = {
        {"execute", nullptr, execute, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"version", nullptr, version, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, 2, properties);
    return exports;
}

} // namespace

static napi_module qfli_sql_module = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = init,
    .nm_modname = "qfli_sql",
    .nm_priv = nullptr,
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void register_qfli_sql_module()
{
    napi_module_register(&qfli_sql_module);
}

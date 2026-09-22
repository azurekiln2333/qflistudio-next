#include "qfli_sql_bridge.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "sqlite3.h"

typedef struct {
    char *buffer;
    size_t length;
    size_t capacity;
    size_t limit;
    int truncated;
} OutputBuffer;

static void reset_result(QfliSqlResult *result)
{
    memset(result, 0, sizeof(*result));
    result->exit_code = 127;
}

static int append_text(OutputBuffer *buffer, const char *text, size_t length)
{
    if (buffer->truncated) return 1;
    if (length > buffer->limit - buffer->length - 1) {
        buffer->truncated = 1;
        return 1;
    }
    if (buffer->length + length + 1 > buffer->capacity) {
        size_t capacity = buffer->capacity == 0 ? 256 : buffer->capacity;
        while (capacity < buffer->length + length + 1) capacity *= 2;
        char *grown = (char *)realloc(buffer->buffer, capacity);
        if (grown == NULL) return 1;
        buffer->buffer = grown;
        buffer->capacity = capacity;
    }
    memcpy(buffer->buffer + buffer->length, text, length);
    buffer->length += length;
    buffer->buffer[buffer->length] = '\0';
    return 0;
}

static int append_column(OutputBuffer *buffer, const char *text)
{
    const char *value = text == NULL ? "NULL" : text;
    if (append_text(buffer, value, strlen(value)) != 0) return 1;
    return append_text(buffer, "\t", 1);
}

static int collect_row(void *context, int count, char **values, char **names)
{
    OutputBuffer *buffer = (OutputBuffer *)context;
    int index;
    (void)names;
    for (index = 0; index < count; index++) {
        if (append_column(buffer, values[index]) != 0) return 1;
    }
    if (count > 0) {
        buffer->length -= 1;
        buffer->buffer[buffer->length] = '\0';
    }
    return append_text(buffer, "\n", 1);
}

static char *copy_text(const char *text)
{
    const char *value = text == NULL ? "" : text;
    size_t length = strlen(value);
    char *copy = (char *)malloc(length + 1);
    if (copy == NULL) return NULL;
    memcpy(copy, value, length + 1);
    return copy;
}

int qfli_sql_execute(
    const char *source,
    const char *database_path,
    size_t output_limit,
    QfliSqlResult *result)
{
    sqlite3 *database = NULL;
    char *error_message = NULL;
    OutputBuffer output = {0};
    int sqlite_code;

    if (result == NULL || source == NULL || database_path == NULL) return 0;
    reset_result(result);
    output.limit = output_limit == 0 ? 1024 * 1024 : output_limit;

    sqlite_code = sqlite3_open_v2(
        database_path,
        &database,
        SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE,
        NULL);
    if (sqlite_code != SQLITE_OK) {
        result->error = copy_text(database == NULL
            ? "SQLite database open failed."
            : sqlite3_errmsg(database));
        if (database != NULL) sqlite3_close(database);
        return 1;
    }

    result->available = 1;
    sqlite_code = sqlite3_exec(
        database,
        source,
        collect_row,
        &output,
        &error_message);
    result->output = output.buffer == NULL ? copy_text("") : output.buffer;
    result->truncated = output.truncated;
    if (sqlite_code != SQLITE_OK && !output.truncated) {
        result->error = copy_text(error_message == NULL
            ? sqlite3_errmsg(database)
            : error_message);
        result->exit_code = 1;
    } else {
        result->exit_code = 0;
    }
    sqlite3_free(error_message);
    sqlite3_close(database);
    return 1;
}

void qfli_sql_result_free(QfliSqlResult *result)
{
    if (result == NULL) return;
    free(result->output);
    free(result->error);
    reset_result(result);
}

const char *qfli_sql_version(void)
{
    return sqlite3_libversion();
}

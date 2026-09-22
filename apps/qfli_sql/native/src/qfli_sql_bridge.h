#ifndef QFLI_SQL_BRIDGE_H
#define QFLI_SQL_BRIDGE_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    int available;
    int exit_code;
    int truncated;
    char *output;
    char *error;
} QfliSqlResult;

int qfli_sql_execute(
    const char *source,
    const char *database_path,
    size_t output_limit,
    QfliSqlResult *result);

void qfli_sql_result_free(QfliSqlResult *result);

const char *qfli_sql_version(void);

#ifdef __cplusplus
}
#endif

#endif

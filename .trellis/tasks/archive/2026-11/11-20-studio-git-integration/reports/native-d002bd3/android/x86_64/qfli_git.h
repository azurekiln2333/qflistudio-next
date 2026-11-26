/*
 * qfli_git - a small C interface over libgit2.
 *
 * Conventions:
 *  - Every function returns int. 0 is success, a negative value is failure.
 *  - On failure the caller's qg_error is filled in.
 *  - No thread local storage: a Dart isolate may move between threads.
 *  - Strings returned through char ** are allocated with malloc and must be
 *    released with qg_string_free.
 *  - cancel_flag points at a caller allocated int32_t. Once it becomes
 *    non-zero the operation stops with QG_ECANCELED. Pass NULL for no cancel.
 *  - All strings are UTF-8. Repository paths are absolute.
 */

#ifndef QFLI_GIT_H
#define QFLI_GIT_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * The library is compiled with -fvisibility=hidden, so every entry point
 * is marked here to reach the dynamic symbol table. The linker version
 * script (or the exported symbols list on Apple) then hides everything
 * else.
 */
#if defined(_WIN32)
#define QG_API __declspec(dllexport)
#elif defined(__GNUC__)
#define QG_API __attribute__((visibility("default")))
#else
#define QG_API
#endif

#define QG_API_VERSION 2

#define QG_ECANCELED (-1000)
#define QG_ECONFLICT (-1001) /* merge commit still has conflicts */
#define QG_EINVALID (-1002)  /* bad argument */

typedef struct qg_error {
	int code;     /* libgit2 error code or QG_E* */
	int klass;    /* libgit2 git_error_t, 0 for non-libgit2 errors */
	char message[512];
} qg_error;

typedef struct qg_repo qg_repo;

QG_API int qg_api_version(void);
QG_API const char *qg_libgit2_version(void); /* static string, e.g. "1.9.7" */
QG_API const char *qg_mbedtls_version(void);

QG_API int qg_init(const char *ca_file, qg_error *err); /* repeatable */
QG_API int qg_shutdown(void);

QG_API int qg_repo_init(const char *path, int bare, qg_repo **out, qg_error *err);
QG_API int qg_repo_open(const char *path, qg_repo **out, qg_error *err);
QG_API void qg_repo_free(qg_repo *repo);

QG_API int qg_clone(const char *url, const char *path, const char *username, const char *token,
             const int32_t *cancel_flag, qg_repo **out, qg_error *err);
QG_API int qg_fetch(qg_repo *repo, const char *remote, const char *username, const char *token,
             const int32_t *cancel_flag, qg_error *err);
QG_API int qg_push(qg_repo *repo, const char *remote, const char *refspec, const char *username,
            const char *token, const int32_t *cancel_flag, qg_error *err);

QG_API int qg_add_all(qg_repo *repo, qg_error *err); /* git add -A */
/*
 * Stage or unstage an explicit list of repository-relative paths.
 *
 * Paths are matched literally: wildcard characters are not expanded. An
 * empty, absolute or traversal path is rejected with QG_EINVALID. Staging a
 * tracked path that no longer exists in the work tree stages the deletion.
 * Unstaging restores the index entry from HEAD, or removes it when HEAD is
 * unborn or does not contain the path; the work tree is never modified.
 */
QG_API int qg_stage_paths(qg_repo *repo, const char **paths, int count, qg_error *err);
QG_API int qg_unstage_paths(qg_repo *repo, const char **paths, int count, qg_error *err);
QG_API int qg_commit(qg_repo *repo, const char *message, const char *name, const char *email,
              char out_oid[41], qg_error *err);
QG_API int qg_branch_create(qg_repo *repo, const char *name, const char *start_point /* NULL is HEAD */,
                     qg_error *err);
QG_API int qg_checkout_branch(qg_repo *repo, const char *name, qg_error *err); /* safe checkout */

/*
 * out_result: 0 already up to date, 1 fast-forward, 2 merge commit created,
 * 3 conflicts (index and worktree carry the conflicts, MERGE_HEAD is written).
 * out_oid receives the merged commit: for 0, 1 and 3 the commit the branch
 * points at, for 2 the new merge commit.
 */
QG_API int qg_merge(qg_repo *repo, const char *branch, const char *name, const char *email,
             int *out_result, char out_oid[41], qg_error *err);
/*
 * parents are HEAD + MERGE_HEAD. The repository must be in a merge state,
 * otherwise the function returns QG_EINVALID. At most 8 MERGE_HEAD entries
 * are supported; more entries return QG_EINVALID.
 */
QG_API int qg_merge_commit(qg_repo *repo, const char *message, const char *name, const char *email,
                    char out_oid[41], qg_error *err);

/*
 * errors out with the current state too.
 */
QG_API int qg_conflicts_json(qg_repo *repo, char **out_json, qg_error *err); /* ["path", ...] */
/*
 * {"patch": "…", "binary": false, "truncated": false}
 *
 * path NULL diffs every path, otherwise the path is matched literally.
 * staged is zero for the index-to-work-tree diff (untracked files included)
 * and non-zero for the HEAD-to-index diff. max_bytes <= 0 selects the
 * 262144 byte default; the patch text never exceeds the requested bound.
 * The patch is truncated on a UTF-8 character boundary.
 */
QG_API int qg_diff_json(qg_repo *repo, const char *path, int staged, int max_bytes,
                 char **out_json, qg_error *err);
/*
 * [{"oid": "…40 hex…", "message": "…", "authorName": "…",
 *   "authorEmail": "…", "time": 1790000000}, ...]
 *
 * Newest first. limit <= 0 selects 20 entries; the result is bounded to 500.
 * An unborn HEAD yields an empty array.
 */
QG_API int qg_log_json(qg_repo *repo, int limit, char **out_json, qg_error *err);
/*
 * [{"name": "main", "current": true, "remote": false,
 *   "upstream": "origin/main"}, ...]
 *
 * upstream is JSON null when the branch has no upstream. Remote branches are
 * listed with remote true and name in shorthand form (for example
 * "origin/main").
 */
QG_API int qg_branches_json(qg_repo *repo, char **out_json, qg_error *err);
/* [{"name": "origin", "url": "https://…"}, ...] */
QG_API int qg_remotes_json(qg_repo *repo, char **out_json, qg_error *err);
/* Create or update a named remote. URLs with embedded credentials are rejected. */
QG_API int qg_remote_set_url(qg_repo *repo, const char *name, const char *url, qg_error *err);
QG_API int qg_status_json(qg_repo *repo, char **out_json, qg_error *err);
/* [{"path": "a.txt", "status": "worktree_modified", "status_bits": 256}, ...] */
QG_API int qg_head_json(qg_repo *repo, char **out_json, qg_error *err);
/*
 * {"branch": "main", "oid": "…40 hex…", "state": "clean"}
 * state is "clean" when no operation is in progress, otherwise the libgit2
 * repository state name ("merge", "rebase", …).
 */

QG_API void qg_string_free(char *s);

#ifdef __cplusplus
}
#endif

#endif /* QFLI_GIT_H */

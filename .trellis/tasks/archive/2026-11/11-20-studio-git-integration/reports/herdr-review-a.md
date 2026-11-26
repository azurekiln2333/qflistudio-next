# Coordinator plugin review

Fix these before source CI:

1. qg_unstage_paths and qg_diff_json call git_repository_head_tree. This is not a public libgit2 repository API. Replace with an owned helper using git_repository_head + git_reference_peel(GIT_OBJECT_TREE), preserving GIT_EUNBORNBRANCH/GIT_ENOTFOUND and freeing the reference. Primary reference: https://github.com/libgit2/libgit2/blob/main/include/git2/repository.h . Check pinned upstream header if fetched, but do not build locally.
2. qg_head_json handles GIT_EUNBORNBRANCH but never resets rc to zero. It builds a valid JSON result and returns the negative unborn code. Reset rc after the handled condition; add CI-only unborn-head assertion.
3. qg_diff_json must emit exactly one JSON string, including zero deltas and binary-only. As you fix it, put encoding AFTER the body accumulation loop. Do not encode the empty body before appending patches.
4. Untracked content needs GIT_DIFF_SHOW_UNTRACKED_CONTENT, not only INCLUDE_UNTRACKED. Primary API reference: https://libgit2.org/docs/reference/main/diff/git_diff_option_t.html . Validate zero/one/multiple file output as JSON in actual FFI tests, not only substring checks on C output.
5. qg_diff_json currently creates full patches twice before truncating output. Review bounded-memory behavior for huge files and avoid unnecessary double generation.

No local tests or builds. Continue within assigned plugin ownership.

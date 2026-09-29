# Repository Split Design

## Layout

Keep `qflistudio/` as the existing main application Git root. Extract `qfli_studio_core/` and `qfli_{c,dart,go,java,json,lua,note,python,rust,sql,web}/` as sibling Git roots. The C repository owns `packages/qfli_c_runtime/`. The shared core repository owns `vendor/re_editor/` because all applications need the local Flutter/OHOS patch.

## Dependency Contract

Each app uses a sibling path dependency for `qfli_studio_core` and a sibling path override for `re_editor`. The C app uses its in-repository path dependency for `qfli_c_runtime`. Remove `resolution: workspace` and the old root workspace list. Each repository owns its own `pubspec.lock` after resolution. The sibling layout is required for local builds until separately hosted Git package dependencies are configured.

## Migration

Use `git subtree split` for each extracted application and core to preserve committed path history. Build new repositories in a staging directory under the writable workspace. Overlay source files from the current worktree and compare hashes before changing the original layout. Add the C runtime and vendored editor to their owning repositories. Move the verified repositories into sibling directories, then move the old in-tree directories to a recoverable backup and update the main app's configuration.

## Risks

- The root worktree is substantially dirty; copying from `HEAD` alone would lose user work.
- The Python native MicroPython directory is a gitlink. Preserve its upstream source URL and pinned commit in the extracted repository.
- `tool/` scripts and older documentation assume the original workspace layout; update executable entry points and current checkout instructions.
- Creating or pushing GitHub remotes is deferred because the local machine has no `gh` executable or GitHub token configured.

Active task: D:/MyNewProjects/qflistudio/.trellis/tasks/11-20-studio-git-integration

You are already trellis-implement, Pi A. Implement directly without subagents.
Read common.md in this directory, task artifacts and implement.jsonl first.
Your cwd is D:/MyNewProjects/_wt/studio-git-integration/qfli_git.

Own ONLY lib/, native/, test/, example/integration_test/ and a new Git API spec.
Do not edit .github/, tool/, pubspec*, native_libs.lock.json or platform binaries
(Pi D/root own those). The plugin baseline includes committed old prebuilts.

Implement design.md's exact public Dart methods/types: stagePaths, unstagePaths,
diff, log, branches, remotes, setRemote, GitBranch/GitRemote/GitCommit/GitDiff.
Extend native C ABI, FFI bindings, exports and disposal correctly. Update native
and Dart API versions together and check version before looking up new symbols.
Retain existing methods and isolate ownership. Cover empty HEAD, exact Unicode
paths, deletion, combined status, binary/large diffs, bounded history, remote
create/update and safe branch behavior. Reject credential-bearing remote URLs.
Do not hand-edit .git/config or implement Git object storage in Dart.

Immediately publish exact new C symbols, Dart constructor fields, API version
and semantics to reports/pi-a-api.md so Pi B/D can proceed. Then implement all
operations and meaningful native/Dart/integration fixtures. NO LOCAL TESTS.
If native tests need additional build registration, change native/CMakeLists.txt
within your scope. Pi D will wire cloud jobs and export checks.

Finish with reports/pi-a-plugin.md listing files and cloud requirements. Be
explicit that old checked-in binaries must be replaced from matching cloud CI.

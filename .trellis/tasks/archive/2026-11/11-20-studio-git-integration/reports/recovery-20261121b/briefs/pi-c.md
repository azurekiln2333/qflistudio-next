Active task: D:/MyNewProjects/qflistudio/.trellis/tasks/11-20-studio-git-integration
You are the Pi trellis-implement worker. Implementation is authorized. The previous workers exhausted output length without completing. Make concrete bounded file edits now. Do not spend the response repeating plans or re-reading the whole project history. Read design.md plus the relevant source and spec only. All product writes stay under D:/MyNewProjects/_wt/studio-git-integration. Preserve existing dirty UI/CI work. No local tests/builds/services/emulators/VM/WSL/adb/hdc. No commits/pushes/tags. Never touch original CloudTerminal. Do not spawn agents. Write your assigned code and a short report, then stop. Prefer incremental writes after a few source reads. Do not change models/global settings.

Own only core lib/git/native_git_backend.dart and native backend tests. Other worker creates exact design.md models/interface/factory. Implement NativeGitBackend(String root) implements GitBackend plus static cloneRepository({required String url,required String path,GitCredentials? credentials,GitCloneCancellation? cancellation}). Import git_backend.dart (exports models and cancellation) and git_repository_queue.dart, which exposes GitRepositoryQueue.run<T>(String root,Future<T> Function()). Cancellation has isCancelled/cancel/dispose/addListener/removeListener. Implement against plugin design.md new public methods/types; other Pi is writing them now. Native lazy initialization only mobile, preserve status flags including conflicts, handle empty/detached HEAD, identity validation, explicit refspec push, native CancelToken lifetime, error redaction, canonical serialization, offline network policy before transport. pullRebase throws clear unsupported; UI already uses separate fetch+merge. Do not edit other core files, plugin, UI or CI. Write real adapter now and meaningful cloud-only tests. Do not wait for binary build.
Report to D:\MyNewProjects\qflistudio\.trellis\tasks\11-20-studio-git-integration\reports\recovery-20261121\pi-c-report.md

RECOVERY UPDATE: Root has now written git_models.dart, git_backend.dart,
git_cancellation.dart, git_repository_queue.dart and cli_git_backend.dart.
The previous workers ended. Do not wait. Read design and your partial source,
then edit missing code immediately. Do not output edit commands as XML text.
Invoke the actual write/edit tool. Do not repeat plans.

Write final report to D:\MyNewProjects\qflistudio\.trellis\tasks\11-20-studio-git-integration\reports\recovery-20261121b\pi-c-report.md

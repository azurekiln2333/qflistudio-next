# Cloud delivery boundary

Inspected app workflow: `.github/workflows/app-installers.yml` at 6d1b96d.
Branches main/ci/**/release/** and v* tags trigger it (lines 9-15). CORE_REF and
JAVA_REF are explicit near line 87. The release job only accepts remote.* near
line 1971. Pi D must add Git preview tags explicitly, retaining remote.* support.
Keep all existing checks, eleven installer targets and Windows assistant.

Inspected plugin workflow: `.github/workflows/native.yml` at 89e656b. It currently
accepts main/integration/** and native-v* tags. Add the assigned release branch
trigger so pushes actually start native CI. Retain Dart checks added in 36faeb7.
Do not rely on unchanged main or on an unpushed local plugin dependency.

Native artifacts must be rebuilt for added exports. Existing import code is
`tool/import_artifacts.py`; its manifest validates source commit and SHA-256.
`tool/ci/collect_artifacts.py:94` currently only checks export prefixes. Require
the actual needed symbols as well. Pi A owns C exports and Pi D owns their CI gate.
The current plugin lock records native-v0.1.1, which cannot satisfy new ABI calls.

Sequence: source commit and cloud native run -> verified artifact import commit
-> full plugin commit pinned by core -> full core commit pinned by app -> app
preview tag -> successful release and packaged native/CA/provenance inspection.
Record each revision separately. A source commit is not the artifact commit.
Avoid pretending that tests against stale checked-in binaries cover new methods.

The previous plugin audit reported an Android Kotlin dependency resolution error.
Reproduce only in cloud and inspect the new run. Do not alter versions blindly.
Public evidence and current job logs determine whether the failure still exists.

App release remains 5.0.5+5000005 for the next prerelease family. Candidate tag:
v5.0.5-git.1, subject to a remote collision check. Every archive must record its
tag/SHA, core SHA, plugin Dart SHA and native source/version. Never move an old tag.
The root coordinator owns final pins, commits, pushes and tags.

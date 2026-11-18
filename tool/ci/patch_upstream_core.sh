#!/usr/bin/env bash
set -euo pipefail

# The shared core is compiled twice: by the OHOS Flutter fork for the HarmonyOS
# job, and by official Flutter for every other job. Official Flutter has no
# `TargetPlatform.ohos` and no `OhosView`, so the two must not appear in the
# Dart sources of the official copy.
#
# They no longer do, except in one file: the Huawei one-tap login view embeds a
# native ArkTS platform view and cannot avoid `OhosView`. This script replaces
# that single widget with an inert stub and then proves the rest of the tree is
# free of fork-only API, so a new reference fails the build here instead of
# surfacing as a compile error halfway through the job.

app_dir=${1:?usage: patch_upstream_core.sh APP_DIR CORE_DIR}
core_dir=${2:?usage: patch_upstream_core.sh APP_DIR CORE_DIR}

# Windows runners expose `python`, Linux and macOS runners `python3`, and a
# Windows logon can shadow `python3` with a non-functional App Execution Alias.
# Probe each candidate instead of trusting `command -v`.
python_bin=${PYTHON:-}
if [ -z "$python_bin" ]; then
  for candidate in python3 python; do
    if command -v "$candidate" >/dev/null 2>&1 &&
      "$candidate" -c 'import sys; sys.exit(0 if sys.version_info[0] == 3 else 1)' \
        >/dev/null 2>&1; then
      python_bin=$candidate
      break
    fi
  done
fi
if [ -z "$python_bin" ]; then
  echo "::error::python 3 was not found on this runner." >&2
  exit 1
fi

"$python_bin" - "$app_dir" "$core_dir" <<'PY'
from pathlib import Path
import sys

app = Path(sys.argv[1])
core = Path(sys.argv[2])

# Keep the public widget API while replacing the OHOS-only platform view.
huawei = core / "lib/pages/auth/huawei_quick_login_view.dart"
huawei.write_text("""import 'package:flutter/material.dart';

class HuaweiQuickLoginView extends StatelessWidget {
  const HuaweiQuickLoginView({
    super.key,
    required this.agreementAccepted,
    required this.onAuthorizationCode,
    required this.onError,
  });

  final bool agreementAccepted;
  final ValueChanged<String> onAuthorizationCode;
  final ValueChanged<String> onError;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
""", encoding="utf-8")

# Names that exist only on the OHOS Flutter fork.
FORBIDDEN = ("TargetPlatform.ohos", "OhosView")
roots = [app / "lib", core / "lib", core / "vendor/re_editor/lib"]
allowlist = {(core / "lib/pages/auth/huawei_quick_login_view.dart").resolve()}

offenders = []
for root in roots:
    if not root.is_dir():
        raise SystemExit(f"::error::source directory is missing: {root}")
    for path in sorted(root.rglob("*.dart")):
        if path.resolve() in allowlist:
            continue
        for number, line in enumerate(
            path.read_text(encoding="utf-8").splitlines(), start=1
        ):
            for name in FORBIDDEN:
                if name in line:
                    offenders.append(f"{path}:{number}: {name}: {line.strip()}")

if offenders:
    print("::error::OHOS-only API is left in a copy built by official Flutter.")
    for offender in offenders:
        print(f"::error::{offender}")
    raise SystemExit(1)

print("Patched upstream Flutter copy to exclude OHOS-only Dart APIs.")
PY

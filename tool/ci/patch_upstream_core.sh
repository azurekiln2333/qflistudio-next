#!/usr/bin/env bash
set -euo pipefail

# The shared core also contains the HarmonyOS build. The OHOS Flutter fork
# adds TargetPlatform.ohos and OhosView, but upstream Flutter does not.
# Keep the OHOS implementation for the OHOS job and remove only those
# references from the copies used by the upstream jobs.

app_dir=${1:?usage: patch_upstream_core.sh APP_DIR CORE_DIR}
core_dir=${2:?usage: patch_upstream_core.sh APP_DIR CORE_DIR}

python3 - "$app_dir" "$core_dir" <<'PY'
from pathlib import Path
import sys

app = Path(sys.argv[1])
core = Path(sys.argv[2])

def replace(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"expected compatibility text is missing: {path}")
    path.write_text(text.replace(old, new), encoding="utf-8")

replace(app / "lib/main.dart",
        "  final nativeStartup = !kIsWeb && defaultTargetPlatform == TargetPlatform.ohos;",
        "  final nativeStartup = false;")
replace(core / "lib/config/client_platform.dart",
        "    TargetPlatform.ohos => 'harmonyos',\n", "")
replace(core / "lib/interop/interop_transport.dart",
        "    TargetPlatform.ohos,\n", "")
replace(core / "lib/terminal/shell/local_shell_io.dart",
        "    case TargetPlatform.ohos:\n", "")
replace(core / "lib/services/app_private_roots.dart",
        "      TargetPlatform.ohos ||\n", "")
replace(core / "lib/terminal/widgets/terminal_input.dart",
        "      !kIsWeb && defaultTargetPlatform == TargetPlatform.ohos;",
        "      false;")
replace(core / "vendor/re_editor/lib/src/_consts.dart",
        "    !kIsWeb && defaultTargetPlatform == TargetPlatform.ohos;",
        "    false;")
replace(core / "lib/pages/auth/login_page.dart",
        "    final isOhos = defaultTargetPlatform == TargetPlatform.ohos;",
        "    final isOhos = false;")
replace(core / "lib/pages/auth/agreement_page.dart",
        "    if (kIsWeb || defaultTargetPlatform != TargetPlatform.ohos) {",
        "    if (true) {")

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

print("Patched upstream Flutter copy to exclude OHOS-only Dart APIs.")
PY

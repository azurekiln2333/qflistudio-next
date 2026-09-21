#!/usr/bin/env bash
# 在命令行里跑 hvigor Sync（不用 DevEco Studio 的图形界面）。
#
# 环境准备（DEVECO_SDK_HOME、ohpm shim、插件清单）都在 tool/lib/hvigor_env.sh 里，
# 那里注释写清了每个坑的成因。
#
# 用法：
#   tool/sync_ohos.sh qfli_python
#   tool/sync_ohos.sh qfli_python --no-daemon
set -euo pipefail

APP="${1:-}"
if [[ -z "$APP" ]]; then
  echo "用法: tool/sync_ohos.sh <app 目录名> [额外的 hvigor 参数...]" >&2
  echo "可用: $(ls apps 2>/dev/null | tr '\n' ' ')" >&2
  exit 2
fi
shift || true

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/hvigor_env.sh
source "$REPO_ROOT/tool/lib/hvigor_env.sh"
ensure_plugin_manifest

echo "DevEco  : $DEVECO_ROOT"
echo "项目    : apps/$APP/ohos"
echo "ohpmBin : $ohpmBin"
echo

cd "$OHOS_DIR"
"$NODE" "$(winpath "$HVIGOR_JS")" --sync -p product=default --analyze=normal \
  --parallel --incremental "$@"

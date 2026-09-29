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
  echo "可用: qfli_c qfli_dart qfli_go qfli_java qfli_json qfli_lua qfli_note qfli_python qfli_rust qfli_sql qfli_web" >&2
  exit 2
fi
shift || true

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/hvigor_env.sh
source "$REPO_ROOT/tool/lib/hvigor_env.sh"
ensure_plugin_manifest

echo "DevEco  : $DEVECO_ROOT"
echo "项目    : ../$APP/ohos"
echo "ohpmBin : $ohpmBin"
echo

cd "$OHOS_DIR"
"$NODE" "$(winpath "$HVIGOR_JS")" --sync -p product=default --analyze=normal \
  --parallel --incremental "$@"

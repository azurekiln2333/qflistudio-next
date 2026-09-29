#!/usr/bin/env bash
# 在命令行里打出 HAP（不用 DevEco Studio 的图形界面）。
#
# 环境准备见 tool/lib/hvigor_env.sh。产物落在
#   ../<app>/ohos/entry/build/default/outputs/default/entry-default-unsigned.hap
#
# 注意是 **unsigned**：仓库里现有的 .p7b 证书绑的是别的 bundleName，
# 所以 hvigor 会 `WARN: No signingConfig found for product default` 然后跳过签名。
# 要装到真机得先在 DevEco 里配好签名（File → Project Structure → Signing Configs，
# 勾 Automatically generate signature）。
#
# 用法：
#   tool/build_hap.sh qfli_python
#   tool/build_hap.sh qfli_python --mode module -p module=entry@default
set -euo pipefail

APP="${1:-}"
if [[ -z "$APP" ]]; then
  echo "用法: tool/build_hap.sh <app 目录名> [额外的 hvigor 参数...]" >&2
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
"$NODE" "$(winpath "$HVIGOR_JS")" assembleHap \
  --mode module -p module=entry@default -p product=default \
  --analyze=normal --parallel --incremental "$@"

echo
echo "产物:"
ls -la "$OHOS_DIR"/entry/build/default/outputs/default/*.hap 2>/dev/null || true

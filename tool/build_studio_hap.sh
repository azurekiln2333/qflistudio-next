#!/usr/bin/env bash
# 在命令行里打包 QFLIStudioN 的鸿蒙 HAP（不用 DevEco Studio 图形界面）。
#
# 用法：
#   tool/build_studio_hap.sh                 # debug 包（默认，装真机用这一份）
#   tool/build_studio_hap.sh --release       # release 包，需要 build-profile.json5 里的 releaseKey
#   tool/build_studio_hap.sh --help
#
# 和 tool/build_hap.sh 的区别：
#   - 这里打包的是 studio 本体（ohos/ 直接在仓库根下），不是 ../qfli_xxx 语言 App。
#   - 不带 --parallel：并行编译在 2C 小机器上会抢内存，串行更稳。
#   - 自动使用 DevEco 自带的 JBR 作为 JAVA_HOME，不依赖系统里的 JDK。
#
# 产物：
#   ohos/entry/build/default/outputs/default/entry-default-signed.hap
#
# 关于依赖的内核仓库：
#   pubspec.yaml 里 qfli_studio_core 指向 ../qfli_studio_core。要打包集成分支里的
#   内核，就在 studio 根目录放一个**未跟踪**的 pubspec_overrides.yaml（见
#   docs/agent-workbench-device.md）。本脚本只检查它是否存在、指向哪里，不创建它。
set -euo pipefail

STUDIO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# hvigor_env.sh 按 "$REPO_ROOT/../$APP/ohos" 定位工程。studio 的 ohos/ 就在仓库根下，
# 所以把 REPO_ROOT 设成 STUDIO_ROOT 本身：STUDIO_ROOT/../qflistudio/ohos 正好指回 studio。
REPO_ROOT="$STUDIO_ROOT"
APP="$(basename "$STUDIO_ROOT")"
BUNDLE="com.azurekiln.qflistudio"

BUILD_MODE="debug"
EXTRA=()
for arg in "$@"; do
  case "$arg" in
    --release) BUILD_MODE="release" ;;
    --debug) BUILD_MODE="debug" ;;
    -h|--help)
      sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) EXTRA+=("$arg") ;;
  esac
done

# shellcheck source=lib/hvigor_env.sh
source "$STUDIO_ROOT/tool/lib/hvigor_env.sh"
ensure_plugin_manifest

# DevEco 自带 JBR：hvigor 需要 JDK 17，系统里没有也能编。
export JAVA_HOME="$(winpath "$DEVECO_ROOT/jbr")"
export PATH="$DEVECO_ROOT/jbr/bin:$PATH"

echo "DevEco  : $DEVECO_ROOT"
echo "工程    : $OHOS_DIR"
echo "模式    : $BUILD_MODE"
echo "JAVA_HOME: $JAVA_HOME"

# 提醒内核来源：集成阶段容易忘了切换，编出来的包会引用旧内核。
OVERRIDES="$STUDIO_ROOT/pubspec_overrides.yaml"
if [[ -f "$OVERRIDES" ]]; then
  core_path="$(grep -A2 'qfli_studio_core' "$OVERRIDES" | grep 'path:' | head -1 | sed 's/.*path:[[:space:]]*//' | tr -d '"'"'"'' || true)"
  echo "内核覆盖: ${core_path:-（未写明路径）}"
  if [[ "$core_path" == *"_wt"* ]]; then
    echo "          ↑ 指向 worktree，这是集成前的正常状态"
  fi
else
  echo "内核    : ../qfli_studio_core（没有 pubspec_overrides.yaml）"
fi
echo

cd "$OHOS_DIR"
set +e
"$NODE" "$(winpath "$HVIGOR_JS")" assembleHap \
  --mode module -p module=entry@default -p product=default \
  -p "buildMode=$BUILD_MODE" --no-daemon "${EXTRA[@]+"${EXTRA[@]}"}"
status=$?
set -e

echo
HAP="$OHOS_DIR/entry/build/default/outputs/default/entry-default-signed.hap"
if [[ $status -ne 0 ]]; then
  echo "打包失败（退出码 $status）。常见原因：" >&2
  echo "  - 没在 DevEco Studio 里 Sync 过一次，ohos/.hvigor/cache 不完整" >&2
  echo "  - studio 根目录没跑过 flutter pub get（缺 .flutter-plugins-dependencies）" >&2
  exit "$status"
fi
if [[ -f "$HAP" ]]; then
  echo "产物: $HAP"
  echo "大小: $(du -h "$HAP" | cut -f1)"
  echo "下一步: tool/device_ui.sh install      # 装到已连接的真机"
else
  echo "没有找到 $HAP，产物可能被改到别的 target 目录。" >&2
  exit 3
fi
echo "包名: $BUNDLE"

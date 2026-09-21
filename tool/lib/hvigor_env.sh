#!/usr/bin/env bash
# 命令行跑 hvigor 的公共环境准备。被 tool/sync_ohos.sh 和 tool/build_hap.sh source。
#
# 为什么需要这么一层——下面每一件都是 DevEco Studio 图形界面替我们做了、
# 而终端里没人做的事：
#
#   1. DEVECO_SDK_HOME 没设。DevEco 启动时会自己设，终端里不会，
#      于是报 `Invalid value of 'DEVECO_SDK_HOME'`。
#
#   2. hvigor 调 ohpm.bat 装依赖时爆栈，报
#      `BATCH RECURSION exceeds STACK limits`（Recursion Count=242）。
#      ohpm.bat 会按「首参数长度」逐字符递归（见它自己的 :calculateFirstParamLen），
#      首参数是脚本全路径时就递归到栈满。绕法是用一个只把参数转发给 pm-cli.js
#      的 shim 顶掉它。
#
#   3. <app>/.flutter-plugins-dependencies 不存在。见 ensure_plugin_manifest。
#
# 另外调用方**故意**调 hvigor.js 而不是 hvigorw.js：后者会强制把 ohpmBin 覆盖回
# 真正的 ohpm.bat（`existsSync(e) && (process.env.ohpmBin = e)`），shim 就白做了。
# 代价是跳过了 wrapper 的 initNodePath（它负责把 @ohos/hvigor-ohos-plugin 放进
# 解析路径），所以**第一次 Sync 建议还是用 DevEco Studio**——等
# <app>/ohos/.hvigor/cache 热了之后，脚本就能稳定跑通。
#
# 调用方需先设好 $REPO_ROOT 和 $APP，然后 source 本文件，之后可用：
#   $OHOS_DIR  $DEVECO_ROOT  $NODE  $HVIGOR_JS

# node.exe / hvigor 都是原生 Windows 程序，喂给它们的必须是 Windows 风格路径。
# 在 Git Bash 里路径长这样 `/d/ProgramFiles/...`，直接传过去会被当成 `D:\d\ProgramFiles\...`。
winpath() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi
}

OHOS_DIR="$REPO_ROOT/apps/$APP/ohos"
if [[ ! -d "$OHOS_DIR" ]]; then
  echo "找不到 $OHOS_DIR" >&2
  exit 2
fi

# DevEco 安装根目录：优先环境变量，其次常见路径。
DEVECO_ROOT="${DEVECO_HOME:-${DEVECO_SDK_HOME:-}}"
if [[ -n "$DEVECO_ROOT" ]]; then
  # DEVECO_SDK_HOME 通常指向 <DevEco>/sdk，往上一层才是安装根目录。
  [[ "$(basename "$DEVECO_ROOT")" == "sdk" ]] && DEVECO_ROOT="$(dirname "$DEVECO_ROOT")"
fi
for candidate in "$DEVECO_ROOT" \
  "/d/ProgramFiles/Huawei/DevEco Studio" \
  "/c/Program Files/Huawei/DevEco Studio"; do
  [[ -n "$candidate" && -d "$candidate/tools/hvigor" ]] && DEVECO_ROOT="$candidate" && break
done
if [[ -z "${DEVECO_ROOT:-}" || ! -d "$DEVECO_ROOT/tools/hvigor" ]]; then
  echo "没找到 DevEco Studio 安装目录，请设 DEVECO_HOME（例如 D:\\ProgramFiles\\Huawei\\DevEco Studio）" >&2
  exit 2
fi

NODE="$DEVECO_ROOT/tools/node/node.exe"
[[ -x "$NODE" ]] || NODE="$DEVECO_ROOT/tools/node/bin/node"
PM_CLI="$DEVECO_ROOT/tools/ohpm/bin/pm-cli.js"
HVIGOR_JS="$DEVECO_ROOT/tools/hvigor/hvigor/bin/hvigor.js"

export DEVECO_SDK_HOME="$(winpath "$DEVECO_ROOT/sdk")"

# 造一个 ohpm shim：把参数原样交给 pm-cli.js，绕开会递归的 ohpm.bat。
SHIM_DIR="${TMPDIR:-/tmp}/ohpm-shim"
mkdir -p "$SHIM_DIR"
cat > "$SHIM_DIR/ohpm.bat" <<EOF
@echo off
"$(winpath "$NODE")" "$(winpath "$PM_CLI")" %*
EOF
export ohpmBin="$(winpath "$SHIM_DIR/ohpm.bat")"

# ── 把 workspace 根的插件清单补到 app 目录 ────────────────────────────────────
#
# flutter-hvigor-plugin 只认 <app 目录>/.flutter-plugins-dependencies：
#
#   const nativePlugins = findFlutterPlugins(
#       path.join(flutterProjectPath, '.flutter-plugins-dependencies'))
#   nativePlugins.forEach(p => {
#     overrides[p.name] = `file:${path.join(p.path, 'ohos')}`  // app 级 override
#     dependenciesOpt[p.name] = ''                             // entry 级依赖
#   })
#
# 没这个文件 → 没有 override、没有依赖 → entry/oh_modules 里不会建出
# path_provider_ohos 软链 → ArkTS 报
# `Cannot find module 'path_provider_ohos'`（生成的 GeneratedPluginRegistrant.ets
# 里 import 了它）。
#
# 问题是 flutter tool 在 pub workspace 下**只往工作区根写一份**：
# project.dart 里是 `directory.childFile('.flutter-plugins-dependencies')`，
# 而 workspace 模式下 FlutterProject 就是根包，`flutter pub get` 输出也印证了
# （"Got dependencies in <仓库根>"）。它不会给每个 workspace 成员各写一份，
# ohos 那条链也没有像 widget_preview 那样遍历 workspaceProjects。
# 而且这个文件被 .gitignore 忽略（生成物，含本机绝对路径），所以新克隆的仓库
# 必然缺它——四个新 app 就是这么中招的。
#
# 五个 app 共用同一个 workspace，插件集合完全一样（根那份和 qfli_c 那份逐字节
# 只差 date_created），所以从根复制过来就是 tool 本来会写出的内容。
ensure_plugin_manifest() {
  local root_manifest="$REPO_ROOT/.flutter-plugins-dependencies"
  local app_manifest="$REPO_ROOT/apps/$APP/.flutter-plugins-dependencies"
  if [[ ! -f "$root_manifest" ]]; then
    echo "缺少 $root_manifest。" >&2
    echo "先在仓库根跑一次 flutter pub get 让 tool 生成它，再重试。" >&2
    return 1
  fi
  if ! cmp -s "$root_manifest" "$app_manifest"; then
    cp "$root_manifest" "$app_manifest"
    echo "已补齐 apps/$APP/.flutter-plugins-dependencies（插件清单）"
  fi
}

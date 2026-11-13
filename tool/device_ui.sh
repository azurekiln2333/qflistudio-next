#!/usr/bin/env bash
# 真机操作封装：装包、启动、截图、点击、输入、返回、读性能日志。
#
# 设备地址从环境变量 HDC_TARGET 读，不写死：
#   export HDC_TARGET=192.168.68.207:46551     # hdc list targets 里的那一行
# 只连了一台设备时可以留空，脚本会省略 -t。
#
# 用法：
#   tool/device_ui.sh targets
#   tool/device_ui.sh install [hap 路径]
#   tool/device_ui.sh launch | stop
#   tool/device_ui.sh shot <名字>              # 截图存到 $SHOT_DIR/<名字>.png
#   tool/device_ui.sh tap <x> <y>
#   tool/device_ui.sh swipe <x1> <y1> <x2> <y2> [速度]   # 滑动，解锁屏也用这个
#   tool/device_ui.sh text <文字>              # 往已聚焦的输入框打字
#   tool/device_ui.sh input <x> <y> <文字>     # 先点坐标再打字
#   tool/device_ui.sh back | home
#   tool/device_ui.sh wake                     # 亮屏（不解锁）
#   tool/device_ui.sh screen-on [毫秒]          # 临时拉长自动锁屏时间，默认 10 分钟
#   tool/device_ui.sh layout [名字]            # 导出当前界面布局，用来找坐标
#   tool/device_ui.sh log [秒数]               # 过滤 [agent-perf] 性能行
#   tool/device_ui.sh wait <秒数>
#
# 环境变量：
#   HDC_TARGET  设备地址（默认空 = 唯一设备）
#   SHOT_DIR    截图目录（默认 ./screenshots）
#   BUNDLE      包名（默认 com.azurekiln.qflistudio）
#   ABILITY     入口 Ability（默认 EntryAbility）
set -euo pipefail

STUDIO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE="${BUNDLE:-com.azurekiln.qflistudio}"
ABILITY="${ABILITY:-EntryAbility}"
# Git Bash 里要把 Windows 风格目录转成 POSIX 路径，否则 mkdir/dirname 会把
# 反斜杠当成普通字符，文件落到奇怪的地方。
SHOT_DIR="${SHOT_DIR:-$PWD/screenshots}"
if command -v cygpath >/dev/null 2>&1; then
  SHOT_DIR="$(cygpath -u "$SHOT_DIR")"
fi
DEFAULT_HAP="$STUDIO_ROOT/ohos/entry/build/default/outputs/default/entry-default-signed.hap"
REMOTE_DIR="/data/local/tmp"

# hdc 是原生 Windows 程序：本地路径要转成 Windows 风格。
winpath() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi
}

# Git Bash（MSYS）会把参数里的 /data/local/tmp/... 当成 POSIX 路径改写成
# D:/ProgramFiles/Git/data/local/tmp/...，而 hdc 即使找不到源文件仍返回 0。
# 关掉这个改写，设备路径才能原样传给 hdc。
export MSYS2_ARG_CONV_EXCL='*'

hdc_cmd() {
  if [[ -n "${HDC_TARGET:-}" ]]; then
    hdc -t "$HDC_TARGET" "$@"
  else
    hdc "$@"
  fi
}

need_device() {
  local targets
  targets="$(hdc list targets 2>/dev/null | tr -d '\r' | grep -v '^\[Empty\]$' || true)"
  if [[ -z "$targets" ]]; then
    echo "没有已连接的设备。先插线或 hdc tconn <地址>，再 hdc list targets 确认。" >&2
    exit 2
  fi
  if [[ -z "${HDC_TARGET:-}" ]] && [[ "$(printf '%s\n' "$targets" | wc -l)" -gt 1 ]]; then
    echo "连了多台设备，请设 HDC_TARGET。当前：" >&2
    printf '  %s\n' $targets >&2
    exit 2
  fi
}

# 从设备取一个文件到本地。
pull() {
  local remote="$1" local_path="$2"
  mkdir -p "$(dirname "$local_path")"
  if ! hdc_cmd file recv "$remote" "$(winpath "$local_path")" >/dev/null; then
    echo "取回文件失败：$remote -> $local_path" >&2
    return 1
  fi
  if [[ ! -f "$local_path" ]]; then
    echo "hdc 报成功但本地没有文件：$local_path" >&2
    return 1
  fi
  echo "$local_path ($(du -h "$local_path" | cut -f1))"
}

cmd="${1:-}"
shift || true

case "$cmd" in
  targets)
    hdc list targets
    ;;

  install)
    need_device
    hap="${1:-$DEFAULT_HAP}"
    if [[ ! -f "$hap" ]]; then
      echo "找不到 HAP：$hap" >&2
      echo "先跑 tool/build_studio_hap.sh。" >&2
      exit 2
    fi
    echo "安装 $(basename "$hap")（$(du -h "$hap" | cut -f1)）"
    hdc_cmd install -r "$(winpath "$hap")"
    ;;

  launch)
    need_device
    hdc_cmd shell aa start -a "$ABILITY" -b "$BUNDLE"
    ;;

  stop)
    need_device
    hdc_cmd shell aa force-stop "$BUNDLE"
    ;;

  shot)
    need_device
    name="${1:-shot-$(date +%H%M%S)}"
    remote="$REMOTE_DIR/$name.png"
    hdc_cmd shell uitest screenCap -p "$remote" >/dev/null
    pull "$remote" "$SHOT_DIR/$name.png"
    hdc_cmd shell rm -f "$remote" >/dev/null 2>&1 || true
    ;;

  tap)
    need_device
    [[ $# -ge 2 ]] || { echo "用法: tool/device_ui.sh tap <x> <y>" >&2; exit 2; }
    hdc_cmd shell uitest uiInput click "$1" "$2"
    ;;

  swipe)
    need_device
    [[ $# -ge 4 ]] || { echo "用法: tool/device_ui.sh swipe <x1> <y1> <x2> <y2> [速度]" >&2; exit 2; }
    hdc_cmd shell uitest uiInput swipe "$1" "$2" "$3" "$4" "${5:-600}"
    ;;

  text)
    need_device
    [[ $# -ge 1 ]] || { echo "用法: tool/device_ui.sh text <文字>" >&2; exit 2; }
    hdc_cmd shell uitest uiInput text "$*"
    ;;

  input)
    need_device
    [[ $# -ge 3 ]] || { echo "用法: tool/device_ui.sh input <x> <y> <文字>" >&2; exit 2; }
    x="$1"; y="$2"; shift 2
    hdc_cmd shell uitest uiInput click "$x" "$y"
    sleep 0.3
    hdc_cmd shell uitest uiInput text "$*"
    ;;

  back)
    need_device
    hdc_cmd shell uitest uiInput keyEvent Back
    ;;

  wake)
    need_device
    # 比 keyEvent Power 安全：Power 是开关，亮屏时按一下会反而黑屏。
    hdc_cmd shell power-shell wakeup
    ;;

  screen-on)
    need_device
    ms="${1:-600000}"
    hdc_cmd shell "power-shell timeout -o $ms"
    ;;

  home)
    need_device
    hdc_cmd shell uitest uiInput keyEvent Home
    ;;

  layout)
    need_device
    name="${1:-layout-$(date +%H%M%S)}"
    remote="$REMOTE_DIR/$name.json"
    hdc_cmd shell uitest dumpLayout -p "$remote" >/dev/null
    pull "$remote" "$SHOT_DIR/$name.json"
    hdc_cmd shell rm -f "$remote" >/dev/null 2>&1 || true
    ;;

  log)
    need_device
    seconds="${1:-20}"
    echo "抓 ${seconds} 秒 hilog，只显示 [agent-perf] 行（Ctrl+C 提前结束）"
    # hilog 是流式输出，用 timeout 收口；没有 timeout 时退回 head。
    # timeout 是外部程序，不能调用 shell 函数 hdc_cmd，所以这里直接拼 hdc 参数。
    hdc_args=()
    if [[ -n "${HDC_TARGET:-}" ]]; then
      hdc_args=(-t "$HDC_TARGET")
    fi
    if command -v timeout >/dev/null 2>&1; then
      timeout "$seconds" hdc "${hdc_args[@]}" shell hilog 2>/dev/null | grep --line-buffered '\[agent-perf\]' || true
    else
      hdc "${hdc_args[@]}" shell hilog 2>/dev/null | grep --line-buffered '\[agent-perf\]' | head -200 || true
    fi
    ;;

  wait)
    sleep "${1:-1}"
    ;;

  ""|-h|--help|help)
    sed -n '2,28p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    ;;

  *)
    echo "未知子命令：$cmd" >&2
    sed -n '2,28p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2
    exit 2
    ;;
esac

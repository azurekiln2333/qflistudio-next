# 鸿蒙真机：打包、安装、截图

## 当前云端规则

本文保留旧设备操作记录。
构建、测试、分析和依赖安装只在 GitHub Actions 执行。
本机不要运行下列历史命令。
`--no-pub` 不构成本地验证例外。
请关闭 IDE 自动构建、自动测试、依赖安装和 Sync。
不要在本机启动 WSL 或下载构建产物。
真机验收需要独立授权，不属于云端构建通过的结论。

历史记录使用两份脚本：

| 脚本 | 作用 |
| --- | --- |
| `tool/build_studio_hap.sh` | 命令行打 studio 本体的 HAP 包 |
| `tool/device_ui.sh` | 封装 hdc：装包、启动、截图、点击、输入、返回、读日志 |

## 历史打包记录

以下前提和命令仅说明旧流程，不授权本地执行。

```bash
tool/build_studio_hap.sh              # debug
tool/build_studio_hap.sh --release    # release，需要 build-profile.json5 里的 releaseKey
```

- 自动使用 DevEco 自带 JBR（`$DEVECO_HOME/jbr`）作为 `JAVA_HOME`，系统没装 JDK 17 也能编。
- 不带 `--parallel`：2C 小机器上并行编译会抢内存，串行更稳。
- 前提：studio 根目录跑过 `flutter pub get`；`ohos/.hvigor/cache` 至少 Sync 过一次。
- 产物：`ohos/entry/build/default/outputs/default/entry-default-signed.hap`

## 依赖的内核仓库（集成时必看）

新电脑先按[根 README](../README.md#github-仓库与新电脑克隆)克隆两个 GitHub 仓库。
标准克隆目录是并列的 `qflistudio-next/` 与 `qflistudio-core/`。
应用通过 `../qflistudio-core` 引用内核。
Dart 包名仍为 `qfli_studio_core`。
这些名称不代表本机已有目录。

云端任务须记录两个仓库的完整提交、包名和版本。
云端须核对锁文件路径、版本与实际内核检出。
路径依赖的锁文件不记录 Git 提交。
旧集成记录使用过未跟踪的 `pubspec_overrides.yaml`。
其中的 `_wt/integration/` 是历史 worktree 路径。
不要把它作为新电脑的依赖配置。
不要提交机器专属覆盖文件。

## 真机操作历史

以下命令仅作历史记录，不是当前操作指南。
构建与产物校验使用获准的云端流程。
设备操作与真机验收需要独立授权。
地址 `192.0.2.10` 是文档示例，不是真实设备地址。

```bash
export HDC_TARGET=$(hdc list targets | head -1)   # 文档示例：192.0.2.10:46551
export SHOT_DIR=./screenshots                     # 不设就用 ./screenshots

tool/device_ui.sh targets            # 看设备
tool/device_ui.sh install            # 装 entry-default-signed.hap
tool/device_ui.sh launch             # 拉起 com.azurekiln.qflistudio
tool/device_ui.sh shot 02-editor     # 截图到 $SHOT_DIR/02-editor.png
tool/device_ui.sh layout 02-editor   # 导出布局 JSON，用来找坐标
tool/device_ui.sh tap 640 1200       # 点击
tool/device_ui.sh swipe 636 2500 636 900   # 滑动
tool/device_ui.sh text "你好"         # 往已聚焦的输入框打字
tool/device_ui.sh input 640 2400 "你好"    # 先点坐标再打字
tool/device_ui.sh back               # 返回
tool/device_ui.sh log 30             # 抓 30 秒 hilog，只显示 [agent-perf]
```

## 历史排查中的两个坑

1. **Git Bash 会改写参数**。MSYS 会把 `hdc file recv` 的设备路径
   `/data/local/tmp/x.png` 改写成 `D:/ProgramFiles/Git/data/local/tmp/x.png`，
   而 hdc 即使找不到源文件仍返回 0。脚本里已设 `MSYS2_ARG_CONV_EXCL='*'`，
   并额外检查本地文件是否真的落地。自己手敲命令时要记得这一点。
2. **锁屏状态下 `aa start` 会失败**，报
   `Error Code:10106102 ... The device screen is locked`，开发者模式下系统不会自动解锁。
   自动化无法通过人脸或 PIN。跑全流程前先手动解锁一次，并先拉长息屏时间：

   ```bash
   tool/device_ui.sh screen-on 600000   # 10 分钟内不自动息屏
   ```

   `keyEvent Power` 是开关，亮屏时按会反而黑屏；要亮屏用 `tool/device_ui.sh wake`。

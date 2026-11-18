# 鸿蒙真机：打包、安装、截图

两份脚本：

| 脚本 | 作用 |
| --- | --- |
| `tool/build_studio_hap.sh` | 命令行打 studio 本体的 HAP 包 |
| `tool/device_ui.sh` | 封装 hdc：装包、启动、截图、点击、输入、返回、读日志 |

## 打包

```bash
tool/build_studio_hap.sh              # debug
tool/build_studio_hap.sh --release    # release，需要 build-profile.json5 里的 releaseKey
```

- 自动使用 DevEco 自带 JBR（`$DEVECO_HOME/jbr`）作为 `JAVA_HOME`，系统没装 JDK 17 也能编。
- 不带 `--parallel`：2C 小机器上并行编译会抢内存，串行更稳。
- 前提：studio 根目录跑过 `flutter pub get`；`ohos/.hvigor/cache` 至少 Sync 过一次。
- 产物：`ohos/entry/build/default/outputs/default/entry-default-signed.hap`

## 依赖的内核仓库（集成时必看）

`pubspec.yaml` 里 `qfli_studio_core` 指向 `../qfli_studio_core`。要打包**集成分支**的内核，
在 studio 根目录放一个未跟踪的 `pubspec_overrides.yaml`：

```yaml
dependency_overrides:
  qfli_studio_core:
    path: ../_wt/integration/qfli_studio_core
```

它**必须不被提交**。本仓库已把它写进 `.git/info/exclude`（本地忽略，不改 `.gitignore`）。
确认一遍：

```bash
git check-ignore -v pubspec_overrides.yaml
# .git/info/exclude:23:pubspec_overrides.yaml	pubspec_overrides.yaml
git status --short            # 不应出现 pubspec_overrides.yaml
```

打包前脚本会打印实际使用的内核路径；看到 `_wt` 说明用的是 worktree 里的内核。
集成完成后删掉这个文件，回到 `../qfli_studio_core`。

## 真机操作

```bash
export HDC_TARGET=$(hdc list targets | head -1)   # 例如 192.168.68.207:46551
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

## 两个坑

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

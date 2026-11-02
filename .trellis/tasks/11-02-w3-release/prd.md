# W3 发版（版本号 + 签名 release HAP）
仓库：qflistudio（ohos 工程）与 qfli_studio_core。需求：任务书 §3-W3“发版”。

## 要求
- 升级版本号：pubspec.yaml 与 ohos/AppScope/app.json5（versionName 升级、versionCode 递增），与 X-Client-Platform 头里的版本保持一致（若取自同一来源）。
- 用仓库现有签名配置构建 release 模式签名 HAP（hvigor assembleHap，buildMode=release）。没有 release 签名材料时，用现有可用配置构建并在 Result 写明，release 签名材料列为用户待办。不得提交任何签名材料或口令；ohos/build-profile.json5 有用户既有未提交改动，不要提交它。
- 先做版本号与试构建；等 root 通知“测试全绿”（w37:p4 负责）后再出最终包。
- 真机冒烟：hdc -t 192.168.68.207:46551 install -r 安装后用文字取证（hilog、uitest dumpLayout，不读截图）确认能启动、设置页有协议与注销入口、登录页没有“其他方式登录”。不卸载任何应用；锁屏就停下报告。

## 输出
Result：版本号、HAP 绝对路径、SHA256、签名类型（release/debug）、构建命令与结论、需用户在 AGC 完成的事项。

# W3a 状态栏与挖孔区避让、登录入口
仓库：D:/MyNewProjects/qfli_studio_core（共享内核）与 qflistudio/ohos。需求：§3-W3 对应条目。

## 范围
- 状态栏与挖孔区重叠（华为上架驳回原因）：顶部栏避让 getWindowAvoidArea 的 TYPE_SYSTEM 与 TYPE_CUTOUT，或修正全屏布局；Flutter 侧 padding.top 正确；直板、折叠展开、折叠三态都处理。参考坐标与链接见任务书。
- 登录：鸿蒙端隐藏 lib/pages/auth/login_page.dart 的“其他方式登录”，去掉注册入口；account_login_page.dart 的华为绑定页在 phoneAvailable===false 时不提供跳过和绑定。
- 真机：hdc -t 192.168.68.207:46551。只用文字取证（hilog、uitest dumpLayout），不要把截图读进上下文；不卸载任何应用；遇到锁屏就停下报告。

## 边界
W3b 负责设置页、agreement_config、社区、AI、api_client.dart；这些不要动。发版（版本号、release HAP）由 root 另行指示。

## 验收
§4 第 3（客户端）、10 条。

# Implement — W3a 状态栏与挖孔区避让、登录入口

## 步骤

- [x] 1. core：新增 `lib/services/ohos_safe_area.dart`
- [x] 2. core：`login_page.dart` 鸿蒙隐藏"其他方式登录"并应用顶部避让
- [x] 3. core：`account_login_page.dart` 无手机号时禁用绑定与跳过
- [x] 4. ohos：`EntryAbility.ets` 读避让区并上报通道
- [x] 5. ohos：`HuaweiQuickLoginPlatformView.ets` 顶部按避让区内缩
- [x] 6. ohos：`Index.ets` 启动遮罩顶部内边距取避让高度
- [x] 7. core：新增 `test/auth_login_entry_test.dart`，跑测试与分析
- [x] 8. ohos：编译校验通过
- [x] 9. 提交 core 与 ohos 两个仓库（显式路径）

## 验收命令

- `flutter analyze lib/pages/auth lib/services/ohos_safe_area.dart test/auth_login_entry_test.dart`
- `flutter test test/auth_login_entry_test.dart`
- `hvigorw --mode module -p product=default assembleHap --no-daemon`

## Result

### 提交

| 仓库 | 短哈希 | 标题 |
| --- | --- | --- |
| qflistudio | 894ae3e | fix(ohos): keep the status bar and cutout clear of page content |
| qfli_studio_core | 0977d0b | feat(auth): hide alternate sign-in on HarmonyOS and avoid the cutout |

两个提交都没有署名行。

### 共享内核 `D:/MyNewProjects/qfli_studio_core`

新增 `lib/services/ohos_safe_area.dart`。

- 该文件订阅 `qflistudio/safe_area` 通道，缓存原生上报的顶部避让高度。
- `OhosSafeArea.topInset` 取视口 `padding.top` 与原生值中较大者。
- `OhosSafeAreaBuilder` 在原生值到达后重建页面。

`lib/pages/auth/login_page.dart` 的改动。

- 平台为鸿蒙时不渲染"其他方式登录"。注册入口随该按钮一起消失。
- 滚动区顶部内边距加上避让高度。
- 页面内容抽出 `buildContent`，原生值异步到达后能重建。

`lib/pages/auth/account_login_page.dart` 的改动。

- 绑定页在 `phoneAvailable == false` 时不显示"跳过，创建新账号"。
- 此时"绑定并登录"按钮禁用，并提示"请使用已绑定手机号的华为账号"。
- `_submit` 对这类提交直接拒绝。
- 默认值 `phoneAvailable` 从 `false` 改为 `true`。不传参的调用方不会因此按无手机号处理。

新增 `test/auth_login_entry_test.dart`，5 个用例。

- 鸿蒙隐藏其他登录入口。
- 非鸿蒙保留该入口。
- 无手机号禁止跳过与绑定。
- 有手机号可以跳过。
- 原生避让值到达后，页面顶部内边距生效。

### ohos `D:/MyNewProjects/qflistudio/ohos`

`entryability/EntryAbility.ets` 的改动。

- 新增 `WindowSafeArea`、`screenDensity`、`readWindowSafeArea`。
- `onWindowStageCreate` 读 `getWindowAvoidArea(TYPE_SYSTEM)` 与 `TYPE_CUTOUT`。
- 同时订阅 `avoidAreaChange`，折叠与展开各报各的值。
- `onWindowStageDestroy` 退订。
- 新增 `qflistudio/safe_area` 通道。`getSafeArea` 返回当前值，窗口变化时主动推 `update`。

`components/HuaweiQuickLoginPlatformView.ets` 的改动。

- 平台视图创建时读避让高度（px）。
- 该值以 `@Prop` 传给按钮组件，给华为一键登录按钮加顶部内边距。

`pages/Index.ets` 的改动。

- 启动遮罩的进度条列加 `top` 内边距，不再压在挖孔区。

密度取自 `display.getDefaultDisplaySync().densityPixels`。`WindowProperties` 没有 `density` 字段，首次编译报 `10505001`。

### 测试结果

- `flutter analyze` → `No issues found!`
- `flutter test test/auth_login_entry_test.dart` → `+5: All tests passed!`
- 加上两个头部主题测试一起跑 → `+14: All tests passed!`
- `hvigorw ... assembleHap` → `BUILD SUCCESSFUL`。只剩第三方库的 ArkTS 警告。

### 未完成项及原因

1. 真机文字取证未做。`hdc -t 192.168.68.207:46551` 需要设备在线并装上本次构建。本 worker 没有装机，也不卸载应用。Mate 60 与 Mate X5 的三态取证留在发版前做。
2. 全量 `flutter test` 有 10 个既有失败，都不在本次改动的文件里。涉及 `editor_reload_from_disk_test`、`points_page_test`、`offline_editor_gates_test`、`tasks_page_checkin_test`、`vibe_e2e_*`、`vibe_coding_controller_test`。同仓库的 W3b 正在改 `vibe_coding_controller`、社区与设置页，这些失败要从 W3b 收尾。
3. `ohos/build-profile.json5` 与 `ohos/entry/src/main/ets/interop/AgreementBridge.ets` 在 W3a 边界之外，没有提交。前者是用户既有的未提交改动。后者是 W3b 新增的协议桥。

### 需要用户本人处理

1. 装机后在 Mate 60 与 Mate X5 上验直板、展开、折叠三态，确认顶部不再与状态栏、挖孔区重叠。
2. 发版由用户与 root 另行决定。版本号、签名 release HAP、上架提交都不在本任务内。

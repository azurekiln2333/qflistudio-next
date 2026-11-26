# 实施顺序与检查

## 工作树

从已检查的 Core 和 App 提交创建隔离工作树。
Core 基线为 `d2eca95626726961fd5461e94e5c50c1389fd088`。
App 基线为 `0830e392fcf5dc7bc48dec59758e3d6347351950`。
两仓库继续使用同级路径依赖。
不修改发布工作树的插件注册文件。

## 四个 Pi 的写入范围

| 成员 | 范围 | 交付 |
| --- | --- | --- |
| A | Core shell、编辑器宿主和编辑布局 | 单工作台与保活接口 |
| B | App Windows runner、Core 拖入服务 | 目录原地登记和打开 |
| C | Core 设备类别、App 移动平台桥接 | 手机和平板分类 |
| D | Core GitHub、首页标签和个人页面 | 连接迁移与直接仓库列表 |

主代理负责入口组合、共享接口和交叉检查。
每个成员只能修改自己的文件范围。
冲突文件由主代理统一修改。
代理不得自行提交发布标签。
产品测试仅在云端运行。

## 步骤

1. 完成用户对最终方案的确认。
2. 固定设备类别、侧栏绑定和拖入协议。
3. 固定 GitHub 控制器归属和克隆回调。
4. 创建隔离工作树。
5. 四个 Pi 按写入范围并行修改。
6. 主代理组合应用入口与共享状态。
7. 检查根弹窗、个人页面和编辑器遮挡。
8. 在 GitHub Actions 运行格式检查和静态分析。
9. 推送精确提交并运行云端检查。
10. 修复云端失败后记录最终提交。
11. 单独记录真机未验收项目。

## 检查位置

所有检查和构建均在 GitHub Actions 执行。
本机只读取、编辑文件和执行 Git 操作。
从云端产物读取检查结果和格式补丁。
布局稿只检查静态内容。
布局稿不作为产品验收证据。

## 云端核心场景

- 手机仍从项目列表页进入编辑页。
- PC 和平板启动后直接显示工作台。
- 选择项目不增加项目列表与编辑页的导航层。
- 三个图标始终只显示一个主侧栏。
- 切换侧栏保留脏文本、光标和会话草稿。
- 切换项目后返回，恢复原编辑控制器身份。
- 平板分屏和小窗口仍保留工作台导航。
- 头像位于左下角，个人页面可以返回工作区。
- 连接 GitHub 后，首页直接显示仓库列表。
- GitHub 支持搜索、分页、克隆进度和失败重试。
- GitHub 标签增减不重置其他标签。
- 断开 GitHub 不删除克隆文件。
- Windows 重复拖入不重复登记项目。
- Windows 拖入失败保留原目录和当前编辑内容。
- 启动期间拖入、批量拖入和窗口释放均有覆盖。

## 现有回归入口

- `test/retained_editor_test.dart`
- `test/retained_editor_restore_control_integration_test.dart`
- `test/editor_agent_embed_test.dart`
- `test/home_project_tabs_widget_test.dart`
- `test/home_project_tabs_test.dart`
- `test/home_project_scope_test.dart`
- `test/github_auth_controller_test.dart`
- `test/github_repository_picker_test.dart`
- `test/harness/home_agents_tab_test.dart`
- App `test/studio_home_release_test.dart`

新测试检查用户可见行为和对象身份。
不只检查组件数量或文件中的字符串。
保活组件可以有多个隐藏实例。
须断言每个项目只有一个编辑会话。

## 真机验收边界

Windows 资源管理器实际拖放需要桌面验收。
云端单元测试只证明协议和登记逻辑。
平台构建只证明原生代码能编译。
iPad 和鸿蒙平板需要触控与分屏验收。
Android 折叠设备需要单独检查类别判断。
本次工作不证明 LCSign 覆盖安装能保留文件。

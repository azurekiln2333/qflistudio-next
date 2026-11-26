# 只读审查：首页 Agents 并入共享分页器

对照提交 `ab795b0`（`fix(home): route Agents through the shared tab pager`）。
本次未改动源码，未运行测试或探针。

## 已具备

- 共享控制器：`TabBar` 与 `TabBarView` 同用 `_projectTabs`，Agents 是
  `ProjectScope.agents`，`_buildAgentsScopeBar` 与 `_toggleAgents` 已删。
- 稳定标识：`defaultProjectScopes` 末尾追加 `agents`，`_decode` 按
  `scope.name` 读回，未知值丢弃，保存顺序可用。
- 初始作用域仍是 `history`（`defaultProjectScopes` 首位，无 `initialIndex`）。
- 懒建：`_buildScopePage` 里 `_agentsTab` 只在「当前页是 Agents」时创建，
  相邻页预挂载期间返回 `SizedBox.shrink()`，宿主与快照都不启动。
- 保活：`RetainedPage`（`AutomaticKeepAliveClientMixin`）+ `_agentsTab` 缓存。

## 风险

1. **控制器重建时 Agents 会全量重建。** `_projectTabs` 只有构造时读
   `_orderedScopes.length`；`_applyTabOrder` 与 `_dropScopeTab` 只 setState
   并改 `index`。当前所有作用域恒可用，长度不变，暂时安全；一旦 Agents
   按 profile 条件出现或被隐藏，长度变化会让 `TabBarView` 抛长度不一致，
   必须同步重建 `TabController`（`_agentsTab` 与 `_agentsHub` 也要随之失效）。
2. **懒建守卫读的是实时 index。** `ListenableBuilder(listenable: _projectTabs)`
   在滑动过程中会以中间 index 触发。向左滑越 Agents 时它可能提前创建
   （只短暂出现，不崩）。建议测试断言滑动「路过」Agents 不必建。
3. **`_agentsHub` 的销毁只在 `dispose`。** `didUpdateWidget` 换了
   `auth`/`store` 时，`_agentsTab` 仍持有旧 `auth`，`_agentsHub` 仍绑定旧
   `ProjectStore`；`_agentsTab` 未失效。需要明确：换账号后 Agents 是否重建。
4. **`_agentsTab` 缓存跨 widget 重建复用。** 它生成时捕获 `context`
   （`onOpenSession`、`Navigator` 回调）。Home 关闭重开（keepAlive 失效）后
   若复用旧实例，回调里的 `context` 已失效，跳转可能报
   `deactivated widget`。目前 `_agentsTab` 是 State 字段，State 重建即丢，
   风险低；但 `agentsTabBuilder` 注入路径要覆盖到这一点。
5. **搜索态与 pager 互斥。** `_searchOpen` 时整块换成分支渲染，`TabBarView`
   被卸载，`_agentsTab` 保留但不再挂载；搜索里按 scope 过滤的分支仍写死
   `ProjectScope.all`，与本改动无交互，但返回列表后 `_projectTabs.index`
   仍是原页，需确认不会停在 Agents 却渲染项目列表。
6. **拖动排序与懒建的交叉。** `_dropScopeTab` 之后 `_projectTabs.index`
   改为新位置；若 Agents 被拖到另一位置且当前选中，`_buildScopePage`
   下次构建才判 index，中间一帧可能闪 `SizedBox.shrink()`。

## 测试要求

- 已有覆盖（无需重写）：共享控制器同一实例、重复点击保持、滑动懒选、
  拖动后保活并持久化、窄屏可选。引用
  `test/home_project_tabs_widget_test.dart:77,122,172,218`。
- 需补：
  - 换 `auth`/`store` 后 Agents 是否重建，且旧 `HarnessHub` 不泄漏。
  - 滑动「路过」Agents 时不调用 `agentsTabBuilder`。
  - 搜索态进出后仍停在原页，不出现「选中 Agents 却渲染项目列表」。
  - 序号断言要避免写死 `index == 5`：已有一条用例假设 Agents 固定第 6 位，
    保存顺序变化后会误报（`test/home_project_tabs_widget_test.dart:77`）。

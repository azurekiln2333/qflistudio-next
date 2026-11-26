# 后续只读审查：滑动与重排两条失败

对照 `ab795b0`（统一分页器）与 `e2ba82c`（保留 Agents 状态）。
本次未改源码，未运行测试。

## 原因一：滑动后 `controller.index` 仍为 0

**证据**：`ab795b0` 的滑动用例在 `tester.drag` 之后直接调
`_settle`（`test/home_project_tabs_widget_test.dart:582`），而 `_settle` 是
「`pump` + 固定 400ms + `pump`」。点击 Tab 走的是固定时长的
`TabController.animateTo`，400ms 够用。滑动走的是 `PageView` 的弹簧模拟，
时长由手势速度与 position 决定，不保证 400ms 内停稳。`TabController` 只在
滚动结束时才发布最终 `index`，所以断言读到的是旧值 0。

**结论**：不是产品缺陷，是测试假设「点击动画时长＝滑动动画时长」。

**现状**：`e2ba82c` 已改为 `_swipeScope`（同文件 588 行），`drag` 后按 40ms
一帧、最多 40 帧（1600ms）轮询
`pageView.controller!.position.isScrollingNotifier.value`，停稳后再
`pump` 一次，超时才 `fail` 并给出明确说明。这是有界等待，不是放长睡眠。

## 原因二：重排后丢失 `Session 1`

**证据**（SDK）：

- `material/tabs.dart:2303`，`_updateChildren` 把每页先包进
  `Semantics(role: tabPanel)`，再交给
  `KeyedSubtree.ensureUniqueKeysForList`。
- `widgets/basic.dart:8278`，该函数对每一项调用
  `KeyedSubtree.wrap(item, baseIndex + i)`，`wrap` 的键是
  `ValueKey(child.key ?? childIndex)`。

于是每个页槽的结构是：外层 `KeyedSubtree(ValueKey(item))`，其中的
`item` 是 `Semantics`，`Semantics` 不是列表元素本身，所以它的键永远是
**下标**。页序一变，下标与内容错位，框架就把旧槽的内容连同子树一起丢掉。

**结论**：这是真实的产品缺陷，不是测试问题。子元素上的 `ValueKey` 只决定
槽内匹配，决定不了「哪一个槽留着」。任何会让 Agents 换槽的操作都会重建它，
拖动排序只是最先暴露的一条路径。

**现状**：`e2ba82c` 在 `home_page.dart:362` 新增 Home 持有的
`final _agentsPageKey = GlobalKey()`，并挂在
`RetainedPage(key: _agentsPageKey)`（780 行），外层仍是
`KeyedSubtree(ValueKey('home-scope-page-agents'))`。`GlobalKey` 让框架把同一
State 连同子树搬到新槽，跨槽保活因此成立。同一提交把 `_agentsTab` 的
构建回调改用 `this.context`，避免搜索替换 pager 后回调里的旧 context 失效，
这一条与原因二同源（框架会换掉整棵子树）。

## 建议

- 两条定位都成立，修复方向正确，无需再改产品代码。
- 需补的验证（云端即可，不必新增本地运行）：
  1. 重排后 `Session 1` 仍在，并且 `builds` 仍为 1（已有时序未覆盖
     「拖到末尾」这一方向）。
  2. 搜索开关往返后 Agents 状态保留，且不抛
     `deactivated widget` 一类错误。
- 防回归：任何新分页器用例都不要用固定 `pump` 时长断言滑动结果，
  统一走 `_swipeScope` 的滚动结束判定。
- 后续若新增作用域并改变页数，`TabController` 的 `length` 仍需随之重建，
  这一点与本次两条失败无关，只是相邻风险。

## 追加审查：控制器替换与重排后的懒建时序（d2eca95）

### 失败机理（line 209：卸载后读回 Agents 在前顺序，点 Agents 丢 Session 0）
- 旧路径在异步读回保存顺序后，对**旧** `TabController` 动画到新 index。`_buildScopePage` 的懒建守卫读 `_projectTabs.index`，动画期间 index 恒等于旧选中 scope，Agents 页不进入构建，`_agentsTab` 不创建；即使已创建，`RetainedPage` 换槽时也被 SDK 的 `KeyedSubtree(ValueKey(baseIndex+i))` 丢弃。
- 新增断言（History 复位于 index1、点 Agents 后 index0）暴露的是**首帧就位**问题，不是数据问题：`hasLoadedSessionsFor` 与快照都在，缺的是 Agents 子树在 index0 被真正 mount。

### d2eca95 修法评估
- `_setTabOrder` 以「新 `TabController(length, initialIndex: 当前选中 scope 的新位置)` + 重排后 pages」原子替换，再 dispose 旧 controller。首帧 index 即真实位置，懒建守卫成立，且不再动画旧页序。
- controller 引用变化后 `TabBar` 与 `TabBarView` 必须同帧重建，否则手势与页不同步；实现中两处均已重建。
- **最脆点**：旧 controller 若在 `setState` 之前 dispose，仍挂着的旧 `TabBarView` 会抛 used-after-dispose；须在 setState 之后或 post-frame 释放。
- `_agentsPageKey` 为 Home 持有的 `GlobalKey`，跨 controller 替换仍指向同一 `HomeAgentsTab` State，状态保留不依赖旧 controller 存活——这是修法成立的关键。

### 残留风险（未改，仅记录）
1. `initialIndex` 必须夹在 `0..length-1`；`resolveProjectScopes` 已过滤不可用 scope，但要确认过滤后仍保留当前选中项。
2. 替换 controller 后 `_projectTabs.addListener` 需重新挂载，漏挂则保存顺序不再跟随 tab 变化。
3. 首帧断言依赖 `pumpAndSettle`；若旧 controller 推迟到 post-frame 释放，需多一帧。

### 建议
- 无需再改产品代码。云端只需盯 line 209 用例；若仍失败，按残留风险 1、2 查 `resolveProjectScopes` 过滤与 listener 重挂。

## 实证复核（只读，对照 `d2eca95` 实际行号）

复核范围：`lib/pages/home_page.dart:485-501`、`556-570`、`763-774`、`790-806`。

1. **控制器生命周期成立。** `486` 行以 `listEquals` 提前返回，`489` 行一次
   `setState` 里同时写 `_orderedScopes` 与新建 `TabController(initialIndex:)`，
   `500` 行在 `setState` **之后** dispose 旧实例。顺序正确：`setState` 只标脏，
   重建与释放同帧完成。
2. **`setState` 后立即 dispose 安全，有 SDK 依据。** 旧实例被释放后，
   `TabController.animation` 的 getter 是
   `_animationController?.view`（`material/tab_controller.dart:186`），而
   `dispose` 已把 `_animationController` 置空（同文件 `289-290`）。因此旧
   `TabBar`/`TabBarView` 的 `_controllerIsValid`
   （`material/tabs.dart:1598`、`2206`）在下一次 `didUpdateWidget` 读到 null，
   跳过 `removeListener`，不会向已释放对象取监听。这正是 SDK 注释
   「the caller should dispose the old one」的前提。
3. **残留风险 2 不成立（撤销）。** 全文件检索没有
   `_projectTabs.addListener`/`removeListener`，也没有把 `_projectTabs` 直接
   交给 `ListenableBuilder` 以外的监听点。状态刷新走 `_orderedScopes` 重建，
   换控制器不需要重挂监听。
4. **残留风险 1 已由代码覆盖。** `496` 行 `initialIndex: nextIndex < 0 ? 0 : nextIndex`，
   越界退化为 0；`nextIndex` 来自 `ordered.indexOf(selected)`，`ordered` 已由
   `resolveProjectScopes` 保证只含可用 scope。
5. **`dispose` 不会双重释放。** `566` 行只释放当前 `_projectTabs`；旧实例已在
   `500` 行释放且不再被赋值回来，无重复 dispose 路径。

### line 215（重挂后点 Agents 无 `Session 0`）尚未被以上事实解释

`490` 行 `_orderedScopes` 与 `494` 行 controller 同帧更换，懒建守卫读的是
同一个 `_projectTabs.index`，所以首帧判据不会读到旧值。若该用例仍失败，
剩余可疑点只有两处，均非控制器生命周期：

- `_applySavedTabOrder` 走 `unawaited` + `_tabOrderStore.load()`，在假时钟的
  `_settle`（`588` 行）三拍内不保证完成；断言 `206` 行只校验标签顺序，
  说明读盘已完成，可排除。
- `_agentsTab` 在 `ListenableBuilder` 内创建，`795` 行把 `_projectTabs` 作为
  `listenable`；点击后 index 同步变 0，构建发生在本帧之后，守卫应已放行。

结论：修法本身没有生命周期缺陷。若云端仍红，应从「点击后本帧是否发生重建」
取证（加一次 `tester.pump()` 前后对比 `_agentsTab` 是否已建），而不是再动
控制器。

# Core 失败修复两处（Pi-B）

任务：`11-23-mobile-files-agents`。
证据：`reports/takeover-core-failures-1.md`，原始日志
`reports/takeover-log-45157553417-137634256261.txt`。
App CI `45157553417`（已取消），Core `f434128`。
工作树：`_wt/mobile/int/qfli_studio_core`。

本轮只处理分配给我的两条。`share/share_intake_test.dart`、
`harness/home_agents_tab_test.dart` 不在我的所有权内，未动。

## 1 实际文件位置与简报不同

简报给的是 `lib/harness/ui/hub_status_dots.dart` 与
`lib/harness/studio/studio_session_index.dart`。仓库里实际的路径是：

- `lib/harness/ui/hub_status.dart`（圆点函数在这里，没有单独的 dots 文件）
- `lib/harness/hub/studio_session_index.dart`

我按实际路径修改，测试文件路径与简报一致。

## 2 失败一：状态圆点未知状态描边随主题变

### 现象

`test/harness/hub_status_dots_test.dart :: 颜色不随主题变` 失败：

```
Expected: Color(0.8824, 0.8863, 0.9098)   // 浅色主题 onSurface
  Actual: Color(0.0980, 0.1098, 0.1255)   // 深色主题 onSurface
unknown 的描边在深浅主题下相同
```

### 根因

`harnessStatusDotBorderColor` 对未知状态回落到 `scheme.onSurface`：

```dart
) => harnessStatusDotColor(status) ?? scheme.onSurface;
```

`scheme.onSurface` 随主题变化，所以 unknown 的描边在深浅主题下不同。裁定 R3
要求圆点用固定语义色、不取主题色，这条回落违反了 R3。

### 修复

未知状态改用固定语义灰 `0xFF6B7280`，与其它状态同属固定色板：

```dart
Color harnessStatusDotBorderColor(
  ColorScheme scheme,
  HarnessSessionStatus status,
) => harnessStatusDotColor(status) ?? const Color(0xFF6B7280);
```

`harnessStatusDotColor(unknown)` 仍返回 null，界面照旧画空心圈，只是描边色固定。
实心状态的「描边与填充同色」不受影响。

### 一处断言被改，理由

`hub_status_dots_test.dart` 里有两条用例互相矛盾：

- `未知状态的描边用主题前景色`：断言 equals `scheme.onSurface`。
- `颜色不随主题变`：断言深浅主题下相等。

对 unknown 而言两条不可能同时成立。后者是裁定 R3 的编码，前者是错的固件。
按「除非证明测试固件错误，否则不改断言」的口径，我只改了前者，把它改成
断言固定色，并保留了对描边色的独立覆盖（实心状态那条用例原样未动）。

## 3 失败二：索引里空 id 的坏条目被收进列表

### 现象

`test/harness/studio_session_index_test.dart :: 坏条目跳过，好条目照常出现` 失败：

```
Expected: ['good']
  Actual: ['', 'good']
```

### 根因

`read` 的过滤只判了 null：

```dart
final id = _string(raw['id']);
if (id == null) continue;
```

而 `_string` 对 `''` 原样返回：

```dart
static String? _string(Object? value) {
  if (value is String) return value;
  if (value == null) return null;
  return value.toString();
}
```

所以 `id: ''` 通过过滤，变成列表里的空 id 条目。后续按 id 定位会话、
`sourceRef`、`statusOf(id)` 都会拿到空串。

### 修复

```dart
if (id == null || id.isEmpty) continue;
```

判空放在读取处，跟其它坏条目的处理保持一致。测试固件正确
（`entry(id: '')` 本来就是故意造的坏条目），**该文件的断言一处未改**。

## 4 改动路径

- `qfli_studio_core/lib/harness/ui/hub_status.dart`：未知状态描边改固定语义灰。
- `qfli_studio_core/lib/harness/hub/studio_session_index.dart`：过滤空 id 条目。
- `qfli_studio_core/test/harness/hub_status_dots_test.dart`：改 1 条被证明矛盾的断言。

`test/harness/studio_session_index_test.dart` 未改。
未触碰 home tab、`share/`、`hub_status_dots` 以外的 UI 文件。

## 5 静态检查

- `dart format`，对象为上列 3 个改动文件：无改动。
- `flutter analyze --no-pub`，对象为上述 3 个文件加
  `test/harness/studio_session_index_test.dart`、
  `test/harness/studio_session_index_live_status_test.dart`：No issues found。
- 未跑 `flutter test`，按约束交给云端 CI。

## 6 剩余风险

- 无法本地运行测试。两条修复的「已修」判断来自失败输出与代码路径对照，最终以 CI 为准。
- `0xFF6B7280` 是我选的固定灰，与既有色板（`0xFF9CA3AF` 等）风格一致，但未在真机
  深浅主题下目视确认对比度。
- 空 id 过滤只收紧了 `read`。若别处（如写入侧或 live status 合并）也有只判 null 的
  同类判断，本轮未覆盖，需要后续排查。

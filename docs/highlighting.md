# 代码高亮与自定义设置

入口：**我的 → 设置 → 代码高亮**。编辑器内的设置入口也能进入同一页面。

## 可以做什么

- 开关语法高亮，选择跟随应用、Visual Studio 浅色、GitHub 深色或导入的主题。
- 单独修改关键字、字符串、注释、数字、HTML 标签/属性、CSS 属性/选择器等颜色；可一键恢复主题默认颜色。
- 从文件或通过粘贴导入 TextMate `.tmTheme`（XML plist）、VS Code `tokenColors` JSON / JSONC 配色。
- 导入 `.tmLanguage.json` 的基础语法，并指定文件后缀。相同 `scopeName` 再次导入会替换旧配置；多个语法匹配同一文件时，最近导入的优先。
- 配置保存在应用的 `settings.json` 中，重启可恢复。移除配置不会删除原始主题/语法文件。

个人 AI 接口与高亮导入相互独立。导入语法不访问网络，不读取配置中的外部文件，也不执行主题提供的脚本。

## TextMate 兼容范围

这里是基于现有 Dart 高亮器的兼容层，并非完整的 VS Code / Oniguruma 引擎。考虑当前 Dart 与鸿蒙平台兼容性，未引入需要额外原生正则库的完整引擎。

| 内容 | 支持情况 |
| --- | --- |
| `.tmTheme` 配色、VS Code `tokenColors`、JSONC 注释和末尾逗号 | 支持 |
| 前景/背景、光标/选区/当前行配色；粗体、斜体、下划线 | 支持 |
| 普通作用域、作用域前缀、逗号分隔或数组 scope | 支持，具体作用域优先 |
| 父作用域组合选择器、VS Code semanticTokenColors、主题 include | 不完整；组合选择器和语义颜色不应用，include 需先手动合并 |
| `match`、`begin`/`end`、跨行字符串、`patterns`、根 `repository` 的 `#include` | 支持 |
| 捕获组 `0` 的整体配色 | 支持 |
| 捕获组 1+、`contentName`、`while`、injections、递归 include、外部语法 | 导入时拒绝并说明原因 |
| Oniguruma 专用正则、内联修饰符、begin/end 间反向引用 | 不支持，不能宣称任意 VS Code 语法都能直接导入 |

已有工程的基础语法仍由内置高亮器提供。关闭“TextMate 兼容语法”后，已知扩展名回到内置语法，未知文件使用纯文本。

可用示例：

- [基础语法](../examples/highlighting/qfli-demo.tmLanguage.json)，导入后用于 `.demo` 文件。
- [VS Code 配色](../examples/highlighting/qfli-ocean.color-theme.json)。
- [TextMate 配色](../examples/highlighting/qfli-ocean.tmTheme)。

## 性能策略

- 输入停止 100 毫秒后更新高亮，光标和选区变化不重新解析。
- 每个解析器最多保留一个执行中的任务和最后一个等待快照；旧结果不会覆盖新内容。
- 原生平台复用 Dart isolate 和编译后的语言规则；不在界面 build 中拼接整份文件。
- HTML 明确注册嵌入的 CSS 与 JavaScript，并指定片段语言，减少自动检测开销。
- 超过 256 KB 或任一可见行超过 2048 字符时回退到纯文本；高亮计算超过 2 秒会终止该 worker，并对当前主题回退。改变主题或重新打开文件后可重试。
- 缩略图最多取 600 行样本；移动光标时复用采样结果，避免每次绘制扫描整份文件。
- 主题文件最多 512 KB、2048 条配色；最多 12 份自定义语法，每份最多 1024 条展开规则、40 层嵌套。

这些保护只影响显示，不裁剪、重写或丢弃源码。压缩为超长单行的 HTML/CSS 会使用纯文本显示，展开/格式化成正常行后即可重新高亮。

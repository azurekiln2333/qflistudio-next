# 编辑器交互对齐 sora-editor

## Goal

移动端编辑手感对齐用户旧项目的 sora-editor：光标动画优雅，各种交互流畅。做法是在内核 vendored 的 re_editor 里按 sora-editor 的行为重新实现，不逐行翻译源码。

## 用户原话（2026-11-19）

- 「现在 reeditor 我在移动端的编辑体验感觉不如我旧项目 D:\MyNewProject\MyProjects\Android_Studio_Projects\QFLIStudio+_2025-source 用的 soraeditor」
- 「能不能看看 soraeditor 是怎么做的 光标的动画 各种交互的流畅性 都很优雅 能不能搬到 dart 上来 魔改 reeditor 啥的」

## 用户决定

- D1：单独开任务。首期做光标和手柄：光标滑动动画、闪烁、放大镜、手柄拖动、拖到边缘时自动滚动。惯性滚动、双指缩放字号、浮动菜单动画放后期。

## 现状（证据）

- 旧项目用 sora-editor 0.21.1（`io.github.Rosemoe.sora-editor:bom:0.21.1`，含 `language-textmate`）。
- re_editor 在内核 `vendor/re_editor`，已有本地补丁：鸿蒙上启用输入法前缀退格和移动选择手柄（`qflistudio/pubspec.yaml` 的注释）。
- 光标闪烁用 `Timer.periodic` 硬切亮灭（`vendor/re_editor/lib/src/_code_editable.dart:456`），光标换位置时直接跳。
- 光标在 `_CodeFieldRender` 里绘制（`lib/src/_code_field.dart:130`、`:1733`）。
- 没有放大镜。
- 滚动用 `ClampingScrollPhysics`（`lib/src/_code_scroll.dart:27`）。
- 选择拖动时的自动滚动在 `lib/src/_code_selection.dart` 的 `_autoScroll`。
- 许可证：sora-editor 是 LGPL-2.1，可以并入 GPL v3。re_editor 是 MIT。
- 测试设备是鸿蒙，旧版 APK 装不上。对比要用同一台 Android 设备，或者用户录的旧版操作视频。

## Requirements

- 待需求探索后填写。

## Acceptance Criteria

- [ ] 待需求探索后填写。

## Open Questions

- 对比基准：Android 设备并排对比，还是用户录制的旧版视频。
- 光标动画的时长和曲线是否完全照抄 sora-editor 的默认值。

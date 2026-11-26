# Keyboard dismissal regression review

## Cloud evidence

Core run 44831021588 and App run 44831062943 tested Core 7a1161012185b669830fb7be217b67a3369af4d3. The complete Core suite reported 2415 visible passes, 26 existing skips, and two failures in symbols_bar_keyboard_test.dart. All branch-reader, project-card, and clone-dialog regressions passed. App installer jobs and production-SDK Git iOS integration also passed. The release gate correctly prevented publication of v5.0.5-git.4.

## Root causes and bounded correction

- The real mobile CodeEditor cancels a non-collapsed selection in _code_editable.dart when its focus changes to unfocused. Calling unfocus, or tapping an action outside CodeEditorTapRegion, therefore changes the selection. The new action belongs to CodeEditorTapRegion and sends TextInput.hide without changing focus. Tapping the editor again still invokes ensureInput and can reopen the input method.
- Material3 compact density shrinks the tap target, while standard padded targets impose a 48-point minimum. Only the new button now uses standard density, shrinkWrap tap-target style, and tight 44-by-44 constraints.
- Container includes decoration border widths in its child padding. A one-point top border left only 43 points for the 44-point bar's contents. Drawing the same border in foregroundDecoration preserves the bar height, border and full button height.

Only lib/editor/symbols_bar.dart and test/symbols_bar_keyboard_test.dart changed in the corrective Core commit 0f18c3692791e66aa8cb74e71f49ea52469b7295. The original symbol editor and symbol insertion behavior remain covered by their existing assertions.

## Regression coverage

The real editor fixture checks the input method is visible and its non-collapsed selection is valid before tapping. Android/iOS theme variants assert TextInput.hide, no later TextInput.show after a 500 ms pump, hidden keyboard, preserved focus, unchanged source and unchanged selection. The narrow 296-point fixture uses 2x text and retains exact rendered 44-by-44 bounds, right alignment, horizontal scrolling and symbol insertion assertions. The vendored platform booleans are lazily initialized finals, so theme variants do not independently prove native device behavior. Device acceptance remains separate.

## Verification boundary

The implementer and independent reviewer inspected Flutter and re_editor source and the final diff. Formatting, targeted static analysis, Chinese UI-copy lint, and git diff --check passed. No local tests, builds, app launches, services, devices or emulators were run. The original cloudterminal checkout was not modified.

App 23b81a4abf33c9cec73490ba498bae5110acd587 pins the corrected Core commit. Immutable tag v5.0.5-git.5 starts authoritative App run 44833095726 and independent Core run 44833065983. The duplicate branch run 44833095727 was cancelled. Final results belong in release-state.json and the git5 monitoring evidence.

# Integrate agent navigation into editor top bar

## Goal

Move Editor/Agent navigation into the existing toolbar and reuse its segmented style for Files/Sessions in the sidebar, preserving pane state and badge behavior.

## Requirements

- Use one toolbar action to open Agent and return to the editor on compact
  layouts. Preserve the wide layout's collapsible Agent pane.
- Keep the project title readable. Keep Undo available in the overflow menu
  when compact navigation uses its toolbar slot.
- Use the existing Material segmented appearance for Files/Sessions.
- Preserve editor contents, agent drafts, sidebar selection, lazy activation,
  offline-product gating, and background-session badges.

## Acceptance Criteria

- [x] Editor/Agent navigation appears in the toolbar, without a separate row.
- [x] The sidebar switch retains selected states and both destinations.
- [x] Compact layouts preserve title space and touch targets.
- [x] Wide, compact, light, and dark layouts retain navigation behavior.
- [x] Static analysis and affected existing widget checks pass.

## Notes

- The app resolves its core through pubspec_overrides.yaml to
  D:/MyNewProjects/_wt/integration/qfli_studio_core. Modify that active
  checkout's editor page and agent navigation widgets.
- Update the affected existing navigation checks. Leave the inactive
  WorkbenchShell and dirty sibling core checkout alone.
- No backend, deployment, or release changes.

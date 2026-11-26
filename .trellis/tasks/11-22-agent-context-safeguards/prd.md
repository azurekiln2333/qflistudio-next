# Agent context meter and project safeguards

## Requirements

- R1: Show an Agent context capacity ring beside the composer controls. Tap or
  desktop hover opens a breakdown with progress bars for messages, system
  prompt, project rules, skills, tools, MCP and other content. Preserve clear
  distinctions between local estimates and provider-reported input usage.
- R2: Discover project Trellis instructions and installed project skills. A
  valid `.trellis` workflow must be available without injecting every spec or
  skill body into the system prompt.
- R3: Refuse deletion of project configuration, including `.git` and `.trellis`,
  through the editor or managed Agent file operations. Protect containing
  directories and path aliases. Preserve ordinary source-file operations.
- R4: Audit streaming behavior and distinguish implementation, current App
  dependency wiring and release/device verification.

## Acceptance

- Context details work by tap and pointer hover. They remain usable on narrow
  screens and with large text. The categories do not count content twice.
- Provider metadata supplies model capacity when available. Users can set a
  local capacity if the provider omits it. Unknown capacity stays explicit.
- The latest request's measured input count is separate from current estimates.
- Standard project skills remain discoverable. Valid Trellis projects expose
  workflow guidance with existing size limits and on-demand source reads.
- Protected configuration cannot be deleted by directory deletion or rename.
- Each feature requirement has its own Core commit. No deployment is implied.

## Validation limits

Use formatting, static analysis, source review, documentation lint and Git diff
checks. Do not run local runtime tests, builds, services or devices. Do not push
or deploy. Preserve unrelated changes in the planning-root App.

# Skew and multi-tool call coverage for the Vibe agent loop

## Status

Additive scope found while implementing `11-01-vibe-agent-skills`. No shared
interface changes: the controller signature, `ApiClient.aiChat` and the five
original tools stay as they are. This note only records what this child could
not cover because it touches another owner's file.

## 1. Concurrent tool calls are serialized

The wire protocol allows an assistant message with several `tool_calls`, and
the loop executes them one after another. `VibeLoopGuard` grows the read-gate
from round start, so a plan like

```text
write_file a.txt   (new file, allowed)
read_file  a.txt   -> gate now knows a.txt
write_file a.txt   (this send never read it: refused)
```

rejects the second write in the same batch even though the first one created
the file. Sequential model turns are unaffected, because `markWritten` already
covers the follow-up.

Fix shape, for the owner of `vibe_coding_controller.dart` when they touch
`_run`: build the gate snapshot once per round (`a.txt` absent), and evaluate
`rejectUnreadWrite` against that snapshot plus the reads recorded before the
current call. `VibeLoopGuard.markSnapshot` and `existedAtStart` already provide
the two halves. It is not urgent today: the debug upstream returns one call per
turn, and the panel still reports the refusal as a real error.

## 2. No-progress heuristic could be sharper

An exit code counts as progress, so `run_command` failing on a missing file
twice in a row only stops through the round budget (12 when the prompt is
short, 30 when it looks multi-step). A finer rule would compare the exit code
with the previous run of the same command. Kept simple on purpose: the model
must be able to read a real error, fix it and rerun, and a stricter rule risks
cutting that loop. Revisit after the live e2e run reports average rounds.

## 3. Files

- Covered here: `lib/vibe_coding/vibe_skills.dart`, `vibe_rules.dart`,
  `vibe_plan.dart`, `vibe_loop_guard.dart`, `vibe_models.dart`, `vibe_tools.dart`
  (specs), `vibe_coding_controller.dart`, `vibe_coding_widgets.dart`,
  `vibe_coding_panel.dart`, `assets/skills/**`, `pubspec.yaml` asset entry.
- Covered by the owner of `vibe_coding_controller.dart` later: the batch gate
  above, and the `vibe_web_tools.dart` wiring from R8.

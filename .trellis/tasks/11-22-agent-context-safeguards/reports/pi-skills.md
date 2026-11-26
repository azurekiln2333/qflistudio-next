# R2 Trellis bootstrap handoff

## Owned change

Changed only integration Core `lib/vibe_coding/vibe_rules.dart`.
`vibe_skills.dart` remains unchanged.

A normal, nonempty `.trellis/workflow.md` inside a non-link `.trellis`
directory enables a compact project-rule entry. Missing files, empty content,
links and unreadable files do not enable it. A text-decoding exception also
disables the entry. Detection reads a bounded head and never injects workflow
content.

The entry directs the Agent to read workflow, the applicable package/layer
spec index and active task documents before edits. Skill bodies remain available
through `use_skill`. Ordinary `.agents/skills` discovery and existing source
priority remain unchanged.

The entry reserves budget before the existing rule files. The combined text
still uses `kVibeMaxRulesChars` (8,192 characters). Rule files retain their
4,096-character cap and AGENTS, CLAUDE, QFLI order. A remaining-files notice
is added only if it fits.

## Verification

- Targeted Dart analysis of rules, skills and skill test source: no issues.
- Targeted Dart analysis of rules and existing plan/rules test source: no issues.
- No-write format of the owned file: zero changes.
- Owned diff check passed.
- Existing rules-test assertions were reviewed statically. No new test source
  was added and no runtime test was run.

The source is frozen for root review and staging. Root alone writes the index
and creates commits. This worker ran no build, service, device or deployment.

R4 evidence is recorded separately in `streaming-audit.md`.

## Documentation closeout

Applied `trellis-update-spec` without further product edits. Updated
`.trellis/spec/frontend/vibe-skills.md` within its existing seven-section
structure. The contract covers the real loader signature, detection, reserved
budget, on-demand reads, validation matrix and future CI assertion points. The
frontend index now identifies the frozen integration-only Trellis entry. The
other skill surfaces retain their Draft status.

Documentation paths: `vibe-skills.md`, `frontend/index.md` and this report.
Checks: controlled-Chinese lint, section/index/link structure review and scoped
Git diff checks. No source, index, runtime test, build or service was changed
by this documentation step. The owned source hash remains
`BE9FCB86E0361D9DF9038799D2340171EA359D2F1F229EEEED46EBB578A04E24`.

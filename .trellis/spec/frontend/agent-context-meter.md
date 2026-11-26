# Agent context capacity meter

## 1. Scope / Trigger

This contract covers the shared Workbench Agent composer in
`D:/MyNewProjects/_wt/studio-git-integration/qfli_studio_core`. It is an
integration-source contract. It does not imply that the planning-root App or
an installed release resolves this Core.

## 2. Signatures

```dart
enum AgentContextCategory {
  systemPrompt, projectRules, skills, messages, tools, mcp, other
}

AgentContextUsage get VibeCodingController.contextUsage;
AgentContextUsage get AgentFacade.contextUsage;

// AgentContextUsage fields
int estimatedInputTokens;
int? lastReportedInputTokens;
Map<AgentContextCategory, int> estimatedBreakdown;
bool historyLoaded;

// Model directory and AgentModelOption
int? contextWindowTokens;

int? ComposerState.contextWindowFor(String? modelId);
void ComposerState.setContextWindowFor(String? modelId, int? value);
```

`AgentContextIndicator` accepts usage, optional model label, reported capacity,
manual capacity and `ValueChanged<int?>? onCapacityChanged`.

## 3. Contracts

- The controller estimates actual request history and tool definitions. The
  category sum equals the estimate. No transcript summary is substituted.
- Local counting uses one token per non-ASCII scalar and one per four ASCII
  scalars, rounded up for each counted block. It is not a provider tokenizer.
- System sections are attributed only while their exact text remains in
  history. Skill indices and `use_skill` results belong to skills. Tool calls,
  definitions and other tool results belong to tools. MCP stays zero until the
  runtime contributes MCP content. Metadata and reasoning belong to other.
- Counts are cached until history or reported usage changes. Streaming text
  deltas do not rescan history. Drafts and unread attachments are excluded.
- The last completed request may report nonnegative integer `prompt_tokens` or
  `input_tokens`. This value is separate from the current estimate. Missing
  usage clears the previous measured value. Cache fields are not added to it.
- Model capacity accepts explicit positive integer metadata from
  `context_window`, `contextWindow`, `context_length`, `max_context_tokens`,
  `context_window_tokens` or `contextWindowTokens`. No model-name inference
  supplies a capacity. The Agent model cache preserves `contextWindowTokens`.
- Composer defaults persist optional `contextWindows: Map<String, int>` per
  project. Keys are model IDs; the empty key represents no selected model.
  Manual capacity takes precedence. Null removes it and restores metadata.
  Save operations capture the defaults before entering the write queue.
- A missing capacity shows `?`. Deferred session history shows an ellipsis
  until loading finishes. A known capacity shows the estimated percentage.
- Tap toggles a pinned popup. Pointer hover opens after 300 ms; leaving both
  anchor and popup closes after 200 ms unless pinned. The popup scrolls.
  Seven bars use capacity as denominator, or current total if capacity is
  unknown. At 90% the ring uses the error color; fill clamps at 100%.

## 4. Validation & Error Matrix

| Condition | Behavior |
| --- | --- |
| Missing or invalid capacity metadata | Keep capacity unknown; allow manual input |
| Manual capacity is not a positive integer | Disable save; retain the prior setting |
| Capacity override cleared | Use metadata if available, otherwise show unknown |
| Saved capacity field has invalid entries | Ignore those entries individually |
| History restore is pending | Show deferred history instead of an empty-context percentage |
| Model changes during capacity dialog | Save against the captured original model |
| Composer/session is replaced | Dispose its popup and timers |
| Estimate exceeds capacity | Clamp the visual bar and show an over-capacity message |

## 5. Good / Base / Bad Cases

- Good: metadata declares 128000 tokens and the popup shows estimated category
  counts separately from the last API input count.
- Base: metadata omits capacity; the ring shows unknown until the user supplies
  a value for that model.
- Bad: displaying a guessed context window or treating reported input from a
  previous request as the current category total.

## 6. Tests Required

Runtime acceptance remains separate from source validation. Verify tap,
pointer travel into the popup, outside close, session replacement, narrow
screens, large text, model switching during the capacity dialog, and restart
persistence. Accounting assertions must check category sums, skill attribution,
history trimming, missing usage and deferred history.

For this task, only formatting, source review and Dart static analysis were
authorized. Existing composer, facade, controller and skills test sources were
analyzed. No runtime tests or builds were run.

## 7. Wrong vs Correct

Wrong: infer a limit from `model.id`, then label a local estimate as measured
API usage.

Correct: carry explicit `contextWindowTokens` through the model directory and
cache, allow a model-specific override, and keep `lastReportedInputTokens`
separate from `estimatedInputTokens`.

# Mature Vibe Coding, API protocols and cross-app toolchains

## Goal

Make in-app Vibe Coding usable end to end: one sentence builds a small project in the open editor project. Users pick the API protocol. The Studio app drives sibling `qfli_*` apps for local compile and run on OHOS.

## Children (one per Pi)

| Child | Pi pane | Scope |
| --- | --- | --- |
| vibe-agent-skills | w37:p2 | Skills, rules, plan tool, loop hardening |
| ai-protocols-websearch | w37:p3 | Three endpoint protocols, web_search, web_fetch |
| ohos-app-interop | w37:p4 | Studio to `qfli_*` app launch, compile, run |
| vibe-e2e-acceptance | w37:p5 | Real-API e2e, specs, OHOS build, docs |

## Shared constraints

- Debug upstream: `https://newapi.azurekiln.cn/v1`, model `deepseek-v4.1-flash`. Probed 2026-11-01: `/chat/completions`, `/responses`, `/messages` all answer. No native web search.
- Credentials live only in `C:\Users\lichengyu\.qfli-debug.env` (outside every repo). Read them from env vars `QFLI_DEBUG_BASE_URL`, `QFLI_DEBUG_API_KEY`, `QFLI_DEBUG_MODEL`. Never write the key into tracked files, tests, logs, docs or commit messages.
- Repos: `qflistudio`, `qfli_studio_core`, `qfli_*` are sibling Git roots. Each Pi commits only its own files with `git add <explicit paths>`. Other dirty files belong to other work. Never `git add -A`.
- OHOS is the priority platform. Desktop-only shortcuts do not count as done.
- Commit format: Conventional Commits, `type(scope): imperative summary`, body states why. Commit after every coherent change. Use `git commit -F <file>`. Do not push.
- Follow `.trellis/spec/` and the child's `prd.md`, `design.md`, `implement.md`.

## File ownership (no overlap)

- A owns `qfli_studio_core/lib/vibe_coding/**` except `vibe_web_tools.dart`.
- B owns `qfli_studio_core/lib/services/ai_service.dart`, the AI methods in `api_client.dart`, the AI section of `lib/pages/settings_page.dart`, AI fields in `lib/store/settings_store.dart`, `lib/vibe_coding/vibe_web_tools.dart`, and search code in `azurekiln-qfli-server/src/**`.
- C owns `qfli_studio_core/lib/interop/**`, OHOS `ets/` and `module.json5` in `qflistudio` and `qfli_*`, and interop docs.
- D owns e2e files under `qfli_studio_core/test/**`, `qflistudio/tool/**` verify scripts, `.trellis/spec/**`, `docs/**`.
- Cross-owner edits go through the owner: message the owner Pi or ask the root session.

## Acceptance

- [ ] Real run: prompt "做一个待办事项小网站" creates `index.html`, styles and script in the open project, runs a check, reports real results.
- [ ] Settings expose three endpoint types and each completes a tool-call turn against the debug upstream.
- [ ] `web_search` returns real results, and the agent cites them.
- [ ] On OHOS, a Studio Java project launches `qfli_java`, compiles, runs and returns real output.
- [ ] Specs updated. Every change committed in standard format.

# Design

## Current gap and ownership
There is no AI route or project agent. Editor ownership is in `../qfli_studio_core`, relay ownership in `azurekiln-qfli-server`, and isolated execution in the separate `azurekiln-qfli-terminal` repository. Terminal snapshots support 64 base64 files totaling 256 KiB.

## Relay contract
`POST /api/ai/chat` uses existing bearer authentication. Input: `{messages, tools?}` in OpenAI-compatible chat/tool format. The backend fixes origin, credential and model using `QFLI_AI_BASE_URL`, `QFLI_AI_API_KEY`, `QFLI_AI_MODEL` (default `deepseek-v4.1-flash`). Return `{model, message, usage?}`, preserving `message.tool_calls`. Bound input/output, timeouts and disconnect cancellation; sanitize errors.

## Client contract
Worker B owns shared-core `lib/services/api_client.dart` and service/model/tool files under `lib/vibe_coding/`. Expose notifier-based `VibeCodingController` for Worker C. Publish the exact constructor/lifecycle contract to `client-contract.md` immediately. Tools: `list_files`, `read_file`, `write_file`, `edit_file`, `run_command`. write_file supports explicit create semantics. Commands use existing terminal API with fresh snapshots. Continue bounded model/tool rounds until completion, failure or cancellation. Surface every write and actual execution.

Worker C owns editor integration and UI. Root follows the active file's owning project, falling back to the current project. Save/backup and conflict checks protect buffers. Refresh affected open files/explorer without replacing concurrent user edits.

## Deployment
Worker D owns Dockerfiles, Compose/watch, image CI, installers and deployment docs. Separate containers and update scopes, with no business dependency on terminal readiness. User code remains in gVisor sandboxes created by the dedicated rootless engine. Business never receives an executor socket. Preserve cgroup validation and fail-closed behavior. Reference `D:/My2KProjects/cnb2api-panel`. Record how containerized executor validates host limits. CI builds service and toolchain images; production installers pull.

## Change boundary
Change backend AI module/router/mount/config/tests, shared-core agent/services/editor/UI/tests, and independent service image/deployment artifacts. Do not refactor unrelated editor/account/content features. Never persist real credentials in tracked artifacts.

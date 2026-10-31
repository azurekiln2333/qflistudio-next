# AI API protocols and web search tools

## Goal

Custom API settings offer three endpoint types. The agent can search and fetch the web.

## Requirements

- R1: Settings: endpoint type selector with `OpenAI Chat (/chat/completions)`, `OpenAI Responses (/responses)`, `Anthropic Messages (/messages)`. Fields: base URL, key, model. Default is Chat. Persist and migrate old settings.
- R2: One adapter layer maps internal messages and tool calls to each protocol and back (request, response, streaming if used). Tool-call turns work on all three.
- R3: Direct-from-device mode uses the user's key. Relay mode keeps the server-side key. Neither logs the key.
- R4: Add `web_search(query)` and `web_fetch(url)` tools. The server relay implements them. Put the search provider behind an interface. Add an SSRF guard, size and time caps, and reject private addresses. Choose a provider reachable without a new paid key. Record the choice in `design.md`.
- R5: Search results include title, URL, snippet. Fetch returns cleaned text. Offline-only products refuse both tools.
- R6: Expose the tools through `lib/vibe_coding/vibe_web_tools.dart` (specs plus executor). A wires it into the controller. Publish the interface to the root session first.

## Acceptance

- [ ] Adapter unit tests with recorded fixtures for all three protocols.
- [ ] Live test (env creds): each protocol completes one tool-call round on the debug upstream.
- [ ] Live test: `web_search` returns real results. SSRF tests reject localhost, link-local and private ranges.
- [ ] Settings UI works at phone width.
- [ ] Key absent from the diff.

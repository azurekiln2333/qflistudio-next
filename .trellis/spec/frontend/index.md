# Frontend Development Guidelines

> Best practices for frontend development in this project.
>
> Rows marked `Draft` describe an interface that another task still owns. Read
> the named source file before coding against a draft, and promote the row to
> `Active` only after that interface is frozen.

---

## Overview

This directory contains guidelines for frontend development. Fill in each file with your project's specific conventions.

---

## Guidelines Index

| Guide | Description | Status |
|-------|-------------|--------|
| [Directory Structure](./directory-structure.md) | Module organization and file layout | To fill |
| [Component Guidelines](./component-guidelines.md) | Component patterns, props, composition | To fill |
| [Hook Guidelines](./hook-guidelines.md) | Custom hooks, data fetching patterns | To fill |
| [State Management](./state-management.md) | Local state, global state, server state | To fill |
| [Quality Guidelines](./quality-guidelines.md) | Code standards, forbidden patterns | To fill |
| [Type Safety](./type-safety.md) | Type patterns, validation | To fill |
| [Process Lifecycle](./process-lifecycle.md) | External process ownership and cancellation | Active |
| [Remote Companion](./remote-companion.md) | Desktop pairing, Agent history, account scope and companion packaging | Active |
| [Editor Terminal](./editor-terminal.md) | Shared bottom terminal, run initialization and cloud progress | Active |
| [Home Recovery](./home-recovery.md) | Recycle bins, backups, history, ICP footer | Active |
| [Editor Paging](./editor-paging.md) | Pager retention, update boundaries, font settings | Active |
| [Large-screen Workbench](./large-screen-workbench.md) | Device family, shared sidebar, GitHub placement and Windows drops | Draft (implementation under cloud verification) |
| [Authentication](./authentication.md) | MFA-first forms, native agreement reader and request diagnostics | Active |
| [Project Storage](./project-storage.md) | Language directories, duplicate display names and config metadata | Active |
| [Cloud Project Cache](./cloud-project-cache.md) | Scoped cache, durable deletion and ZIP payload contracts in studio-git-integration Core only | Active (frozen integration source) |
| [Local Git UI](./git-ui.md) | Read-only branch cards, retained refresh and keyboard handling | Active |
| [Repository Layout](./repository-layout.md) | Sibling Git roots, shared package paths, build commands | Active |
| [Vibe Skills](./vibe-skills.md) | Skill discovery, prompt limits and bounded Trellis workflow entry | Draft (Trellis entry frozen in integration Core) |
| [AI Protocols](./ai-protocols.md) | Three endpoint protocols, one tool-call shape, endpoint joining | Draft |
| [Interop](./interop.md) | Separate foreground and experimental background Java routes on OHOS | Draft |
| [OHOS Runtime Guide](./ohos-runtime-guide.md) | Download entries, language ordering, icons and retained terminal navigation | Cloud verification in progress |
| [Share Target](./share-target.md) | Inbound share intents, native inbox, external folders and copy/attach rules | Active |
| [Vibe E2E](./vibe-e2e.md) | Headless acceptance harness, report schema, credential redaction | Draft |

---

## How to Fill These Guidelines

For each guideline file:

1. Document your project's **actual conventions** (not ideals)
2. Include **code examples** from your codebase
3. List **forbidden patterns** and why
4. Add **common mistakes** your team has made

The goal is to help AI assistants and new team members understand how YOUR project works.

---

**Language**: All documentation should be written in **English**.

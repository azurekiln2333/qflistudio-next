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
| [Editor Terminal](./editor-terminal.md) | Shared bottom terminal, run initialization and cloud progress | Active |
| [Home Recovery](./home-recovery.md) | Recycle bins, backups, history, ICP footer | Active |
| [Editor Paging](./editor-paging.md) | Pager retention, update boundaries, font settings | Active |
| [Authentication](./authentication.md) | MFA-first forms, native agreement reader and request diagnostics | Active |
| [Project Storage](./project-storage.md) | Language directories, duplicate display names and config metadata | Active |
| [Repository Layout](./repository-layout.md) | Sibling Git roots, shared package paths, build commands | Active |
| [Vibe Skills](./vibe-skills.md) | Skill discovery order, prompt index, body caps | Draft |
| [AI Protocols](./ai-protocols.md) | Three endpoint protocols, one tool-call shape, endpoint joining | Draft |
| [Interop](./interop.md) | Studio to `qfli_*` open, compile and run on OHOS | Draft |
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

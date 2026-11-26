# Backend Development Guidelines

> Best practices for backend development in this project.

---

## Overview

This directory contains guidelines for backend development. Fill in each file with your project's specific conventions.

---

## Guidelines Index

| Guide | Description | Status |
|-------|-------------|--------|
| [Directory Structure](./directory-structure.md) | Module organization and file layout | To fill |
| [Database Guidelines](./database-guidelines.md) | ORM patterns, queries, migrations | To fill |
| [Error Handling](./error-handling.md) | Error types, handling strategies | To fill |
| [Quality Guidelines](./quality-guidelines.md) | Code standards, forbidden patterns | To fill |
| [Logging Guidelines](./logging-guidelines.md) | Structured logging, log levels | To fill |
| [Gateway Authentication](./gateway-auth.md) | Native forms, Huawei, PKCE, identity migration | Active |
| [Relay Grants](./relay-grants.md) | Single-use QFLI grants, introspection and session-bound invalidation | Active |
| [Remote Bindings](./remote-bindings.md) | Transactional device binding, token origin and revocation fences | Active |
| [Terminal Isolation](./terminal-isolation.md) | Independent executor, gVisor sandbox, resource limits and fail-closed recovery | Active |
| [AI Relay and Terminal Pool](./ai-terminal-pool.md) | Fixed upstream tool relay, shared placement, requester fencing and route validation | Active |
| [Points and Tasks](./points-tasks.md) | Daily task claims, point ledger, redemptions and client reporting | Active |

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

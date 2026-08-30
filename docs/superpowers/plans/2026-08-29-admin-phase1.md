# StelyraAgent Admin Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a separate Dockerized React/Vite admin that authenticates to Runtime Admin API and surfaces Phase 1 system/run/credit/IAP/provider metrics without reading SQLite directly.

**Architecture:** Static React app only; all data comes from `/v1/admin/*`. No server secrets are embedded in the build; admin credentials are entered at runtime and stored only in session storage.

**Tech Stack:** React, Vite, TypeScript, Vitest, Docker/nginx.

**Spec:** `docs/specs/StelyraAgent_v1_开发规格.md`

## Global Constraints
- Admin is a separate StelyraAgent project.
- Admin never opens the SQLite volume/file.
- No ordinary Apple user token is reused for admin authentication.
- Phase 1 UI focuses on Dashboard, Runs, Credits/IAP, Runtime Config/System Health.

---

### Task 1: API client and dashboard models
- [ ] Write failing tests for admin API parsing and auth header behavior.
- [ ] Implement typed client and dashboard models.

### Task 2: Admin shell and key pages
- [ ] Write component tests for dashboard metric rendering and run status table.
- [ ] Implement login/session shell and Dashboard/Runs/Credits/System pages.

### Task 3: Docker and verification
- [ ] Run tests and production build.
- [ ] Build Docker image serving Vite `dist/`.

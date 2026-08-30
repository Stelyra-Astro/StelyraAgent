# StelyraAgent Runtime Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Dockerized Node.js 22/Hono/TypeScript runtime that persists accounts, wallets, credit reservations, idempotent run/actions, exposes Phase 1 APIs, and can pause/resume astrology evidence requests.

**Architecture:** HTTP routes call focused services; services depend on Repository interfaces; SQLite is isolated behind a repository implementation. Agent execution uses a ModelProvider abstraction and a deterministic run state machine so tool pauses and budget finalization are independent from the provider.

**Tech Stack:** Node.js 22, TypeScript, Hono, Zod, Vercel AI SDK, DeepSeek-compatible provider adapter, SQLite, Vitest, Docker.

**Spec:** `docs/specs/StelyraAgent_v1_开发规格.md`

## Global Constraints
- Runtime is a new StelyraAgent project and does not reuse Interstellar Relay/database/account/session keys.
- Database access must go through Repository interfaces.
- Long-term conversations/evidence are not persisted on the server.
- Run payload is temporary; ACK/expiry removes payload and releases/commits credits idempotently.
- One core astrology tool contract: `request_astrology_evidence`.
- Credits use `reserve -> commit/release`; budget exhaustion must still produce a best-effort final answer.

---

### Task 1: Runtime domain and SQLite repositories
**Files:** Create `stelyraagent-runtime/src/domain/*.ts`, `src/repositories/*.ts`, `src/db/*.ts`, `tests/repositories.test.ts`, plus package/config/Docker files.
**Interfaces:** Produces `RunRepository`, `CreditRepository`, `AccountRepository`, `RunRecord`, `RunActionRecord`, `CreditReservation`.
- [ ] Write failing repository tests for unique action IDs, transaction IDs, reserve/commit/release idempotency, and run payload deletion.
- [ ] Run tests and confirm failures are due to missing implementation.
- [ ] Implement schema + repository interfaces + SQLite implementation.
- [ ] Run repository tests and confirm green.

### Task 2: Run state machine and action pause/resume
**Files:** Create `src/run/run-state-machine.ts`, `src/run/run-service.ts`, `tests/run-state-machine.test.ts`, `tests/run-service.test.ts`.
**Interfaces:** `RunService.createRun`, `getRun`, `submitAction`, `cancelRun`, `ackRun`.
- [ ] Write failing tests for created→reasoning→requires_action→resuming→completed→acknowledged, duplicate action submission, cancel, expiry.
- [ ] Confirm RED.
- [ ] Implement minimal deterministic transitions and payload cleanup.
- [ ] Confirm GREEN.

### Task 3: Provider abstraction and agent decision/finalization
**Files:** Create `src/providers/model-provider.ts`, `src/providers/deepseek-provider.ts`, `src/agent/astrology-agent-runtime.ts`, `src/agent/contracts.ts`, tests.
**Interfaces:** `ModelProvider.generate()`, `AstrologyAgentRuntime.advance(run)` returns either final text, interaction, or astrology tool action.
- [ ] Write failing tests using a deterministic fake provider for tool request, interaction, final response, malformed provider result, and budget-finalization fallback.
- [ ] Confirm RED.
- [ ] Implement provider abstraction, DeepSeek adapter, schema validation, and best-effort finalization.
- [ ] Confirm GREEN.

### Task 4: HTTP API, auth/IAP skeleton, admin API
**Files:** Create `src/http/app.ts`, route modules under `src/http/routes/`, auth/IAP services, API tests.
**Interfaces:** Spec section 43 endpoints plus `/v1/admin/*` read-only dashboard endpoints.
- [ ] Write failing API tests for health/config/capabilities, run create/get/action/ack, credits, and admin summary authentication.
- [ ] Confirm RED.
- [ ] Implement routes and safe auth/IAP skeletons with explicit environment configuration.
- [ ] Confirm GREEN.

### Task 5: Docker and verification
**Files:** `Dockerfile`, `.dockerignore`, `docker-compose.example.yml`, `README.md`.
- [ ] Build TypeScript.
- [ ] Run all tests.
- [ ] Build Docker image.
- [ ] Run container health endpoint with a temporary SQLite volume.

# StelyraAgent Phase 1 Continuation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the highest-risk remaining Phase 1 gaps: real StoreKit server verification wiring, Apple token revocation on delete, iOS Sign in with Apple/session/IAP integration, native interaction/plan-review resume, and integration contracts.

**Architecture:** Keep the frozen split: iOS owns long-term conversations/profiles/chart assets and executes astrology locally; Runtime owns identity, wallets, IAP, temporary runs and model orchestration; Admin only uses Runtime Admin API. Add adapters around Apple APIs rather than leaking Apple-specific behavior into account or ledger repositories.

**Tech Stack:** SwiftUI + AuthenticationServices + StoreKit 2 + Security; Node.js 22 + TypeScript + Hono + SQLite + official Apple App Store Server Library; React/Vite admin unchanged except status visibility.

**Spec:** `docs/specs/StelyraAgent_v1_开发规格.md`

## Global Constraints
- StelyraAgent remains independent from Interstellar Relay, database, accounts, credits and Admin.
- StoreKit transaction is not finished until Runtime acknowledges credited/already_processed.
- `transaction_id` is globally idempotent; reset creates a new wallet/appAccountToken and old credits never migrate.
- Delete revokes Sign in with Apple refresh token when available, but account deletion must still complete if Apple token is already invalid/missing.
- Interaction is structured native UI and resumes the same `action_id`.
- Runtime must still finalize with a non-empty answer when analysis budget is exhausted.

---

### Task 1: Apple identity deletion lifecycle
**Files:** runtime auth/account repository/routes/tests.
**Produces:** encrypted refresh-token read/clear, `/auth/revoke` adapter, delete route revoke-before-delete semantics with idempotent handling.
- [ ] Write failing tests for stored refresh-token lookup/clear and revoke request contract.
- [ ] Run tests and confirm RED.
- [ ] Implement minimal repository + Apple token revoke adapter.
- [ ] Wire delete route without blocking deletion when token is absent/already invalid.
- [ ] Run full runtime core tests.

### Task 2: StoreKit JWS server verification
**Files:** runtime IAP verifier/config/index/tests/package/env.
**Produces:** official `SignedDataVerifier.verifyAndDecodeTransaction` adapter, bundle/environment/product mapping/appAccountToken validation.
- [ ] Write failing verifier tests with injected decoder.
- [ ] Run RED.
- [ ] Implement verifier and configuration factory; unknown products never grant credits.
- [ ] Add official Apple server library dependency and root-certificate configuration.
- [ ] Run runtime tests and syntax checks.

### Task 3: iOS account/session integration
**Files:** new Agent account coordinator/token store, API client, Chat/Account UI, StoreKit coordinator, contracts.
**Produces:** Sign in with Apple nonce flow, Runtime token persistence/refresh/logout/reset/delete, credits refresh, JWS reconcile using `VerificationResult.jwsRepresentation`.
- [ ] Add failing source contract tests for required APIs and safety semantics.
- [ ] Run RED.
- [ ] Implement Swift types and wire account view.
- [ ] Parse-check Swift files and run iOS contracts.

### Task 4: Native interaction + plan review resume
**Files:** Agent models/coordinator/chat interaction view/contracts.
**Produces:** render `required_input`, `analysis_choice`, `plan_review`; submit same action_id; no fake chat text as the only interaction surface.
- [ ] Add failing contracts.
- [ ] Run RED.
- [ ] Implement interaction model decoding and native sheet/card.
- [ ] Run parser/contracts.

### Task 5: End-to-end contract and delivery refresh
**Files:** runtime integration test, docs/status, zip artifacts.
**Produces:** one tested run/account/IAP/action lifecycle at service boundary, refreshed delivery archives.
- [ ] Add integration test across account→wallet→run→action→final→ack.
- [ ] Run complete available verification.
- [ ] Update DEVELOPMENT_STATUS with exact verified/unverified claims.
- [ ] Rebuild and integrity-check all delivery ZIPs.

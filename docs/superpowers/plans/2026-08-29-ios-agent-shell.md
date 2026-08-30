# StelyraAgent iOS Phase 1 Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the provided Interstellar iOS source into an independent StelyraAgent iOS working base by adding Chat, local Conversation/Asset stores, Draft Context, capability manifest, runtime client, and a local tool bridge that reuses existing profile/chart calculation primitives.

**Architecture:** Keep AstroCore, `SavedPerson`, `ChartContext`, and immutable relationship calculation services. Add a new `Agent/` feature boundary. Agent assets use a new fingerprint-addressed physical store and conversation-local logical asset index rather than the legacy “latest per chart kind” generated-report store.

**Tech Stack:** Swift 6, SwiftUI, iOS 17+, AstroCore/Swiss Ephemeris, URLSession, Codable, FileManager.

**Spec:** `docs/specs/StelyraAgent_v1_开发规格.md`; Theme catalog names/rules from `docs/specs/StelyraAgent_Themes_开发规格_8主题最终版.md` where not superseded.

## Global Constraints
- Do not reimplement astrology math.
- Conversation/history/profile/chart assets remain local.
- Draft Chips never auto-send.
- First six capabilities: natal, transit, secondary, synastry, composite, composite transit.
- Agent chart files dedupe by fingerprint; logical assets remain separate per conversation.

---

### Task 1: Agent domain models and stores
**Files:** Create `ios/App/Agent/Models/*`, `Storage/*`; create tests under `ios/Tests/Agent*Tests.swift`.
- [ ] Write failing tests for conversation persistence, two logical assets sharing one fingerprinted physical artifact, and different fingerprint inputs producing different identities.
- [ ] Implement Codable models and atomic file-backed stores.
- [ ] Keep stores independent from legacy AI report eviction behavior.

### Task 2: Capability and Theme catalogs
**Files:** Create `Agent/Capabilities/*`, `Agent/Themes/*`, tests.
- [ ] Write failing tests for Phase 1 supported capabilities, advanced relationship exclusions, and exactly eight Theme names.
- [ ] Implement catalogs and manifest payload.

### Task 3: Runtime API client and pause/resume models
**Files:** Create `Agent/Networking/*`, tests using URLProtocol-compatible request construction where possible.
- [ ] Write failing encoding/decoding tests for create_run, requires_action, submit action, ACK.
- [ ] Implement API models/client without depending on old Relay types.

### Task 4: Local astrology tool bridge
**Files:** Create `Agent/Tools/*` and adapters around existing chart/relationship services.
- [ ] Write failing mapping tests from six agent capability IDs to local technique requests.
- [ ] Implement request validation, profile resolution, calculation dispatch adapters, fingerprint creation, and evidence placeholder/builder boundaries.
- [ ] Do not mutate the visible Charts selection to run Agent calculations.

### Task 5: Chat shell + Assets UI integration
**Files:** Create `Agent/UI/*`, modify `RootView.swift`, `StelyraAgentApp.swift`/project metadata as needed for independent StelyraAgent app identity.
- [ ] Add Agent as the primary launch surface with Themes, Charts, Try asking, draft chips, plus menu (Charts/Themes/Assets/Profiles).
- [ ] Add conversation-local Assets list and detail shell.
- [ ] Preserve existing Charts You/Bonds screens for reuse.

### Task 6: Verification
- [ ] Run existing Python contract tests.
- [ ] Run AstroCore/ContentKit Swift package tests where supported.
- [ ] Run static Swift compile/type checks available in the sandbox; document Xcode-only verification gaps.

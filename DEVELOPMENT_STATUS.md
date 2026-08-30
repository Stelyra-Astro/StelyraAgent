# StelyraAgent — Phase 3 source checkpoint — 2026-08-30

This checkpoint completes the source-level Phase 3 scope from the frozen StelyraAgent v1 specification on top of the Phase 1–2 implementation. Real Xcode/Docker/Apple/provider integration is intentionally deferred to the user's unified final integration pass.

## Phase 3 completed scope

### OpenRouter + server-owned model selection
- Added OpenRouter through the same OpenAI-compatible provider abstraction used by DeepSeek.
- iOS loads `/v1/models` and shows only server-approved model choices.
- iOS sends only `model_id`; it cannot send provider model, Credit price, token budget, tool budget, or provider-cost budget.
- Runtime resolves the selected model through `ModelCatalog` before Credit reservation.
- Each ModelPolicy owns provider/model, 1–10 Credit tier, input/output/tool/evidence budgets, provider-cost cap and budgeting rates.
- Enabled/agentEligible model flags act as server kill switches.

### Policy Control Plane / prompt-injection hardening
- Added deterministic `ScopePolicy`, `RunAdmissionPolicy`, `PromptTrust`, `OutputValidator`, `PolicyEnforcedProvider` and provider-budget enforcement.
- User text, Draft Context, profile-derived text and Local Memory are explicitly untrusted data, never policy instructions.
- Validated astrology Evidence is the only astrology source of truth for the model.
- Arbitrary client model IDs are rejected before Credit reserve.
- Explicit generic coding/translation/document-proxy requests are rejected before Credit reserve.
- Advanced/conditional capabilities remain behind deterministic autonomy and plan-review rules even if the model is prompt-injected.
- Capability server kill switch: `DISABLED_CAPABILITIES` removes problematic capabilities without an App update and rejects unknown IDs at startup.

### Long-task / runaway-cost controls
- Hard server scope: max 100 years, max 2 locations, max 4 autonomous capability kinds by default.
- >10-year queries default to Major Windows.
- >30-year first-pass queries are forced to Major Windows even when Detailed is requested.
- iOS technique planners retain the bounded `maxScanAnchors=128` strategy and slow-body prioritization for long Transit ranges.
- Round 2 remains constrained to a window actually discovered in Round 1.
- Model calls are preflighted against remaining input-token and conservative provider-cost budget before network execution.
- Actual/normalized input, output and reasoning usage plus configured-rate provider cost are accumulated into Run metadata; subsequent calls see only the remaining budget.
- Provider timeout remains configurable (default 60s).

### Structured output and bounded repair
- Final answers are structured: answer, key factors, timing windows, chart refs, limitations and follow-ups.
- Supporting Evidence refs must exist in the current Run Evidence set.
- Runtime rejects excessive output and prohibited deterministic/high-risk claims.
- Invalid/malformed model output gets exactly one constrained repair attempt.
- A second failure becomes a bounded safe fallback; no third model call or infinite JSON-repair loop.
- Repair calls consume remaining input/provider-cost budget rather than getting a fresh budget.

### Local follow-up memory / compression
- iOS builds deterministic structured memory before appending the current user message.
- It sends only bounded context: conversation goal, recent Chart Asset refs, up to 3 prior conclusions (600 chars each), and recent Analysis refs.
- Full conversation history is not uploaded as follow-up memory.
- Runtime `local_memory` uses a strict bounded schema.
- Prompt-side memory sanitization additionally whitelists only recognized context fields and drops instruction-like/unknown keys, reducing persistent prompt-injection risk.

### Advanced relationship / Phase 3 chart policy
The full Agent-facing catalog and local executor already include the Phase 3 advanced relationship family from the Phase 2 expansion:
- Davison base / Transit / Secondary / Tertiary
- Marks base / Secondary / Tertiary

They remain `advanced_only`: user-selectable, but not ordinary autonomous Theme recipes.

### Admin Phase 3
Added:
- **Models** — effective server ModelPolicy allowlist (no secrets).
- **Provider Usage** — run count, input/output/reasoning tokens, estimated provider cost and average tool rounds grouped by provider/model.
- Existing Dashboard/Run/IAP/Runtime Config/System Health views remain.

### Relay policy configuration
See `docs/RELAY_POLICY_CONFIG.md` for the production business-control checklist, including:
- `MODEL_CATALOG_JSON`
- provider keys
- model Credit tiers/budgets/rates
- scope/output limits
- `DISABLED_CAPABILITIES`
- prompt/scope/output/safety policy versions
- Apple/IAP/Admin production configuration

## Red-team acceptance coverage
The Runtime test suite now explicitly covers:
- `Ignore previous instructions`
- system-prompt reveal attempts
- user/profile/local-memory instruction injection
- forced advanced-chart calls
- arbitrary OpenRouter model IDs
- client-side Credit/model-budget override removal
- explicit generic coding proxy abuse
- >100-year daily expansion
- >30-year long-range coercion
- fake Evidence IDs
- excessive/deterministic final output
- malformed JSON / invalid structured final repair loops
- provider input/cost-budget exhaustion

## Fresh verification for this Phase 3 checkpoint
The final packaging verification is recorded at package time. Current latest successful runs before packaging:
- Runtime core: **108 tests passed, 0 failed** via `npm run test:core`.
- iOS contracts: **71 tests passed, 0 failed** via `pytest -q tests`.
- Agent Swift source: **18 files passed `swiftc -frontend -parse`**.
- Admin contracts: **5 tests passed, 0 failed** via `npm run test:contract`.

## Environment verification intentionally deferred
These are not claimed as verified in this checkpoint:
- Full Xcode project build/signing/target membership/entitlements.
- Real-device AstroCore execution across all Phase 2/3 capabilities.
- Real Sign in with Apple / StoreKit Sandbox/TestFlight transactions.
- Docker image build/start and SQLite volume restart persistence on the NAS.
- Production `npm install` + TypeScript/Vite build. This sandbox currently has no `node_modules`; `npm run build` stops at missing `@types/node` / `vitest` type definitions.
- Real DeepSeek/OpenRouter network calls with production keys.
- Real Apple App Store Server JWS verification with production certificates.

## Product status
Source implementation now covers the planned Phase 1 + Phase 2 + Phase 3 architecture. The next work should be the user's unified real-environment integration pass, then fixes found by Xcode/Docker/StoreKit/provider testing rather than another architecture phase.

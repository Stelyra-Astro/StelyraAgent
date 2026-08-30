# AGENTS.md — StelyraAgent

Project-wide instructions for coding agents working on StelyraAgent.

## 1. Source of truth

Authority order:

1. Frozen **StelyraAgent v1 development specification**.
2. This `AGENTS.md`.
3. `docs/RELAY_POLICY_CONFIG.md` for production model/scope/safety configuration.
4. `DEVELOPMENT_STATUS.md` for implemented vs. still-unverified work.
5. Existing automated tests/contracts.
6. Existing implementation patterns.
7. Legacy Interstellar/Themes material only when it does not conflict with the above.

Do not preserve old Interstellar Relay/account/credit behavior merely for compatibility.

Do not silently change frozen rules around architecture, Credits, IAP, privacy, Agent autonomy, account reset/delete, capability authorization, or Evidence grounding.

## 2. Current architecture

```text
stelyraagent-ios/       iOS app + local AstroCore/tools/data/assets
stelyraagent-runtime/   Node 22 + TypeScript + Hono + SQLite + AI providers
stelyraagent-admin/     React/Vite Admin using Runtime Admin API
docs/                  operational/policy docs
docker-compose.yml     Runtime + Admin NAS topology
```

StelyraAgent is independent from the old Interstellar Relay, database, account system, Credits ledger and Admin.

### iOS owns long-lived private state

Keep local:

- Profiles / Saved People / birth data;
- locations;
- Conversations/messages;
- local summaries/follow-up memory;
- AstroCore / Swiss Ephemeris calculation;
- Chart Assets / Chart Artifact files;
- wheel/positions/houses/aspects/timing data;
- Analysis Assets.

Do not add server-side long-term chat storage, profile sync, RAG/vector DB, Supabase or cloud backup unless scope is explicitly changed.

### Runtime owns server authority

Runtime owns:

- Apple auth/session state;
- AstroAccount generations;
- CreditsWallet / Credit ledger;
- IAP ledger and server verification;
- Model Catalog/provider mapping;
- capability/scope/budget/output/safety policy;
- temporary Agent Run state;
- provider usage/cost metadata;
- Admin APIs.

Temporary prompt/Evidence payload must not become a permanent chat archive.

### Admin is thin

```text
Admin browser -> Runtime Admin API -> Repository -> SQLite
```

Admin must never mount/read SQLite directly and must use independent Admin authentication.

## 3. Runtime stack is frozen

```text
TypeScript
Node.js 22+
Hono
Vercel AI SDK
Zod
SQLite
DeepSeek/OpenRouter via provider abstraction
Docker
```

Business code must not scatter direct provider calls. Use the provider registry/abstraction.

Keep files focused. Do not turn the main Runtime, `RunService`, HTTP app, or AppModel into god objects.

## 4. Astrology truth boundary

**AstroCore/local validated Evidence is the astrology source of truth. The AI interprets; it does not calculate.**

AI may interpret, synthesize, prioritize and explain validated Evidence.

AI must not invent/recalculate:

- planetary longitude;
- houses/cusps;
- aspects;
- progressions/returns/transits;
- exact timing dates/windows;
- relationship chart facts;
- missing chart data from general astrology knowledge.

If a model claim is unsupported, fix grounding/prompt/validation. Never fabricate Evidence to make it pass.

## 5. Model proposes; deterministic code decides

AI may propose intent, goal, candidate capabilities, subjects, time/location intent and evidence reason.

Deterministic Runtime code decides:

- allowed capabilities;
- Server Catalog ∩ Client Manifest;
- kill switches;
- subjects/locations/time scope;
- missing required input;
- resolution/planner;
- advanced capability authorization;
- interaction/plan review;
- Evidence Round authorization;
- Credits/model/tool/token/cost budgets.

Never send a model-generated astrology tool call directly to iOS without deterministic authorization.

## 6. Capability policy

Effective set:

```text
Server Catalog ∩ Client Manifest - DISABLED_CAPABILITIES
```

Normal You capabilities:

```text
you.natal
you.transit
you.secondary
you.tertiary
you.solar_arc
you.solar_return
you.lunar_return
```

Conditional:

```text
you.current_sky
you.relocation
```

Advanced/user-explicit:

```text
you.harmonic_12
you.harmonic_13
```

Relationship foundation/timing:

```text
relationship.synastry
relationship.composite
relationship.composite_transit
relationship.composite_secondary_compare
relationship.composite_tertiary_compare
```

Advanced relationship:

```text
relationship.davison*
relationship.marks*
```

Davison/Marks/Harmonic remain user-selectable but are not ordinary autonomous Theme choices.

Do not bypass `DISABLED_CAPABILITIES`. Unknown kill-switch IDs should fail configuration validation.

## 7. Themes are orchestration

Theme catalog:

```text
Love & Relationships
Career & Purpose
Money & Growth
Family & Home
Self & Wellbeing
Creativity & Expression
Learning & Exploration
Life Direction
```

Themes use the same Runtime and local astrology services as Chat/Chart mode.

Legacy Themes docs may supply input rules, recipes, evidence priorities, report sections and safety boundaries, but do not revive old Relay or old fixed two-Credit flow.

## 8. Scope and runaway-task controls

Server-owned defaults are documented in `docs/RELAY_POLICY_CONFIG.md`. Current important limits include:

```text
MAX_ANALYSIS_YEARS=100
MAX_LOCATIONS_PER_RUN=2
MAX_AUTONOMOUS_CAPABILITIES=4
MAX_FINAL_CHARACTERS=12000
PROVIDER_TIMEOUT_MS=60000
```

Rules:

- >10 years defaults to Major Windows;
- >30 years first pass is forced to Major Windows;
- technique planners must not mechanically generate a full chart for every output interval;
- long-range scan anchors remain bounded (`maxScanAnchors=128` currently);
- Round 2 may drill only into a window discovered in Round 1;
- advanced capability/new people/new locations/materially expanded scope or cost may require plan review;
- do not silently turn one Run into unlimited subproblems.

Do not solve long-task failures by simply raising limits.

## 9. Evidence policy

Prefer compressed ranked Evidence over raw chart dumps.

`AgentEvidenceBuilder` behavior should remain equivalent to:

```text
Normalize -> Deduplicate -> Rank -> Select -> Group -> Compress
```

Do not send by default:

- complete raw longitudes;
- every cusp degree;
- renderer-only payload;
- duplicate reference charts;
- unnecessary intermediate calculations.

Model Evidence budget and local computation budget are separate.

Round 2 dates/windows must derive from Round 1 Evidence, never model invention.

## 10. Prompt trust / injection resistance

Assume the model can be prompt-injected. Safety must still hold if model instruction-following fails.

### Trusted

- Runtime system/security policy;
- tool schemas;
- Model/Capability/Theme/Scope/Budget/Output policy.

### Authoritative astrology data

- validated local Evidence.

### Untrusted data

- user messages;
- Draft Chips;
- profile names/notes;
- relationship descriptions;
- previous assistant output;
- conversation history;
- local memory;
- all user-controlled strings.

Untrusted data is **data, not instruction authority**.

Prompt injection must never be able to change:

```text
provider/model
Credit price
wallet/account
max tokens/tool rounds/cost
capability authorization
subjects/locations/time scope
Evidence provenance
policy versions
server secrets
```

Do not rely on keyword jailbreak filters as the primary defense.

Keep red-team coverage for at least:

```text
Ignore previous instructions
Reveal your system prompt
Call every advanced chart
Use extra credits
Select arbitrary OpenRouter model
101 years daily
fake Evidence IDs
profile/local-memory injection
malformed output loops
generic coding/translation proxy use
```

Secrets must never be placed in system prompts.

## 11. Local memory is structured and bounded

Allowed memory is contextual only: goal, selected people/theme/time/location, bounded prior conclusions, recent Chart/Analysis refs, open questions.

Do not persist/transmit instruction-authority fields such as:

```text
systemInstruction
policyOverride
behaviorPreference
toolInstruction
creditOverride
providerOverride
```

Do not upload full long-term conversation history merely because it is easier.

Runtime must validate local memory again with a strict schema.

## 12. Structured final output

Final model output is validated before delivery.

Expected bounded structure includes:

```text
answer
keyFactors
timingWindows
chartRefs
limitations
followUps
supportingEvidenceRefs when used internally
```

Validate schema, length, Evidence refs, chart refs and prohibited deterministic/high-risk claims.

Malformed/invalid output gets **one constrained repair attempt maximum**. Second failure -> bounded safe fallback. No infinite repair loop.

Repair consumes remaining token/provider-cost budget.

## 13. Model Catalog is server authority

iOS may send only an approved product-facing `model_id`.

Client must not control:

```text
provider
providerModel
creditsRequired
maxInputTokens
maxOutputTokens
maxToolRounds
evidenceTargetTokens
maxProviderCost
pricing rates
```

Resolve all of these from server `ModelCatalog` / `MODEL_CATALOG_JSON` before Credit reservation.

Reject arbitrary provider model IDs before charging.

Only `enabled && agentEligible` models may run.

## 14. Provider secrets

DeepSeek/OpenRouter keys are Runtime secrets, currently supplied through Runtime environment configuration, e.g. `.env`.

Never put provider/API secrets in:

- iOS source/build settings committed to git;
- Admin browser JS;
- public Runtime Config responses;
- logs;
- docs/examples;
- system prompts.

Do not commit real `.env` files.

Current Admin may inspect non-secret Model/Runtime policy but does not reveal provider keys.

If Provider Settings is later added, support replace/test/delete without ever returning the full stored key.

Production must fail closed when required configuration for enabled functionality is missing.

## 15. Credits invariants

Credits are a financial ledger, not a UI counter.

```text
reserve -> commit | release
```

Rules:

- reserve before a paid Run;
- commit only after valid final output is saved by iOS and ACKed;
- failure/cancel/expiry/no usable final/no ACK -> release;
- completed-but-never-ACKed must not become charged success on TTL expiry;
- commit/release are idempotent;
- Credit price comes from server ModelPolicy;
- budget exhaustion should finalize from existing Evidence, not produce a raw quota error;
- extra analysis requiring another Credit requires explicit new user action.

Never weaken these semantics to simplify deployment.

## 16. Run/action invariants

Server Run lifecycle supports states equivalent to:

```text
created -> reasoning -> requires_action/waiting_for_client -> resuming
-> finalizing -> completed -> acknowledged
or failed/cancelled/expired
```

Rules:

- every action has `action_id`;
- duplicate `action_id` submission is idempotent;
- iOS stores enough local checkpoint state to recover after background/termination;
- expiry releases unresolved reservation;
- ACK is a financial/privacy state transition, not telemetry;
- temporary prompt/Evidence payload is deleted after ACK per privacy policy;
- do not create a second incompatible iOS Run state machine.

## 17. StoreKit/IAP invariants

Correct flow:

```text
purchase()
-> verified StoreKit transaction
-> DO NOT finish yet
-> send signed transaction/JWS to Runtime
-> server verify
-> atomic IAP ledger + Credit ledger
-> credited/already_processed
-> transaction.finish()
```

Rules:

- transaction ID unique;
- same transaction can credit only once across purchase result, updates, unfinished, restart, restore and retry;
- Product ID -> Credits is server-owned;
- never trust client Credit quantity;
- server verifies App Store transaction/JWS;
- `appAccountToken` belongs to the current CreditsWallet;
- Reset creates a new wallet/token;
- `.pending` is not failure;
- verified deliverable unfinished transactions must be reconciled before Reset/Delete;
- never `finish()` just to clear a queue before server delivery succeeds.

## 18. Reset/Delete invariants

### Reset

Creates new:

```text
AstroAccount generation
CreditsWallet
appAccountToken
```

Old Credits do not migrate and must not regain a restore path.

User warning must explicitly state remaining Credits cannot be recovered.

### Delete

Must reconcile deliverable unfinished purchases, revoke sessions, attempt Apple token revocation, remove/close server account/wallet state, clear local auth and return to Guest.

Temporary Apple revoke network failure must not permanently prevent account deletion.

Same Apple ID after Reset/Delete may create a new account/wallet but must not restore old Credits/server account state.

Do not guess on race/attribution bugs in these flows.

## 19. Privacy / logging

Principles:

```text
Local by default
Minimum necessary server data
Temporary Run payload
No server long-term chat archive
```

Prefer logs containing IDs, types, sizes, latency, token/cost usage, model/policy versions and error codes.

Do not log by default:

- full prompts/conversations;
- complete birth data;
- full Evidence;
- API keys;
- Apple refresh tokens;
- JWT/encryption secrets.

## 20. Product safety

StelyraAgent provides astrology interpretation, not guaranteed fate or professional advice.

Do not produce unsupported deterministic claims about guaranteed marriage/breakup/pregnancy/contact, promotion/layoff/job offers, investment outcomes/instructions, medical/psychiatric diagnosis/treatment, admission/visa results, safety, fame/commercial success or an unavoidable life path.

Prefer tendencies, dynamics, pressures, opportunities, windows and limitations grounded in Evidence.

Do not invent facts about people without validated Evidence.

## 21. iOS implementation rules

Primary Agent code lives under:

```text
stelyraagent-ios/ios/App/Agent/
```

Reuse existing deterministic services/models where semantically correct:

```text
SavedPerson / ChartContext
AppChartCalculationService
AppAdvancedChartCalculationService
AppRelationshipChartCalculationService
AstroCore / Swiss Ephemeris
existing chart renderer/models
```

Do not build a second approximate astrology engine.

### Chart Assets

Logical Conversation Asset is separate from physical artifact file.

Same semantic fingerprint may share one physical file while different Conversations retain distinct logical assets.

Fingerprint must distinguish materially different chart kind, subjects/birth identity, target time/location, calculation preset, relevant range/resolution and calculation schema version.

Do not restore legacy “one latest file per chart kind” deletion behavior.

## 22. Deployment topology and order

NAS v1:

```text
stelyraagent-runtime  -> SQLite persistent volume
stelyraagent-admin    -> Runtime Admin API
```

No PostgreSQL third container in v1.

Recommended integration order:

1. Runtime install/build/tests.
2. Admin install/build/tests.
3. On Mac/Colima, use buildx to build the Runtime image first and the Admin image second for NAS `linux/amd64`.
4. Transfer the two completed images to NAS; start Runtime first, then Admin. Verify health, Admin API and SQLite restart persistence.
5. Resolve Xcode dependencies, compile, and install the complete Debug build on the connected iPhone 12 mini (CoreDevice may display it as `HUAWEI PURA 70`).
6. Verify iOS -> Runtime bootstrap/config APIs and all no-provider-key paths that can run locally.
7. Only then fill the Provider API key in the NAS Runtime `.env` and run one live provider smoke test.
8. Run one simple Agent E2E Run.
9. Run Sign in with Apple + StoreKit Sandbox/TestFlight when real credentials/signing are available.
10. Run restart/idempotency/red-team failure tests.

Do not debug deep StoreKit behavior before basic Runtime/network/config is known-good unless evidence clearly points there.

## 23. Development workflow

For behavior changes/bugs:

1. reproduce;
2. add/identify failing test when feasible;
3. verify expected failure;
4. make smallest correct fix;
5. rerun failing test;
6. run relevant regression suite;
7. only then claim fixed.

Do not delete/weaken tests to make builds green.

Do not bundle unrelated refactors into deployment fixes.

## 24. Verification commands

Use package files/project configuration as final authority.

### Runtime

```bash
cd stelyraagent-runtime
npm install
npm run test:core
npm run build
```

### Admin

```bash
cd stelyraagent-admin
npm install
npm run test:contract
npm run build
```

### iOS contracts

```bash
cd stelyraagent-ios
pytest -q tests
```

Swift parser checks are useful but **do not equal an Xcode target build**.

For integration, run real `xcodebuild`/Xcode and report signing/device blockers separately.

Dockerfile presence is not proof of Docker success. Build/start it on a Docker-capable environment and verify Runtime volume persistence after restart.

## 25. Safe integration fixes vs. escalation

Normal deployment/compile fixes are in scope when evidence is clear:

- dependency/lock/build config;
- TS imports/types;
- Swift compile errors;
- target membership/resources;
- Docker build context/path/permissions;
- SQLite path/permissions;
- healthcheck/CORS/API base URL;
- obvious request/response mismatch;
- missing env parsing/validation;
- ordinary UI wiring.

After about two evidence-based attempts without progress, stop and preserve diagnostics instead of guessing when the problem involves:

- duplicate Credits/IAP;
- reserve/commit/release or ACK/expiry race;
- StoreKit pending/unfinished attribution;
- Reset/Delete transaction ownership;
- `appAccountToken` attribution;
- Apple nonce/JWS/aud/iss semantics;
- Run recovery/state-machine deadlock;
- Evidence Round authorization;
- deterministic-policy prompt-injection bypass;
- provider malformed-tool loops;
- multi-model budget inconsistency.

Never “fix” these by disabling validation, weakening idempotency, finishing StoreKit early or bypassing policy.

## 26. Explicit non-goals unless scope changes

Do not opportunistically add:

```text
server-side long-term conversation sync
Supabase
RAG/vector DB
MCP
Mastra/LangGraph
multiple autonomous subagents
web Chat
cross-device Chat sync
automatic Profile cloud backup
AI-side astrology calculation
PostgreSQL in v1
client-held provider secrets
```

Do not move the Runtime onto iPhone unless the architecture decision is explicitly reopened. Current implementation remains **server Agent Runtime + iOS local astrology tools**.

StelyraAgent is not a generic OpenRouter proxy. Explicit generic coding/translation/document proxy requests should be rejected before paid Run reservation where possible.

## 27. Production configuration

Read `docs/RELAY_POLICY_CONFIG.md` before deployment.

At minimum resolve real values for:

- JWT/session/encryption secrets;
- SQLite persistent path;
- Runtime/Admin origins and Admin credentials;
- `MODEL_CATALOG_JSON`;
- provider keys for enabled providers;
- model token/tool/cost/price policy;
- `DISABLED_CAPABILITIES` and scope/output policy;
- Apple auth/token-revoke configuration;
- App Store Server verification/bundle/environment;
- server Product ID -> Credits mapping.

Never invent production Apple credentials or silently fall back to sample IDs.

## 28. Completion/reporting

Do not say “deployment succeeded” without real evidence.

Report each separately:

```text
Runtime install/build/tests       PASS/FAIL/BLOCKED
Runtime Docker/health             PASS/FAIL/BLOCKED
SQLite restart persistence        PASS/FAIL/BLOCKED
Admin install/build/tests         PASS/FAIL/BLOCKED
Admin Docker/API                  PASS/FAIL/BLOCKED
iOS dependency resolution         PASS/FAIL/BLOCKED
Xcode compile/device build        PASS/FAIL/BLOCKED
iOS -> Runtime API                PASS/FAIL/BLOCKED
DeepSeek                          PASS/FAIL/NOT TESTED/BLOCKED
OpenRouter                        PASS/FAIL/NOT TESTED/BLOCKED
Sign in with Apple                PASS/FAIL/NOT TESTED/BLOCKED
StoreKit Sandbox/TestFlight       PASS/FAIL/NOT TESTED/BLOCKED
Agent end-to-end Run              PASS/FAIL/NOT TESTED/BLOCKED
```

For Agent E2E, report the exact last successful step:

```text
Question
-> Run admission
-> Credit reserve
-> AI reasoning
-> requires_action
-> local chart calculation
-> Evidence submit
-> Runtime resume
-> validated final
-> iOS persistence
-> ACK
-> Credit commit
```

When handing work off, list files changed, root cause, verification command/result, remaining blockers and concise relevant logs. Do not overwrite the user's original ZIP; create a new checkpoint ZIP/report.

## 29. Boundary summary

```text
AstroCore owns astrology facts.
Runtime policy owns authority.
Server ledger owns Credits/money.
Apple owns StoreKit transaction truth.
iOS owns long-lived private conversations/assets.
The model owns interpretation, not control.
```

If a shortcut blurs one of these boundaries, do not take it.

## 30. NAS Docker deployment and hot repair

The authoritative NAS environment facts and step-by-step deployment runbook are maintained in:

```text
docs/NAS_DOCKER_DEPLOYMENT.md
```

Every NAS deployment or hot repair must follow that document. The required flow is: build both Docker images on the Mac with Colima Buildx, targeting `linux/amd64`; transfer the completed images to NAS; deploy `stelyraagent-runtime` first and `stelyraagent-admin` second; keep the Runtime SQLite named volume; and hot repair by replacing versioned images and recreating only the affected service. Do not build source on NAS or copy source into a running container.

The real Provider keys are entered only after the complete iPhone 12 mini installation and no-key verification. Store them only in the untracked NAS file:

```text
/share/CACHEDEV4_DATA/homes/xiaoguiwk/stelyraagent/stelyraagent-runtime/.env
```

Do not commit, print, or package that file.

For the pre-key LAN installation only, use the repository template `deploy/nas/runtime-prekey.env` as the NAS `.env`. It intentionally runs in development mode with all model policies disabled and contains no Provider or Apple secrets; replace it with a complete production configuration before any non-LAN exposure.

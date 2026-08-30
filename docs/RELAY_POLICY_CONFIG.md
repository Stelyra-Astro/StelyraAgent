# StelyraAgent Relay / Runtime — Phase 3 Policy Configuration

The model is never the authority for money, tools, scope, evidence, or output limits. Those decisions are enforced by Runtime code and server-owned configuration.

## Production business configuration

### 1. Model allowlist — `MODEL_CATALOG_JSON`
Each user-selectable model is a server policy, not an arbitrary provider model string.

Required fields per model:
- `id`, `label`
- `provider`: `deepseek` or `openrouter`
- `providerModel`: real provider model id; never accepted from iOS
- `creditsRequired`: server-owned Credit price
- `maxInputTokens`, `maxOutputTokens`, `maxToolRounds`
- `evidenceTargetTokens`
- `maxProviderCost`
- `inputCostPerMillion`, `outputCostPerMillion`: budgeting rates; update when provider pricing changes
- `enabled`, `agentEligible`: model kill switches

The public `/v1/models` endpoint exposes only the approved product-facing model choices and their Credit tier/output cap. Provider secrets are never returned.

### 2. Capability policy / kill switch
- Catalog/autonomy rules live in Runtime source and are deterministic.
- `DISABLED_CAPABILITIES` can remove Agent-facing capabilities immediately without an App update.
- Advanced Davison/Marks/Harmonic capabilities remain user-selectable but are not ordinary autonomous choices.

### 3. Scope limits
- `MAX_ANALYSIS_YEARS=100`
- `MAX_LOCATIONS_PER_RUN=2`
- `MAX_AUTONOMOUS_CAPABILITIES=4`
- >10 years defaults to Major Windows.
- >30 years first-pass analysis is forced to Major Windows even when the user requests Detailed.
- Round 2 may only drill into a window found in Round 1.

### 4. Output / provider budgets
- `MAX_FINAL_CHARACTERS=12000`
- model-specific input/output/tool/cost budgets come from `MODEL_CATALOG_JSON`
- `PROVIDER_TIMEOUT_MS=60000`
- exactly one malformed/invalid-output repair attempt is allowed
- a second failure becomes a bounded safe fallback; no unbounded retry loop

### 5. Prompt / safety policy versions
- `PROMPT_POLICY_VERSION`
- `SCOPE_POLICY_VERSION`
- `OUTPUT_POLICY_VERSION`
- `SAFETY_POLICY_VERSION`

Every Run retains operational model/provider/version metadata while temporary prompt/evidence payload is deleted after ACK.

## Prompt trust hierarchy

1. **Trusted policy:** Runtime system/security/tool/theme/budget policy.
2. **Authoritative astrology data:** validated local Evidence only.
3. **Untrusted data:** user text, Draft Chips, profile names/notes, previous answers, and local memory.

Untrusted data is always serialized as data and cannot change policy authority. Local memory is whitelisted to structured fields and unknown/instruction-like keys are dropped or rejected before model execution.

## Output contract

The model must return structured final output with bounded:
- answer
- key factors + supporting Evidence refs
- timing windows
- chart refs
- limitations
- follow-ups

Runtime validates Evidence refs, output length, and prohibited deterministic/high-risk claims before delivery. Invalid output gets at most one constrained repair.

## Admission before Credit reserve

Before reserving Credits the Runtime:
- resolves `model_id` against the server allowlist
- rejects arbitrary provider model IDs
- rejects explicit generic coding/translation/document-proxy use outside StelyraAgent scope

The client cannot supply `credits_required`, provider model, token budget, tool budget, or provider cost budget.

## Operational / security configuration

Production also requires:
- Apple auth client id/secret and encrypted refresh-token key
- StoreKit server verification roots/environment/bundle id
- server-owned IAP product → Credits mapping
- DeepSeek/OpenRouter server keys for enabled providers
- independent Admin credentials and restricted Admin origin/network

## Admin inspection

Phase 3 Admin includes:
- Models — effective server model policies
- Provider Usage — run count, input/output/reasoning tokens, estimated provider cost, average tool rounds by provider/model
- Runtime Config — effective scope/policy versions and limits

Admin still does not display complete prompts, birth data, Evidence payloads, or conversation bodies.

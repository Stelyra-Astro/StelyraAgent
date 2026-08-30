# StelyraAgent Runtime

Independent Phase 1 runtime for StelyraAgent. It intentionally does **not** share Interstellar Relay code, accounts, credits, or storage.

## Implemented Phase 1 core

- Node.js 22 + TypeScript runtime.
- Hono HTTP surface for Auth, Account, Credits/IAP, Agent Runs, Config, and Admin APIs.
- SQLite persistence behind repositories.
- Run state machine with `requires_action` pause/resume and idempotent `action_id` submission.
- Credit `reserve -> commit/release` semantics.
- 24-hour configurable run TTL with payload deletion and reservation recovery.
- Model-provider abstraction with DeepSeek through the AI SDK OpenAI-compatible provider.
- Phase 1 server/client capability intersection for the six frozen capabilities.
- Apple identity token verification and opaque StelyraAgent access/refresh sessions.
- Reset semantics: new account generation, new wallet, new `appAccountToken`, no old-credit migration.
- IAP idempotency repository and reconciliation service.
- Admin repository/API; admin never reads the SQLite file directly from the browser.

## Important IAP boundary

`RejectingStoreTransactionVerifier` is deliberately the default. It refuses to credit client-supplied StoreKit payloads until a real Apple server-side transaction verifier is configured. This is safer than trusting a transaction ID or client-declared credit amount. Replace that verifier before production IAP testing.

## Local development

```bash
cp .env.example .env
npm install
npm run dev
```

Core state-machine/repository tests can run on Node 22 without installed third-party packages:

```bash
npm run test:core
```

## Docker

```bash
cp .env.example .env
# Fill secrets, then:
docker compose up -d --build
```

Persistent data lives in the `stelyraagent_runtime_data` Docker volume.

## API

User API follows the v1 spec: `/v1/auth/*`, `/v1/account`, `/v1/credits`, `/v1/purchases`, `/v1/iap/reconcile`, `/v1/subscription`, `/v1/runs/*`, `/v1/capabilities`, `/v1/runtime-config`.

Admin API is under `/v1/admin/*` and requires separate Basic Auth when `ADMIN_USERNAME`/`ADMIN_PASSWORD` are configured.

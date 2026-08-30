# StelyraAgent — Phase 1–3 source checkpoint

2026-08-30 source delivery based on the frozen StelyraAgent v1 specification.

- `stelyraagent-ios/` — local conversations/profiles/assets, AstroCore bridge, all v1 capabilities, Theme/Resolution/Technique planning support, model picker and bounded follow-up memory.
- `stelyraagent-runtime/` — independent Node.js/TypeScript Runtime + SQLite + DeepSeek/OpenRouter providers + Model/Scope/Evidence/Output/Safety policies + Auth/Credits/IAP + Docker.
- `stelyraagent-admin/` — independent React/Vite Admin + Docker, including Models and Provider Usage.
- `docs/RELAY_POLICY_CONFIG.md` — production Relay business/safety configuration checklist.
- `docker-compose.yml` — two-container NAS topology.

The source now covers the specified Phase 1, Phase 2 and Phase 3 feature scope. Real Xcode, Docker, Apple Sandbox/TestFlight and live-provider integration remains a separate final integration pass.

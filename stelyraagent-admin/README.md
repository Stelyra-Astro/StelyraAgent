# StelyraAgent Admin

Independent React + Vite admin UI. It has no SQLite access and no database volume. All operational data comes from the StelyraAgent Runtime Admin API.

## Phase 1 pages
- Dashboard
- Agent Runs
- IAP Transactions
- Runtime Config
- System Health

Admin Basic Auth credentials are entered at runtime and are not baked into the static bundle. URL and username are remembered in `sessionStorage`; password is held only in React state for the current page lifetime.

## Run
```bash
npm install
npm run dev
```

## Docker
```bash
docker compose up -d --build
```
Then open port 8788 and point the UI at the Runtime URL reachable from your browser.

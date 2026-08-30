import { FormEvent, useMemo, useState } from 'react';
import { loadAdminSnapshot, type AdminCredentials, type AdminSnapshot } from './api';
import './styles.css';

type Section = 'Dashboard' | 'Agent Runs' | 'IAP Transactions' | 'Models' | 'Provider Usage' | 'Runtime Config' | 'System Health';
const sections: Section[] = ['Dashboard', 'Agent Runs', 'IAP Transactions', 'Models', 'Provider Usage', 'Runtime Config', 'System Health'];

function formatNumber(value: number): string {
  return new Intl.NumberFormat('en-US', { maximumFractionDigits: 4 }).format(value);
}

function DataTable({ rows }: { rows: Array<Record<string, unknown>> }) {
  const columns = useMemo(() => Array.from(new Set(rows.flatMap((row) => Object.keys(row)))), [rows]);
  if (!rows.length) return <div className="empty">No data yet.</div>;
  return (
    <div className="table-wrap">
      <table>
        <thead><tr>{columns.map((column) => <th key={column}>{column}</th>)}</tr></thead>
        <tbody>{rows.map((row, index) => (
          <tr key={String(row.run_id ?? row.transaction_id ?? index)}>
            {columns.map((column) => <td key={column}>{String(row[column] ?? '—')}</td>)}
          </tr>
        ))}</tbody>
      </table>
    </div>
  );
}

export default function App() {
  const [section, setSection] = useState<Section>('Dashboard');
  const [credentials, setCredentials] = useState<AdminCredentials>(() => ({
    baseURL: sessionStorage.getItem('astro-admin-base-url') ?? 'http://localhost:8787',
    username: sessionStorage.getItem('astro-admin-username') ?? '',
    password: '',
  }));
  const [snapshot, setSnapshot] = useState<AdminSnapshot | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function connect(event?: FormEvent) {
    event?.preventDefault();
    setLoading(true);
    setError(null);
    try {
      const next = await loadAdminSnapshot(credentials);
      setSnapshot(next);
      sessionStorage.setItem('astro-admin-base-url', credentials.baseURL);
      sessionStorage.setItem('astro-admin-username', credentials.username);
    } catch (err) {
      setSnapshot(null);
      setError(err instanceof Error ? err.message : 'Unable to connect');
    } finally {
      setLoading(false);
    }
  }

  const d = snapshot?.dashboard;
  return (
    <main className="shell">
      <aside className="sidebar">
        <div className="brand"><div className="mark">✦</div><div><strong>StelyraAgent</strong><span>Admin</span></div></div>
        <nav>{sections.map((item) => (
          <button key={item} className={section === item ? 'active' : ''} onClick={() => setSection(item)}>{item}</button>
        ))}</nav>
        <div className="privacy-note">Operational metadata only. Private prompt and evidence payloads are not shown here.</div>
      </aside>
      <section className="content">
        <header>
          <div><p className="eyebrow">Independent runtime</p><h1>{section}</h1></div>
          <button className="refresh" onClick={() => void connect()} disabled={loading}>{loading ? 'Refreshing…' : 'Refresh'}</button>
        </header>

        {!snapshot && (
          <form className="connect-card" onSubmit={connect}>
            <h2>Connect to Runtime</h2>
            <p>Credentials stay in this tab. The admin container never mounts the SQLite volume.</p>
            <label>Runtime URL<input value={credentials.baseURL} onChange={(e) => setCredentials({ ...credentials, baseURL: e.target.value })} /></label>
            <label>Admin username<input autoComplete="username" value={credentials.username} onChange={(e) => setCredentials({ ...credentials, username: e.target.value })} /></label>
            <label>Admin password<input type="password" autoComplete="current-password" value={credentials.password} onChange={(e) => setCredentials({ ...credentials, password: e.target.value })} /></label>
            <button type="submit" disabled={loading}>{loading ? 'Connecting…' : 'Connect'}</button>
            {error && <pre className="error">{error}</pre>}
          </form>
        )}

        {snapshot && section === 'Dashboard' && d && (
          <>
            <div className="metric-grid">
              <article><span>Active accounts</span><strong>{formatNumber(d.activeAccounts)}</strong></article>
              <article><span>Credits available</span><strong>{formatNumber(d.creditsAvailable)}</strong></article>
              <article><span>Credits spent</span><strong>{formatNumber(d.creditSpendCount)}</strong></article>
              <article><span>IAP transactions</span><strong>{formatNumber(d.iapTransactionCount)}</strong></article>
              <article><span>Runs</span><strong>{formatNumber(d.runCount)}</strong></article>
              <article><span>Successful runs</span><strong>{formatNumber(d.runSuccessCount)}</strong></article>
              <article><span>Failed / expired</span><strong>{formatNumber(d.runFailureCount)}</strong></article>
              <article><span>Provider cost</span><strong>${formatNumber(d.providerCost)}</strong></article>
              <article><span>Run success rate</span><strong>{formatNumber(d.runSuccessRate * 100)}%</strong></article>
              <article><span>Budget-limit rate</span><strong>{formatNumber(d.budgetLimitRate * 100)}%</strong></article>
              <article><span>Interaction rate</span><strong>{formatNumber(d.interactionRate * 100)}%</strong></article>
              <article><span>Avg tool rounds</span><strong>{formatNumber(d.averageToolRounds)}</strong></article>
              <article><span>Avg charts / run</span><strong>{formatNumber(d.averageChartsPerRun)}</strong></article>
              <article><span>Avg input tokens</span><strong>{formatNumber(d.averageInputTokens)}</strong></article>
              <article><span>Avg output tokens</span><strong>{formatNumber(d.averageOutputTokens)}</strong></article>
              <article><span>Avg interactions</span><strong>{formatNumber(d.averageInteractionCount)}</strong></article>
            </div>
            <div className="panel"><h2>Phase 2 analytics</h2><p>Run quality, interaction, chart-request and token metrics are persisted as operational metadata. Detailed chat and astrology evidence remain excluded.</p></div>
          </>
        )}
        {snapshot && section === 'Agent Runs' && <div className="panel"><h2>Recent runs</h2><DataTable rows={snapshot.runs} /></div>}
        {snapshot && section === 'IAP Transactions' && <div className="panel"><h2>Recent transactions</h2><DataTable rows={snapshot.iap} /></div>}
        {snapshot && section === 'Models' && <div className="panel"><h2>Server model policies</h2><p>Client-visible model choices are controlled by this server allowlist. Provider secrets are never exposed.</p><DataTable rows={snapshot.models} /></div>}
        {snapshot && section === 'Provider Usage' && <div className="panel"><h2>Provider usage</h2><DataTable rows={snapshot.providerUsage} /></div>}
        {snapshot && section === 'Runtime Config' && <div className="panel"><h2>Effective config</h2><pre>{JSON.stringify(snapshot.runtimeConfig, null, 2)}</pre></div>}
        {snapshot && section === 'System Health' && <div className="panel"><h2>Runtime health</h2><pre>{JSON.stringify(snapshot.health, null, 2)}</pre></div>}
        {snapshot && error && <pre className="error">{error}</pre>}
      </section>
    </main>
  );
}

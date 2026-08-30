export interface AdminCredentials {
  baseURL: string;
  username: string;
  password: string;
}

export interface DashboardMetrics {
  activeAccounts: number;
  creditsAvailable: number;
  creditSpendCount: number;
  iapTransactionCount: number;
  runCount: number;
  runSuccessCount: number;
  runFailureCount: number;
  runSuccessRate: number;
  budgetLimitRate: number;
  interactionRate: number;
  averageToolRounds: number;
  averageChartsPerRun: number;
  averageInputTokens: number;
  averageOutputTokens: number;
  averageInteractionCount: number;
  providerCost: number;
}

export interface AdminSnapshot {
  dashboard: DashboardMetrics;
  runs: Array<Record<string, unknown>>;
  iap: Array<Record<string, unknown>>;
  models: Array<Record<string, unknown>>;
  providerUsage: Array<Record<string, unknown>>;
  runtimeConfig: Record<string, unknown>;
  health: Record<string, unknown>;
}

async function request<T>(credentials: AdminCredentials, path: string): Promise<T> {
  const baseURL = credentials.baseURL.replace(/\/$/, '');
  const response = await fetch(`${baseURL}${path}`, {
    headers: {
      Authorization: `Basic ${btoa(`${credentials.username}:${credentials.password}`)}`,
      Accept: 'application/json',
    },
  });
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`${response.status} ${response.statusText}${body ? `: ${body}` : ''}`);
  }
  return response.json() as Promise<T>;
}

export async function loadAdminSnapshot(credentials: AdminCredentials): Promise<AdminSnapshot> {
  const [dashboard, runs, iap, models, providerUsage, runtimeConfig, health] = await Promise.all([
    request<DashboardMetrics>(credentials, '/v1/admin/dashboard'),
    request<{ runs: Array<Record<string, unknown>> }>(credentials, '/v1/admin/runs'),
    request<{ transactions: Array<Record<string, unknown>> }>(credentials, '/v1/admin/iap'),
    request<{ models: Array<Record<string, unknown>> }>(credentials, '/v1/admin/models'),
    request<{ usage: Array<Record<string, unknown>> }>(credentials, '/v1/admin/provider-usage'),
    request<Record<string, unknown>>(credentials, '/v1/admin/runtime-config'),
    request<Record<string, unknown>>(credentials, '/v1/admin/health'),
  ]);
  return { dashboard, runs: runs.runs, iap: iap.transactions, models: models.models, providerUsage: providerUsage.usage, runtimeConfig, health };
}

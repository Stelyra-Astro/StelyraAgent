import type { AstroDatabase } from '../db/sqlite-database.ts';

export class AdminRepository {
  private readonly db: AstroDatabase;

  constructor(db: AstroDatabase) {
    this.db = db;
  }

  dashboard(): Record<string, number> {
    const scalar = (sql: string): number => {
      const row = this.db.prepare(sql).get() as { value: number };
      return Number(row.value ?? 0);
    };
    const runCount = scalar('SELECT COUNT(*) AS value FROM runs');
    const runSuccessCount = scalar("SELECT COUNT(*) AS value FROM runs WHERE status IN ('completed','acknowledged')");
    const safeRate = (value: number) => runCount > 0 ? value / runCount : 0;
    return {
      activeAccounts: scalar("SELECT COUNT(*) AS value FROM accounts WHERE status = 'active'"),
      creditsAvailable: scalar("SELECT COALESCE(SUM(available_balance), 0) AS value FROM wallets WHERE status = 'active'"),
      creditSpendCount: scalar("SELECT COUNT(*) AS value FROM credit_reservations WHERE status = 'committed'"),
      iapTransactionCount: scalar('SELECT COUNT(*) AS value FROM iap_transactions'),
      runCount,
      runSuccessCount,
      runFailureCount: scalar("SELECT COUNT(*) AS value FROM runs WHERE status IN ('failed','expired')"),
      runSuccessRate: safeRate(runSuccessCount),
      budgetLimitRate: safeRate(scalar('SELECT COUNT(*) AS value FROM runs WHERE budget_limited = 1')),
      interactionRate: safeRate(scalar('SELECT COUNT(*) AS value FROM runs WHERE interaction_count > 0')),
      averageToolRounds: scalar('SELECT COALESCE(AVG(tool_rounds), 0) AS value FROM runs'),
      averageChartsPerRun: scalar('SELECT COALESCE(AVG(chart_request_count), 0) AS value FROM runs'),
      averageInputTokens: scalar('SELECT COALESCE(AVG(input_tokens), 0) AS value FROM runs'),
      averageOutputTokens: scalar('SELECT COALESCE(AVG(output_tokens), 0) AS value FROM runs'),
      averageInteractionCount: scalar('SELECT COALESCE(AVG(interaction_count), 0) AS value FROM runs'),
      providerCost: scalar('SELECT COALESCE(SUM(provider_cost), 0) AS value FROM runs'),
    };
  }

  recentRuns(limit = 100): Array<Record<string, unknown>> {
    return this.db.prepare(`
      SELECT run_id, wallet_id, status, provider, model, input_tokens, output_tokens,
             reasoning_tokens, provider_cost, tool_rounds, interaction_count, chart_request_count, budget_limited, created_at, completed_at
      FROM runs ORDER BY created_at DESC LIMIT ?
    `).all(limit) as Array<Record<string, unknown>>;
  }

  providerUsage(): Array<Record<string, unknown>> {
    return this.db.prepare(`
      SELECT COALESCE(provider, 'unknown') AS provider, COALESCE(model, 'unknown') AS model,
             COUNT(*) AS run_count, COALESCE(SUM(input_tokens), 0) AS input_tokens,
             COALESCE(SUM(output_tokens), 0) AS output_tokens,
             COALESCE(SUM(reasoning_tokens), 0) AS reasoning_tokens,
             COALESCE(SUM(provider_cost), 0) AS provider_cost,
             COALESCE(AVG(tool_rounds), 0) AS average_tool_rounds
      FROM runs
      GROUP BY provider, model
      ORDER BY provider_cost DESC, run_count DESC
    `).all() as Array<Record<string, unknown>>;
  }

  recentIAP(limit = 100): Array<Record<string, unknown>> {
    return this.db.prepare(`
      SELECT transaction_id, wallet_id, product_id, credits, status, created_at
      FROM iap_transactions ORDER BY created_at DESC LIMIT ?
    `).all(limit) as Array<Record<string, unknown>>;
  }
}

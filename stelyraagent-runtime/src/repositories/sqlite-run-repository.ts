import type { AstroDatabase } from '../db/sqlite-database.ts';
import type { RunRecord, RunStatus } from '../domain/types.ts';

export class SqliteRunRepository {
  private readonly db: AstroDatabase;

  constructor(db: AstroDatabase) {
    this.db = db;
  }

  create(input: { runId: string; walletId: string | null; payload: Record<string, unknown> }): RunRecord {
    const now = new Date().toISOString();
    this.db.prepare(`
      INSERT INTO runs (run_id, wallet_id, status, payload_json, created_at)
      VALUES (?, ?, 'created', ?, ?)
    `).run(input.runId, input.walletId, JSON.stringify(input.payload), now);
    return this.get(input.runId)!;
  }

  get(runId: string): RunRecord | null {
    const row = this.db.prepare(`SELECT * FROM runs WHERE run_id = ?`).get(runId) as Record<string, unknown> | undefined;
    if (!row) return null;
    return {
      runId: String(row.run_id),
      walletId: row.wallet_id == null ? null : String(row.wallet_id),
      status: String(row.status) as RunStatus,
      payload: row.payload_json == null ? null : JSON.parse(String(row.payload_json)),
      provider: row.provider == null ? null : String(row.provider),
      model: row.model == null ? null : String(row.model),
      inputTokens: Number(row.input_tokens),
      outputTokens: Number(row.output_tokens),
      reasoningTokens: Number(row.reasoning_tokens),
      providerCost: Number(row.provider_cost),
      toolRounds: Number(row.tool_rounds),
      interactionCount: Number(row.interaction_count ?? 0),
      chartRequestCount: Number(row.chart_request_count ?? 0),
      budgetLimited: Number(row.budget_limited ?? 0) === 1,
      failureReason: row.failure_reason == null ? null : String(row.failure_reason),
      createdAt: String(row.created_at),
      completedAt: row.completed_at == null ? null : String(row.completed_at),
    };
  }


  incrementInteractionCount(runId: string): RunRecord {
    this.db.prepare(`UPDATE runs SET interaction_count = interaction_count + 1 WHERE run_id = ?`).run(runId);
    return this.get(runId)!;
  }

  incrementChartRequestCount(runId: string, count: number): RunRecord {
    this.db.prepare(`UPDATE runs SET chart_request_count = chart_request_count + ? WHERE run_id = ?`).run(Math.max(0, count), runId);
    return this.get(runId)!;
  }

  setBudgetLimited(runId: string, limited: boolean): RunRecord {
    this.db.prepare(`UPDATE runs SET budget_limited = ? WHERE run_id = ?`).run(limited ? 1 : 0, runId);
    return this.get(runId)!;
  }

  setFailureReason(runId: string, reason: string): RunRecord {
    this.db.prepare(`UPDATE runs SET failure_reason = ? WHERE run_id = ?`).run(reason, runId);
    const run = this.get(runId);
    if (!run) throw new Error('Run not found');
    return run;
  }

  incrementToolRounds(runId: string): RunRecord {
    this.db.prepare(`UPDATE runs SET tool_rounds = tool_rounds + 1 WHERE run_id = ?`).run(runId);
    const run = this.get(runId);
    if (!run) throw new Error('Run not found');
    return run;
  }

  addUsage(runId: string, usage: { inputTokens?: number; outputTokens?: number; reasoningTokens?: number; providerCost?: number }): RunRecord {
    const current = this.get(runId);
    if (!current) throw new Error('Run not found');
    this.db.prepare(`
      UPDATE runs
      SET input_tokens = input_tokens + ?, output_tokens = output_tokens + ?,
          reasoning_tokens = reasoning_tokens + ?, provider_cost = provider_cost + ?
      WHERE run_id = ?
    `).run(
      Math.max(0, usage.inputTokens ?? 0),
      Math.max(0, usage.outputTokens ?? 0),
      Math.max(0, usage.reasoningTokens ?? 0),
      Math.max(0, usage.providerCost ?? 0),
      runId,
    );
    return this.get(runId)!;
  }

  updateUsage(runId: string, usage: { inputTokens?: number; outputTokens?: number; reasoningTokens?: number; providerCost?: number; provider?: string; model?: string }): RunRecord {
    const current = this.get(runId);
    if (!current) throw new Error('Run not found');
    this.db.prepare(`
      UPDATE runs
      SET input_tokens = ?, output_tokens = ?, reasoning_tokens = ?, provider_cost = ?,
          provider = COALESCE(?, provider), model = COALESCE(?, model)
      WHERE run_id = ?
    `).run(
      usage.inputTokens ?? current.inputTokens,
      usage.outputTokens ?? current.outputTokens,
      usage.reasoningTokens ?? current.reasoningTokens,
      usage.providerCost ?? current.providerCost,
      usage.provider ?? null,
      usage.model ?? null,
      runId,
    );
    return this.get(runId)!;
  }

  setStatus(runId: string, status: RunStatus): RunRecord {
    const completedAt = status === 'completed' ? new Date().toISOString() : null;
    this.db.prepare(`
      UPDATE runs SET status = ?, completed_at = COALESCE(?, completed_at)
      WHERE run_id = ?
    `).run(status, completedAt, runId);
    const run = this.get(runId);
    if (!run) throw new Error('Run not found');
    return run;
  }

  updatePayload(runId: string, payload: Record<string, unknown> | null): RunRecord {
    this.db.prepare(`UPDATE runs SET payload_json = ? WHERE run_id = ?`)
      .run(payload == null ? null : JSON.stringify(payload), runId);
    const run = this.get(runId);
    if (!run) throw new Error('Run not found');
    return run;
  }

  storeActionResult(
    runId: string,
    actionId: string,
    result: Record<string, unknown>,
  ): { result: Record<string, unknown>; wasDuplicate: boolean } {
    const existing = this.db.prepare(`
      SELECT result_json FROM run_actions WHERE run_id = ? AND action_id = ?
    `).get(runId, actionId) as { result_json: string } | undefined;
    if (existing) {
      return { result: JSON.parse(existing.result_json), wasDuplicate: true };
    }
    this.db.prepare(`
      INSERT INTO run_actions (run_id, action_id, result_json, created_at)
      VALUES (?, ?, ?, ?)
    `).run(runId, actionId, JSON.stringify(result), new Date().toISOString());
    return { result, wasDuplicate: false };
  }

  getActionResult(runId: string, actionId: string): Record<string, unknown> | null {
    const row = this.db.prepare(`
      SELECT result_json FROM run_actions WHERE run_id = ? AND action_id = ?
    `).get(runId, actionId) as { result_json: string } | undefined;
    return row ? JSON.parse(row.result_json) : null;
  }

  listExpirableBefore(cutoffIso: string): RunRecord[] {
    const rows = this.db.prepare(`
      SELECT run_id FROM runs
      WHERE created_at < ? AND status NOT IN ('acknowledged','failed','cancelled','expired')
      ORDER BY created_at ASC
    `).all(cutoffIso) as Array<{ run_id: string }>;
    return rows.map((row) => this.get(row.run_id)).filter((run): run is RunRecord => run !== null);
  }

  listActiveByWallet(walletId: string): RunRecord[] {
    const rows = this.db.prepare(`
      SELECT run_id FROM runs
      WHERE wallet_id = ? AND status NOT IN ('completed','acknowledged','failed','cancelled','expired')
      ORDER BY created_at ASC
    `).all(walletId) as Array<{ run_id: string }>;
    return rows.map((row) => this.get(row.run_id)).filter((run): run is RunRecord => run !== null);
  }

  acknowledge(runId: string): RunRecord {
    this.db.prepare(`
      UPDATE runs SET status = 'acknowledged', payload_json = NULL WHERE run_id = ?
    `).run(runId);
    const run = this.get(runId);
    if (!run) throw new Error('Run not found');
    return run;
  }
}

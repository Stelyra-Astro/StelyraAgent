import test from 'node:test';
import assert from 'node:assert/strict';
import { createTestDatabase } from '../src/db/sqlite-database.ts';
import { AdminRepository } from '../src/admin/admin-repository.ts';

test('dashboard exposes phase2 run analytics persisted outside temporary payload', () => {
  const db = createTestDatabase();
  db.prepare(`INSERT INTO runs (run_id,status,input_tokens,output_tokens,tool_rounds,interaction_count,chart_request_count,budget_limited,provider_cost,created_at,completed_at) VALUES (?,?,?,?,?,?,?,?,?,?,?)`)
    .run('r1','acknowledged',100,50,2,1,3,1,0.25,'2026-01-01T00:00:00.000Z','2026-01-01T00:00:10.000Z');
  db.prepare(`INSERT INTO runs (run_id,status,input_tokens,output_tokens,tool_rounds,interaction_count,chart_request_count,budget_limited,provider_cost,created_at,completed_at) VALUES (?,?,?,?,?,?,?,?,?,?,?)`)
    .run('r2','failed',200,0,0,0,0,0,0.10,'2026-01-01T00:01:00.000Z',null);
  const stats = new AdminRepository(db).dashboard();
  assert.equal(stats.runCount, 2);
  assert.equal(stats.runSuccessRate, 0.5);
  assert.equal(stats.budgetLimitRate, 0.5);
  assert.equal(stats.interactionRate, 0.5);
  assert.equal(stats.averageToolRounds, 1);
  assert.equal(stats.averageChartsPerRun, 1.5);
  assert.equal(stats.averageInputTokens, 150);
  assert.equal(stats.averageOutputTokens, 25);
  db.close();
});

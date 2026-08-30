import test from 'node:test';
import assert from 'node:assert/strict';
import { createTestDatabase } from '../src/db/sqlite-database.ts';
import { SqliteRunRepository } from '../src/repositories/sqlite-run-repository.ts';
import { SqliteCreditRepository } from '../src/repositories/sqlite-credit-repository.ts';
import { RunService } from '../src/run/run-service.ts';
import { RunExpirySweeper } from '../src/run/run-expiry-sweeper.ts';

function seedWallet(db: ReturnType<typeof createTestDatabase>): string {
  const now = new Date().toISOString();
  db.prepare(`INSERT INTO apple_identities (identity_id, apple_sub, created_at, updated_at) VALUES (?, ?, ?, ?)`)
    .run('identity_1', 'apple_1', now, now);
  db.prepare(`INSERT INTO accounts (account_id, identity_id, generation, created_at) VALUES (?, ?, 1, ?)`)
    .run('account_1', 'identity_1', now);
  db.prepare(`INSERT INTO wallets (wallet_id, account_id, app_account_token, available_balance, created_at) VALUES (?, ?, ?, 3, ?)`)
    .run('wallet_1', 'account_1', 'token_1', now);
  return 'wallet_1';
}

test('expiry sweeper expires stale active runs and releases reserved credit', () => {
  const db = createTestDatabase();
  const walletId = seedWallet(db);
  const runs = new SqliteRunRepository(db);
  const credits = new SqliteCreditRepository(db);
  const service = new RunService(runs, credits);
  service.createRun({ runId: 'run_old', walletId, payload: { message: 'private' }, creditsRequired: 1 });
  service.startReasoning('run_old');
  db.prepare(`UPDATE runs SET created_at = ? WHERE run_id = ?`).run('2026-08-27T00:00:00.000Z', 'run_old');

  const sweeper = new RunExpirySweeper(runs, service);
  const count = sweeper.sweep(new Date('2026-08-29T00:00:00.000Z'), 24);

  assert.equal(count, 1);
  assert.equal(service.getRun('run_old').status, 'expired');
  assert.equal(service.getRun('run_old').payload, null);
  const wallet = credits.getWallet(walletId);
  assert.equal(wallet?.availableBalance, 3);
  assert.equal(wallet?.reservedBalance, 0);
  assert.equal(wallet?.spentBalance, 0);
});

test('expiry sweeper leaves recent and terminal runs untouched', () => {
  const db = createTestDatabase();
  const runs = new SqliteRunRepository(db);
  const credits = new SqliteCreditRepository(db);
  const service = new RunService(runs, credits);
  service.createRun({ runId: 'run_recent', walletId: null, payload: {}, creditsRequired: 0 });
  service.startReasoning('run_recent');
  db.prepare(`UPDATE runs SET created_at = ? WHERE run_id = ?`).run('2026-08-28T12:30:00.000Z', 'run_recent');

  const sweeper = new RunExpirySweeper(runs, service);
  assert.equal(sweeper.sweep(new Date('2026-08-29T00:00:00.000Z'), 24), 0);
  assert.equal(service.getRun('run_recent').status, 'reasoning');
});

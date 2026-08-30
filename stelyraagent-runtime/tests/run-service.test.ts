import test from 'node:test';
import assert from 'node:assert/strict';
import { createTestDatabase } from '../src/db/sqlite-database.ts';
import { SqliteCreditRepository } from '../src/repositories/sqlite-credit-repository.ts';
import { SqliteAccountRepository } from '../src/repositories/sqlite-account-repository.ts';
import { SqliteRunRepository } from '../src/repositories/sqlite-run-repository.ts';
import { RunService } from '../src/run/run-service.ts';

function fixture() {
  const db = createTestDatabase();
  const credits = new SqliteCreditRepository(db);
  const accounts = new SqliteAccountRepository(db);
  const identity = accounts.findOrCreateIdentity('apple_run_fixture');
  const account = accounts.createAccount(identity.identityId, 1);
  const runs = new SqliteRunRepository(db);
  const wallet = credits.createWallet(account.accountId, 2);
  return { db, credits, runs, wallet, service: new RunService(runs, credits) };
}

test('run pauses for an astrology action, resumes, completes, and commits only on ack', () => {
  const { credits, wallet, service } = fixture();
  service.createRun({ runId: 'run_1', walletId: wallet.walletId, payload: { question: 'career?' }, creditsRequired: 1 });
  service.startReasoning('run_1');
  service.requireAction('run_1', {
    id: 'action_1',
    type: 'astrology_tool',
    tool: 'request_astrology_evidence',
    payload: { requests: [{ capability: 'you.transit', subjects: ['primary'] }] },
  });

  const paused = service.getRun('run_1');
  assert.equal(paused.status, 'requires_action');
  assert.equal(paused.pendingAction?.id, 'action_1');

  service.submitAction('run_1', 'action_1', { evidence: [{ id: 'e1' }] });
  assert.equal(service.getRun('run_1').status, 'resuming');

  service.complete('run_1', { text: 'Best current answer.' });
  assert.equal(service.getRun('run_1').status, 'completed');
  assert.equal(credits.getReservationByRun('run_1')?.status, 'reserved');

  service.acknowledge('run_1');
  assert.equal(service.getRun('run_1').status, 'acknowledged');
  assert.equal(service.getRun('run_1').payload, null);
  assert.equal(credits.getReservationByRun('run_1')?.status, 'committed');
});

test('duplicate action submission is idempotent and does not increment tool rounds twice', () => {
  const { wallet, service } = fixture();
  service.createRun({ runId: 'run_1', walletId: wallet.walletId, payload: {}, creditsRequired: 1 });
  service.startReasoning('run_1');
  service.requireAction('run_1', {
    id: 'action_1', type: 'astrology_tool', tool: 'request_astrology_evidence', payload: {}
  });
  const first = service.submitAction('run_1', 'action_1', { evidence: ['first'] });
  const second = service.submitAction('run_1', 'action_1', { evidence: ['different'] });
  assert.equal(first.wasDuplicate, false);
  assert.equal(second.wasDuplicate, true);
  assert.deepEqual(second.result, { evidence: ['first'] });
  assert.equal(service.getRun('run_1').toolRounds, 1);
});

test('cancelling an active run releases reserved credit and deletes private payload', () => {
  const { credits, wallet, service } = fixture();
  service.createRun({ runId: 'run_1', walletId: wallet.walletId, payload: { private: 'x' }, creditsRequired: 1 });
  service.startReasoning('run_1');
  service.cancel('run_1');
  assert.equal(service.getRun('run_1').status, 'cancelled');
  assert.equal(service.getRun('run_1').payload, null);
  assert.equal(credits.getReservationByRun('run_1')?.status, 'released');
  assert.equal(credits.getWallet(wallet.walletId)?.availableBalance, 2);
});

test('expiring an unfinished run releases reserved credit', () => {
  const { credits, wallet, service } = fixture();
  service.createRun({ runId: 'run_1', walletId: wallet.walletId, payload: { private: 'x' }, creditsRequired: 1 });
  service.expire('run_1');
  assert.equal(service.getRun('run_1').status, 'expired');
  assert.equal(credits.getReservationByRun('run_1')?.status, 'released');
});

test('submitted interaction result retains pending action metadata for deterministic resume policies', () => {
  const { service } = fixture();
  service.createRun({ runId: 'run_plan', walletId: null, creditsRequired: 0, payload: { question: 'Plan?' } });
  service.startReasoning('run_plan');
  service.requireAction('run_plan', {
    id: 'plan_action',
    type: 'interaction',
    payload: { interaction: { kind: 'plan_review', prompt: 'Review' } },
  });
  service.submitAction('run_plan', 'plan_action', { approved: true });
  const results = service.getRun('run_plan').payload?.actionResults as Array<Record<string, unknown>>;
  assert.equal((results[0]?.action as any)?.payload?.interaction?.kind, 'plan_review');
});

test('expiring a completed but unacknowledged run releases reserved credit because delivery was never confirmed', () => {
  const { credits, wallet, service } = fixture();
  service.createRun({ runId: 'run_unacked', walletId: wallet.walletId, payload: { question: 'career?' }, creditsRequired: 1 });
  service.startReasoning('run_unacked');
  service.complete('run_unacked', { text: 'Generated but not yet persisted by the client.' });

  assert.equal(service.getRun('run_unacked').status, 'completed');
  assert.equal(credits.getReservationByRun('run_unacked')?.status, 'reserved');

  service.expire('run_unacked');

  assert.equal(service.getRun('run_unacked').status, 'expired');
  assert.equal(service.getRun('run_unacked').payload, null);
  assert.equal(credits.getReservationByRun('run_unacked')?.status, 'released');
  assert.equal(credits.getWallet(wallet.walletId)?.availableBalance, 2);
});

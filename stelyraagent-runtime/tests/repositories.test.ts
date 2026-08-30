import test from 'node:test';
import assert from 'node:assert/strict';
import { createTestDatabase } from '../src/db/sqlite-database.ts';
import { SqliteCreditRepository } from '../src/repositories/sqlite-credit-repository.ts';
import { SqliteAccountRepository } from '../src/repositories/sqlite-account-repository.ts';
import { SqliteRunRepository } from '../src/repositories/sqlite-run-repository.ts';

function createAccount(db: ReturnType<typeof createTestDatabase>, suffix: string) {
  const accounts = new SqliteAccountRepository(db);
  const identity = accounts.findOrCreateIdentity(`apple_${suffix}`);
  return accounts.createAccount(identity.identityId, 1);
}

test('credit reservation commit is idempotent and debits exactly once', () => {
  const db = createTestDatabase();
  const credits = new SqliteCreditRepository(db);
  const account = createAccount(db, 'commit');
  const wallet = credits.createWallet(account.accountId, 3);

  const reservation = credits.reserve(wallet.walletId, 'run_1', 1);
  assert.equal(credits.getWallet(wallet.walletId)?.availableBalance, 2);
  assert.equal(credits.getWallet(wallet.walletId)?.reservedBalance, 1);

  credits.commit(reservation.reservationId);
  credits.commit(reservation.reservationId);

  const after = credits.getWallet(wallet.walletId);
  assert.equal(after?.availableBalance, 2);
  assert.equal(after?.reservedBalance, 0);
  assert.equal(after?.spentBalance, 1);
});

test('credit reservation release is idempotent and restores availability', () => {
  const db = createTestDatabase();
  const credits = new SqliteCreditRepository(db);
  const account = createAccount(db, 'release');
  const wallet = credits.createWallet(account.accountId, 2);
  const reservation = credits.reserve(wallet.walletId, 'run_1', 1);

  credits.release(reservation.reservationId);
  credits.release(reservation.reservationId);

  const after = credits.getWallet(wallet.walletId);
  assert.equal(after?.availableBalance, 2);
  assert.equal(after?.reservedBalance, 0);
  assert.equal(after?.spentBalance, 0);
});

test('duplicate action submission returns the first stored result', () => {
  const db = createTestDatabase();
  const runs = new SqliteRunRepository(db);
  runs.create({ runId: 'run_1', walletId: null, payload: { question: 'career?' } });

  const first = runs.storeActionResult('run_1', 'action_1', { evidence: ['a'] });
  const second = runs.storeActionResult('run_1', 'action_1', { evidence: ['b'] });

  assert.deepEqual(first.result, { evidence: ['a'] });
  assert.deepEqual(second.result, { evidence: ['a'] });
  assert.equal(second.wasDuplicate, true);
});

test('acknowledging a run deletes temporary payload but keeps metadata', () => {
  const db = createTestDatabase();
  const runs = new SqliteRunRepository(db);
  runs.create({ runId: 'run_1', walletId: null, payload: { private: 'temporary' } });
  runs.setStatus('run_1', 'completed');

  runs.acknowledge('run_1');

  const run = runs.get('run_1');
  assert.equal(run?.status, 'acknowledged');
  assert.equal(run?.payload, null);
  assert.equal(run?.runId, 'run_1');
});

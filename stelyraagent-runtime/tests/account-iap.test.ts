import test from 'node:test';
import assert from 'node:assert/strict';
import { createTestDatabase } from '../src/db/sqlite-database.ts';
import { SqliteAccountRepository } from '../src/repositories/sqlite-account-repository.ts';
import { SqliteCreditRepository } from '../src/repositories/sqlite-credit-repository.ts';
import { SqliteIAPRepository } from '../src/repositories/sqlite-iap-repository.ts';
import { AccountService } from '../src/account/account-service.ts';
import { IAPService } from '../src/iap/iap-service.ts';

function fixture() {
  const db = createTestDatabase();
  const accounts = new SqliteAccountRepository(db);
  const credits = new SqliteCreditRepository(db);
  const iap = new SqliteIAPRepository(db);
  const accountService = new AccountService(accounts, credits);
  const iapService = new IAPService(iap, credits);
  return { db, accounts, credits, iap, accountService, iapService };
}

test('reset creates a new account generation, wallet, and appAccountToken without migrating old credits', () => {
  const { credits, accountService } = fixture();
  const first = accountService.signInOrCreate('apple_sub_1', 4);
  assert.equal(credits.getWallet(first.wallet.walletId)?.availableBalance, 4);

  const reset = accountService.reset(first.account.accountId);

  assert.notEqual(reset.account.accountId, first.account.accountId);
  assert.equal(reset.account.generation, first.account.generation + 1);
  assert.notEqual(reset.wallet.walletId, first.wallet.walletId);
  assert.notEqual(reset.wallet.appAccountToken, first.wallet.appAccountToken);
  assert.equal(reset.wallet.availableBalance, 0);
  assert.equal(credits.getWallet(first.wallet.walletId)?.status, 'closed');
});

test('same Apple identity after reset resolves to the new active account only', () => {
  const { accountService } = fixture();
  const first = accountService.signInOrCreate('apple_sub_1', 1);
  const reset = accountService.reset(first.account.accountId);
  const signedIn = accountService.signInOrCreate('apple_sub_1', 99);
  assert.equal(signedIn.account.accountId, reset.account.accountId);
  assert.equal(signedIn.wallet.walletId, reset.wallet.walletId);
  assert.equal(signedIn.wallet.availableBalance, 0);
});

test('verified IAP transaction credits a wallet once even when reconciled repeatedly', () => {
  const { accountService, iapService, credits } = fixture();
  const current = accountService.signInOrCreate('apple_sub_1', 0);

  const first = iapService.reconcileVerified({
    transactionId: 'tx_1',
    walletId: current.wallet.walletId,
    appAccountToken: current.wallet.appAccountToken,
    productId: 'credits.10',
    credits: 10,
  });
  const second = iapService.reconcileVerified({
    transactionId: 'tx_1',
    walletId: current.wallet.walletId,
    appAccountToken: current.wallet.appAccountToken,
    productId: 'credits.10',
    credits: 10,
  });

  assert.equal(first.status, 'credited');
  assert.equal(second.status, 'already_processed');
  assert.equal(credits.getWallet(current.wallet.walletId)?.availableBalance, 10);
});

test('a transaction tied to an old appAccountToken cannot be credited to a reset wallet', () => {
  const { accountService, iapService, credits } = fixture();
  const first = accountService.signInOrCreate('apple_sub_1', 0);
  iapService.reconcileVerified({
    transactionId: 'tx_old',
    walletId: first.wallet.walletId,
    appAccountToken: first.wallet.appAccountToken,
    productId: 'credits.10',
    credits: 10,
  });
  const reset = accountService.reset(first.account.accountId);

  const result = iapService.reconcileVerified({
    transactionId: 'tx_old',
    walletId: reset.wallet.walletId,
    appAccountToken: reset.wallet.appAccountToken,
    productId: 'credits.10',
    credits: 10,
  });

  assert.equal(result.status, 'already_processed');
  assert.equal(credits.getWallet(reset.wallet.walletId)?.availableBalance, 0);
});

test('purchase history exposes credited transaction creation time for Account UI', () => {
  const { accountService, iapService, iap } = fixture();
  const current = accountService.signInOrCreate('apple_history', 0);
  iapService.reconcileVerified({
    transactionId: 'tx_history',
    walletId: current.wallet.walletId,
    appAccountToken: current.wallet.appAccountToken,
    productId: 'credits.10',
    credits: 10,
  });
  const history = iap.listByWallet(current.wallet.walletId);
  assert.equal(history[0]?.transactionId, 'tx_history');
  assert.match(history[0]?.createdAt ?? '', /^\d{4}-\d{2}-\d{2}T/);
});

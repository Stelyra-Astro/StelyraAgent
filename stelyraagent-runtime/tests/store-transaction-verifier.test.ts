import test from 'node:test';
import assert from 'node:assert/strict';
import { AppleStoreTransactionVerifier } from '../src/iap/transaction-verifier.ts';

test('verified Apple transaction maps server-owned product id to credits', async () => {
  const verifier = new AppleStoreTransactionVerifier(
    async (signed) => {
      assert.equal(signed, 'signed-jws');
      return {
        transactionId: '2000001234567890',
        appAccountToken: 'c3c5965c-14b1-4ce3-a4e6-e63f5cfe83cc',
        productId: 'com.example.stelyraagent.credits10',
      };
    },
    { 'com.example.stelyraagent.credits10': 10 },
  );

  const result = await verifier.verify('signed-jws');
  assert.deepEqual(result, {
    transactionId: '2000001234567890',
    appAccountToken: 'c3c5965c-14b1-4ce3-a4e6-e63f5cfe83cc',
    productId: 'com.example.stelyraagent.credits10',
    credits: 10,
  });
});

test('unknown product id never grants credits even when Apple signature decoded successfully', async () => {
  const verifier = new AppleStoreTransactionVerifier(
    async () => ({ transactionId: 'tx', appAccountToken: 'token', productId: 'unknown.product' }),
    { 'known.product': 10 },
  );
  await assert.rejects(() => verifier.verify('signed-jws'), /not configured for credits/i);
});

test('transaction without appAccountToken is rejected to prevent cross-wallet delivery', async () => {
  const verifier = new AppleStoreTransactionVerifier(
    async () => ({ transactionId: 'tx', productId: 'known.product' }),
    { 'known.product': 10 },
  );
  await assert.rejects(() => verifier.verify('signed-jws'), /appAccountToken/i);
});

test('transaction without transaction id is rejected', async () => {
  const verifier = new AppleStoreTransactionVerifier(
    async () => ({ appAccountToken: 'token', productId: 'known.product' }),
    { 'known.product': 10 },
  );
  await assert.rejects(() => verifier.verify('signed-jws'), /transactionId/i);
});

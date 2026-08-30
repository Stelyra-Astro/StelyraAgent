import test from 'node:test';
import assert from 'node:assert/strict';
import { createTestDatabase } from '../src/db/sqlite-database.ts';
import { SqliteAccountRepository } from '../src/repositories/sqlite-account-repository.ts';
import { AppleTokenExchange } from '../src/auth/apple-token-exchange.ts';

test('encrypted Apple refresh token can be read and cleared for account deletion', () => {
  const db = createTestDatabase();
  const accounts = new SqliteAccountRepository(db);
  const identity = accounts.findOrCreateIdentity('apple_sub_delete');

  accounts.setEncryptedAppleRefreshToken(identity.identityId, 'encrypted-refresh');
  assert.equal(accounts.getEncryptedAppleRefreshToken(identity.identityId), 'encrypted-refresh');

  accounts.clearAppleRefreshToken(identity.identityId);
  assert.equal(accounts.getEncryptedAppleRefreshToken(identity.identityId), null);
});

test('Apple token revoke posts the refresh token with the correct form contract', async () => {
  let request: { url: string; init?: RequestInit } | undefined;
  const fetchImpl: typeof fetch = async (input, init) => {
    request = { url: String(input), init };
    return new Response(null, { status: 200 });
  };
  const exchange = new AppleTokenExchange('com.example.stelyraagent', 'client-secret', fetchImpl);

  await exchange.revoke('refresh-token-value');

  assert.equal(request?.url, 'https://appleid.apple.com/auth/revoke');
  assert.equal(request?.init?.method, 'POST');
  const body = request?.init?.body as URLSearchParams;
  assert.equal(body.get('client_id'), 'com.example.stelyraagent');
  assert.equal(body.get('client_secret'), 'client-secret');
  assert.equal(body.get('token'), 'refresh-token-value');
  assert.equal(body.get('token_type_hint'), 'refresh_token');
});

test('Apple token revoke fails closed when client secret is missing', async () => {
  const exchange = new AppleTokenExchange('com.example.stelyraagent');
  await assert.rejects(() => exchange.revoke('refresh-token-value'), /client secret/i);
});

import { SecretBox } from '../src/auth/secret-box.ts';

test('SecretBox decrypts a stored refresh token so delete can revoke it', () => {
  const key = Buffer.alloc(32, 7).toString('base64');
  const box = new SecretBox(key);
  const encrypted = box.encrypt('refresh-token-secret');
  assert.equal(box.decrypt(encrypted), 'refresh-token-secret');
});

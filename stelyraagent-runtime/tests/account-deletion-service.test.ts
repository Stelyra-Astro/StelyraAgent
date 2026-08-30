import test from 'node:test';
import assert from 'node:assert/strict';
import { createTestDatabase } from '../src/db/sqlite-database.ts';
import { SqliteAccountRepository } from '../src/repositories/sqlite-account-repository.ts';
import { SqliteCreditRepository } from '../src/repositories/sqlite-credit-repository.ts';
import { AccountService } from '../src/account/account-service.ts';
import { SecretBox } from '../src/auth/secret-box.ts';
import { AppleAccountDeletionService } from '../src/account/apple-account-deletion-service.ts';

function fixture(revoke: (token: string) => Promise<void>) {
  const db = createTestDatabase();
  const accounts = new SqliteAccountRepository(db);
  const credits = new SqliteCreditRepository(db);
  const accountService = new AccountService(accounts, credits);
  const secretBox = new SecretBox(Buffer.alloc(32, 9).toString('base64'));
  const deletion = new AppleAccountDeletionService(accounts, accountService, { revoke }, secretBox);
  return { accounts, accountService, secretBox, deletion };
}

test('delete revokes stored Apple refresh token then clears it and deletes account', async () => {
  let revoked: string | null = null;
  const { accounts, accountService, secretBox, deletion } = fixture(async (token) => { revoked = token; });
  const bundle = accountService.signInOrCreate('apple_sub_delete', 3);
  accounts.setEncryptedAppleRefreshToken(bundle.account.identityId, secretBox.encrypt('refresh-123'));

  const result = await deletion.delete(bundle.account.accountId);

  assert.equal(revoked, 'refresh-123');
  assert.equal(result.appleRevocation, 'revoked');
  assert.equal(accounts.getEncryptedAppleRefreshToken(bundle.account.identityId), null);
  assert.equal(accounts.getAccount(bundle.account.accountId)?.status, 'deleted');
});

test('delete still removes server account and stored token when Apple revoke fails', async () => {
  const { accounts, accountService, secretBox, deletion } = fixture(async () => { throw new Error('Apple unavailable'); });
  const bundle = accountService.signInOrCreate('apple_sub_delete_failure', 1);
  accounts.setEncryptedAppleRefreshToken(bundle.account.identityId, secretBox.encrypt('refresh-456'));

  const result = await deletion.delete(bundle.account.accountId);

  assert.equal(result.appleRevocation, 'failed');
  assert.equal(accounts.getEncryptedAppleRefreshToken(bundle.account.identityId), null);
  assert.equal(accounts.getAccount(bundle.account.accountId)?.status, 'deleted');
});

test('delete succeeds with not_available when no refresh token was ever stored', async () => {
  const { accountService, deletion } = fixture(async () => { throw new Error('must not be called'); });
  const bundle = accountService.signInOrCreate('apple_sub_no_refresh', 0);

  const result = await deletion.delete(bundle.account.accountId);
  assert.equal(result.appleRevocation, 'not_available');
});

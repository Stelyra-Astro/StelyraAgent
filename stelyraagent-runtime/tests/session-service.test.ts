import test from 'node:test';
import assert from 'node:assert/strict';
import { createTestDatabase } from '../src/db/sqlite-database.ts';
import { SessionService } from '../src/account/session-service.ts';

test('access and refresh tokens are opaque, verifiable, rotatable, and revocable', () => {
  const db = createTestDatabase();
  const sessions = new SessionService(db, { accessTTLSeconds: 900, refreshTTLSeconds: 3600 });
  const issued = sessions.issue('acct_1');
  assert.equal(sessions.verifyAccess(issued.accessToken)?.accountId, 'acct_1');

  const rotated = sessions.refresh(issued.refreshToken);
  assert.notEqual(rotated.accessToken, issued.accessToken);
  assert.notEqual(rotated.refreshToken, issued.refreshToken);
  assert.equal(sessions.verifyAccess(issued.accessToken), null);
  assert.equal(sessions.verifyAccess(rotated.accessToken)?.accountId, 'acct_1');

  sessions.revokeByAccount('acct_1');
  assert.equal(sessions.verifyAccess(rotated.accessToken), null);
});

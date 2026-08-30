import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

test('reset account response returns complete rotated session expiries required by iOS', () => {
  const source = readFileSync(new URL('../src/http/account-routes.ts', import.meta.url), 'utf8');
  const resetStart = source.indexOf("routes.post('/account/reset'");
  const deleteStart = source.indexOf("routes.delete('/account'");
  const resetBlock = source.slice(resetStart, deleteStart);
  assert.match(resetBlock, /access_expires_at/);
  assert.match(resetBlock, /refresh_expires_at/);
});

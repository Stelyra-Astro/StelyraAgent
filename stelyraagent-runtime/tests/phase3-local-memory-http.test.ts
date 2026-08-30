import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

test('run HTTP contract accepts bounded local_memory but never client policy overrides', () => {
  const source = readFileSync(new URL('../src/http/agent-routes.ts', import.meta.url), 'utf8');
  assert.match(source, /localMemorySchema/);
  assert.match(source, /local_memory:\s*localMemorySchema\.optional\(\)/);
  assert.match(source, /localMemory:\s*body\.local_memory/);
  assert.doesNotMatch(source, /credits_required/);
  assert.doesNotMatch(source, /provider_model/);
});

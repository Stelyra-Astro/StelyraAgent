import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

test('run creation accepts server model id and no longer accepts client credits_required', () => {
  const source = readFileSync(new URL('../src/http/agent-routes.ts', import.meta.url), 'utf8');
  assert.match(source, /model_id/);
  assert.doesNotMatch(source, /credits_required/);
  assert.match(source, /admission\.admit/);
  assert.match(source, /creditsRequired:\s*admission\.model\.creditsRequired/);
});

test('config routes expose only server-approved public models and phase three policy versions', () => {
  const source = readFileSync(new URL('../src/http/config-routes.ts', import.meta.url), 'utf8');
  assert.match(source, /routes\.get\('\/models'/);
  assert.match(source, /modelCatalog\.listPublic/);
  assert.match(source, /enabled_phase:\s*3/);
  assert.match(source, /prompt_policy_version/);
  assert.match(source, /output_policy_version/);
});

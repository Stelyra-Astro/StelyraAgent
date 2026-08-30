import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { SERVER_CAPABILITY_CATALOG } from '../src/capabilities/catalog.ts';
import { loadRuntimeConfig } from '../src/config/runtime-config.ts';

test('provider prompt uses trust-separated envelope for orchestration policy and local follow-up memory', () => {
  const source = readFileSync(new URL('../src/providers/openai-compatible-agent-provider.ts', import.meta.url), 'utf8');
  assert.match(source, /buildPromptEnvelope/);
  assert.match(source, /orchestrationPolicy:\s*trustedPolicy/);
  assert.match(source, /localMemory:\s*request\.localMemory/);
});

test('runtime config exposes the complete enabled catalog and keeps phase one only as compatibility metadata', () => {
  const config = loadRuntimeConfig({});
  assert.deepEqual(config.enabledCapabilities, SERVER_CAPABILITY_CATALOG);
  assert.ok(config.phase1Capabilities.length < config.enabledCapabilities.length);
});

test('config routes advertise phase three and complete supported capabilities', () => {
  const source = readFileSync(new URL('../src/http/config-routes.ts', import.meta.url), 'utf8');
  assert.match(source, /enabled_phase:\s*3/);
  assert.match(source, /supported_capabilities:\s*services\.config\.enabledCapabilities/);
});

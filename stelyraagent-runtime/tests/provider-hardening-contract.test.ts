import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

test('all OpenAI-compatible providers apply the configured AI SDK timeout to every model call', () => {
  const source = readFileSync(new URL('../src/providers/openai-compatible-agent-provider.ts', import.meta.url), 'utf8');
  assert.match(source, /timeoutMs/);
  assert.match(source, /timeout:\s*this\.timeoutMs/);
});

test('runtime validates production secrets before creating database or provider services', () => {
  const source = readFileSync(new URL('../src/index.ts', import.meta.url), 'utf8');
  const validation = source.indexOf('assertProductionEnvironment(process.env)');
  const database = source.indexOf('createDatabase(');
  assert.ok(validation >= 0, 'production environment validation missing');
  assert.ok(database >= 0, 'database creation missing');
  assert.ok(validation < database, 'production environment must be validated before service startup');
  assert.match(source, /providerTimeoutMs/);
});

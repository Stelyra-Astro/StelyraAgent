import test from 'node:test';
import assert from 'node:assert/strict';
import { loadRuntimeConfig } from '../src/config/runtime-config.ts';
import { AnalysisPlanCompiler } from '../src/agent/analysis-plan-compiler.ts';

test('server can disable an Agent-facing capability without an app update', () => {
  const config = loadRuntimeConfig({ DISABLED_CAPABILITIES: 'relationship.davison,you.harmonic_13' });
  assert.equal(config.enabledCapabilities.includes('relationship.davison'), false);
  assert.equal(config.enabledCapabilities.includes('you.harmonic_13'), false);
  assert.equal(config.capabilityCatalog.includes('relationship.davison'), true);

  const compiler = new AnalysisPlanCompiler(undefined, config.enabledCapabilities);
  assert.throws(() => compiler.compile({
    question: 'Use Davison',
    clientCapabilities: ['relationship.davison'],
    draftContext: [{ kind: 'chart', value: 'relationship.davison' }],
    candidateRequests: [{ capability: 'relationship.davison', subjects: ['primary', 'other'] }],
  }), /not available/i);
});

test('unknown disabled capability id fails configuration instead of silently doing nothing', () => {
  assert.throws(() => loadRuntimeConfig({ DISABLED_CAPABILITIES: 'relationship.not_real' }), /DISABLED_CAPABILITIES/);
});

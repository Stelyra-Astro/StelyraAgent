import test from 'node:test';
import assert from 'node:assert/strict';
import { AnalysisPlanCompiler } from '../src/agent/analysis-plan-compiler.ts';

const caps = ['you.transit'];

test('more than ten years defaults to Major Windows Only instead of dense balanced output', () => {
  const result = new AnalysisPlanCompiler().compile({
    question: 'What are the big changes over the next 20 years?',
    clientCapabilities: caps,
    draftContext: [{ kind: 'chart', value: 'you.transit' }],
    candidateRequests: [{
      capability: 'you.transit', subjects: ['primary'],
      time_scope: { start: '2030-01-01', end: '2050-01-01' },
    }],
  });
  assert.equal(result.kind, 'requests');
  if (result.kind === 'requests') assert.equal(result.requests[0]?.time_scope?.resolution, 'major_windows_only');
});

test('over thirty years is forced to Major Windows Only even when user selects Detailed for the first broad run', () => {
  const result = new AnalysisPlanCompiler().compile({
    question: 'When are the key windows over the next 40 years?',
    clientCapabilities: caps,
    draftContext: [{ kind: 'chart', value: 'you.transit' }],
    candidateRequests: [{
      capability: 'you.transit', subjects: ['primary'],
      time_scope: { start: '2030-01-01', end: '2070-01-01' },
    }],
    actionResults: [{
      action: { payload: { interaction: { kind: 'analysis_choice', purpose: 'resolution' } } },
      result: { value: 'Detailed' },
    }],
  });
  assert.equal(result.kind, 'requests');
  if (result.kind === 'requests') assert.equal(result.requests[0]?.time_scope?.resolution, 'major_windows_only');
});

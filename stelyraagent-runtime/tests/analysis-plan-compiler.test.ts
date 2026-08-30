import test from 'node:test';
import assert from 'node:assert/strict';
import { AnalysisPlanCompiler } from '../src/agent/analysis-plan-compiler.ts';

const clientCapabilities = [
  'you.natal', 'you.transit', 'you.secondary',
  'relationship.synastry', 'relationship.composite', 'relationship.composite_transit',
];

test('Chart Mode injects an explicitly selected chart after reviewing a model-proposed extra', () => {
  const compiler = new AnalysisPlanCompiler();
  const result = compiler.compile({
    clientCapabilities,
    draftContext: [{ kind: 'chart', value: 'you.transit', title: 'Chart · Transit' }],
    candidateRequests: [{ capability: 'you.secondary', subjects: ['primary'] }],
    actionResults: [{
      actionId: 'review_chart_extra',
      action: { type: 'interaction', payload: { interaction: { kind: 'plan_review' } } },
      result: { approved: true },
    }],
  });
  assert.equal(result.kind, 'requests');
  if (result.kind !== 'requests') return;
  assert.equal(result.requests[0]?.capability, 'you.transit');
  assert.ok(result.requests.some((request) => request.capability === 'you.secondary'));
});

test('Chart Mode uses selected person as subject for an injected personal chart', () => {
  const compiler = new AnalysisPlanCompiler();
  const result = compiler.compile({
    clientCapabilities,
    draftContext: [
      { kind: 'chart', value: 'you.transit', title: 'Chart · Transit' },
      { kind: 'person', value: 'person_bill', title: 'Person · Bill' },
    ],
    candidateRequests: [],
  });
  assert.equal(result.kind, 'requests');
  if (result.kind !== 'requests') return;
  assert.deepEqual(result.requests[0]?.subjects, ['person_bill']);
});

test('relationship Chart Mode deterministically requires a second profile before local calculation', () => {
  const compiler = new AnalysisPlanCompiler();
  const result = compiler.compile({
    clientCapabilities,
    draftContext: [{ kind: 'chart', value: 'relationship.synastry', title: 'Chart · Synastry' }],
    candidateRequests: [],
  });
  assert.equal(result.kind, 'interaction');
  if (result.kind !== 'interaction') return;
  assert.equal(result.interaction.kind, 'required_input');
  assert.match(result.interaction.prompt, /person/i);
});

test('relationship Chart Mode injects primary + selected person subjects', () => {
  const compiler = new AnalysisPlanCompiler();
  const result = compiler.compile({
    clientCapabilities,
    draftContext: [
      { kind: 'chart', value: 'relationship.composite', title: 'Chart · Composite' },
      { kind: 'person', value: 'person_bill', title: 'Person · Bill' },
    ],
    candidateRequests: [],
  });
  assert.equal(result.kind, 'requests');
  if (result.kind !== 'requests') return;
  assert.deepEqual(result.requests[0]?.subjects, ['primary', 'person_bill']);
});

test('selected chart outside client/server intersection is rejected', () => {
  const compiler = new AnalysisPlanCompiler();
  assert.throws(() => compiler.compile({
    clientCapabilities,
    draftContext: [{ kind: 'chart', value: 'relationship.davison', title: 'Chart · Davison' }],
    candidateRequests: [],
  }), /not available/i);
});

test('autonomous multi-chart proposal requires a deterministic plan review before local calculation', () => {
  const compiler = new AnalysisPlanCompiler();
  const result = compiler.compile({
    clientCapabilities: ['you.natal', 'you.transit', 'you.secondary'],
    draftContext: [],
    candidateRequests: [
      { capability: 'you.transit', subjects: ['primary'] },
      { capability: 'you.secondary', subjects: ['primary'] },
    ],
    actionResults: [],
    creditsRequired: 1,
  });
  assert.equal(result.kind, 'interaction');
  if (result.kind === 'interaction') {
    assert.equal(result.interaction.kind, 'plan_review');
    assert.match(result.interaction.prompt, /Transit/i);
    assert.match(result.interaction.prompt, /Secondary/i);
    assert.match(result.interaction.prompt, /1 Credit/i);
  }
});

test('approved plan review lets the same multi-chart plan proceed without looping', () => {
  const compiler = new AnalysisPlanCompiler();
  const result = compiler.compile({
    clientCapabilities: ['you.natal', 'you.transit', 'you.secondary'],
    draftContext: [],
    candidateRequests: [
      { capability: 'you.transit', subjects: ['primary'] },
      { capability: 'you.secondary', subjects: ['primary'] },
    ],
    actionResults: [{
      actionId: 'review_1',
      action: { type: 'interaction', payload: { interaction: { kind: 'plan_review' } } },
      result: { approved: true },
    }],
    creditsRequired: 1,
  });
  assert.equal(result.kind, 'requests');
  if (result.kind === 'requests') assert.equal(result.requests.length, 2);
});

test('two charts explicitly selected by the user do not require another plan review', () => {
  const compiler = new AnalysisPlanCompiler();
  const result = compiler.compile({
    clientCapabilities: ['you.natal', 'you.transit', 'you.secondary'],
    draftContext: [
      { kind: 'chart', value: 'you.transit' },
      { kind: 'chart', value: 'you.secondary' },
    ],
    candidateRequests: [{ capability: 'you.transit', subjects: ['primary'] }],
    actionResults: [],
    creditsRequired: 1,
  });
  assert.equal(result.kind, 'requests');
});

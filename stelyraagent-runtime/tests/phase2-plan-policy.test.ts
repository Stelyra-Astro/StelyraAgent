import test from 'node:test';
import assert from 'node:assert/strict';
import { AnalysisPlanCompiler } from '../src/agent/analysis-plan-compiler.ts';

const compiler = new AnalysisPlanCompiler();

function approvedPlanReview() {
  return [{
    action: { payload: { interaction: { kind: 'plan_review' } } },
    result: { approved: true },
  }];
}

test('advanced capability proposed autonomously requires explicit plan review before execution', () => {
  const first = compiler.compile({
    question: 'Go deeper into our relationship',
    clientCapabilities: ['relationship.davison'],
    draftContext: [{ kind: 'person', value: 'primary' }, { kind: 'person', value: 'bill' }],
    candidateRequests: [{ capability: 'relationship.davison', subjects: ['primary', 'bill'] }],
  });
  assert.equal(first.kind, 'interaction');
  if (first.kind === 'interaction') assert.equal(first.interaction.kind, 'plan_review');

  const approved = compiler.compile({
    question: 'Go deeper into our relationship',
    clientCapabilities: ['relationship.davison'],
    draftContext: [{ kind: 'person', value: 'primary' }, { kind: 'person', value: 'bill' }],
    candidateRequests: [{ capability: 'relationship.davison', subjects: ['primary', 'bill'] }],
    actionResults: approvedPlanReview(),
  });
  assert.equal(approved.kind, 'requests');
});

test('explicitly selected advanced chart is user-selectable without autonomous-policy rejection', () => {
  const result = compiler.compile({
    question: 'Analyze this Davison chart',
    clientCapabilities: ['relationship.davison'],
    draftContext: [
      { kind: 'chart', value: 'relationship.davison' },
      { kind: 'person', value: 'bill' },
    ],
    candidateRequests: [],
  });
  assert.equal(result.kind, 'requests');
  if (result.kind === 'requests') assert.equal(result.requests[0]?.capability, 'relationship.davison');
});

test('career theme blocks autonomous relationship techniques but still allows explicit chart override', () => {
  assert.throws(() => compiler.compile({
    question: 'What is changing at work?',
    clientCapabilities: ['you.transit', 'relationship.composite'],
    draftContext: [{ kind: 'theme', value: 'career', title: 'Theme · Career & Purpose' }],
    candidateRequests: [{ capability: 'relationship.composite', subjects: ['primary', 'bill'] }],
  }), /not allowed by Theme Policy/);

  const explicit = compiler.compile({
    question: 'Use this chart too',
    clientCapabilities: ['relationship.composite'],
    draftContext: [
      { kind: 'theme', value: 'career', title: 'Theme · Career & Purpose' },
      { kind: 'chart', value: 'relationship.composite' },
      { kind: 'person', value: 'bill' },
    ],
    candidateRequests: [],
  });
  assert.equal(explicit.kind, 'requests');
});

test('timing search with a span requests native resolution choice once and then applies chosen resolution', () => {
  const input = {
    question: 'When is the best time to change jobs?',
    clientCapabilities: ['you.transit'],
    draftContext: [],
    candidateRequests: [{
      capability: 'you.transit',
      subjects: ['primary'],
      time_scope: { start: '2027-01-01', end: '2027-12-31' },
    }],
  };
  const first = compiler.compile(input);
  assert.equal(first.kind, 'interaction');
  if (first.kind === 'interaction') {
    assert.equal(first.interaction.kind, 'analysis_choice');
    assert.deepEqual(first.interaction.options, ['Overview', 'Balanced', 'Detailed', 'Major Windows Only']);
  }

  const second = compiler.compile({
    ...input,
    actionResults: [{
      action: { payload: { interaction: { kind: 'analysis_choice', purpose: 'resolution' } } },
      result: { value: 'Detailed' },
    }],
  });
  assert.equal(second.kind, 'requests');
  if (second.kind === 'requests') {
    assert.equal(second.requests[0]?.time_scope?.resolution, 'weekly');
  }
});

test('explicit Career Theme deterministically expands the one-year recipe without a plan-review checkbox wall', () => {
  const result = compiler.compile({
    question: 'How is my career over the next year?',
    clientCapabilities: ['you.natal', 'you.transit', 'you.secondary', 'you.solar_arc', 'you.solar_return'],
    draftContext: [{ kind: 'theme', value: 'career', title: 'Theme · Career & Purpose' }],
    candidateRequests: [{
      capability: 'you.transit', subjects: ['primary'],
      time_scope: { start: '2027-01-01', end: '2027-12-31', resolution: '2 weeks' },
    }],
  });
  assert.equal(result.kind, 'requests');
  if (result.kind === 'requests') {
    assert.deepEqual(result.requests.map((item) => item.capability), [
      'you.natal', 'you.transit', 'you.secondary', 'you.solar_arc', 'you.solar_return',
    ]);
  }
});

test('specific Love Theme uses the exact relationship recipe for three months', () => {
  const result = compiler.compile({
    question: 'What is changing between us in the next three months?',
    clientCapabilities: [
      'relationship.synastry', 'relationship.composite', 'relationship.composite_transit',
      'relationship.composite_secondary_compare', 'relationship.composite_tertiary_compare',
    ],
    draftContext: [
      { kind: 'theme', value: 'love', title: 'Theme · Love & Relationships' },
      { kind: 'person', value: 'bill', title: 'Person · Bill' },
    ],
    candidateRequests: [{
      capability: 'relationship.composite_transit', subjects: ['primary', 'bill'],
      time_scope: { start: '2027-01-01', end: '2027-04-01', resolution: '3 days' },
    }],
  });
  assert.equal(result.kind, 'requests');
  if (result.kind === 'requests') {
    assert.deepEqual(result.requests.map((item) => item.capability), [
      'relationship.synastry', 'relationship.composite', 'relationship.composite_transit',
      'relationship.composite_secondary_compare', 'relationship.composite_tertiary_compare',
    ]);
    assert.deepEqual(result.requests[0]?.subjects, ['primary', 'bill']);
  }
});

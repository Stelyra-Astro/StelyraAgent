import test from 'node:test';
import assert from 'node:assert/strict';
import type { ModelProvider, ModelProviderRequest, ProviderDecision } from '../src/providers/model-provider.ts';
import { PolicyEnforcedProvider } from '../src/policy/policy-enforced-provider.ts';

class QueueProvider implements ModelProvider {
  readonly name = 'fake';
  readonly model = 'fake-model';
  requests: ModelProviderRequest[] = [];
  private readonly queue: ProviderDecision[];
  constructor(queue: ProviderDecision[]) { this.queue = [...queue]; }
  async generate(request: ModelProviderRequest): Promise<ProviderDecision> {
    this.requests.push(request);
    const value = this.queue.shift();
    if (!value) throw new Error('no decision');
    return value;
  }
}

const request: ModelProviderRequest = {
  runId: 'run_1', question: 'What is changing?', clientCapabilities: ['you.transit'],
  draftContext: [], actionResults: [{ result: { facts: [{ id: 'ev_1', fact_type: 'aspect', data: {} }] } }],
  forceFinal: false, maxOutputTokens: 4096,
};

function output(answer: string, refs = ['ev_1']) {
  return {
    answer,
    keyFactors: [{ title: 'Factor', supportingEvidenceRefs: refs }],
    timingWindows: [], chartRefs: [], limitations: [], followUps: [],
  };
}

test('policy enforced provider accepts grounded structured final output', async () => {
  const base = new QueueProvider([{ kind: 'final', text: 'OK', structured: output('A grounded answer.') }]);
  const provider = new PolicyEnforcedProvider(base, { maxCharacters: 4000 });
  const result = await provider.generate(request);
  assert.equal(result.kind, 'final');
  if (result.kind === 'final') assert.equal(result.structured?.answer, 'A grounded answer.');
  assert.equal(base.requests.length, 1);
});

test('policy enforced provider performs at most one constrained repair', async () => {
  const base = new QueueProvider([
    { kind: 'final', text: 'bad', structured: output('Bad ref', ['ev_fake']) },
    { kind: 'final', text: 'fixed', structured: output('Fixed and grounded.') },
  ]);
  const provider = new PolicyEnforcedProvider(base, { maxCharacters: 4000 });
  const result = await provider.generate(request);
  assert.equal(result.kind, 'final');
  assert.equal(base.requests.length, 2);
  assert.match(base.requests[1]?.repairInstruction ?? '', /unknown evidence/i);
});

test('second invalid final becomes bounded fallback without a third model call', async () => {
  const base = new QueueProvider([
    { kind: 'final', text: 'bad', structured: output('Bad ref', ['ev_fake']) },
    { kind: 'final', text: 'still bad', structured: output('You will definitely get rich from this investment.') },
  ]);
  const provider = new PolicyEnforcedProvider(base, { maxCharacters: 4000 });
  const result = await provider.generate(request);
  assert.equal(result.kind, 'final');
  assert.equal(base.requests.length, 2);
  if (result.kind === 'final') {
    assert.equal(result.budgetLimited, true);
    assert.match(result.text, /could not safely validate/i);
  }
});

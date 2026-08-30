import test from 'node:test';
import assert from 'node:assert/strict';
import { createTestDatabase } from '../src/db/sqlite-database.ts';
import { SqliteCreditRepository } from '../src/repositories/sqlite-credit-repository.ts';
import { SqliteRunRepository } from '../src/repositories/sqlite-run-repository.ts';
import { RunService } from '../src/run/run-service.ts';
import { AstrologyAgentRuntime } from '../src/agent/astrology-agent-runtime.ts';
import type { ModelProvider, ModelProviderRequest, ProviderDecision } from '../src/providers/model-provider.ts';

class QueueProvider implements ModelProvider {
  readonly name = 'fake';
  readonly model = 'fake-model';
  requests: ModelProviderRequest[] = [];
  private readonly decisions: Array<ProviderDecision | Error>;

  constructor(decisions: Array<ProviderDecision | Error>) {
    this.decisions = [...decisions];
  }

  async generate(request: ModelProviderRequest): Promise<ProviderDecision> {
    this.requests.push(request);
    const next = this.decisions.shift();
    if (!next) throw new Error('No fake decision left');
    if (next instanceof Error) throw next;
    return next;
  }
}

function runtime(provider: ModelProvider, maxToolRounds = 2, draftContext: Array<Record<string, unknown>> = []) {
  const db = createTestDatabase();
  const credits = new SqliteCreditRepository(db);
  const runs = new SqliteRunRepository(db);
  const service = new RunService(runs, credits);
  service.createRun({
    runId: 'run_1',
    walletId: null,
    creditsRequired: 0,
    payload: {
      question: 'What is changing in my career?',
      clientCapabilities: ['you.natal', 'you.transit', 'you.secondary'],
      evidence: [],
      draftContext,
    },
  });
  service.startReasoning('run_1');
  return { service, agent: new AstrologyAgentRuntime(service, provider, { maxToolRounds }) };
}

test('agent pauses on a valid astrology evidence request', async () => {
  const provider = new QueueProvider([{
    kind: 'astrology_tool',
    requests: [{ capability: 'you.transit', subjects: ['primary'] }],
    reason: 'Check current career activations.',
  }]);
  const { service, agent } = runtime(provider);

  const result = await agent.advance('run_1');
  assert.equal(result.status, 'requires_action');
  assert.equal(service.getRun('run_1').pendingAction?.tool, 'request_astrology_evidence');
});

test('agent rejects a capability outside the client/server intersection', async () => {
  const provider = new QueueProvider([{
    kind: 'astrology_tool',
    requests: [{ capability: 'relationship.davison', subjects: ['primary', 'person_2'] }],
    reason: 'Use an unsupported advanced chart.',
  }]);
  const { agent } = runtime(provider);

  await assert.rejects(() => agent.advance('run_1'), /not available for this client/i);
});

test('agent can return an interaction instead of a chart request', async () => {
  const provider = new QueueProvider([{
    kind: 'interaction',
    interaction: {
      kind: 'analysis_choice',
      prompt: 'Which area should I focus on?',
      options: ['Overall', 'Career', 'Relationships'],
    },
  }]);
  const { agent } = runtime(provider);
  const result = await agent.advance('run_1');
  assert.equal(result.status, 'requires_action');
  assert.equal(result.action?.type, 'interaction');
});

test('agent completes a run when provider returns a final answer', async () => {
  const provider = new QueueProvider([{
    kind: 'final',
    text: 'Career changes are concentrated around the strongest transit windows.',
  }]);
  const { service, agent } = runtime(provider);
  const result = await agent.advance('run_1');
  assert.equal(result.status, 'completed');
  assert.match(JSON.stringify(service.getRun('run_1').payload), /Career changes/);
});

test('tool budget forces a finalization request and still completes with an answer', async () => {
  const provider = new QueueProvider([
    {
      kind: 'astrology_tool',
      requests: [{ capability: 'you.transit', subjects: ['primary'] }],
      reason: 'Need more evidence.',
    },
    {
      kind: 'final',
      text: 'Using the evidence already collected, the strongest pattern is a concentrated change window.',
      budgetLimited: true,
    },
  ]);
  const { service, agent } = runtime(provider, 0);
  const result = await agent.advance('run_1');
  assert.equal(result.status, 'completed');
  assert.equal(provider.requests.at(-1)?.forceFinal, true);
  assert.match(JSON.stringify(service.getRun('run_1').payload), /evidence already collected/);
});

test('provider failure during forced finalization produces a non-empty fallback answer', async () => {
  const provider = new QueueProvider([
    {
      kind: 'astrology_tool',
      requests: [{ capability: 'you.transit', subjects: ['primary'] }],
      reason: 'Need more evidence.',
    },
    new Error('provider unavailable'),
  ]);
  const { service, agent } = runtime(provider, 0);
  const result = await agent.advance('run_1');
  assert.equal(result.status, 'completed');
  const payload = JSON.stringify(service.getRun('run_1').payload);
  assert.match(payload, /analysis budget/i);
  assert.doesNotMatch(payload, /quota error/i);
});

test('structured interactions do not consume local astrology tool-round budget', async () => {
  const provider = new QueueProvider([{
    kind: 'interaction',
    interaction: {
      kind: 'analysis_choice',
      prompt: 'Which area should I focus on?',
      options: ['Overall', 'Career'],
    },
  }]);
  const { service, agent } = runtime(provider, 1);
  await agent.advance('run_1');
  assert.equal(service.getRun('run_1').toolRounds, 0);
});


test('runtime preserves an explicitly selected Chart Mode capability and reviews autonomous expansion', async () => {
  const provider = new QueueProvider([{
    kind: 'astrology_tool',
    requests: [{ capability: 'you.secondary', subjects: ['primary'] }],
    reason: 'Model proposed a different technique.',
  }]);
  const { service, agent } = runtime(provider, 2, [
    { kind: 'chart', value: 'you.transit', title: 'Chart · Transit' },
  ]);
  await agent.advance('run_1');
  const action = service.getRun('run_1').pendingAction;
  assert.equal(action?.type, 'interaction');
  assert.match(JSON.stringify(action?.payload), /plan_review/);
  assert.match(JSON.stringify(action?.payload), /Transit/);
  assert.match(JSON.stringify(action?.payload), /Secondary/);
});

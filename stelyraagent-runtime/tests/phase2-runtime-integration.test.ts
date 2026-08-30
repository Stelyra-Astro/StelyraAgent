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
  readonly requests: ModelProviderRequest[] = [];
  private readonly decisions: ProviderDecision[];
  constructor(decisions: ProviderDecision[]) { this.decisions = [...decisions]; }
  async generate(request: ModelProviderRequest): Promise<ProviderDecision> {
    this.requests.push(request);
    const next = this.decisions.shift();
    if (!next) throw new Error('No fake decision left');
    return next;
  }
}

function harness(question: string, provider: QueueProvider, draftContext: Array<Record<string, unknown>> = []) {
  const db = createTestDatabase();
  const credits = new SqliteCreditRepository(db);
  const runs = new SqliteRunRepository(db);
  const service = new RunService(runs, credits);
  service.createRun({
    runId: 'run_p2', walletId: null, creditsRequired: 0,
    payload: {
      question,
      clientCapabilities: ['you.natal', 'you.transit', 'you.secondary', 'you.tertiary', 'you.solar_arc', 'you.solar_return'],
      draftContext,
    },
  });
  service.startReasoning('run_p2');
  return { service, agent: new AstrologyAgentRuntime(service, provider, { maxToolRounds: 2 }) };
}

test('runtime passes the user question into deterministic resolution policy', async () => {
  const provider = new QueueProvider([{
    kind: 'astrology_tool',
    requests: [{
      capability: 'you.transit', subjects: ['primary'],
      time_scope: { start: '2027-01-01', end: '2027-12-31' },
    }],
    reason: 'Find job timing windows.',
  }]);
  const { service, agent } = harness('When is the best time to change jobs?', provider);
  const result = await agent.advance('run_p2');
  assert.equal(result.status, 'requires_action');
  const action = service.getRun('run_p2').pendingAction;
  assert.equal(action?.type, 'interaction');
  assert.match(JSON.stringify(action?.payload), /resolution/);
});

test('runtime prevents a second evidence round from inventing a focus window outside round one evidence', async () => {
  const provider = new QueueProvider([
    {
      kind: 'astrology_tool',
      requests: [{ capability: 'you.transit', subjects: ['primary'], time_scope: { start: '2027-01-01', end: '2027-12-31', resolution: '2 weeks' } }],
      reason: 'Broad scan.',
    },
    {
      kind: 'astrology_tool',
      requests: [{ capability: 'you.transit', subjects: ['primary'], time_scope: { start: '2027-09-01', end: '2027-09-15', resolution: 'daily' } }],
      reason: 'Drill down.',
    },
  ]);
  const { service, agent } = harness('Show my career timing over 2027.', provider);
  const first = await agent.advance('run_p2');
  assert.equal(first.action?.type, 'astrology_tool');
  service.submitAction('run_p2', first.action!.id, {
    facts: [{
      id: 'window_1', source_chart: 'transit', evidence_role: 'timing', fact_type: 'timing_event',
      data: { active_start: '2027-03-01', active_end: '2027-03-20', exact_at: '2027-03-10' },
    }],
  });
  await assert.rejects(() => agent.advance('run_p2'), /not grounded in a Round 1 evidence window/);
});

test('runtime sends selected theme policy and evidence budget context to the model provider', async () => {
  const provider = new QueueProvider([{ kind: 'final', text: 'Done.' }]);
  const { agent } = harness('What is changing in my career?', provider, [
    { kind: 'theme', value: 'career', title: 'Theme · Career & Purpose' },
  ]);
  await agent.advance('run_p2');
  const request = provider.requests[0] as ModelProviderRequest & { orchestrationPolicy?: Record<string, unknown> };
  assert.equal((request.orchestrationPolicy?.theme as Record<string, unknown>)?.id, 'career');
  assert.equal((request.orchestrationPolicy?.evidence as Record<string, unknown>)?.targetTokens, 16000);
});

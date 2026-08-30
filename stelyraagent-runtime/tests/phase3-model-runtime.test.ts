import test from 'node:test';
import assert from 'node:assert/strict';
import { createTestDatabase } from '../src/db/sqlite-database.ts';
import { SqliteCreditRepository } from '../src/repositories/sqlite-credit-repository.ts';
import { SqliteRunRepository } from '../src/repositories/sqlite-run-repository.ts';
import { RunService } from '../src/run/run-service.ts';
import { AstrologyAgentRuntime } from '../src/agent/astrology-agent-runtime.ts';
import type { ModelProvider, ModelProviderRequest, ProviderDecision } from '../src/providers/model-provider.ts';
import type { ModelProviderResolver } from '../src/providers/provider-registry.ts';

class QueueProvider implements ModelProvider {
  readonly name = 'openrouter';
  readonly model = 'vendor/reasoning';
  requests: ModelProviderRequest[] = [];
  private queue: ProviderDecision[];
  constructor(queue: ProviderDecision[]) { this.queue = [...queue]; }
  async generate(request: ModelProviderRequest): Promise<ProviderDecision> {
    this.requests.push(request);
    const next = this.queue.shift();
    if (!next) throw new Error('no decision');
    return next;
  }
}

test('runtime resolves server model policy per run and enforces its tool/output budget', async () => {
  const db = createTestDatabase();
  const credits = new SqliteCreditRepository(db);
  const runs = new SqliteRunRepository(db);
  const service = new RunService(runs, credits);
  const provider = new QueueProvider([
    { kind: 'astrology_tool', requests: [{ capability: 'you.transit', subjects: ['primary'] }], reason: 'round1', usage: { inputTokens: 1000, outputTokens: 100, reasoningTokens: 0, providerCost: 0.01 } },
    { kind: 'final', text: 'final from existing evidence', usage: { inputTokens: 1200, outputTokens: 200, reasoningTokens: 50, providerCost: 0.02 }, structured: { answer: 'final from existing evidence', keyFactors: [], timingWindows: [], chartRefs: [], limitations: [], followUps: [] } },
  ]);
  const resolver: ModelProviderResolver = {
    resolve(modelId: string) {
      assert.equal(modelId, 'premium');
      return {
        provider,
        policy: {
          id: 'premium', label: 'Premium', provider: 'openrouter', providerModel: 'vendor/reasoning',
          creditsRequired: 3, maxInputTokens: 64000, maxOutputTokens: 1234,
          maxToolRounds: 1, evidenceTargetTokens: 22000, maxProviderCost: 0.2,
          inputCostPerMillion: 1, outputCostPerMillion: 4,
          enabled: true, agentEligible: true,
        },
      };
    },
  };
  service.createRun({
    runId: 'run_model', walletId: null, creditsRequired: 0,
    payload: { question: 'career timing', modelId: 'premium', clientCapabilities: ['you.transit'], draftContext: [] },
  });
  service.startReasoning('run_model');
  const agent = new AstrologyAgentRuntime(service, resolver, { maxToolRounds: 2, maxOutputTokens: 4096 });

  const first = await agent.advance('run_model');
  assert.equal(first.status, 'requires_action');
  service.submitAction('run_model', first.action!.id, { facts: [] });
  const second = await agent.advance('run_model');
  assert.equal(second.status, 'completed');
  assert.equal(provider.requests[1]?.forceFinal, true);
  assert.equal(provider.requests[0]?.maxOutputTokens, 1234);
  assert.equal(service.getRun('run_model').provider, 'openrouter');
  assert.equal(service.getRun('run_model').model, 'vendor/reasoning');
  assert.equal(service.getRun('run_model').inputTokens, 2200);
  assert.equal(service.getRun('run_model').outputTokens, 300);
  assert.equal(service.getRun('run_model').reasoningTokens, 50);
  assert.equal(service.getRun('run_model').providerCost, 0.03);
  assert.equal(provider.requests[1]?.maxInputTokens, 63000);
  assert.equal(provider.requests[1]?.maxProviderCost, 0.19);
});

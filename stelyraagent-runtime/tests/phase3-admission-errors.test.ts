import test from 'node:test';
import assert from 'node:assert/strict';
import { ModelCatalog } from '../src/policy/model-catalog.ts';
import { RunAdmissionPolicy, RunAdmissionError } from '../src/policy/run-admission-policy.ts';

const catalog = new ModelCatalog([{
  id: 'standard', label: 'Standard', provider: 'deepseek', providerModel: 'deepseek-chat',
  creditsRequired: 1, maxInputTokens: 32000, maxOutputTokens: 4096,
  maxToolRounds: 2, evidenceTargetTokens: 16000, maxProviderCost: 0.05,
  inputCostPerMillion: 1, outputCostPerMillion: 4,
  enabled: true, agentEligible: true,
}]);

test('unknown client model becomes a typed admission error instead of an internal server failure', () => {
  const policy = new RunAdmissionPolicy(catalog);
  assert.throws(
    () => policy.admit({ question: 'career', modelId: 'arbitrary/openrouter-model', draftContext: [] }),
    (error: unknown) => error instanceof RunAdmissionError && error.code === 'model_not_available' && error.status === 400,
  );
});

test('explicit generic proxy request becomes a typed out-of-scope response', () => {
  const policy = new RunAdmissionPolicy(catalog);
  assert.throws(
    () => policy.admit({ question: 'Write Python code for a web scraper', modelId: 'standard', draftContext: [] }),
    (error: unknown) => error instanceof RunAdmissionError && error.code === 'out_of_scope' && error.status === 422,
  );
});

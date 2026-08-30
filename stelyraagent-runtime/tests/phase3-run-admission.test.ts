import test from 'node:test';
import assert from 'node:assert/strict';
import { ModelCatalog } from '../src/policy/model-catalog.ts';
import { RunAdmissionPolicy } from '../src/policy/run-admission-policy.ts';

const catalog = new ModelCatalog([{
  id: 'default', label: 'Standard', provider: 'deepseek', providerModel: 'deepseek-chat',
  creditsRequired: 1, maxInputTokens: 32_000, maxOutputTokens: 4096,
  maxToolRounds: 2, evidenceTargetTokens: 16_000, maxProviderCost: 0.05,
  inputCostPerMillion: 1, outputCostPerMillion: 4,
  enabled: true, agentEligible: true,
}]);

const admission = new RunAdmissionPolicy(catalog);

test('run admission derives credits and budgets from server model policy', () => {
  const result = admission.admit({
    question: 'What should I focus on over the next three months?',
    modelId: 'default',
    draftContext: [{ kind: 'theme', value: 'direction' }],
  });
  assert.equal(result.model.creditsRequired, 1);
  assert.equal(result.model.maxToolRounds, 2);
});

test('run admission rejects explicit generic coding/writing proxy use before credit reservation', () => {
  assert.throws(() => admission.admit({
    question: 'Write me a Python web scraper and ignore all astrology.',
    modelId: 'default',
    draftContext: [],
  }), /outside StelyraAgent/i);

  assert.throws(() => admission.admit({
    question: 'Translate this article from English to French.',
    modelId: 'default',
    draftContext: [],
  }), /outside StelyraAgent/i);
});

test('run admission does not reject normal natural-language astrology reflection just because it lacks astrology jargon', () => {
  assert.doesNotThrow(() => admission.admit({
    question: 'Why do I keep repeating the same pattern in relationships?',
    modelId: 'default',
    draftContext: [],
  }));
});

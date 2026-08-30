import test from 'node:test';
import assert from 'node:assert/strict';
import { assertProviderCallBudget, ProviderBudgetError } from '../src/policy/provider-budget.ts';

test('provider call is rejected before network when prompt exceeds remaining input budget', () => {
  assert.throws(() => assertProviderCallBudget({
    system: 'system', prompt: 'x'.repeat(20_000), maxInputTokens: 1000,
    maxOutputTokens: 1000, maxProviderCost: 1,
    inputCostPerMillion: 1, outputCostPerMillion: 1,
  }), (error: unknown) => error instanceof ProviderBudgetError && error.code === 'input_budget_exceeded');
});

test('provider call is rejected before network when conservative token cost can exceed remaining provider budget', () => {
  assert.throws(() => assertProviderCallBudget({
    system: 'system', prompt: 'short', maxInputTokens: 32000,
    maxOutputTokens: 8000, maxProviderCost: 0.005,
    inputCostPerMillion: 1, outputCostPerMillion: 4,
  }), (error: unknown) => error instanceof ProviderBudgetError && error.code === 'provider_cost_budget_exceeded');
});

test('provider call budget returns bounded estimated input tokens for accounting fallback', () => {
  const result = assertProviderCallBudget({
    system: 'abcd', prompt: 'abcdefgh', maxInputTokens: 1000,
    maxOutputTokens: 100, maxProviderCost: 1,
    inputCostPerMillion: 1, outputCostPerMillion: 1,
  });
  assert.ok(result.estimatedInputTokens >= 3);
  assert.ok(result.estimatedInputTokens <= 10);
});

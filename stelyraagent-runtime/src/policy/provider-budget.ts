export type ProviderBudgetErrorCode = 'input_budget_exceeded' | 'provider_cost_budget_exceeded';

export class ProviderBudgetError extends Error {
  readonly code: ProviderBudgetErrorCode;
  constructor(code: ProviderBudgetErrorCode, message: string) {
    super(message);
    this.name = 'ProviderBudgetError';
    this.code = code;
  }
}

export function estimateTextTokens(text: string): number {
  if (!text) return 0;
  return Math.max(1, Math.ceil(text.length / 4));
}

export function assertProviderCallBudget(input: {
  system: string;
  prompt: string;
  maxInputTokens: number;
  maxOutputTokens: number;
  maxProviderCost: number;
  inputCostPerMillion: number;
  outputCostPerMillion: number;
}): { estimatedInputTokens: number; conservativeMaxCost: number } {
  const estimatedInputTokens = estimateTextTokens(input.system) + estimateTextTokens(input.prompt);
  if (estimatedInputTokens > input.maxInputTokens) {
    throw new ProviderBudgetError(
      'input_budget_exceeded',
      `Estimated model input ${estimatedInputTokens} exceeds remaining budget ${input.maxInputTokens}`,
    );
  }
  const conservativeMaxCost = (
    estimatedInputTokens * input.inputCostPerMillion
    + input.maxOutputTokens * input.outputCostPerMillion
  ) / 1_000_000;
  if (conservativeMaxCost > input.maxProviderCost) {
    throw new ProviderBudgetError(
      'provider_cost_budget_exceeded',
      `Conservative provider cost ${conservativeMaxCost.toFixed(6)} exceeds remaining budget ${input.maxProviderCost.toFixed(6)}`,
    );
  }
  return { estimatedInputTokens, conservativeMaxCost };
}

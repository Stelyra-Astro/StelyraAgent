import { ProviderResponseError, type ModelProvider, type ModelProviderRequest, type ProviderDecision, type ProviderUsage } from '../providers/model-provider.ts';
import { ProviderBudgetError } from './provider-budget.ts';
import { OutputValidator, type StructuredFinalAnswer } from './output-validator.ts';

export class PolicyEnforcedProvider implements ModelProvider {
  readonly name: string;
  readonly model: string;
  private readonly delegate: ModelProvider;
  private readonly validator: OutputValidator;

  constructor(delegate: ModelProvider, options: { maxCharacters: number }) {
    this.delegate = delegate;
    this.name = delegate.name;
    this.model = delegate.model;
    this.validator = new OutputValidator(options);
  }

  async generate(request: ModelProviderRequest): Promise<ProviderDecision> {
    let first: ProviderDecision;
    try {
      first = await this.delegate.generate(request);
    } catch (error) {
      if (error instanceof ProviderBudgetError) return fallbackFinal();
      const consumed = error instanceof ProviderResponseError ? error.usage : undefined;
      return this.repairOrFallback(request, normalizeProviderError(error), consumed);
    }

    if (first.kind !== 'final') return first;
    const firstError = this.validationError(first, request);
    if (!firstError) return first;
    return this.repairOrFallback(request, firstError, first.usage);
  }

  private async repairOrFallback(request: ModelProviderRequest, reason: string, consumed?: ProviderUsage): Promise<ProviderDecision> {
    const repairRequest = subtractUsageFromBudget(request, consumed);
    if ((repairRequest.maxInputTokens ?? 1) <= 0 || (repairRequest.maxProviderCost ?? 1) <= 0) {
      return withUsage(fallbackFinal(), consumed);
    }
    try {
      const repaired = await this.delegate.generate({
        ...repairRequest,
        forceFinal: true,
        repairInstruction: `Your previous response was rejected by the server validator: ${reason}. Return one corrected structured final output. Do not add new evidence or tool calls.`,
      });
      const combinedUsage = addUsage(consumed, repaired.usage);
      if (repaired.kind === 'final' && !this.validationError(repaired, request)) return withUsage(repaired, combinedUsage);
      return withUsage(fallbackFinal(), combinedUsage);
    } catch (error) {
      const secondUsage = error instanceof ProviderResponseError ? error.usage : undefined;
      return withUsage(fallbackFinal(), addUsage(consumed, secondUsage));
    }
  }

  private validationError(decision: Extract<ProviderDecision, { kind: 'final' }>, request: ModelProviderRequest): string | null {
    if (!decision.structured) return 'Structured final output is required';
    try {
      this.validator.validate(decision.structured, { allowedEvidenceIds: collectEvidenceIDs(request.actionResults) });
      return null;
    } catch (error) {
      return error instanceof Error ? error.message : 'Final output validation failed';
    }
  }
}

function collectEvidenceIDs(actionResults: Array<Record<string, unknown>>): Set<string> {
  const ids = new Set<string>();
  for (const record of actionResults) {
    const result = asRecord(record.result);
    const facts = Array.isArray(result?.facts) ? result.facts : [];
    for (const raw of facts) {
      const fact = asRecord(raw);
      if (typeof fact?.id === 'string' && fact.id) ids.add(fact.id);
    }
  }
  return ids;
}

function fallbackFinal(): ProviderDecision {
  const structured: StructuredFinalAnswer = {
    answer: 'I could not safely validate the model output for this run. No additional calculation or charge escalation was performed. You can retry the analysis or narrow the question.',
    keyFactors: [],
    timingWindows: [],
    chartRefs: [],
    limitations: ['The generated answer did not satisfy StelyraAgent grounding or safety rules.'],
    followUps: ['Retry this analysis', 'Narrow the question'],
  };
  return { kind: 'final', text: structured.answer, structured, budgetLimited: true };
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return value && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, unknown> : null;
}

function normalizeProviderError(error: unknown): string {
  if (error instanceof Error && error.message) return error.message.slice(0, 500);
  return 'Model response could not be parsed or validated';
}

function subtractUsageFromBudget(request: ModelProviderRequest, usage?: ProviderUsage): ModelProviderRequest {
  if (!usage) return request;
  return {
    ...request,
    maxInputTokens: request.maxInputTokens == null ? undefined : Math.max(0, request.maxInputTokens - usage.inputTokens),
    maxProviderCost: request.maxProviderCost == null ? undefined : Math.max(0, request.maxProviderCost - usage.providerCost),
  };
}

function addUsage(a?: ProviderUsage, b?: ProviderUsage): ProviderUsage | undefined {
  if (!a) return b;
  if (!b) return a;
  return {
    inputTokens: a.inputTokens + b.inputTokens,
    outputTokens: a.outputTokens + b.outputTokens,
    reasoningTokens: a.reasoningTokens + b.reasoningTokens,
    providerCost: a.providerCost + b.providerCost,
  };
}

function withUsage(decision: ProviderDecision, usage?: ProviderUsage): ProviderDecision {
  return usage ? { ...decision, usage } : decision;
}

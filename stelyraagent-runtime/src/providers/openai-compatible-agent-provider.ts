import { createOpenAICompatible } from '@ai-sdk/openai-compatible';
import { generateText } from 'ai';
import { ProviderResponseError, type ModelProvider, type ModelProviderRequest, type ProviderDecision, type ProviderUsage } from './model-provider.ts';
import { parseAgentDecision } from './agent-decision-parser.ts';
import { stelyraAgentSystemPrompt } from './agent-system-prompt.ts';
import { buildPromptEnvelope } from '../policy/prompt-trust.ts';
import { assertProviderCallBudget, estimateTextTokens } from '../policy/provider-budget.ts';

export class OpenAICompatibleAgentProvider implements ModelProvider {
  readonly name: string;
  readonly model: string;
  private readonly client: ReturnType<typeof createOpenAICompatible>;
  private readonly timeoutMs: number;

  constructor(options: { name: string; apiKey: string; model: string; baseURL: string; timeoutMs: number }) {
    this.name = options.name;
    this.model = options.model;
    this.timeoutMs = options.timeoutMs;
    this.client = createOpenAICompatible({ name: options.name, apiKey: options.apiKey, baseURL: options.baseURL });
  }

  async generate(request: ModelProviderRequest): Promise<ProviderDecision> {
    const trustedPolicy = {
      ...(request.orchestrationPolicy ?? {}),
      supported_capabilities: request.clientCapabilities,
      force_final: request.forceFinal,
      repair_instruction: request.repairInstruction ?? null,
    };
    const envelope = buildPromptEnvelope({
      question: request.question,
      draftContext: request.draftContext,
      localMemory: request.localMemory,
      orchestrationPolicy: trustedPolicy,
      actionResults: request.actionResults,
    });
    const prompt = JSON.stringify(envelope);
    const budget = assertProviderCallBudget({
      system: stelyraAgentSystemPrompt,
      prompt,
      maxInputTokens: request.maxInputTokens ?? Number.MAX_SAFE_INTEGER,
      maxOutputTokens: request.maxOutputTokens,
      maxProviderCost: request.maxProviderCost ?? Number.MAX_SAFE_INTEGER,
      inputCostPerMillion: request.inputCostPerMillion ?? 1,
      outputCostPerMillion: request.outputCostPerMillion ?? 1,
    });
    const result = await generateText({
      model: this.client.chatModel(this.model),
      system: stelyraAgentSystemPrompt,
      prompt,
      maxOutputTokens: request.maxOutputTokens,
      timeout: this.timeoutMs,
    });
    const usage = normalizeUsage(result.usage, result.text, budget.estimatedInputTokens, request);
    try {
      return { ...parseAgentDecision(result.text), usage };
    } catch (error) {
      throw new ProviderResponseError(error instanceof Error ? error.message : 'Malformed model response', usage);
    }
  }
}

function normalizeUsage(raw: unknown, text: string, estimatedInputTokens: number, request: ModelProviderRequest): ProviderUsage {
  const usage = raw && typeof raw === 'object' ? raw as Record<string, unknown> : {};
  const inputTokens = finiteToken(usage.inputTokens, estimatedInputTokens);
  const outputTokens = finiteToken(usage.outputTokens, estimateTextTokens(text));
  const reasoningTokens = finiteToken(usage.reasoningTokens, 0);
  const providerCost = (
    inputTokens * (request.inputCostPerMillion ?? 1)
    + outputTokens * (request.outputCostPerMillion ?? 1)
  ) / 1_000_000;
  return { inputTokens, outputTokens, reasoningTokens, providerCost };
}

function finiteToken(value: unknown, fallback: number): number {
  const number = Number(value);
  return Number.isFinite(number) && number >= 0 ? Math.floor(number) : fallback;
}

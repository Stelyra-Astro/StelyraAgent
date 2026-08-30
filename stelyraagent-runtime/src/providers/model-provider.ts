import type { StructuredFinalAnswer } from '../policy/output-validator.ts';

export interface AstrologyEvidenceRequest {
  capability: string;
  subjects: string[];
  time_scope?: Record<string, unknown>;
  locations?: string[];
}

export interface InteractionDecision {
  kind: 'analysis_choice' | 'clarify_intent' | 'required_input' | 'plan_review';
  prompt: string;
  options?: string[];
  fields?: Array<Record<string, unknown>>;
  purpose?: string;
}

export interface ProviderUsage {
  inputTokens: number;
  outputTokens: number;
  reasoningTokens: number;
  providerCost: number;
}

export class ProviderResponseError extends Error {
  readonly usage: ProviderUsage;
  constructor(message: string, usage: ProviderUsage) {
    super(message);
    this.name = 'ProviderResponseError';
    this.usage = usage;
  }
}

type ProviderDecisionCore =
  | {
      kind: 'astrology_tool';
      requests: AstrologyEvidenceRequest[];
      reason: string;
    }
  | {
      kind: 'interaction';
      interaction: InteractionDecision;
    }
  | {
      kind: 'final';
      text: string;
      structured?: StructuredFinalAnswer;
      budgetLimited?: boolean;
      title?: string;
    };

export type ProviderDecision = ProviderDecisionCore & { usage?: ProviderUsage };

export interface ModelProviderRequest {
  runId: string;
  question: string;
  clientCapabilities: string[];
  draftContext: Array<Record<string, unknown>>;
  actionResults: Array<Record<string, unknown>>;
  orchestrationPolicy?: Record<string, unknown>;
  localMemory?: Record<string, unknown> | null;
  forceFinal: boolean;
  maxOutputTokens: number;
  maxInputTokens?: number;
  maxProviderCost?: number;
  inputCostPerMillion?: number;
  outputCostPerMillion?: number;
  repairInstruction?: string;
}

export interface ModelProvider {
  readonly name: string;
  readonly model: string;
  generate(request: ModelProviderRequest): Promise<ProviderDecision>;
}

export type ModelProviderKind = 'deepseek' | 'openrouter';

export interface ModelPolicy {
  id: string;
  label: string;
  provider: ModelProviderKind;
  providerModel: string;
  creditsRequired: number;
  maxInputTokens: number;
  maxOutputTokens: number;
  maxToolRounds: number;
  evidenceTargetTokens: number;
  maxProviderCost: number;
  inputCostPerMillion: number;
  outputCostPerMillion: number;
  enabled: boolean;
  agentEligible: boolean;
}

export class ModelCatalog {
  private readonly byID: Map<string, ModelPolicy>;

  constructor(models: readonly ModelPolicy[]) {
    this.byID = new Map(models.map((model) => [model.id, validateModel(model)]));
  }

  require(id: string): ModelPolicy {
    const model = this.byID.get(id);
    if (!model || !model.enabled || !model.agentEligible) {
      throw new Error(`Model is not available for StelyraAgent: ${id}`);
    }
    return model;
  }

  listPublic(): Array<Pick<ModelPolicy, 'id' | 'label' | 'creditsRequired' | 'maxOutputTokens'>> {
    return [...this.byID.values()]
      .filter((model) => model.enabled && model.agentEligible)
      .map(({ id, label, creditsRequired, maxOutputTokens }) => ({ id, label, creditsRequired, maxOutputTokens }));
  }

  listOperational(): ModelPolicy[] {
    return [...this.byID.values()].map((model) => ({ ...model }));
  }
}

function validateModel(model: ModelPolicy): ModelPolicy {
  if (!model.id.trim() || !model.label.trim() || !model.providerModel.trim()) throw new Error('Model policy requires id, label, and providerModel');
  if (!Number.isInteger(model.creditsRequired) || model.creditsRequired < 1 || model.creditsRequired > 10) throw new Error('Model creditsRequired must be 1-10');
  if (!Number.isInteger(model.maxInputTokens) || model.maxInputTokens < 1_000) throw new Error('Model maxInputTokens is invalid');
  if (!Number.isInteger(model.maxOutputTokens) || model.maxOutputTokens < 256) throw new Error('Model maxOutputTokens is invalid');
  if (!Number.isInteger(model.maxToolRounds) || model.maxToolRounds < 1 || model.maxToolRounds > 4) throw new Error('Model maxToolRounds is invalid');
  if (!Number.isInteger(model.evidenceTargetTokens) || model.evidenceTargetTokens < 1_000) throw new Error('Model evidenceTargetTokens is invalid');
  if (!Number.isFinite(model.maxProviderCost) || model.maxProviderCost <= 0) throw new Error('Model maxProviderCost is invalid');
  if (!Number.isFinite(model.inputCostPerMillion) || model.inputCostPerMillion <= 0) throw new Error('Model inputCostPerMillion is invalid');
  if (!Number.isFinite(model.outputCostPerMillion) || model.outputCostPerMillion <= 0) throw new Error('Model outputCostPerMillion is invalid');
  return { ...model };
}

export function loadModelPolicies(env: NodeJS.ProcessEnv = process.env): ModelPolicy[] {
  const raw = env.MODEL_CATALOG_JSON?.trim();
  if (!raw) {
    return [validateModel({
      id: 'standard',
      label: 'Standard',
      provider: 'deepseek',
      providerModel: env.DEEPSEEK_MODEL?.trim() || 'deepseek-chat',
      creditsRequired: 1,
      maxInputTokens: 32_000,
      maxOutputTokens: 4_096,
      maxToolRounds: 2,
      evidenceTargetTokens: 16_000,
      maxProviderCost: 0.05,
      inputCostPerMillion: 1,
      outputCostPerMillion: 4,
      enabled: true,
      agentEligible: true,
    })];
  }
  let parsed: unknown;
  try { parsed = JSON.parse(raw); } catch { throw new Error('MODEL_CATALOG_JSON must be valid JSON'); }
  if (!Array.isArray(parsed) || parsed.length === 0) throw new Error('MODEL_CATALOG_JSON must contain at least one model');
  return parsed.map((value) => {
    if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('MODEL_CATALOG_JSON entries must be objects');
    const item = value as Record<string, unknown>;
    if (item.provider !== 'deepseek' && item.provider !== 'openrouter') throw new Error('Model provider must be deepseek or openrouter');
    return validateModel({
      id: String(item.id ?? ''),
      label: String(item.label ?? ''),
      provider: item.provider,
      providerModel: String(item.providerModel ?? ''),
      creditsRequired: Number(item.creditsRequired),
      maxInputTokens: Number(item.maxInputTokens),
      maxOutputTokens: Number(item.maxOutputTokens),
      maxToolRounds: Number(item.maxToolRounds),
      evidenceTargetTokens: Number(item.evidenceTargetTokens),
      maxProviderCost: Number(item.maxProviderCost),
      inputCostPerMillion: Number(item.inputCostPerMillion),
      outputCostPerMillion: Number(item.outputCostPerMillion),
      enabled: item.enabled !== false,
      agentEligible: item.agentEligible !== false,
    });
  });
}

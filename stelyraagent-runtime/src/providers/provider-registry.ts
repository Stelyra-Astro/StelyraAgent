import type { ModelPolicy } from '../policy/model-catalog.ts';
import type { ModelProvider } from './model-provider.ts';

export interface ResolvedModelProvider {
  provider: ModelProvider;
  policy: ModelPolicy;
}

export interface ModelProviderResolver {
  resolve(modelId: string): ResolvedModelProvider;
}

export class ProviderRegistry implements ModelProviderResolver {
  private readonly entries: Map<string, ResolvedModelProvider>;

  constructor(entries: Array<{ modelId: string; provider: ModelProvider; policy: ModelPolicy }>) {
    this.entries = new Map(entries.map(({ modelId, provider, policy }) => [modelId, { provider, policy }]));
  }

  resolve(modelId: string): ResolvedModelProvider {
    const entry = this.entries.get(modelId);
    if (!entry || !entry.policy.enabled || !entry.policy.agentEligible) throw new Error(`Model is not available for StelyraAgent: ${modelId}`);
    return entry;
  }
}

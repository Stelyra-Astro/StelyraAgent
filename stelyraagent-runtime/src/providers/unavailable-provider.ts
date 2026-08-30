import type { ModelProvider, ModelProviderRequest, ProviderDecision } from './model-provider.ts';

export class UnavailableProvider implements ModelProvider {
  readonly name: string;
  readonly model: string;

  constructor(name = 'unavailable', model = 'unconfigured') {
    this.name = name;
    this.model = model;
  }

  async generate(_request: ModelProviderRequest): Promise<ProviderDecision> {
    throw new Error(`LLM provider is not configured for ${this.name}/${this.model}`);
  }
}

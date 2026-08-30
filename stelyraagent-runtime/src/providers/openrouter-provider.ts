import type { ModelProvider, ModelProviderRequest, ProviderDecision } from './model-provider.ts';
import { OpenAICompatibleAgentProvider } from './openai-compatible-agent-provider.ts';

export class OpenRouterProvider implements ModelProvider {
  readonly name = 'openrouter';
  readonly model: string;
  private readonly delegate: OpenAICompatibleAgentProvider;

  constructor(options: { apiKey: string; model: string; baseURL?: string; timeoutMs?: number }) {
    this.model = options.model;
    this.delegate = new OpenAICompatibleAgentProvider({
      name: 'openrouter',
      apiKey: options.apiKey,
      model: this.model,
      baseURL: options.baseURL ?? 'https://openrouter.ai/api/v1',
      timeoutMs: options.timeoutMs ?? 60_000,
    });
  }

  generate(request: ModelProviderRequest): Promise<ProviderDecision> { return this.delegate.generate(request); }
}

import type { ModelProvider, ModelProviderRequest, ProviderDecision } from './model-provider.ts';
import { OpenAICompatibleAgentProvider } from './openai-compatible-agent-provider.ts';

export class DeepSeekProvider implements ModelProvider {
  readonly name = 'deepseek';
  readonly model: string;
  private readonly delegate: OpenAICompatibleAgentProvider;

  constructor(options: { apiKey: string; model?: string; baseURL?: string; timeoutMs?: number }) {
    this.model = options.model ?? 'deepseek-chat';
    this.delegate = new OpenAICompatibleAgentProvider({
      name: 'deepseek',
      apiKey: options.apiKey,
      model: this.model,
      baseURL: options.baseURL ?? 'https://api.deepseek.com/v1',
      timeoutMs: options.timeoutMs ?? 60_000,
    });
  }

  generate(request: ModelProviderRequest): Promise<ProviderDecision> { return this.delegate.generate(request); }
}

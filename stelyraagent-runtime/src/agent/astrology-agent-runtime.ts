import { randomUUID } from 'node:crypto';
import type { ModelProvider, ProviderDecision } from '../providers/model-provider.ts';
import type { ModelProviderResolver } from '../providers/provider-registry.ts';
import type { ModelPolicy } from '../policy/model-catalog.ts';
import type { RunService, RuntimeAction } from '../run/run-service.ts';
import { AnalysisPlanCompiler, type DraftContextValue } from './analysis-plan-compiler.ts';
import { EvidenceRoundPolicy } from '../planning/evidence-round-policy.ts';
import { ThemePolicyCatalog } from '../themes/theme-policy.ts';
import { capabilityPolicy } from '../capabilities/catalog.ts';

export interface AgentRuntimeOptions {
  maxToolRounds: number;
  maxOutputTokens?: number;
  evidenceTargetTokens?: number;
  finalizationReserveTokens?: number;
}

export interface AgentAdvanceResult {
  status: 'requires_action' | 'completed';
  action?: RuntimeAction;
}

export class AstrologyAgentRuntime {
  private readonly runs: RunService;
  private readonly provider: ModelProvider | null;
  private readonly providerResolver: ModelProviderResolver | null;
  private readonly compiler: AnalysisPlanCompiler;
  private readonly evidenceRounds = new EvidenceRoundPolicy();
  private readonly themes = new ThemePolicyCatalog();
  private readonly options: Required<AgentRuntimeOptions>;

  constructor(
    runs: RunService,
    provider: ModelProvider | ModelProviderResolver,
    options: AgentRuntimeOptions,
    compiler = new AnalysisPlanCompiler(),
  ) {
    this.runs = runs;
    if ('generate' in provider && typeof provider.generate === 'function') {
      this.provider = provider as ModelProvider;
      this.providerResolver = null;
    } else {
      this.provider = null;
      this.providerResolver = provider as ModelProviderResolver;
    }
    this.compiler = compiler;
    this.options = {
      maxToolRounds: options.maxToolRounds,
      maxOutputTokens: options.maxOutputTokens ?? 4096,
      evidenceTargetTokens: options.evidenceTargetTokens ?? 16_000,
      finalizationReserveTokens: options.finalizationReserveTokens ?? 2_000,
    };
  }

  async advance(runId: string): Promise<AgentAdvanceResult> {
    const run = this.runs.getRun(runId);
    if (!['reasoning', 'resuming'].includes(run.status)) {
      throw new Error(`Run cannot advance from status ${run.status}`);
    }

    const payload = run.payload ?? {};
    const question = typeof payload.question === 'string' ? payload.question : '';
    const clientCapabilities = Array.isArray(payload.clientCapabilities)
      ? payload.clientCapabilities.filter((v): v is string => typeof v === 'string')
      : [];
    const draftContext = Array.isArray(payload.draftContext)
      ? payload.draftContext.filter(isDraftContextValue)
      : [];
    const actionResults = Array.isArray(payload.actionResults)
      ? payload.actionResults.filter((v): v is Record<string, unknown> => !!v && typeof v === 'object')
      : [];
    const creditsRequired = typeof payload.creditsRequired === 'number' ? payload.creditsRequired : 1;
    const localMemory = asRecord(payload.localMemory);

    const selection = this.resolveProvider(payload);
    const provider = selection.provider;
    const limits = selection.policy;
    this.runs.recordProvider(runId, provider.name, provider.model);

    const request = {
      runId,
      question,
      clientCapabilities,
      draftContext,
      actionResults,
      orchestrationPolicy: this.buildOrchestrationPolicy(draftContext, clientCapabilities, limits),
      localMemory,
      forceFinal: run.toolRounds >= limits.maxToolRounds,
      maxOutputTokens: limits.maxOutputTokens,
      maxInputTokens: Math.max(0, limits.maxInputTokens - run.inputTokens),
      maxProviderCost: Math.max(0, limits.maxProviderCost - run.providerCost),
      inputCostPerMillion: limits.inputCostPerMillion,
      outputCostPerMillion: limits.outputCostPerMillion,
    };

    let decision = await provider.generate(request);
    if (decision.usage) this.runs.recordUsage(runId, decision.usage);

    if (decision.kind === 'astrology_tool' && run.toolRounds >= limits.maxToolRounds) {
      try {
        decision = await provider.generate({ ...request, forceFinal: true });
        if (decision.usage) this.runs.recordUsage(runId, decision.usage);
      } catch {
        decision = this.fallbackBudgetFinal();
      }
      if (decision.kind !== 'final') {
        decision = this.fallbackBudgetFinal();
      }
    }

    return this.applyDecision(
      runId,
      decision,
      clientCapabilities,
      draftContext,
      actionResults,
      creditsRequired,
      question,
      run.toolRounds,
    );
  }

  private applyDecision(
    runId: string,
    decision: ProviderDecision,
    clientCapabilities: string[],
    draftContext: DraftContextValue[],
    actionResults: Array<Record<string, unknown>>,
    creditsRequired: number,
    question: string,
    toolRounds: number,
  ): AgentAdvanceResult {
    if (decision.kind === 'final') {
      this.runs.complete(runId, {
        text: decision.text,
        structured: decision.structured ?? null,
        title: decision.title ?? null,
        budgetLimited: decision.budgetLimited ?? false,
      });
      return { status: 'completed' };
    }

    if (decision.kind === 'interaction') {
      return this.requireInteraction(runId, decision.interaction);
    }

    const compiled = this.compiler.compile({
      question,
      clientCapabilities,
      draftContext,
      candidateRequests: decision.requests,
      actionResults,
      creditsRequired,
    });
    if (compiled.kind === 'interaction') {
      return this.requireInteraction(runId, compiled.interaction);
    }

    this.evidenceRounds.assertAllowed({
      round: toolRounds + 1,
      actionResults,
      requests: compiled.requests,
    });

    const action: RuntimeAction = {
      id: randomUUID(),
      type: 'astrology_tool',
      tool: 'request_astrology_evidence',
      payload: {
        requests: compiled.requests,
        reason: decision.reason,
        evidence_round: toolRounds + 1,
      },
    };
    this.runs.requireAction(runId, action);
    return { status: 'requires_action', action };
  }

  private requireInteraction(
    runId: string,
    interaction: Extract<ProviderDecision, { kind: 'interaction' }>['interaction'],
  ): AgentAdvanceResult {
    const action: RuntimeAction = {
      id: randomUUID(),
      type: 'interaction',
      payload: { interaction },
    };
    this.runs.requireAction(runId, action);
    return { status: 'requires_action', action };
  }

  private buildOrchestrationPolicy(
    draftContext: DraftContextValue[],
    clientCapabilities: string[],
    limits: Pick<ModelPolicy, 'evidenceTargetTokens' | 'maxToolRounds' | 'maxInputTokens' | 'maxOutputTokens' | 'maxProviderCost' | 'inputCostPerMillion' | 'outputCostPerMillion'>,
  ): Record<string, unknown> {
    const themeChip = draftContext.find((item) => item.kind === 'theme');
    let theme = undefined as ReturnType<ThemePolicyCatalog['definition']> | undefined;
    if (themeChip && typeof themeChip.value === 'string') theme = this.themes.definition(themeChip.value);
    if (!theme && themeChip && typeof themeChip.title === 'string') {
      theme = this.themes.definition(themeChip.title.replace(/^Theme\s*·\s*/i, '').trim());
    }
    return {
      theme: theme ? {
        id: theme.id,
        title: theme.title,
        people: theme.people,
        reportSections: theme.reportSections,
        safetyBoundary: theme.safetyBoundary ?? null,
        allowedCapabilities: [...this.themes.allowedAutonomousCapabilities(theme.id)],
      } : null,
      capabilityPolicies: clientCapabilities
        .map((id) => capabilityPolicy(id))
        .filter((value): value is NonNullable<typeof value> => !!value)
        .map((value) => ({
          id: value.id,
          autonomy: value.agentAutonomy,
          userSelectable: value.userSelectable,
          defaultThemeRecipe: value.defaultThemeRecipe,
        })),
      evidence: {
        targetTokens: limits.evidenceTargetTokens,
        finalizationReserveTokens: this.options.finalizationReserveTokens,
        maxLocalRounds: limits.maxToolRounds,
        maxInputTokens: limits.maxInputTokens,
        maxOutputTokens: limits.maxOutputTokens,
        maxProviderCost: limits.maxProviderCost,
        inputCostPerMillion: limits.inputCostPerMillion,
        outputCostPerMillion: limits.outputCostPerMillion,
      },
    };
  }


  private resolveProvider(payload: Record<string, unknown>): { provider: ModelProvider; policy: ModelPolicy } {
    if (this.providerResolver) {
      const modelId = typeof payload.modelId === 'string' ? payload.modelId : '';
      if (!modelId) throw new Error('Run is missing server-selected model policy');
      return this.providerResolver.resolve(modelId);
    }
    if (!this.provider) throw new Error('No model provider configured');
    return {
      provider: this.provider,
      policy: {
        id: 'legacy-static', label: 'Legacy Static', provider: 'deepseek', providerModel: this.provider.model,
        creditsRequired: 1, maxInputTokens: 32_000, maxOutputTokens: this.options.maxOutputTokens,
        maxToolRounds: this.options.maxToolRounds, evidenceTargetTokens: this.options.evidenceTargetTokens,
        maxProviderCost: 1, inputCostPerMillion: 1, outputCostPerMillion: 4, enabled: true, agentEligible: true,
      },
    };
  }

  private fallbackBudgetFinal(): ProviderDecision {
    return {
      kind: 'final',
      budgetLimited: true,
      text: 'This run reached its analysis budget before another calculation round could be completed. I am finalizing with the evidence already collected; you can continue with another Credit if you want a deeper drill-down.',
    };
  }
}

function isDraftContextValue(value: unknown): value is DraftContextValue {
  return !!value && typeof value === 'object';
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

import { SERVER_CAPABILITY_CATALOG, allowedCapabilities, canAgentAutonomouslySelect } from '../capabilities/catalog.ts';
import type { AstrologyEvidenceRequest, InteractionDecision } from '../providers/model-provider.ts';
import { ResolutionPolicy, type ResolutionDetail } from '../planning/resolution-policy.ts';
import { ThemePolicyCatalog } from '../themes/theme-policy.ts';
import { ScopePolicy } from '../policy/scope-policy.ts';

export interface DraftContextValue extends Record<string, unknown> {
  kind?: unknown;
  value?: unknown;
  title?: unknown;
}

export type CompiledAnalysisPlan =
  | { kind: 'requests'; requests: AstrologyEvidenceRequest[] }
  | { kind: 'interaction'; interaction: InteractionDecision };

export class AnalysisPlanCompiler {
  private readonly themes = new ThemePolicyCatalog();
  private readonly resolutions = new ResolutionPolicy();
  private readonly scope: ScopePolicy;
  private readonly serverCapabilities: readonly string[];

  constructor(scope = new ScopePolicy(), serverCapabilities: readonly string[] = SERVER_CAPABILITY_CATALOG) {
    this.scope = scope;
    this.serverCapabilities = serverCapabilities;
  }

  compile(input: {
    question?: string;
    clientCapabilities: string[];
    draftContext: DraftContextValue[];
    candidateRequests: AstrologyEvidenceRequest[];
    actionResults?: Array<Record<string, unknown>>;
    creditsRequired?: number;
  }): CompiledAnalysisPlan {
    const allowed = allowedCapabilities(input.clientCapabilities, this.serverCapabilities);
    const selectedCharts = unique(values(input.draftContext, 'chart'));
    const selectedPeople = unique(values(input.draftContext, 'person'));
    const selectedTheme = resolveSelectedTheme(input.draftContext, this.themes);
    const approvedReview = hasApprovedPlanReview(input.actionResults ?? []);

    for (const request of input.candidateRequests) {
      if (!allowed.has(request.capability)) {
        throw new Error(`Capability ${request.capability} is not available for this client`);
      }
      const explicit = selectedCharts.includes(request.capability);
      if (!explicit && selectedTheme) {
        const themeAllowed = this.themes.allowedAutonomousCapabilities(selectedTheme.id);
        if (!themeAllowed.has(request.capability)) {
          throw new Error(`Capability ${request.capability} is not allowed by Theme Policy for ${selectedTheme.title}`);
        }
      }
      if (!explicit && !canAgentAutonomouslySelect(request.capability, { conditionalAllowed: approvedReview })) {
        if (!approvedReview) {
          return this.planReview(
            input.candidateRequests,
            input.creditsRequired ?? 1,
            'This analysis includes an advanced or conditional chart and needs your confirmation.',
          );
        }
      }
    }
    for (const capability of selectedCharts) {
      if (!allowed.has(capability)) {
        throw new Error(`Capability ${capability} is not available for this client`);
      }
      if (!canAgentAutonomouslySelect(capability, { explicit: true })) {
        throw new Error(`Capability ${capability} is not user-selectable`);
      }
    }

    const themeRequests = selectedTheme && selectedCharts.length === 0
      ? buildThemeRequests({
          theme: selectedTheme,
          themes: this.themes,
          question: input.question ?? '',
          selectedPeople,
          candidateRequests: input.candidateRequests,
          allowed,
        })
      : input.candidateRequests;

    if (selectedCharts.some(isRelationshipCapability) && relationshipSubjects(selectedPeople) === null) {
      return {
        kind: 'interaction',
        interaction: {
          kind: 'required_input',
          prompt: 'Choose the other person required for this relationship chart.',
          fields: [{ id: 'person', type: 'profile', label: 'Person', required: true }],
        },
      };
    }

    let compiledRequests: AstrologyEvidenceRequest[];
    if (selectedCharts.length === 0) {
      compiledRequests = dedupeRequests(themeRequests);
    } else {
      const selectedRequests: AstrologyEvidenceRequest[] = selectedCharts.map((capability) => {
        const proposed = themeRequests.find((request) => request.capability === capability) ?? input.candidateRequests.find((request) => request.capability === capability);
        const subjects = isRelationshipCapability(capability)
          ? relationshipSubjects(selectedPeople)!
          : selectedPeople.length > 0
            ? [selectedPeople[0]!]
            : proposed?.subjects?.length
              ? proposed.subjects
              : ['primary'];
        return {
          ...(proposed ?? {}),
          capability,
          subjects,
        };
      });

      const extras = themeRequests.filter(
        (request) => !selectedCharts.includes(request.capability),
      );
      compiledRequests = dedupeRequests([...selectedRequests, ...extras]);
    }

    const resolutionChoice = extractResolutionChoice(input.actionResults ?? []);
    if (requiresResolutionChoice(input.question ?? '', compiledRequests) && !resolutionChoice) {
      return {
        kind: 'interaction',
        interaction: {
          kind: 'analysis_choice',
          purpose: 'resolution',
          prompt: 'How precise should the timing search be?',
          options: ['Overview', 'Balanced', 'Detailed', 'Major Windows Only'],
        },
      };
    }
    if (resolutionChoice) {
      compiledRequests = compiledRequests.map((request) => applyResolution(request, resolutionChoice, this.resolutions));
    } else {
      compiledRequests = compiledRequests.map((request) => applyDefaultResolution(request, this.resolutions));
    }

    const autonomousExpansion = compiledRequests.some(
      (request) => !selectedCharts.includes(request.capability),
    );
    const userExplicitlySelectedAll = selectedCharts.length >= compiledRequests.length
      && compiledRequests.every((request) => selectedCharts.includes(request.capability));
    const needsReview = compiledRequests.length >= 2
      && !selectedTheme
      && !userExplicitlySelectedAll
      && (selectedCharts.length === 0 || autonomousExpansion)
      && !approvedReview;

    if (needsReview) {
      return this.planReview(compiledRequests, input.creditsRequired ?? 1);
    }

    const themeAuthorized = selectedTheme
      ? [...this.themes.allowedAutonomousCapabilities(selectedTheme.id)]
      : [];
    this.scope.assertRequestsAllowed(compiledRequests, {
      explicitCapabilities: unique([...selectedCharts, ...themeAuthorized]),
    });

    return { kind: 'requests', requests: compiledRequests };
  }

  private planReview(
    requests: AstrologyEvidenceRequest[],
    credits: number,
    lead = 'Review this analysis plan before local calculation.',
  ): CompiledAnalysisPlan {
    const creditText = `${credits} Credit${credits === 1 ? '' : 's'}`;
    return {
      kind: 'interaction',
      interaction: {
        kind: 'plan_review',
        prompt: [
          lead,
          `Charts: ${requests.map((request) => capabilityTitle(request.capability)).join(' + ')}`,
          creditText,
        ].join('\n'),
      },
    };
  }
}

function values(context: DraftContextValue[], kind: string): string[] {
  return context
    .filter((item) => item.kind === kind && typeof item.value === 'string')
    .map((item) => String(item.value));
}

function unique(values: string[]): string[] { return [...new Set(values)]; }
function isRelationshipCapability(capability: string): boolean { return capability.startsWith('relationship.'); }

function relationshipSubjects(selectedPeople: string[]): string[] | null {
  const people = unique(selectedPeople);
  if (people.length >= 2) return people.slice(0, 2);
  if (people.length === 1 && people[0] !== 'primary') return ['primary', people[0]!];
  return null;
}

function dedupeRequests(requests: AstrologyEvidenceRequest[]): AstrologyEvidenceRequest[] {
  const seen = new Set<string>();
  const result: AstrologyEvidenceRequest[] = [];
  for (const request of requests) {
    const key = JSON.stringify({
      capability: request.capability,
      subjects: request.subjects,
      time_scope: request.time_scope ?? null,
      locations: request.locations ?? null,
    });
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(request);
  }
  return result;
}

function hasApprovedPlanReview(actionResults: Array<Record<string, unknown>>): boolean {
  return actionResults.some((record) => {
    const action = asRecord(record.action);
    const payload = asRecord(action?.payload);
    const interaction = asRecord(payload?.interaction);
    const result = asRecord(record.result);
    return interaction?.kind === 'plan_review' && result?.approved === true;
  });
}

function resolveSelectedTheme(context: DraftContextValue[], themes: ThemePolicyCatalog) {
  const chip = context.find((item) => item.kind === 'theme');
  if (!chip) return undefined;
  if (typeof chip.value === 'string') {
    const byID = themes.definition(chip.value);
    if (byID) return byID;
  }
  if (typeof chip.title === 'string') {
    const title = chip.title.replace(/^Theme\s*·\s*/i, '').trim();
    return themes.definition(title);
  }
  return undefined;
}

function requiresResolutionChoice(question: string, requests: AstrologyEvidenceRequest[]): boolean {
  if (!requests.some(hasRangeWithoutResolution)) return false;
  const q = question.toLowerCase();
  return /\bwhen\b|best time|best date|which day|which week|which month|key window|timing|什么时候|哪一天|哪一周|哪个月份|最佳时间|最适合|关键窗口/.test(q);
}

function hasRangeWithoutResolution(request: AstrologyEvidenceRequest): boolean {
  const scope = request.time_scope;
  return !!scope && typeof scope.start === 'string' && typeof scope.end === 'string' && typeof scope.resolution !== 'string';
}

function extractResolutionChoice(actionResults: Array<Record<string, unknown>>): ResolutionDetail | null {
  for (const record of actionResults) {
    const action = asRecord(record.action);
    const payload = asRecord(action?.payload);
    const interaction = asRecord(payload?.interaction);
    if (interaction?.kind !== 'analysis_choice' || interaction?.purpose !== 'resolution') continue;
    const result = asRecord(record.result);
    const raw = result?.selection ?? result?.value;
    if (typeof raw !== 'string') continue;
    switch (raw.toLowerCase()) {
      case 'overview': return 'overview';
      case 'balanced': return 'balanced';
      case 'detailed': return 'detailed';
      case 'major windows only': return 'major_windows';
    }
  }
  return null;
}

function applyResolution(request: AstrologyEvidenceRequest, detail: ResolutionDetail, policy: ResolutionPolicy): AstrologyEvidenceRequest {
  const scope = request.time_scope;
  if (!scope || typeof scope.start !== 'string' || typeof scope.end !== 'string') return request;
  const start = Date.parse(scope.start);
  const end = Date.parse(scope.end);
  if (!Number.isFinite(start) || !Number.isFinite(end) || end <= start) return request;
  const spanMs = end - start;
  const thirtyYears = 30 * 365 * 86_400_000;
  const decision = spanMs > thirtyYears
    ? policy.resolve({ spanMs, detail: 'major_windows' })
    : policy.resolve({ spanMs, detail });
  return { ...request, time_scope: { ...scope, resolution: decision.label } };
}

function applyDefaultResolution(request: AstrologyEvidenceRequest, policy: ResolutionPolicy): AstrologyEvidenceRequest {
  const scope = request.time_scope;
  if (!scope || typeof scope.resolution === 'string' || typeof scope.start !== 'string' || typeof scope.end !== 'string') return request;
  const start = Date.parse(scope.start);
  const end = Date.parse(scope.end);
  if (!Number.isFinite(start) || !Number.isFinite(end) || end <= start) return request;
  const spanMs = end - start;
  const tenYears = 10 * 365 * 86_400_000;
  const decision = policy.resolve({ spanMs, detail: spanMs > tenYears ? 'major_windows' : 'balanced' });
  return { ...request, time_scope: { ...scope, resolution: decision.label } };
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return value && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, unknown> : null;
}

function buildThemeRequests(input: {
  theme: NonNullable<ReturnType<ThemePolicyCatalog['definition']>>;
  themes: ThemePolicyCatalog;
  question: string;
  selectedPeople: string[];
  candidateRequests: AstrologyEvidenceRequest[];
  allowed: Set<string>;
}): AstrologyEvidenceRequest[] {
  const horizon = inferThemeHorizon(input.question, input.candidateRequests);
  const nonPrimaryPeople = unique(input.selectedPeople.filter((person) => person !== 'primary'));
  const specificRelationship = input.theme.id === 'love' && nonPrimaryPeople.length > 0;
  const recipe = input.themes.recipe({
    theme: input.theme.title,
    horizon,
    mode: input.theme.id === 'love' ? (specificRelationship ? 'specific_relationship' : 'my_love_life') : undefined,
    familyMemberCount: input.theme.id === 'family' ? Math.min(3, nonPrimaryPeople.length) : undefined,
  });
  const template = input.candidateRequests.find((request) => request.time_scope) ?? input.candidateRequests[0];
  const relationshipPeople = specificRelationship ? ['primary', nonPrimaryPeople[0]!] : null;
  const requests: AstrologyEvidenceRequest[] = [];

  for (const capability of recipe.capabilities) {
    if (!input.allowed.has(capability)) {
      throw new Error(`Theme recipe capability ${capability} is not available for this client`);
    }
    const subjects = isRelationshipCapability(capability)
      ? relationshipPeople ?? relationshipSubjects(input.selectedPeople) ?? ['primary']
      : ['primary'];
    requests.push(themeRequest(capability, subjects, template));
  }

  for (const capability of recipe.relationshipPerMemberCapabilities ?? []) {
    if (!input.allowed.has(capability)) {
      throw new Error(`Theme recipe capability ${capability} is not available for this client`);
    }
    for (const person of nonPrimaryPeople.slice(0, 3)) {
      requests.push(themeRequest(capability, ['primary', person], template));
    }
  }
  return dedupeRequests(requests);
}

function themeRequest(
  capability: string,
  subjects: string[],
  template?: AstrologyEvidenceRequest,
): AstrologyEvidenceRequest {
  const request: AstrologyEvidenceRequest = { capability, subjects };
  if (template?.time_scope && themeCapabilityUsesTime(capability)) request.time_scope = { ...template.time_scope };
  if (template?.locations?.length && themeCapabilityUsesLocation(capability)) request.locations = [...template.locations];
  return request;
}

function themeCapabilityUsesTime(capability: string): boolean {
  return !['you.natal', 'relationship.synastry', 'relationship.composite', 'relationship.davison', 'relationship.marks'].includes(capability);
}

function themeCapabilityUsesLocation(capability: string): boolean {
  return [
    'you.transit', 'you.solar_return', 'you.lunar_return', 'you.current_sky', 'you.relocation',
    'relationship.composite_transit', 'relationship.davison_transit',
  ].includes(capability);
}

function inferThemeHorizon(question: string, requests: AstrologyEvidenceRequest[]): 'now' | 'three_months' | 'six_months' | 'one_year' {
  const q = question.toLowerCase();
  if (/\b(1|one)\s*year\b|\b12\s*months?\b|未来一年|明年/.test(q)) return 'one_year';
  if (/\b6\s*months?\b|six months|半年/.test(q)) return 'six_months';
  if (/\b3\s*months?\b|three months|三个月|3个月/.test(q)) return 'three_months';
  const ranged = requests.map((request) => request.time_scope).find((scope) =>
    scope && typeof scope.start === 'string' && typeof scope.end === 'string'
  );
  if (!ranged || typeof ranged.start !== 'string' || typeof ranged.end !== 'string') return 'now';
  const start = Date.parse(ranged.start);
  const end = Date.parse(ranged.end);
  if (!Number.isFinite(start) || !Number.isFinite(end) || end <= start) return 'now';
  const days = (end - start) / 86_400_000;
  if (days <= 45) return 'now';
  if (days <= 120) return 'three_months';
  if (days <= 240) return 'six_months';
  return 'one_year';
}

function capabilityTitle(capability: string): string {
  const titles: Record<string, string> = {
    'you.natal': 'Natal', 'you.transit': 'Transit', 'you.secondary': 'Secondary', 'you.tertiary': 'Tertiary',
    'you.solar_arc': 'Solar Arc', 'you.solar_return': 'Solar Return', 'you.lunar_return': 'Lunar Return',
    'you.current_sky': 'Current Sky', 'you.relocation': 'Relocation', 'you.harmonic_12': 'Harmonic 12', 'you.harmonic_13': 'Harmonic 13',
    'relationship.synastry': 'Synastry', 'relationship.composite': 'Composite', 'relationship.composite_transit': 'Relationship Transit',
    'relationship.composite_secondary_compare': 'Composite Secondary Compare', 'relationship.composite_tertiary_compare': 'Composite Tertiary Compare',
    'relationship.davison': 'Davison', 'relationship.davison_transit': 'Davison Transit', 'relationship.davison_secondary': 'Davison Secondary',
    'relationship.davison_tertiary': 'Davison Tertiary', 'relationship.marks': 'Marks', 'relationship.marks_secondary': 'Marks Secondary', 'relationship.marks_tertiary': 'Marks Tertiary',
  };
  return titles[capability] ?? capability;
}

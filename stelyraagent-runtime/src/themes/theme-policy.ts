export type ThemeHorizon = 'now' | 'three_months' | 'six_months' | 'one_year';
export type LoveAnalysisMode = 'my_love_life' | 'specific_relationship';

export interface ThemeRecipeInput {
  theme: string;
  horizon: ThemeHorizon;
  mode?: LoveAnalysisMode;
  familyMemberCount?: number;
}

export interface ThemeRecipe {
  theme: string;
  horizon: ThemeHorizon;
  capabilities: string[];
  relationshipPerMemberCapabilities?: string[];
}

export interface ThemeDefinition {
  id: string;
  title: string;
  people: { min: number; max: number };
  reportSections: readonly string[];
  safetyBoundary?: string;
}

const SINGLE_NOW = ['you.natal', 'you.transit', 'you.tertiary'];
const SINGLE_3M = ['you.natal', 'you.transit', 'you.tertiary', 'you.secondary'];
const SINGLE_6M = ['you.natal', 'you.transit', 'you.secondary', 'you.solar_arc'];
const SINGLE_1Y = ['you.natal', 'you.transit', 'you.secondary', 'you.solar_arc', 'you.solar_return'];

const definitions: readonly ThemeDefinition[] = [
  { id: 'love', title: 'Love & Relationships', people: { min: 1, max: 2 }, reportSections: ['The Core Dynamic', 'Emotional Connection', 'Communication', 'Attraction & Intimacy', 'Stability & Tension', 'Current Phase', 'What Is Changing', 'The Period Ahead'] },
  { id: 'career', title: 'Career & Purpose', people: { min: 1, max: 1 }, reportSections: ['Your Work & Purpose Pattern', 'Where You Are Now', 'Strengths & Contribution', 'Pressure & Friction', 'Direction & Opportunity', 'What Is Changing', 'The Period Ahead', 'Practical Focus'], safetyBoundary: 'Do not guarantee promotions, layoffs, offers, or other outcomes.' },
  { id: 'money', title: 'Money & Growth', people: { min: 1, max: 1 }, reportSections: ['Your Relationship With Resources', 'Current Resource Climate', 'Growth & Opportunity', 'Security & Pressure', 'Priorities & Trade-offs', 'What Is Changing', 'The Period Ahead'], safetyBoundary: 'Do not provide specific investment, trading, lending, or deterministic wealth advice.' },
  { id: 'family', title: 'Family & Home', people: { min: 1, max: 4 }, reportSections: ['Your Family & Home Pattern', 'Belonging & Roots', 'Emotional Climate', 'Communication & Boundaries', 'Home & Stability', 'What Is Changing', 'The Period Ahead'] },
  { id: 'self', title: 'Self & Wellbeing', people: { min: 1, max: 1 }, reportSections: ['Your Inner Climate', 'Emotional Needs', 'Energy & Vitality', 'Stress & Recovery', 'Your Relationship With Yourself', 'What Is Changing', 'The Period Ahead'], safetyBoundary: 'Do not diagnose medical or mental-health conditions or recommend treatment.' },
  { id: 'creativity', title: 'Creativity & Expression', people: { min: 1, max: 1 }, reportSections: ['Your Creative Signature', 'Voice & Expression', 'Current Spark', 'Projects & Momentum', 'Blocks & Pressure', 'What Is Changing', 'The Period Ahead'] },
  { id: 'learning', title: 'Learning & Exploration', people: { min: 1, max: 1 }, reportSections: ['How You Learn & Explore', 'Current Curiosity', 'Study & Skill Growth', 'Travel & New Perspectives', 'Momentum & Friction', 'What Is Changing', 'The Period Ahead'] },
  { id: 'direction', title: 'Life Direction', people: { min: 1, max: 1 }, reportSections: ['Your Current Chapter', 'Identity & Inner Direction', 'What Is Changing', 'Areas of Growth', 'Pressure & Transition', 'What Deserves Attention', 'The Period Ahead'] },
] as const;

export class ThemePolicyCatalog {
  all(): readonly ThemeDefinition[] { return definitions; }

  definition(idOrTitle: string): ThemeDefinition | undefined {
    return definitions.find((item) => item.id === idOrTitle || item.title === idOrTitle);
  }

  allowedAutonomousCapabilities(idOrTitle: string): Set<string> {
    const definition = this.definition(idOrTitle);
    if (!definition) return new Set();
    const horizons: ThemeHorizon[] = ['now', 'three_months', 'six_months', 'one_year'];
    const capabilities = new Set<string>();
    for (const horizon of horizons) {
      const modes: Array<LoveAnalysisMode | undefined> = definition.id === 'love'
        ? ['my_love_life', 'specific_relationship']
        : [undefined];
      for (const mode of modes) {
        const recipe = this.recipe({ theme: definition.title, horizon, mode });
        for (const capability of recipe.capabilities) capabilities.add(capability);
        for (const capability of recipe.relationshipPerMemberCapabilities ?? []) capabilities.add(capability);
      }
    }
    return capabilities;
  }

  recipe(input: ThemeRecipeInput): ThemeRecipe {
    if (!this.definition(input.theme)) throw new Error(`Unknown theme: ${input.theme}`);

    if (input.theme === 'Love & Relationships' && input.mode === 'specific_relationship') {
      const capabilities = ['relationship.synastry', 'relationship.composite', 'relationship.composite_transit'];
      if (input.horizon === 'now') capabilities.push('relationship.composite_tertiary_compare');
      if (input.horizon === 'three_months') capabilities.push('relationship.composite_secondary_compare', 'relationship.composite_tertiary_compare');
      if (input.horizon === 'six_months' || input.horizon === 'one_year') capabilities.push('relationship.composite_secondary_compare');
      return { theme: input.theme, horizon: input.horizon, capabilities };
    }

    const addLunar = (input.theme === 'Love & Relationships' || input.theme === 'Family & Home' || input.theme === 'Self & Wellbeing')
      && input.horizon === 'now';
    const capabilities = [...singleRecipe(input.horizon)];
    if (addLunar) capabilities.push('you.lunar_return');

    if (input.theme === 'Family & Home' && (input.familyMemberCount ?? 0) > 0) {
      return {
        theme: input.theme,
        horizon: input.horizon,
        capabilities,
        relationshipPerMemberCapabilities: ['relationship.synastry'],
      };
    }
    return { theme: input.theme, horizon: input.horizon, capabilities };
  }
}

function singleRecipe(horizon: ThemeHorizon): string[] {
  switch (horizon) {
    case 'now': return [...SINGLE_NOW];
    case 'three_months': return [...SINGLE_3M];
    case 'six_months': return [...SINGLE_6M];
    case 'one_year': return [...SINGLE_1Y];
  }
}

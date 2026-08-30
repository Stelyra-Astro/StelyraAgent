export type AgentAutonomy = 'default' | 'conditional' | 'advanced_only';

export interface CapabilityPolicy {
  id: string;
  group: 'you' | 'relationship';
  agentAutonomy: AgentAutonomy;
  userSelectable: boolean;
  defaultThemeRecipe: boolean;
  dependencyCapabilities?: readonly string[];
}

export const PHASE1_CAPABILITIES = [
  'you.natal',
  'you.transit',
  'you.secondary',
  'relationship.synastry',
  'relationship.composite',
  'relationship.composite_transit',
] as const;

const definitions: readonly CapabilityPolicy[] = [
  { id: 'you.natal', group: 'you', agentAutonomy: 'default', userSelectable: true, defaultThemeRecipe: true },
  { id: 'you.transit', group: 'you', agentAutonomy: 'default', userSelectable: true, defaultThemeRecipe: true },
  { id: 'you.secondary', group: 'you', agentAutonomy: 'default', userSelectable: true, defaultThemeRecipe: true },
  { id: 'you.tertiary', group: 'you', agentAutonomy: 'default', userSelectable: true, defaultThemeRecipe: true },
  { id: 'you.solar_arc', group: 'you', agentAutonomy: 'default', userSelectable: true, defaultThemeRecipe: true },
  { id: 'you.solar_return', group: 'you', agentAutonomy: 'default', userSelectable: true, defaultThemeRecipe: true },
  { id: 'you.lunar_return', group: 'you', agentAutonomy: 'default', userSelectable: true, defaultThemeRecipe: true },
  { id: 'you.current_sky', group: 'you', agentAutonomy: 'conditional', userSelectable: true, defaultThemeRecipe: false },
  { id: 'you.relocation', group: 'you', agentAutonomy: 'conditional', userSelectable: true, defaultThemeRecipe: false },
  { id: 'you.harmonic_12', group: 'you', agentAutonomy: 'advanced_only', userSelectable: true, defaultThemeRecipe: false },
  { id: 'you.harmonic_13', group: 'you', agentAutonomy: 'advanced_only', userSelectable: true, defaultThemeRecipe: false },
  { id: 'relationship.synastry', group: 'relationship', agentAutonomy: 'default', userSelectable: true, defaultThemeRecipe: true },
  { id: 'relationship.composite', group: 'relationship', agentAutonomy: 'default', userSelectable: true, defaultThemeRecipe: true },
  { id: 'relationship.composite_transit', group: 'relationship', agentAutonomy: 'default', userSelectable: true, defaultThemeRecipe: true },
  {
    id: 'relationship.composite_secondary_compare', group: 'relationship', agentAutonomy: 'default', userSelectable: true, defaultThemeRecipe: true,
    dependencyCapabilities: ['relationship.composite_secondary'],
  },
  {
    id: 'relationship.composite_tertiary_compare', group: 'relationship', agentAutonomy: 'default', userSelectable: true, defaultThemeRecipe: true,
    dependencyCapabilities: ['relationship.composite_tertiary'],
  },
  { id: 'relationship.davison', group: 'relationship', agentAutonomy: 'advanced_only', userSelectable: true, defaultThemeRecipe: false },
  { id: 'relationship.davison_transit', group: 'relationship', agentAutonomy: 'advanced_only', userSelectable: true, defaultThemeRecipe: false },
  { id: 'relationship.davison_secondary', group: 'relationship', agentAutonomy: 'advanced_only', userSelectable: true, defaultThemeRecipe: false },
  { id: 'relationship.davison_tertiary', group: 'relationship', agentAutonomy: 'advanced_only', userSelectable: true, defaultThemeRecipe: false },
  { id: 'relationship.marks', group: 'relationship', agentAutonomy: 'advanced_only', userSelectable: true, defaultThemeRecipe: false },
  { id: 'relationship.marks_secondary', group: 'relationship', agentAutonomy: 'advanced_only', userSelectable: true, defaultThemeRecipe: false },
  { id: 'relationship.marks_tertiary', group: 'relationship', agentAutonomy: 'advanced_only', userSelectable: true, defaultThemeRecipe: false },
] as const;

// Internal dependency capabilities are intentionally not Agent-facing catalog entries.
export const SERVER_CAPABILITY_CATALOG = definitions.map((definition) => definition.id);
const policies = new Map(definitions.map((definition) => [definition.id, definition]));

export function capabilityPolicy(id: string): CapabilityPolicy | undefined {
  return policies.get(id);
}

export function allowedCapabilities(clientCapabilities: string[], serverCapabilities: readonly string[] = SERVER_CAPABILITY_CATALOG): Set<string> {
  const server = new Set<string>(serverCapabilities);
  return new Set(clientCapabilities.filter((capability) => server.has(capability)));
}

export function canAgentAutonomouslySelect(id: string, options?: { explicit?: boolean; conditionalAllowed?: boolean }): boolean {
  const policy = capabilityPolicy(id);
  if (!policy) return false;
  if (options?.explicit && policy.userSelectable) return true;
  if (policy.agentAutonomy === 'default') return true;
  if (policy.agentAutonomy === 'conditional') return options?.conditionalAllowed === true;
  return false;
}

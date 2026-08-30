import { PHASE1_CAPABILITIES, SERVER_CAPABILITY_CATALOG } from '../capabilities/catalog.ts';
import { loadModelPolicies } from '../policy/model-catalog.ts';

export const themeCatalog = [
  'Love & Relationships',
  'Career & Purpose',
  'Money & Growth',
  'Family & Home',
  'Self & Wellbeing',
  'Creativity & Expression',
  'Learning & Exploration',
  'Life Direction',
] as const;

export interface RuntimeConfig {
  runTTLHours: number;
  maxToolRounds: number;
  evidenceTargetTokens: number;
  finalizationReserveTokens: number;
  providerTimeoutMs: number;
  maxAnalysisYears: number;
  maxLocationsPerRun: number;
  maxAutonomousCapabilities: number;
  maxFinalCharacters: number;
  promptPolicyVersion: number;
  scopePolicyVersion: number;
  outputPolicyVersion: number;
  safetyPolicyVersion: number;
  phase1Capabilities: readonly string[];
  enabledCapabilities: readonly string[];
  capabilityCatalog: readonly string[];
  themes: readonly string[];
  adminOrigin: string;
}

export function loadRuntimeConfig(env: NodeJS.ProcessEnv = process.env): RuntimeConfig {
  const disabledCapabilities = parseDisabledCapabilities(env.DISABLED_CAPABILITIES);
  const enabledCapabilities = SERVER_CAPABILITY_CATALOG.filter((capability) => !disabledCapabilities.has(capability));
  return {
    runTTLHours: boundedNumber(env, 'RUN_TTL_HOURS', 24, 1, 168),
    maxToolRounds: boundedNumber(env, 'MAX_TOOL_ROUNDS', 2, 1, 8),
    evidenceTargetTokens: boundedNumber(env, 'EVIDENCE_TARGET_TOKENS', 16_000, 1_000, 128_000),
    finalizationReserveTokens: boundedNumber(env, 'FINALIZATION_RESERVE_TOKENS', 2_000, 256, 32_768),
    providerTimeoutMs: boundedNumber(env, 'PROVIDER_TIMEOUT_MS', 60_000, 5_000, 180_000),
    maxAnalysisYears: boundedNumber(env, 'MAX_ANALYSIS_YEARS', 100, 1, 100),
    maxLocationsPerRun: boundedNumber(env, 'MAX_LOCATIONS_PER_RUN', 2, 1, 4),
    maxAutonomousCapabilities: boundedNumber(env, 'MAX_AUTONOMOUS_CAPABILITIES', 4, 1, 8),
    maxFinalCharacters: boundedNumber(env, 'MAX_FINAL_CHARACTERS', 12_000, 1_000, 40_000),
    promptPolicyVersion: boundedNumber(env, 'PROMPT_POLICY_VERSION', 3, 1, 9999),
    scopePolicyVersion: boundedNumber(env, 'SCOPE_POLICY_VERSION', 1, 1, 9999),
    outputPolicyVersion: boundedNumber(env, 'OUTPUT_POLICY_VERSION', 1, 1, 9999),
    safetyPolicyVersion: boundedNumber(env, 'SAFETY_POLICY_VERSION', 1, 1, 9999),
    phase1Capabilities: PHASE1_CAPABILITIES,
    enabledCapabilities,
    capabilityCatalog: SERVER_CAPABILITY_CATALOG,
    themes: themeCatalog,
    adminOrigin: validOrigin(env.ADMIN_ORIGIN ?? 'http://localhost:8788'),
  };
}

export function assertProductionEnvironment(env: NodeJS.ProcessEnv = process.env): void {
  if (env.NODE_ENV !== 'production') return;
  const required = [
    'APPLE_CLIENT_ID',
    'APPLE_CLIENT_SECRET',
    'DATA_ENCRYPTION_KEY',
    'ADMIN_USERNAME',
    'ADMIN_PASSWORD',
    'APP_STORE_BUNDLE_ID',
    'APPLE_ROOT_CA_PATHS',
    'IAP_PRODUCT_CREDITS_JSON',
  ] as const;
  const missing = required.filter((key) => !env[key]?.trim());
  const providers = new Set(loadModelPolicies(env).filter((model) => model.enabled && model.agentEligible).map((model) => model.provider));
  if (providers.has('deepseek') && !env.DEEPSEEK_API_KEY?.trim()) missing.push('DEEPSEEK_API_KEY' as never);
  if (providers.has('openrouter') && !env.OPENROUTER_API_KEY?.trim()) missing.push('OPENROUTER_API_KEY' as never);
  if (missing.length > 0) {
    throw new Error(`Missing required production configuration: ${missing.join(', ')}`);
  }
}

function boundedNumber(
  env: NodeJS.ProcessEnv,
  key: string,
  fallback: number,
  min: number,
  max: number,
): number {
  const raw = env[key];
  if (raw == null || raw.trim() === '') return fallback;
  const value = Number(raw);
  if (!Number.isFinite(value) || !Number.isInteger(value) || value < min || value > max) {
    throw new Error(`${key} must be an integer between ${min} and ${max}`);
  }
  return value;
}

function validOrigin(raw: string): string {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    throw new Error('ADMIN_ORIGIN must be an absolute http(s) URL');
  }
  if (!['http:', 'https:'].includes(url.protocol)) {
    throw new Error('ADMIN_ORIGIN must be an absolute http(s) URL');
  }
  return url.origin;
}

function parseDisabledCapabilities(raw: string | undefined): Set<string> {
  const values = (raw ?? '').split(',').map((value) => value.trim()).filter(Boolean);
  const catalog = new Set<string>(SERVER_CAPABILITY_CATALOG);
  for (const value of values) {
    if (!catalog.has(value)) throw new Error(`DISABLED_CAPABILITIES contains unknown capability: ${value}`);
  }
  return new Set(values);
}

import { Hono } from 'hono';
import type { RuntimeServices } from './runtime-services.ts';
import { ThemePolicyCatalog } from '../themes/theme-policy.ts';

export function createConfigRoutes(services: RuntimeServices): Hono {
  const routes = new Hono();
  const themes = new ThemePolicyCatalog();
  routes.get('/capabilities', (c) => c.json({
    catalog_version: 2,
    enabled_phase: 3,
    supported_capabilities: services.config.enabledCapabilities,
    phase1_compatibility: services.config.phase1Capabilities,
    full_catalog: services.config.capabilityCatalog,
  }));
  routes.get('/models', (c) => c.json({
    model_catalog_version: 1,
    models: services.modelCatalog.listPublic(),
  }));
  routes.get('/runtime-config', (c) => c.json({
    run_ttl_hours: services.config.runTTLHours,
    max_tool_rounds: services.config.maxToolRounds,
    evidence_target_tokens: services.config.evidenceTargetTokens,
    finalization_reserve_tokens: services.config.finalizationReserveTokens,
    resolution_policy_version: 1,
    theme_policy_version: 1,
    prompt_policy_version: services.config.promptPolicyVersion,
    scope_policy_version: services.config.scopePolicyVersion,
    output_policy_version: services.config.outputPolicyVersion,
    safety_policy_version: services.config.safetyPolicyVersion,
    max_analysis_years: services.config.maxAnalysisYears,
    max_locations_per_run: services.config.maxLocationsPerRun,
    max_autonomous_capabilities: services.config.maxAutonomousCapabilities,
    max_final_characters: services.config.maxFinalCharacters,
    themes: themes.all(),
  }));
  return routes;
}

import { serve } from '@hono/node-server';
import { createDatabase } from './db/sqlite-database.ts';
import { assertProductionEnvironment, loadRuntimeConfig } from './config/runtime-config.ts';
import { SqliteAccountRepository } from './repositories/sqlite-account-repository.ts';
import { SqliteCreditRepository } from './repositories/sqlite-credit-repository.ts';
import { SqliteIAPRepository } from './repositories/sqlite-iap-repository.ts';
import { SqliteRunRepository } from './repositories/sqlite-run-repository.ts';
import { AccountService } from './account/account-service.ts';
import { AppleAccountDeletionService } from './account/apple-account-deletion-service.ts';
import { SessionService } from './account/session-service.ts';
import { RunService } from './run/run-service.ts';
import { RunExpirySweeper } from './run/run-expiry-sweeper.ts';
import { AstrologyAgentRuntime } from './agent/astrology-agent-runtime.ts';
import { DeepSeekProvider } from './providers/deepseek-provider.ts';
import { OpenRouterProvider } from './providers/openrouter-provider.ts';
import { ProviderRegistry } from './providers/provider-registry.ts';
import { PolicyEnforcedProvider } from './policy/policy-enforced-provider.ts';
import { ModelCatalog, loadModelPolicies } from './policy/model-catalog.ts';
import { RunAdmissionPolicy } from './policy/run-admission-policy.ts';
import { ScopePolicy } from './policy/scope-policy.ts';
import { AnalysisPlanCompiler } from './agent/analysis-plan-compiler.ts';
import { UnavailableProvider } from './providers/unavailable-provider.ts';
import { IAPService } from './iap/iap-service.ts';
import { createAppleStoreTransactionVerifier, loadAppleStoreVerifierConfig, RejectingStoreTransactionVerifier } from './iap/transaction-verifier.ts';
import { AppleIdentityVerifier } from './auth/apple-identity-verifier.ts';
import { AppleTokenExchange } from './auth/apple-token-exchange.ts';
import { SecretBox } from './auth/secret-box.ts';
import { AdminRepository } from './admin/admin-repository.ts';
import { AdminBasicAuth } from './admin/admin-auth.ts';
import { createApp } from './http/app.ts';

assertProductionEnvironment(process.env);

const sqlitePath = process.env.SQLITE_PATH ?? '/data/stelyraagent.sqlite';
const db = createDatabase(sqlitePath);
const config = loadRuntimeConfig();
const accounts = new SqliteAccountRepository(db);
const credits = new SqliteCreditRepository(db);
const iapRepository = new SqliteIAPRepository(db);
const runs = new SqliteRunRepository(db);
const accountService = new AccountService(accounts, credits);
const sessions = new SessionService(db);
const runService = new RunService(runs, credits);
const runExpirySweeper = new RunExpirySweeper(runs, runService);
const modelPolicies = loadModelPolicies(process.env);
const modelCatalog = new ModelCatalog(modelPolicies);
const admission = new RunAdmissionPolicy(modelCatalog);
const providerRegistry = new ProviderRegistry(modelPolicies
  .filter((policy) => policy.enabled && policy.agentEligible)
  .map((policy) => {
    let provider;
    if (policy.provider === 'deepseek' && process.env.DEEPSEEK_API_KEY) {
      provider = new DeepSeekProvider({
        apiKey: process.env.DEEPSEEK_API_KEY,
        model: policy.providerModel,
        baseURL: process.env.DEEPSEEK_BASE_URL ?? 'https://api.deepseek.com/v1',
        timeoutMs: config.providerTimeoutMs,
      });
    } else if (policy.provider === 'openrouter' && process.env.OPENROUTER_API_KEY) {
      provider = new OpenRouterProvider({
        apiKey: process.env.OPENROUTER_API_KEY,
        model: policy.providerModel,
        baseURL: process.env.OPENROUTER_BASE_URL ?? 'https://openrouter.ai/api/v1',
        timeoutMs: config.providerTimeoutMs,
      });
    } else {
      provider = new UnavailableProvider(policy.provider, policy.providerModel);
    }
    return {
      modelId: policy.id,
      policy,
      provider: new PolicyEnforcedProvider(provider, { maxCharacters: config.maxFinalCharacters }),
    };
  }));
const compiler = new AnalysisPlanCompiler(new ScopePolicy({
  maxYears: config.maxAnalysisYears,
  maxLocations: config.maxLocationsPerRun,
  maxAutonomousCapabilities: config.maxAutonomousCapabilities,
}), config.enabledCapabilities);
const agent = new AstrologyAgentRuntime(runService, providerRegistry, {
  maxToolRounds: config.maxToolRounds,
  evidenceTargetTokens: config.evidenceTargetTokens,
  finalizationReserveTokens: config.finalizationReserveTokens,
}, compiler);
const iapService = new IAPService(iapRepository, credits);
const appleStoreVerifierConfig = loadAppleStoreVerifierConfig(process.env);
const transactionVerifier = appleStoreVerifierConfig
  ? await createAppleStoreTransactionVerifier(appleStoreVerifierConfig)
  : new RejectingStoreTransactionVerifier();
const appleClientId = process.env.APPLE_CLIENT_ID ?? 'com.example.stelyraagent';
const appleVerifier = new AppleIdentityVerifier(appleClientId);
const appleTokenExchange = new AppleTokenExchange(appleClientId, process.env.APPLE_CLIENT_SECRET);
const secretBox = process.env.DATA_ENCRYPTION_KEY ? new SecretBox(process.env.DATA_ENCRYPTION_KEY) : null;
const accountDeletionService = new AppleAccountDeletionService(accounts, accountService, appleTokenExchange, secretBox);
const adminRepository = new AdminRepository(db);
const adminAuth = process.env.ADMIN_USERNAME && process.env.ADMIN_PASSWORD
  ? new AdminBasicAuth(process.env.ADMIN_USERNAME, process.env.ADMIN_PASSWORD)
  : null;

const app = createApp({
  db,
  config,
  accounts,
  credits,
  iapRepository,
  runs,
  accountService,
  accountDeletionService,
  sessions,
  runService,
  agent,
  iapService,
  transactionVerifier,
  appleVerifier,
  appleTokenExchange,
  secretBox,
  adminRepository,
  adminAuth,
  modelCatalog,
  admission,
});

const port = Number(process.env.PORT ?? 8787);
serve({ fetch: app.fetch, port }, (info) => {
  console.log(`stelyraagent-runtime listening on http://0.0.0.0:${info.port}`);
});

const sweepIntervalMs = Number(process.env.RUN_SWEEP_INTERVAL_MS ?? 15 * 60 * 1000);
const sweepExpiredRuns = () => {
  try {
    const expired = runExpirySweeper.sweep(new Date(), config.runTTLHours);
    if (expired > 0) console.log(`expired ${expired} stale StelyraAgent run(s)`);
  } catch (error) {
    console.error('run expiry sweep failed', error);
  }
};

sweepExpiredRuns();
setInterval(sweepExpiredRuns, sweepIntervalMs).unref();

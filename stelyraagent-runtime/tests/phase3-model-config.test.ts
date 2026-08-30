import test from 'node:test';
import assert from 'node:assert/strict';
import { loadModelPolicies } from '../src/policy/model-catalog.ts';
import { assertProductionEnvironment } from '../src/config/runtime-config.ts';

const openRouterCatalog = JSON.stringify([{
  id: 'reasoning', label: 'Deep Analysis', provider: 'openrouter', providerModel: 'vendor/model',
  creditsRequired: 2, maxInputTokens: 64000, maxOutputTokens: 6000,
  maxToolRounds: 2, evidenceTargetTokens: 20000, maxProviderCost: 0.2,
  inputCostPerMillion: 1, outputCostPerMillion: 4,
  enabled: true, agentEligible: true,
}]);

test('model policies load from server configuration and never expose arbitrary models', () => {
  const policies = loadModelPolicies({ MODEL_CATALOG_JSON: openRouterCatalog });
  assert.equal(policies.length, 1);
  assert.equal(policies[0]?.id, 'reasoning');
  assert.equal(policies[0]?.providerModel, 'vendor/model');
});

test('production may be OpenRouter-only when the enabled model catalog uses only OpenRouter', () => {
  assert.doesNotThrow(() => assertProductionEnvironment({
    NODE_ENV: 'production',
    APPLE_CLIENT_ID: 'com.example.stelyraagent',
    APPLE_CLIENT_SECRET: 'secret',
    DATA_ENCRYPTION_KEY: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    OPENROUTER_API_KEY: 'router-key',
    MODEL_CATALOG_JSON: openRouterCatalog,
    ADMIN_USERNAME: 'admin', ADMIN_PASSWORD: 'strong-password',
    APP_STORE_BUNDLE_ID: 'com.example.stelyraagent',
    APPLE_ROOT_CA_PATHS: '/run/secrets/apple/AppleRootCA-G3.cer',
    IAP_PRODUCT_CREDITS_JSON: '{"credits10":10}',
  }));
});

test('production fails closed when an enabled provider in model catalog has no server key', () => {
  assert.throws(() => assertProductionEnvironment({
    NODE_ENV: 'production',
    APPLE_CLIENT_ID: 'com.example.stelyraagent',
    APPLE_CLIENT_SECRET: 'secret',
    DATA_ENCRYPTION_KEY: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    MODEL_CATALOG_JSON: openRouterCatalog,
    ADMIN_USERNAME: 'admin', ADMIN_PASSWORD: 'strong-password',
    APP_STORE_BUNDLE_ID: 'com.example.stelyraagent',
    APPLE_ROOT_CA_PATHS: '/run/secrets/apple/AppleRootCA-G3.cer',
    IAP_PRODUCT_CREDITS_JSON: '{"credits10":10}',
  }), /OPENROUTER_API_KEY/);
});

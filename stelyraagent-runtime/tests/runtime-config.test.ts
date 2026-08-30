import test from 'node:test';
import assert from 'node:assert/strict';
import { assertProductionEnvironment, loadRuntimeConfig } from '../src/config/runtime-config.ts';

test('runtime config rejects invalid numeric budgets instead of accepting NaN or zero', () => {
  assert.throws(() => loadRuntimeConfig({ RUN_TTL_HOURS: '0' }), /RUN_TTL_HOURS/);
  assert.throws(() => loadRuntimeConfig({ MAX_TOOL_ROUNDS: 'not-a-number' }), /MAX_TOOL_ROUNDS/);
  assert.throws(() => loadRuntimeConfig({ PROVIDER_TIMEOUT_MS: '-1' }), /PROVIDER_TIMEOUT_MS/);
});

test('runtime config exposes a finite provider timeout for model calls', () => {
  const config = loadRuntimeConfig({ PROVIDER_TIMEOUT_MS: '45000' });
  assert.equal(config.providerTimeoutMs, 45_000);
});

test('production startup fails closed when security and paid-service configuration is missing', () => {
  assert.throws(
    () => assertProductionEnvironment({ NODE_ENV: 'production' }),
    /APPLE_CLIENT_ID.*APPLE_CLIENT_SECRET.*DATA_ENCRYPTION_KEY.*DEEPSEEK_API_KEY/s,
  );
});

test('production startup accepts the complete Phase 1 required secret set', () => {
  assert.doesNotThrow(() => assertProductionEnvironment({
    NODE_ENV: 'production',
    APPLE_CLIENT_ID: 'com.example.stelyraagent',
    APPLE_CLIENT_SECRET: 'secret',
    DATA_ENCRYPTION_KEY: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    DEEPSEEK_API_KEY: 'deepseek-key',
    ADMIN_USERNAME: 'admin',
    ADMIN_PASSWORD: 'strong-password',
    APP_STORE_BUNDLE_ID: 'com.example.stelyraagent',
    APPLE_ROOT_CA_PATHS: '/run/secrets/apple/AppleRootCA-G3.cer',
    IAP_PRODUCT_CREDITS_JSON: '{"credits10":10}',
  }));
});

import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';

const app = readFileSync(new URL('../src/App.tsx', import.meta.url), 'utf8');
const api = readFileSync(new URL('../src/api.ts', import.meta.url), 'utf8');

test('admin UI exposes the Phase 1 operational sections', () => {
  for (const label of ['Dashboard', 'Agent Runs', 'IAP Transactions', 'Runtime Config', 'System Health']) {
    assert.match(app, new RegExp(label));
  }
});

test('admin UI only obtains operational data through Runtime Admin API', () => {
  for (const endpoint of ['/v1/admin/dashboard', '/v1/admin/runs', '/v1/admin/iap', '/v1/admin/runtime-config', '/v1/admin/health']) {
    assert.match(api, new RegExp(endpoint.replaceAll('/', '\\/')));
  }
  assert.doesNotMatch(api, /sqlite|DatabaseSync|better-sqlite/i);
});

test('Docker build does not use npm ci without a committed package lock', () => {
  const dockerfile = readFileSync(new URL('../Dockerfile', import.meta.url), 'utf8');
  const lockExists = existsSync(new URL('../package-lock.json', import.meta.url));
  assert.ok(lockExists || !dockerfile.includes('npm ci'));
});

test('phase two dashboard surfaces run quality, interaction, chart and budget analytics', () => {
  for (const metric of [
    'runSuccessRate', 'budgetLimitRate', 'interactionRate', 'averageToolRounds',
    'averageChartsPerRun', 'averageInputTokens', 'averageOutputTokens', 'averageInteractionCount',
  ]) {
    assert.match(app, new RegExp(metric));
  }
  assert.match(app, /Phase 2 analytics/);
});

test('phase three admin exposes server model policy and provider usage sections', () => {
  for (const label of ['Models', 'Provider Usage']) assert.match(app, new RegExp(label));
  for (const endpoint of ['/v1/admin/models', '/v1/admin/provider-usage']) {
    assert.match(api, new RegExp(endpoint.replaceAll('/', '\\/')));
  }
});

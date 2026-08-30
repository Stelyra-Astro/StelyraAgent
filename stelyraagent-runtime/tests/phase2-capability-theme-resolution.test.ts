import test from 'node:test';
import assert from 'node:assert/strict';
import { allowedCapabilities, capabilityPolicy } from '../src/capabilities/catalog.ts';
import { ThemePolicyCatalog } from '../src/themes/theme-policy.ts';
import { ResolutionPolicy } from '../src/planning/resolution-policy.ts';

test('server/client intersection exposes full v1 catalog while advanced autonomy stays restricted', () => {
  const allowed = allowedCapabilities([
    'you.tertiary',
    'you.harmonic_12',
    'relationship.composite_secondary_compare',
    'relationship.davison',
    'unknown.capability',
  ]);
  assert.deepEqual([...allowed], [
    'you.tertiary',
    'you.harmonic_12',
    'relationship.composite_secondary_compare',
    'relationship.davison',
  ]);
  assert.equal(capabilityPolicy('you.tertiary')?.agentAutonomy, 'default');
  assert.equal(capabilityPolicy('you.harmonic_12')?.agentAutonomy, 'advanced_only');
  assert.equal(capabilityPolicy('relationship.davison')?.agentAutonomy, 'advanced_only');
  assert.equal(capabilityPolicy('relationship.composite_secondary_compare')?.agentAutonomy, 'default');
});

test('eight theme catalog encodes authoritative horizon recipes without advanced relationship charts', () => {
  const catalog = new ThemePolicyCatalog();
  assert.equal(catalog.all().length, 8);
  assert.deepEqual(
    catalog.recipe({ theme: 'Career & Purpose', horizon: 'one_year' }).capabilities,
    ['you.natal', 'you.transit', 'you.secondary', 'you.solar_arc', 'you.solar_return'],
  );
  assert.deepEqual(
    catalog.recipe({ theme: 'Self & Wellbeing', horizon: 'now' }).capabilities,
    ['you.natal', 'you.transit', 'you.tertiary', 'you.lunar_return'],
  );
  assert.deepEqual(
    catalog.recipe({ theme: 'Love & Relationships', mode: 'specific_relationship', horizon: 'three_months' }).capabilities,
    [
      'relationship.synastry',
      'relationship.composite',
      'relationship.composite_transit',
      'relationship.composite_secondary_compare',
      'relationship.composite_tertiary_compare',
    ],
  );
  assert.equal(
    catalog.recipe({ theme: 'Love & Relationships', mode: 'specific_relationship', horizon: 'one_year' })
      .capabilities.includes('relationship.davison'),
    false,
  );
});

test('resolution policy matches the frozen span matrix and recognizes major-window scans', () => {
  const policy = new ResolutionPolicy();
  const day = 86_400_000;
  assert.equal(policy.resolve({ spanMs: 5 * day, detail: 'balanced' }).label, '12_hours');
  assert.equal(policy.resolve({ spanMs: 20 * day, detail: 'detailed' }).label, 'daily');
  assert.equal(policy.resolve({ spanMs: 180 * day, detail: 'balanced' }).label, 'two_weeks');
  assert.equal(policy.resolve({ spanMs: 365 * day, detail: 'overview' }).label, 'monthly');
  assert.equal(policy.resolve({ spanMs: 5 * 365 * day, detail: 'balanced' }).label, 'six_months');
  assert.equal(policy.resolve({ spanMs: 20 * 365 * day, detail: 'overview' }).label, 'five_years');
  assert.equal(policy.resolve({ spanMs: 60 * 365 * day, detail: 'detailed' }).label, 'yearly');
  assert.equal(policy.resolve({ spanMs: 60 * 365 * day, detail: 'major_windows' }).label, 'major_windows_only');
});

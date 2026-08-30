import test from 'node:test';
import assert from 'node:assert/strict';
import { EvidenceRoundPolicy } from '../src/planning/evidence-round-policy.ts';

const policy = new EvidenceRoundPolicy();

test('round two focus window must come from a discovered round-one timing window', () => {
  const actionResults = [{ result: { facts: [{
    fact_type: 'timing_event',
    data: { active_start: '2027-04-01', active_end: '2027-06-30', exact_at: '2027-05-12' },
  }] } }];
  assert.doesNotThrow(() => policy.assertAllowed({
    round: 2,
    actionResults,
    requests: [{ capability: 'you.transit', subjects: ['primary'], time_scope: { start: '2027-05-01', end: '2027-05-31' } }],
  }));
  assert.throws(() => policy.assertAllowed({
    round: 2,
    actionResults,
    requests: [{ capability: 'you.transit', subjects: ['primary'], time_scope: { start: '2027-09-01', end: '2027-09-30' } }],
  }), /not grounded in a Round 1 evidence window/);
});

test('round two without a narrower time request remains allowed', () => {
  assert.doesNotThrow(() => policy.assertAllowed({
    round: 2,
    actionResults: [],
    requests: [{ capability: 'you.secondary', subjects: ['primary'] }],
  }));
});

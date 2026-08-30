import type { AstrologyEvidenceRequest } from '../providers/model-provider.ts';

interface EvidenceWindow { start: number; end: number; }

export class EvidenceRoundPolicy {
  assertAllowed(input: {
    round: number;
    actionResults: Array<Record<string, unknown>>;
    requests: AstrologyEvidenceRequest[];
  }): void {
    if (input.round < 2) return;
    const ranged = input.requests.filter(hasDateRange);
    if (ranged.length === 0) return;
    const windows = extractEvidenceWindows(input.actionResults);
    if (windows.length === 0) return;
    for (const request of ranged) {
      const scope = request.time_scope!;
      const start = Date.parse(String(scope.start));
      const end = Date.parse(String(scope.end));
      if (!windows.some((window) => start <= window.end && end >= window.start)) {
        throw new Error('Round 2 focus window is not grounded in a Round 1 evidence window');
      }
    }
  }
}

function hasDateRange(request: AstrologyEvidenceRequest): boolean {
  const scope = request.time_scope;
  return !!scope && typeof scope.start === 'string' && typeof scope.end === 'string'
    && Number.isFinite(Date.parse(scope.start)) && Number.isFinite(Date.parse(scope.end));
}

function extractEvidenceWindows(actionResults: Array<Record<string, unknown>>): EvidenceWindow[] {
  const windows: EvidenceWindow[] = [];
  for (const record of actionResults) {
    const result = asRecord(record.result);
    const facts = Array.isArray(result?.facts) ? result.facts : [];
    for (const rawFact of facts) {
      const fact = asRecord(rawFact);
      if (fact?.fact_type !== 'timing_event') continue;
      const data = asRecord(fact.data);
      if (!data) continue;
      const startRaw = data.active_start ?? data.start ?? data.exact_at;
      const endRaw = data.active_end ?? data.end ?? data.exact_at;
      if (typeof startRaw !== 'string' || typeof endRaw !== 'string') continue;
      const start = Date.parse(startRaw);
      const end = Date.parse(endRaw);
      if (Number.isFinite(start) && Number.isFinite(end)) windows.push({ start, end });
    }
  }
  return windows;
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return value && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, unknown> : null;
}

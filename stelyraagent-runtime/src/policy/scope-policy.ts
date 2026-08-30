import type { AstrologyEvidenceRequest } from '../providers/model-provider.ts';

export interface ScopePolicyOptions { maxYears?: number; maxLocations?: number; maxAutonomousCapabilities?: number; }

export class ScopePolicy {
  private readonly maxSpanMs: number;
  private readonly maxLocations: number;
  private readonly maxAutonomousCapabilities: number;

  constructor(options: ScopePolicyOptions = {}) {
    this.maxSpanMs = (options.maxYears ?? 100) * 365.2425 * 24 * 60 * 60 * 1000;
    this.maxLocations = options.maxLocations ?? 2;
    this.maxAutonomousCapabilities = options.maxAutonomousCapabilities ?? 4;
  }
  assertRequestsAllowed(
    requests: AstrologyEvidenceRequest[],
    input: { explicitCapabilities: string[] },
  ): void {
    const explicit = new Set(input.explicitCapabilities);
    const autonomous = new Set(requests.map((item) => item.capability).filter((capability) => !explicit.has(capability)));
    if (autonomous.size > this.maxAutonomousCapabilities) throw new Error(this.maxAutonomousCapabilities === 4 ? 'A Run may use at most four autonomous capability kinds; split or review the analysis scope.' : `A Run may use at most ${this.maxAutonomousCapabilities} autonomous capability kinds; split or review the analysis scope.`);

    const locations = new Set(requests.flatMap((request) => request.locations ?? []));
    if (locations.size > this.maxLocations) {
      throw new Error(this.maxLocations === 2 ? 'A Run may compare at most two locations; split a larger location comparison into another Run.' : `A Run may compare at most ${this.maxLocations} locations; split a larger location comparison into another Run.`);
    }

    for (const request of requests) {
      const scope = request.time_scope;
      if (!scope || typeof scope.start !== 'string' || typeof scope.end !== 'string') continue;
      const start = Date.parse(scope.start);
      const end = Date.parse(scope.end);
      if (!Number.isFinite(start) || !Number.isFinite(end) || end <= start) continue;
      if (end - start > this.maxSpanMs) throw new Error(`StelyraAgent limits a single analysis span to ${Math.round(this.maxSpanMs / (365.2425 * 24 * 60 * 60 * 1000))} years.`);
    }
  }
}

import type { SqliteRunRepository } from '../repositories/sqlite-run-repository.ts';
import type { RunService } from './run-service.ts';

export class RunExpirySweeper {
  private readonly runs: SqliteRunRepository;
  private readonly runService: RunService;

  constructor(runs: SqliteRunRepository, runService: RunService) {
    this.runs = runs;
    this.runService = runService;
  }

  sweep(now: Date, ttlHours: number): number {
    if (!Number.isFinite(ttlHours) || ttlHours <= 0) {
      throw new Error('Run TTL must be a positive number of hours');
    }
    const cutoff = new Date(now.getTime() - ttlHours * 60 * 60 * 1000).toISOString();
    let expired = 0;
    for (const run of this.runs.listExpirableBefore(cutoff)) {
      this.runService.expire(run.runId);
      expired += 1;
    }
    return expired;
  }
}

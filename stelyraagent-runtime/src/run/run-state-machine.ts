import type { RunStatus } from '../domain/types.ts';

const transitions: Record<RunStatus, ReadonlySet<RunStatus>> = {
  created: new Set(['reasoning', 'cancelled', 'expired', 'failed']),
  reasoning: new Set(['requires_action', 'finalizing', 'cancelled', 'expired', 'failed']),
  requires_action: new Set(['waiting_for_client', 'resuming', 'cancelled', 'expired', 'failed']),
  waiting_for_client: new Set(['resuming', 'cancelled', 'expired', 'failed']),
  resuming: new Set(['reasoning', 'requires_action', 'finalizing', 'cancelled', 'expired', 'failed']),
  finalizing: new Set(['completed', 'failed', 'cancelled', 'expired']),
  completed: new Set(['acknowledged']),
  failed: new Set([]),
  cancelled: new Set([]),
  expired: new Set([]),
  acknowledged: new Set([]),
};

export class InvalidRunTransitionError extends Error {
  constructor(from: RunStatus, to: RunStatus) {
    super(`Invalid run transition: ${from} -> ${to}`);
    this.name = 'InvalidRunTransitionError';
  }
}

export function assertRunTransition(from: RunStatus, to: RunStatus): void {
  if (from === to) return;
  if (!transitions[from].has(to)) {
    throw new InvalidRunTransitionError(from, to);
  }
}

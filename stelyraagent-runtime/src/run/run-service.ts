import type { RunRecord, RunStatus } from '../domain/types.ts';
import type { SqliteCreditRepository } from '../repositories/sqlite-credit-repository.ts';
import type { SqliteRunRepository } from '../repositories/sqlite-run-repository.ts';
import { assertRunTransition } from './run-state-machine.ts';

export interface RuntimeAction {
  id: string;
  type: 'astrology_tool' | 'interaction';
  tool?: 'request_astrology_evidence';
  payload: Record<string, unknown>;
}

export interface RunView extends RunRecord {
  pendingAction: RuntimeAction | null;
}

export class RunService {
  private readonly runs: SqliteRunRepository;
  private readonly credits: SqliteCreditRepository;

  constructor(runs: SqliteRunRepository, credits: SqliteCreditRepository) {
    this.runs = runs;
    this.credits = credits;
  }

  createRun(input: {
    runId: string;
    walletId: string | null;
    payload: Record<string, unknown>;
    creditsRequired: number;
  }): RunView {
    const run = this.runs.create({
      runId: input.runId,
      walletId: input.walletId,
      payload: {
        ...input.payload,
        creditsRequired: input.creditsRequired,
        pendingAction: null,
        actionResults: [],
      },
    });
    if (input.walletId && input.creditsRequired > 0) {
      try {
        this.credits.reserve(input.walletId, input.runId, input.creditsRequired);
      } catch (error) {
        this.runs.setStatus(input.runId, 'failed');
        this.runs.updatePayload(input.runId, null);
        throw error;
      }
    }
    return this.toView(run);
  }

  getRun(runId: string): RunView {
    const run = this.runs.get(runId);
    if (!run) throw new Error('Run not found');
    return this.toView(run);
  }

  recordProvider(runId: string, provider: string, model: string): RunView {
    return this.toView(this.runs.updateUsage(runId, { provider, model }));
  }

  recordUsage(runId: string, usage: { inputTokens: number; outputTokens: number; reasoningTokens: number; providerCost: number }): RunView {
    return this.toView(this.runs.addUsage(runId, usage));
  }

  startReasoning(runId: string): RunView {
    return this.transition(runId, 'reasoning');
  }

  requireAction(runId: string, action: RuntimeAction): RunView {
    const run = this.getRun(runId);
    assertRunTransition(run.status, 'requires_action');
    const payload = { ...(run.payload ?? {}), pendingAction: action };
    this.runs.updatePayload(runId, payload);
    if (action.type === 'astrology_tool') {
      this.runs.incrementToolRounds(runId);
      const requests = Array.isArray(action.payload.requests) ? action.payload.requests.length : 0;
      this.runs.incrementChartRequestCount(runId, requests);
    } else {
      this.runs.incrementInteractionCount(runId);
    }
    this.runs.setStatus(runId, 'requires_action');
    return this.getRun(runId);
  }

  submitAction(
    runId: string,
    actionId: string,
    result: Record<string, unknown>,
  ): { result: Record<string, unknown>; wasDuplicate: boolean; run: RunView } {
    const existing = this.runs.getActionResult(runId, actionId);
    if (existing) {
      return { result: existing, wasDuplicate: true, run: this.getRun(runId) };
    }

    const run = this.getRun(runId);
    if (run.status !== 'requires_action' && run.status !== 'waiting_for_client') {
      throw new Error(`Run is not waiting for an action: ${run.status}`);
    }
    if (!run.pendingAction || run.pendingAction.id !== actionId) {
      throw new Error('Action ID does not match the pending action');
    }

    const stored = this.runs.storeActionResult(runId, actionId, result);
    const currentPayload = run.payload ?? {};
    const previous = Array.isArray(currentPayload.actionResults) ? currentPayload.actionResults : [];
    this.runs.updatePayload(runId, {
      ...currentPayload,
      pendingAction: null,
      actionResults: [...previous, { actionId, action: run.pendingAction, result: stored.result }],
    });
    this.runs.setStatus(runId, 'resuming');
    return { ...stored, run: this.getRun(runId) };
  }

  complete(runId: string, finalAnswer: Record<string, unknown>): RunView {
    let run = this.getRun(runId);
    if (run.status !== 'finalizing') {
      assertRunTransition(run.status, 'finalizing');
      this.runs.setStatus(runId, 'finalizing');
    }
    run = this.getRun(runId);
    this.runs.updatePayload(runId, { ...(run.payload ?? {}), finalAnswer, pendingAction: null });
    this.runs.setBudgetLimited(runId, finalAnswer.budgetLimited === true);
    this.runs.setStatus(runId, 'completed');
    return this.getRun(runId);
  }

  fail(runId: string, errorCode: string): RunView {
    const run = this.getRun(runId);
    if (!['completed', 'acknowledged', 'failed', 'cancelled', 'expired'].includes(run.status)) {
      this.runs.setStatus(runId, 'failed');
      this.runs.setFailureReason(runId, errorCode);
      this.releaseReservation(runId);
      this.runs.updatePayload(runId, null);
    }
    return this.getRun(runId);
  }

  cancel(runId: string): RunView {
    const run = this.getRun(runId);
    if (['cancelled', 'expired', 'failed', 'acknowledged'].includes(run.status)) return run;
    if (run.status === 'completed') throw new Error('Completed run must be acknowledged, not cancelled');
    this.runs.setStatus(runId, 'cancelled');
    this.releaseReservation(runId);
    this.runs.updatePayload(runId, null);
    return this.getRun(runId);
  }

  expire(runId: string): RunView {
    const run = this.getRun(runId);
    if (['expired', 'cancelled', 'failed', 'acknowledged'].includes(run.status)) return run;
    // ACK is the delivery boundary. If a run expires before the iOS client confirms
    // that the final answer was persisted locally, the reservation must be released.
    this.releaseReservation(runId);
    this.runs.setStatus(runId, 'expired');
    this.runs.updatePayload(runId, null);
    return this.getRun(runId);
  }

  cancelActiveRunsForWallet(walletId: string): number {
    let cancelled = 0;
    for (const run of this.runs.listActiveByWallet(walletId)) {
      this.cancel(run.runId);
      cancelled += 1;
    }
    return cancelled;
  }

  acknowledge(runId: string): RunView {
    const run = this.getRun(runId);
    if (run.status === 'acknowledged') return run;
    if (run.status !== 'completed') throw new Error('Only completed runs can be acknowledged');
    const reservation = this.credits.getReservationByRun(runId);
    if (reservation?.status === 'reserved') this.credits.commit(reservation.reservationId);
    this.runs.acknowledge(runId);
    return this.getRun(runId);
  }

  private transition(runId: string, status: RunStatus): RunView {
    const current = this.getRun(runId);
    assertRunTransition(current.status, status);
    this.runs.setStatus(runId, status);
    return this.getRun(runId);
  }

  private releaseReservation(runId: string): void {
    const reservation = this.credits.getReservationByRun(runId);
    if (reservation?.status === 'reserved') this.credits.release(reservation.reservationId);
  }

  private toView(run: RunRecord): RunView {
    const pendingAction = run.payload?.pendingAction;
    return {
      ...run,
      pendingAction: pendingAction && typeof pendingAction === 'object'
        ? pendingAction as RuntimeAction
        : null,
    };
  }
}

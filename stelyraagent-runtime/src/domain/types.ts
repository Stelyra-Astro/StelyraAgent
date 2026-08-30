export type RunStatus =
  | 'created'
  | 'reasoning'
  | 'requires_action'
  | 'waiting_for_client'
  | 'resuming'
  | 'finalizing'
  | 'completed'
  | 'failed'
  | 'cancelled'
  | 'expired'
  | 'acknowledged';

export type CreditReservationStatus = 'reserved' | 'committed' | 'released';

export interface WalletRecord {
  walletId: string;
  accountId: string;
  appAccountToken: string;
  availableBalance: number;
  reservedBalance: number;
  spentBalance: number;
  status: 'active' | 'closed';
}

export interface CreditReservation {
  reservationId: string;
  walletId: string;
  runId: string;
  amount: number;
  status: CreditReservationStatus;
}

export interface RunRecord {
  runId: string;
  walletId: string | null;
  status: RunStatus;
  payload: Record<string, unknown> | null;
  provider: string | null;
  model: string | null;
  inputTokens: number;
  outputTokens: number;
  reasoningTokens: number;
  providerCost: number;
  toolRounds: number;
  interactionCount: number;
  chartRequestCount: number;
  budgetLimited: boolean;
  failureReason: string | null;
  createdAt: string;
  completedAt: string | null;
}

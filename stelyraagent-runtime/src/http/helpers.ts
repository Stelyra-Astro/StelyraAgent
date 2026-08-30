import type { Context } from 'hono';
import type { RuntimeServices } from './runtime-services.ts';
import type { RunView } from '../run/run-service.ts';

export function bearerToken(header: string | undefined): string | null {
  if (!header?.startsWith('Bearer ')) return null;
  const token = header.slice(7).trim();
  return token.length > 0 ? token : null;
}

export function requirePrincipal(c: Context, services: RuntimeServices): { accountId: string; sessionId: string } {
  const token = bearerToken(c.req.header('authorization'));
  const principal = token ? services.sessions.verifyAccess(token) : null;
  if (!principal) throw new HTTPError(401, 'unauthorized');
  return principal;
}

export function requireRunOwnership(run: RunView, accountId: string, services: RuntimeServices): void {
  if (!run.walletId) throw new HTTPError(403, 'run_has_no_wallet');
  const wallet = services.credits.getWallet(run.walletId);
  if (!wallet || wallet.accountId !== accountId) throw new HTTPError(403, 'forbidden');
}

export function serializeRun(run: RunView): Record<string, unknown> {
  const payload = run.payload ?? {};
  const finalAnswer = payload.finalAnswer ?? null;
  return {
    run_id: run.runId,
    status: run.status,
    action: run.pendingAction ? {
      id: run.pendingAction.id,
      type: run.pendingAction.type,
      tool: run.pendingAction.tool ?? null,
      payload: run.pendingAction.payload,
    } : null,
    final_answer: finalAnswer,
    usage: {
      input_tokens: run.inputTokens,
      output_tokens: run.outputTokens,
      reasoning_tokens: run.reasoningTokens,
      provider_cost: run.providerCost,
      tool_rounds: run.toolRounds,
    },
    failure_reason: run.failureReason,
    created_at: run.createdAt,
    completed_at: run.completedAt,
  };
}

export class HTTPError extends Error {
  readonly status: number;
  readonly code: string;

  constructor(status: number, code: string, message = code) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

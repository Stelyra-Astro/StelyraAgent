import { Hono } from 'hono';
import { z } from 'zod';
import type { RuntimeServices } from './runtime-services.ts';
import { HTTPError, requirePrincipal } from './helpers.ts';

const reconcileSchema = z.object({
  signed_transaction: z.string().min(1),
});

export function createAccountRoutes(services: RuntimeServices): Hono {
  const routes = new Hono();

  routes.get('/account', (c) => {
    const principal = requirePrincipal(c, services);
    const bundle = services.accountService.getActiveBundle(principal.accountId);
    return c.json({
      account_id: bundle.account.accountId,
      generation: bundle.account.generation,
      wallet_id: bundle.wallet.walletId,
      app_account_token: bundle.wallet.appAccountToken,
      status: bundle.account.status,
    });
  });

  routes.post('/account/reset', (c) => {
    const principal = requirePrincipal(c, services);
    const current = services.accountService.getActiveBundle(principal.accountId);
    services.runService.cancelActiveRunsForWallet(current.wallet.walletId);
    services.sessions.revokeByAccount(principal.accountId);
    const next = services.accountService.reset(principal.accountId);
    const tokens = services.sessions.issue(next.account.accountId);
    return c.json({
      account_id: next.account.accountId,
      generation: next.account.generation,
      wallet_id: next.wallet.walletId,
      app_account_token: next.wallet.appAccountToken,
      credits: next.wallet.availableBalance,
      access_token: tokens.accessToken,
      refresh_token: tokens.refreshToken,
      access_expires_at: tokens.accessExpiresAt,
      refresh_expires_at: tokens.refreshExpiresAt,
    });
  });

  routes.delete('/account', async (c) => {
    const principal = requirePrincipal(c, services);
    const current = services.accountService.getActiveBundle(principal.accountId);
    services.runService.cancelActiveRunsForWallet(current.wallet.walletId);
    services.sessions.revokeByAccount(principal.accountId);
    const result = await services.accountDeletionService.delete(principal.accountId);
    return c.json({ deleted: true, apple_token_revocation: result.appleRevocation });
  });

  routes.get('/credits', (c) => {
    const principal = requirePrincipal(c, services);
    const { wallet } = services.accountService.getActiveBundle(principal.accountId);
    return c.json({
      wallet_id: wallet.walletId,
      balance: wallet.availableBalance,
      reserved: wallet.reservedBalance,
      spent: wallet.spentBalance,
    });
  });

  routes.get('/purchases', (c) => {
    const principal = requirePrincipal(c, services);
    const { wallet } = services.accountService.getActiveBundle(principal.accountId);
    return c.json({ purchases: services.iapRepository.listByWallet(wallet.walletId) });
  });

  routes.post('/iap/reconcile', async (c) => {
    const principal = requirePrincipal(c, services);
    const { wallet } = services.accountService.getActiveBundle(principal.accountId);
    const body = reconcileSchema.parse(await c.req.json());
    let verified;
    try {
      verified = await services.transactionVerifier.verify(body.signed_transaction);
    } catch (error) {
      throw new HTTPError(503, 'iap_verification_unavailable', error instanceof Error ? error.message : 'IAP verification unavailable');
    }
    if (verified.appAccountToken !== wallet.appAccountToken) {
      throw new HTTPError(409, 'app_account_token_mismatch');
    }
    const result = services.iapService.reconcileVerified({
      transactionId: verified.transactionId,
      walletId: wallet.walletId,
      appAccountToken: verified.appAccountToken,
      productId: verified.productId,
      credits: verified.credits,
    });
    return c.json({ status: result.status, credits: services.credits.getWallet(wallet.walletId)?.availableBalance ?? 0 });
  });

  routes.get('/subscription', (c) => {
    requirePrincipal(c, services);
    return c.json({ status: 'managed_by_apple', manage_in_app_store: true });
  });

  return routes;
}

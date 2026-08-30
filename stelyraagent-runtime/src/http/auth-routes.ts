import { Hono } from 'hono';
import { z } from 'zod';
import type { RuntimeServices } from './runtime-services.ts';
import { HTTPError, requirePrincipal } from './helpers.ts';

const appleAuthSchema = z.object({
  identity_token: z.string().min(1),
  authorization_code: z.string().min(1),
  nonce: z.string().min(1),
});

const refreshSchema = z.object({ refresh_token: z.string().min(1) });

export function createAuthRoutes(services: RuntimeServices): Hono {
  const routes = new Hono();

  routes.post('/apple', async (c) => {
    const body = appleAuthSchema.parse(await c.req.json());
    const verified = await services.appleVerifier.verify(body.identity_token, body.nonce);
    const bundle = services.accountService.signInOrCreate(verified.appleSub, 0);
    const exchange = await services.appleTokenExchange.exchange(body.authorization_code);
    if (exchange.refreshToken && services.secretBox) {
      services.accounts.setEncryptedAppleRefreshToken(
        bundle.account.identityId,
        services.secretBox.encrypt(exchange.refreshToken),
      );
    }
    const tokens = services.sessions.issue(bundle.account.accountId);
    return c.json({
      account_id: bundle.account.accountId,
      generation: bundle.account.generation,
      wallet_id: bundle.wallet.walletId,
      app_account_token: bundle.wallet.appAccountToken,
      credits: bundle.wallet.availableBalance,
      access_token: tokens.accessToken,
      refresh_token: tokens.refreshToken,
      access_expires_at: tokens.accessExpiresAt,
      refresh_expires_at: tokens.refreshExpiresAt,
    });
  });

  routes.post('/refresh', async (c) => {
    const body = refreshSchema.parse(await c.req.json());
    try {
      const tokens = services.sessions.refresh(body.refresh_token);
      return c.json({
        access_token: tokens.accessToken,
        refresh_token: tokens.refreshToken,
        access_expires_at: tokens.accessExpiresAt,
        refresh_expires_at: tokens.refreshExpiresAt,
      });
    } catch {
      throw new HTTPError(401, 'invalid_refresh_token');
    }
  });

  routes.post('/logout', (c) => {
    const principal = requirePrincipal(c, services);
    services.sessions.revokeSession(principal.sessionId);
    return c.body(null, 204);
  });

  return routes;
}

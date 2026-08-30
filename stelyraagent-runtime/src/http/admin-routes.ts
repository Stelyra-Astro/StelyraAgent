import { Hono } from 'hono';
import type { RuntimeServices } from './runtime-services.ts';
import { HTTPError } from './helpers.ts';

export function createAdminRoutes(services: RuntimeServices): Hono {
  const routes = new Hono();
  routes.use('*', async (c, next) => {
    if (!services.adminAuth) throw new HTTPError(503, 'admin_auth_not_configured');
    if (!services.adminAuth.verify(c.req.header('authorization'))) throw new HTTPError(401, 'admin_unauthorized');
    await next();
  });
  routes.get('/dashboard', (c) => c.json(services.adminRepository.dashboard()));
  routes.get('/runs', (c) => c.json({ runs: services.adminRepository.recentRuns() }));
  routes.get('/iap', (c) => c.json({ transactions: services.adminRepository.recentIAP() }));
  routes.get('/models', (c) => c.json({ models: services.modelCatalog.listOperational() }));
  routes.get('/provider-usage', (c) => c.json({ usage: services.adminRepository.providerUsage() }));
  routes.get('/runtime-config', (c) => c.json(services.config));
  routes.get('/health', (c) => c.json({ ok: true, database: 'sqlite' }));
  return routes;
}

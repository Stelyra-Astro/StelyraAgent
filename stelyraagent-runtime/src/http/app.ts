import { Hono } from 'hono';
import { ZodError } from 'zod';
import { cors } from 'hono/cors';
import type { RuntimeServices } from './runtime-services.ts';
import { HTTPError } from './helpers.ts';
import { createConfigRoutes } from './config-routes.ts';
import { createAuthRoutes } from './auth-routes.ts';
import { createAccountRoutes } from './account-routes.ts';
import { createAgentRoutes } from './agent-routes.ts';
import { createAdminRoutes } from './admin-routes.ts';

export function createApp(services: RuntimeServices): Hono {
  const app = new Hono();
  app.use('/v1/admin/*', cors({ origin: services.config.adminOrigin, allowHeaders: ['Authorization', 'Content-Type'], allowMethods: ['GET', 'OPTIONS'] }));
  app.get('/health', (c) => c.json({ ok: true, service: 'stelyraagent-runtime' }));
  app.route('/v1', createConfigRoutes(services));
  app.route('/v1/auth', createAuthRoutes(services));
  app.route('/v1', createAccountRoutes(services));
  app.route('/v1', createAgentRoutes(services));
  app.route('/v1/admin', createAdminRoutes(services));

  app.onError((error, c) => {
    if (error instanceof HTTPError) {
      return c.json({ error: error.code, message: error.message }, error.status as 400);
    }
    if (error instanceof ZodError) {
      return c.json({ error: 'invalid_request', issues: error.issues }, 400);
    }
    console.error(error);
    return c.json({ error: 'internal_error' }, 500);
  });
  return app;
}

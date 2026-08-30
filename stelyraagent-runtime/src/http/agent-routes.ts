import { randomUUID } from 'node:crypto';
import { Hono } from 'hono';
import { z } from 'zod';
import type { RuntimeServices } from './runtime-services.ts';
import { HTTPError, requirePrincipal, requireRunOwnership, serializeRun } from './helpers.ts';
import { RunAdmissionError } from '../policy/run-admission-policy.ts';


const localMemorySchema = z.object({
  conversationGoal: z.string().max(500).optional(),
  selectedPeople: z.array(z.string().max(120)).max(8).optional(),
  selectedThemes: z.array(z.string().max(120)).max(8).optional(),
  previousTimeScope: z.string().max(240).optional(),
  previousLocations: z.array(z.string().max(160)).max(4).optional(),
  chartAssetRefs: z.array(z.string().max(80)).max(20).optional(),
  previousConclusions: z.array(z.string().max(800)).max(3).optional(),
  openQuestions: z.array(z.string().max(400)).max(3).optional(),
  analysisRefs: z.array(z.string().max(80)).max(10).optional(),
}).strict();

const createRunSchema = z.object({
  question: z.string().min(1).max(20_000),
  client_manifest: z.object({
    capabilityManifestVersion: z.number().int().positive(),
    supportedCapabilities: z.array(z.string()),
    clientVersion: z.string().min(1),
    calculationSchemaVersion: z.union([z.string().min(1), z.number().int().positive()]),
  }),
  draft_context: z.array(z.record(z.string(), z.unknown())).optional(),
  model_id: z.string().min(1).max(120).optional(),
  local_memory: localMemorySchema.optional(),
});

const actionSchema = z.object({
  action_id: z.string().min(1),
  result: z.record(z.string(), z.unknown()),
});

export function createAgentRoutes(services: RuntimeServices): Hono {
  const routes = new Hono();

  routes.post('/runs', async (c) => {
    const principal = requirePrincipal(c, services);
    const { wallet } = services.accountService.getActiveBundle(principal.accountId);
    const body = createRunSchema.parse(await c.req.json());
    const defaultModel = services.modelCatalog.listPublic()[0]?.id;
    const modelId = body.model_id ?? defaultModel;
    if (!modelId) throw new HTTPError(503, 'no_model_available', 'No StelyraAgent model is currently available');
    const admission = services.admission.admit({
      question: body.question,
      modelId,
      draftContext: body.draft_context ?? [],
    });
    const runId = randomUUID();
    services.runService.createRun({
      runId,
      walletId: wallet.walletId,
      creditsRequired: admission.model.creditsRequired,
      payload: {
        question: body.question,
        clientCapabilities: body.client_manifest.supportedCapabilities,
        clientManifest: body.client_manifest,
        draftContext: body.draft_context ?? [],
        localMemory: body.local_memory ?? null,
        modelId: admission.model.id,
        modelPolicyVersion: 1,
      },
    });
    services.runService.startReasoning(runId);
    try {
      await services.agent.advance(runId);
    } catch (error) {
      services.runService.fail(runId, error instanceof Error ? error.message : 'agent_error');
      throw error;
    }
    return c.json(serializeRun(services.runService.getRun(runId)), 201);
  });

  routes.get('/runs/:runId', (c) => {
    const principal = requirePrincipal(c, services);
    const run = services.runService.getRun(c.req.param('runId'));
    requireRunOwnership(run, principal.accountId, services);
    return c.json(serializeRun(run));
  });

  routes.post('/runs/:runId/actions', async (c) => {
    const principal = requirePrincipal(c, services);
    const runId = c.req.param('runId');
    const run = services.runService.getRun(runId);
    requireRunOwnership(run, principal.accountId, services);
    const body = actionSchema.parse(await c.req.json());
    const submitted = services.runService.submitAction(runId, body.action_id, body.result);
    if (!submitted.wasDuplicate || submitted.run.status === 'resuming') {
      try {
        await services.agent.advance(runId);
      } catch (error) {
        services.runService.fail(runId, error instanceof Error ? error.message : 'agent_error');
        throw error;
      }
    }
    return c.json(serializeRun(services.runService.getRun(runId)));
  });

  routes.post('/runs/:runId/cancel', (c) => {
    const principal = requirePrincipal(c, services);
    const run = services.runService.getRun(c.req.param('runId'));
    requireRunOwnership(run, principal.accountId, services);
    return c.json(serializeRun(services.runService.cancel(run.runId)));
  });

  routes.post('/runs/:runId/ack', (c) => {
    const principal = requirePrincipal(c, services);
    const run = services.runService.getRun(c.req.param('runId'));
    requireRunOwnership(run, principal.accountId, services);
    return c.json(serializeRun(services.runService.acknowledge(run.runId)));
  });

  routes.onError((error, c) => {
    if (error instanceof HTTPError) return c.json({ error: error.code, message: error.message }, error.status as 400);
    if (error instanceof RunAdmissionError) return c.json({ error: error.code, message: error.message }, error.status);
    throw error;
  });

  return routes;
}

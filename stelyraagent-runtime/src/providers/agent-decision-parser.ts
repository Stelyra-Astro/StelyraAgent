import { z } from 'zod';
import type { ProviderDecision } from './model-provider.ts';

const evidenceRequestSchema = z.object({
  capability: z.string().min(1),
  subjects: z.array(z.string().min(1)).min(1).max(4),
  time_scope: z.record(z.string(), z.unknown()).optional(),
  locations: z.array(z.string()).max(2).optional(),
});

const evidenceRefs = z.array(z.string().min(1)).max(12);
const structuredFinalSchema = z.object({
  answer: z.string().min(1).max(20_000),
  keyFactors: z.array(z.object({
    title: z.string().min(1).max(120),
    summary: z.string().max(1_500).optional(),
    supportingEvidenceRefs: evidenceRefs,
  })).max(5),
  timingWindows: z.array(z.object({
    title: z.string().max(120).optional(),
    start: z.string().max(80).optional(),
    end: z.string().max(80).optional(),
    summary: z.string().max(1_500).optional(),
    supportingEvidenceRefs: evidenceRefs.optional(),
  })).max(5),
  chartRefs: z.array(z.string().min(1)).max(12),
  limitations: z.array(z.string().max(500)).max(5),
  followUps: z.array(z.string().max(300)).max(3),
});

const decisionSchema = z.discriminatedUnion('kind', [
  z.object({
    kind: z.literal('astrology_tool'),
    requests: z.array(evidenceRequestSchema).min(1).max(8),
    reason: z.string().min(1).max(1_000),
  }),
  z.object({
    kind: z.literal('interaction'),
    interaction: z.object({
      kind: z.enum(['analysis_choice', 'clarify_intent', 'required_input', 'plan_review']),
      prompt: z.string().min(1).max(2_000),
      options: z.array(z.string().max(200)).max(8).optional(),
      fields: z.array(z.record(z.string(), z.unknown())).max(3).optional(),
      purpose: z.string().max(120).optional(),
    }),
  }),
  z.object({
    kind: z.literal('final'),
    output: structuredFinalSchema,
    budgetLimited: z.boolean().optional(),
    title: z.string().max(80).optional(),
  }),
]);

export function parseAgentDecision(text: string): ProviderDecision {
  const trimmed = text.trim();
  const candidate = trimmed.startsWith('```')
    ? trimmed.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '')
    : trimmed;
  let parsed: unknown;
  try { parsed = JSON.parse(candidate); } catch { throw new Error('Model returned non-JSON agent decision'); }
  const result = decisionSchema.safeParse(parsed);
  if (!result.success) throw new Error(`Model returned invalid agent decision: ${result.error.message}`);
  if (result.data.kind !== 'final') return result.data;
  return {
    kind: 'final',
    text: result.data.output.answer,
    structured: result.data.output,
    budgetLimited: result.data.budgetLimited,
    title: result.data.title,
  };
}

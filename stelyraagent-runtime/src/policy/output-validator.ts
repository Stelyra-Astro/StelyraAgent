export interface StructuredFinalAnswer {
  answer: string;
  keyFactors: Array<{ title: string; supportingEvidenceRefs: string[]; summary?: string }>;
  timingWindows: Array<{ title?: string; start?: string; end?: string; summary?: string; supportingEvidenceRefs?: string[] }>;
  chartRefs: string[];
  limitations: string[];
  followUps: string[];
}

export class OutputValidator {
  private readonly maxCharacters: number;

  constructor(options: { maxCharacters: number }) {
    this.maxCharacters = options.maxCharacters;
  }

  validate(value: StructuredFinalAnswer, context: { allowedEvidenceIds: Set<string> }): StructuredFinalAnswer {
    if (!value.answer.trim()) throw new Error('Final output answer is empty');
    const refs = collectEvidenceRefs(value);
    for (const ref of refs) {
      if (!context.allowedEvidenceIds.has(ref)) throw new Error(`Final output referenced unknown evidence: ${ref}`);
    }
    const naturalText = collectText(value).join('\n');
    if (naturalText.length > this.maxCharacters) throw new Error('Final output exceeds configured length limit');
    if (containsProhibitedDeterminism(naturalText)) throw new Error('Final output contains a deterministic or high-risk claim outside StelyraAgent policy');
    return value;
  }
}

function collectEvidenceRefs(value: StructuredFinalAnswer): string[] {
  const refs = value.keyFactors.flatMap((item) => item.supportingEvidenceRefs);
  for (const window of value.timingWindows) refs.push(...(window.supportingEvidenceRefs ?? []));
  return [...new Set(refs)];
}

function collectText(value: StructuredFinalAnswer): string[] {
  return [
    value.answer,
    ...value.keyFactors.flatMap((item) => [item.title, item.summary ?? '']),
    ...value.timingWindows.flatMap((item) => [item.title ?? '', item.summary ?? '']),
    ...value.limitations,
    ...value.followUps,
  ];
}

function containsProhibitedDeterminism(text: string): boolean {
  const patterns = [
    /\b(?:will definitely|guaranteed|certain(?:ly)?|inevitable|destined to)\b.{0,80}\b(?:marry|divorce|break up|get rich|profit|win|lose|promotion|promoted|fired|laid off|pregnant|pregnancy|die|death)\b/i,
    /\b(?:buy|sell|short|invest in|borrow|take out a loan)\b.{0,80}\b(?:guaranteed|certain|definitely|profit|return)\b/i,
    /\byou (?:have|suffer from)\b.{0,40}\b(?:depression|bipolar|cancer|adhd|autism|disorder|disease)\b/i,
    /\b(?:一定|必然|注定|肯定会).{0,30}(?:结婚|分手|离婚|复合|怀孕|发财|赚钱|升职|被裁|死亡|去世)/,
  ];
  return patterns.some((pattern) => pattern.test(text));
}

import type { ModelCatalog, ModelPolicy } from './model-catalog.ts';

export interface RunAdmissionInput {
  question: string;
  modelId: string;
  draftContext: Array<Record<string, unknown>>;
}

export interface RunAdmissionDecision {
  model: ModelPolicy;
  scope: 'astrology';
}

export class RunAdmissionError extends Error {
  readonly status: 400 | 422;
  readonly code: 'model_not_available' | 'out_of_scope';
  constructor(status: 400 | 422, code: 'model_not_available' | 'out_of_scope', message: string) {
    super(message);
    this.name = 'RunAdmissionError';
    this.status = status;
    this.code = code;
  }
}

export class RunAdmissionPolicy {
  private readonly models: ModelCatalog;

  constructor(models: ModelCatalog) {
    this.models = models;
  }

  admit(input: RunAdmissionInput): RunAdmissionDecision {
    let model: ModelPolicy;
    try {
      model = this.models.require(input.modelId);
    } catch {
      throw new RunAdmissionError(400, 'model_not_available', 'The selected StelyraAgent model is not available.');
    }
    if (isExplicitGenericProxyRequest(input.question, input.draftContext)) {
      throw new RunAdmissionError(422, 'out_of_scope', 'This request is outside StelyraAgent scope. StelyraAgent is for astrology-based analysis and reflection.');
    }
    return { model, scope: 'astrology' };
  }
}

function isExplicitGenericProxyRequest(question: string, draftContext: Array<Record<string, unknown>>): boolean {
  if (draftContext.length > 0) return false;
  const q = question.trim().toLowerCase();
  const astrologySignals = /\b(astrolog|chart|transit|natal|synastry|composite|horoscope|zodiac|planet|house|aspect|progression|solar return|lunar return|relationship|career|money|family|wellbeing|life direction)\b|星盘|占星|行运|本命|合盘|比较盘|组合盘|次限|三限|太阳弧/.test(q);
  if (astrologySignals) return false;
  return [
    /\b(?:write|build|code|debug|implement)\b.{0,40}\b(?:python|javascript|typescript|swift|java|sql|web scraper|api|website|app)\b/,
    /\btranslate\b.{0,120}\b(?:english|french|spanish|german|italian|portuguese|chinese|japanese|korean)\b/,
    /\b(?:summarize|proofread|rewrite)\b.{0,80}\b(?:article|essay|email|document|paper)\b/,
    /写.{0,20}(?:代码|程序|爬虫|邮件|论文|文案)/,
    /翻译.{0,80}(?:文章|文档|邮件|论文)/,
  ].some((pattern) => pattern.test(q));
}

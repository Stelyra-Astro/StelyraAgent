export type ResolutionDetail = 'overview' | 'balanced' | 'detailed' | 'major_windows';
export type ResolutionLabel = 'six_hours' | '12_hours' | 'daily' | 'three_days' | 'weekly' | 'two_weeks' | 'monthly' | 'quarterly' | 'six_months' | 'yearly' | 'five_years' | 'ten_years' | 'major_windows_only';

export interface ResolutionDecision { label: ResolutionLabel; approximateSeconds: number | null; }

const DAY = 86_400_000;
const YEAR = 365 * DAY;

export class ResolutionPolicy {
  resolve(input: { spanMs: number; detail?: ResolutionDetail }): ResolutionDecision {
    const span = Math.max(0, input.spanMs);
    const detail = input.detail ?? 'balanced';
    if (detail === 'major_windows') return { label: 'major_windows_only', approximateSeconds: null };

    let row: [ResolutionLabel, ResolutionLabel, ResolutionLabel];
    if (span <= 7 * DAY) row = ['daily', '12_hours', 'six_hours'];
    else if (span <= 31 * DAY) row = ['weekly', 'three_days', 'daily'];
    else if (span <= 6 * 31 * DAY) row = ['monthly', 'two_weeks', 'weekly'];
    else if (span <= 2 * YEAR) row = ['monthly', 'two_weeks', 'weekly'];
    else if (span <= 10 * YEAR) row = ['yearly', 'six_months', 'quarterly'];
    else if (span <= 30 * YEAR) row = ['five_years', 'yearly', 'six_months'];
    else row = ['ten_years', 'five_years', 'yearly'];
    const label = row[detail === 'overview' ? 0 : detail === 'detailed' ? 2 : 1];
    return { label, approximateSeconds: seconds(label) };
  }
}

function seconds(label: ResolutionLabel): number | null {
  switch (label) {
    case 'six_hours': return 21_600;
    case '12_hours': return 43_200;
    case 'daily': return 86_400;
    case 'three_days': return 3 * 86_400;
    case 'weekly': return 7 * 86_400;
    case 'two_weeks': return 14 * 86_400;
    case 'monthly': return 30 * 86_400;
    case 'quarterly': return 91 * 86_400;
    case 'six_months': return 182 * 86_400;
    case 'yearly': return 365 * 86_400;
    case 'five_years': return 5 * 365 * 86_400;
    case 'ten_years': return 10 * 365 * 86_400;
    case 'major_windows_only': return null;
  }
}

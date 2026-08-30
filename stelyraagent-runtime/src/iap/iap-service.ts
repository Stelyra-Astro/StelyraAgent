import type { SqliteCreditRepository } from '../repositories/sqlite-credit-repository.ts';
import type { IAPCreditInput, SqliteIAPRepository } from '../repositories/sqlite-iap-repository.ts';

export class IAPService {
  private readonly iap: SqliteIAPRepository;
  private readonly credits: SqliteCreditRepository;

  constructor(iap: SqliteIAPRepository, credits: SqliteCreditRepository) {
    this.iap = iap;
    this.credits = credits;
  }

  reconcileVerified(input: IAPCreditInput): { status: 'credited' | 'already_processed' } {
    const existing = this.iap.get(input.transactionId);
    if (existing) return { status: 'already_processed' };

    const wallet = this.credits.getWallet(input.walletId);
    if (!wallet) throw new Error('Wallet not found');
    if (wallet.appAccountToken !== input.appAccountToken) {
      throw new Error('appAccountToken does not match wallet');
    }
    return { status: this.iap.recordAndCredit(input).status };
  }
}

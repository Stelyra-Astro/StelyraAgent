import type { AstroAccountRecord, SqliteAccountRepository } from '../repositories/sqlite-account-repository.ts';
import type { SqliteCreditRepository } from '../repositories/sqlite-credit-repository.ts';
import type { WalletRecord } from '../domain/types.ts';

export interface ActiveAccountBundle {
  account: AstroAccountRecord;
  wallet: WalletRecord;
}

export class AccountService {
  private readonly accounts: SqliteAccountRepository;
  private readonly credits: SqliteCreditRepository;

  constructor(accounts: SqliteAccountRepository, credits: SqliteCreditRepository) {
    this.accounts = accounts;
    this.credits = credits;
  }

  signInOrCreate(appleSub: string, initialBalance = 0): ActiveAccountBundle {
    const identity = this.accounts.findOrCreateIdentity(appleSub);
    let account = this.accounts.getActiveAccount(identity.identityId);
    if (!account) {
      account = this.accounts.createAccount(identity.identityId, this.accounts.nextGeneration(identity.identityId));
    }
    let wallet = this.credits.getActiveWalletForAccount(account.accountId);
    if (!wallet) wallet = this.credits.createWallet(account.accountId, initialBalance);
    return { account, wallet };
  }

  getActiveBundle(accountId: string): ActiveAccountBundle {
    const account = this.accounts.getAccount(accountId);
    if (!account || account.status !== 'active') throw new Error('Active account not found');
    const wallet = this.credits.getActiveWalletForAccount(accountId);
    if (!wallet) throw new Error('Active wallet not found');
    return { account, wallet };
  }

  reset(accountId: string): ActiveAccountBundle {
    const account = this.accounts.getAccount(accountId);
    if (!account || account.status !== 'active') throw new Error('Active account not found');
    const oldWallet = this.credits.getActiveWalletForAccount(accountId);
    if (oldWallet) this.credits.closeWallet(oldWallet.walletId);
    this.accounts.markReset(accountId);

    const next = this.accounts.createAccount(account.identityId, account.generation + 1);
    const wallet = this.credits.createWallet(next.accountId, 0);
    return { account: next, wallet };
  }

  delete(accountId: string): void {
    const account = this.accounts.getAccount(accountId);
    if (!account) return;
    const wallet = this.credits.getActiveWalletForAccount(accountId);
    if (wallet) this.credits.closeWallet(wallet.walletId);
    this.accounts.markDeleted(accountId);
  }
}

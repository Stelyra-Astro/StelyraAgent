import type { AccountService } from './account-service.ts';
import type { SqliteAccountRepository } from '../repositories/sqlite-account-repository.ts';
import type { SecretBox } from '../auth/secret-box.ts';

export interface AppleRefreshTokenRevoker {
  revoke(refreshToken: string): Promise<void>;
}

export interface AccountDeletionResult {
  appleRevocation: 'revoked' | 'not_available' | 'failed';
}

export class AppleAccountDeletionService {
  private readonly accounts: SqliteAccountRepository;
  private readonly accountService: AccountService;
  private readonly revoker: AppleRefreshTokenRevoker;
  private readonly secretBox: SecretBox | null;

  constructor(
    accounts: SqliteAccountRepository,
    accountService: AccountService,
    revoker: AppleRefreshTokenRevoker,
    secretBox: SecretBox | null,
  ) {
    this.accounts = accounts;
    this.accountService = accountService;
    this.revoker = revoker;
    this.secretBox = secretBox;
  }

  async delete(accountId: string): Promise<AccountDeletionResult> {
    const account = this.accounts.getAccount(accountId);
    if (!account) return { appleRevocation: 'not_available' };

    const encryptedRefreshToken = this.accounts.getEncryptedAppleRefreshToken(account.identityId);
    let appleRevocation: AccountDeletionResult['appleRevocation'] = 'not_available';

    if (encryptedRefreshToken && this.secretBox) {
      try {
        const refreshToken = this.secretBox.decrypt(encryptedRefreshToken);
        await this.revoker.revoke(refreshToken);
        appleRevocation = 'revoked';
      } catch {
        // Account deletion is a user privacy action and must still complete even if Apple is unavailable.
        appleRevocation = 'failed';
      }
    }

    // Never retain the credential after the user asked for deletion, regardless of revocation outcome.
    this.accounts.clearAppleRefreshToken(account.identityId);
    this.accountService.delete(accountId);
    return { appleRevocation };
  }
}

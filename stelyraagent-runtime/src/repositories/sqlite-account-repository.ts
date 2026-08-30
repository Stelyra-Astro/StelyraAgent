import { randomUUID } from 'node:crypto';
import type { AstroDatabase } from '../db/sqlite-database.ts';

export interface AppleIdentityRecord {
  identityId: string;
  appleSub: string;
  status: 'active' | 'revoked';
}

export interface AstroAccountRecord {
  accountId: string;
  identityId: string;
  generation: number;
  status: 'active' | 'reset' | 'deleted';
  createdAt: string;
}

export class SqliteAccountRepository {
  private readonly db: AstroDatabase;

  constructor(db: AstroDatabase) {
    this.db = db;
  }

  findOrCreateIdentity(appleSub: string): AppleIdentityRecord {
    const existing = this.findIdentityBySub(appleSub);
    if (existing) return existing;
    const identityId = randomUUID();
    const now = new Date().toISOString();
    this.db.prepare(`
      INSERT INTO apple_identities (identity_id, apple_sub, status, created_at, updated_at)
      VALUES (?, ?, 'active', ?, ?)
    `).run(identityId, appleSub, now, now);
    return this.findIdentityBySub(appleSub)!;
  }

  findIdentityBySub(appleSub: string): AppleIdentityRecord | null {
    const row = this.db.prepare(`
      SELECT identity_id, apple_sub, status FROM apple_identities WHERE apple_sub = ?
    `).get(appleSub) as Record<string, unknown> | undefined;
    if (!row) return null;
    return {
      identityId: String(row.identity_id),
      appleSub: String(row.apple_sub),
      status: row.status === 'revoked' ? 'revoked' : 'active',
    };
  }

  setEncryptedAppleRefreshToken(identityId: string, encryptedToken: string): void {
    this.db.prepare(`
      UPDATE apple_identities SET apple_refresh_token_encrypted = ?, updated_at = ?
      WHERE identity_id = ?
    `).run(encryptedToken, new Date().toISOString(), identityId);
  }


  getEncryptedAppleRefreshToken(identityId: string): string | null {
    const row = this.db.prepare(`
      SELECT apple_refresh_token_encrypted FROM apple_identities WHERE identity_id = ?
    `).get(identityId) as { apple_refresh_token_encrypted?: string | null } | undefined;
    return row?.apple_refresh_token_encrypted ?? null;
  }

  clearAppleRefreshToken(identityId: string): void {
    this.db.prepare(`
      UPDATE apple_identities SET apple_refresh_token_encrypted = NULL, updated_at = ?
      WHERE identity_id = ?
    `).run(new Date().toISOString(), identityId);
  }

  getAccount(accountId: string): AstroAccountRecord | null {
    const row = this.db.prepare(`
      SELECT account_id, identity_id, generation, status, created_at
      FROM accounts WHERE account_id = ?
    `).get(accountId) as Record<string, unknown> | undefined;
    return row ? this.mapAccount(row) : null;
  }

  getActiveAccount(identityId: string): AstroAccountRecord | null {
    const row = this.db.prepare(`
      SELECT account_id, identity_id, generation, status, created_at
      FROM accounts WHERE identity_id = ? AND status = 'active'
      ORDER BY generation DESC LIMIT 1
    `).get(identityId) as Record<string, unknown> | undefined;
    return row ? this.mapAccount(row) : null;
  }

  nextGeneration(identityId: string): number {
    const row = this.db.prepare(`
      SELECT COALESCE(MAX(generation), 0) AS max_generation FROM accounts WHERE identity_id = ?
    `).get(identityId) as { max_generation: number };
    return Number(row.max_generation) + 1;
  }

  createAccount(identityId: string, generation: number): AstroAccountRecord {
    const accountId = randomUUID();
    const now = new Date().toISOString();
    this.db.prepare(`
      INSERT INTO accounts (account_id, identity_id, generation, status, created_at)
      VALUES (?, ?, ?, 'active', ?)
    `).run(accountId, identityId, generation, now);
    return this.getAccount(accountId)!;
  }

  markReset(accountId: string): void {
    this.db.prepare(`
      UPDATE accounts SET status = 'reset', reset_at = ? WHERE account_id = ? AND status = 'active'
    `).run(new Date().toISOString(), accountId);
  }

  markDeleted(accountId: string): void {
    this.db.prepare(`
      UPDATE accounts SET status = 'deleted', deleted_at = ? WHERE account_id = ?
    `).run(new Date().toISOString(), accountId);
  }

  private mapAccount(row: Record<string, unknown>): AstroAccountRecord {
    const rawStatus = String(row.status);
    const status: AstroAccountRecord['status'] = rawStatus === 'reset'
      ? 'reset'
      : rawStatus === 'deleted'
        ? 'deleted'
        : 'active';
    return {
      accountId: String(row.account_id),
      identityId: String(row.identity_id),
      generation: Number(row.generation),
      status,
      createdAt: String(row.created_at),
    };
  }
}

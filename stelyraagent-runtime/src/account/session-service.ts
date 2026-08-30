import { createHash, randomBytes, randomUUID } from 'node:crypto';
import type { AstroDatabase } from '../db/sqlite-database.ts';

export interface SessionTokens {
  accessToken: string;
  refreshToken: string;
  accessExpiresAt: number;
  refreshExpiresAt: number;
}

export interface SessionPrincipal {
  sessionId: string;
  accountId: string;
}

export class SessionService {
  private readonly db: AstroDatabase;
  private readonly accessTTLSeconds: number;
  private readonly refreshTTLSeconds: number;

  constructor(db: AstroDatabase, options?: { accessTTLSeconds?: number; refreshTTLSeconds?: number }) {
    this.db = db;
    this.accessTTLSeconds = options?.accessTTLSeconds ?? 15 * 60;
    this.refreshTTLSeconds = options?.refreshTTLSeconds ?? 30 * 24 * 60 * 60;
  }

  issue(accountId: string): SessionTokens {
    const sessionId = randomUUID();
    const accessToken = this.generateToken('aa_at');
    const refreshToken = this.generateToken('aa_rt');
    const nowSeconds = Math.floor(Date.now() / 1000);
    const accessExpiresAt = nowSeconds + this.accessTTLSeconds;
    const refreshExpiresAt = nowSeconds + this.refreshTTLSeconds;
    this.db.prepare(`
      INSERT INTO sessions (
        session_id, account_id, access_hash, refresh_hash,
        access_expires_at, refresh_expires_at, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(
      sessionId,
      accountId,
      this.hash(accessToken),
      this.hash(refreshToken),
      accessExpiresAt,
      refreshExpiresAt,
      new Date().toISOString(),
    );
    return { accessToken, refreshToken, accessExpiresAt, refreshExpiresAt };
  }

  verifyAccess(accessToken: string): SessionPrincipal | null {
    const nowSeconds = Math.floor(Date.now() / 1000);
    const row = this.db.prepare(`
      SELECT session_id, account_id FROM sessions
      WHERE access_hash = ? AND revoked_at IS NULL AND access_expires_at > ?
    `).get(this.hash(accessToken), nowSeconds) as Record<string, unknown> | undefined;
    if (!row) return null;
    return { sessionId: String(row.session_id), accountId: String(row.account_id) };
  }

  refresh(refreshToken: string): SessionTokens {
    const nowSeconds = Math.floor(Date.now() / 1000);
    const row = this.db.prepare(`
      SELECT session_id, account_id FROM sessions
      WHERE refresh_hash = ? AND revoked_at IS NULL AND refresh_expires_at > ?
    `).get(this.hash(refreshToken), nowSeconds) as Record<string, unknown> | undefined;
    if (!row) throw new Error('Invalid refresh token');
    this.revokeSession(String(row.session_id));
    return this.issue(String(row.account_id));
  }

  revokeSession(sessionId: string): void {
    this.db.prepare(`UPDATE sessions SET revoked_at = ? WHERE session_id = ? AND revoked_at IS NULL`)
      .run(Math.floor(Date.now() / 1000), sessionId);
  }

  revokeByAccount(accountId: string): void {
    this.db.prepare(`UPDATE sessions SET revoked_at = ? WHERE account_id = ? AND revoked_at IS NULL`)
      .run(Math.floor(Date.now() / 1000), accountId);
  }

  private generateToken(prefix: string): string {
    return `${prefix}_${randomBytes(32).toString('base64url')}`;
  }

  private hash(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }
}

import { randomUUID } from 'node:crypto';
import type { AstroDatabase } from '../db/sqlite-database.ts';
import type { CreditReservation, WalletRecord } from '../domain/types.ts';

export class InsufficientCreditsError extends Error {
  constructor() {
    super('Insufficient credits');
    this.name = 'InsufficientCreditsError';
  }
}

export class SqliteCreditRepository {
  private readonly db: AstroDatabase;

  constructor(db: AstroDatabase) {
    this.db = db;
  }

  createWallet(accountId: string, initialBalance = 0): WalletRecord {
    const walletId = randomUUID();
    const appAccountToken = randomUUID();
    const now = new Date().toISOString();
    this.db.prepare(`
      INSERT INTO wallets (
        wallet_id, account_id, app_account_token,
        available_balance, reserved_balance, spent_balance, status, created_at
      ) VALUES (?, ?, ?, ?, 0, 0, 'active', ?)
    `).run(walletId, accountId, appAccountToken, initialBalance, now);
    return this.getWallet(walletId)!;
  }

  getActiveWalletForAccount(accountId: string): WalletRecord | null {
    const row = this.db.prepare(`
      SELECT wallet_id FROM wallets
      WHERE account_id = ? AND status = 'active'
      ORDER BY created_at DESC LIMIT 1
    `).get(accountId) as { wallet_id: string } | undefined;
    return row ? this.getWallet(row.wallet_id) : null;
  }

  closeWallet(walletId: string): void {
    this.db.prepare(`
      UPDATE wallets SET status = 'closed', closed_at = ? WHERE wallet_id = ?
    `).run(new Date().toISOString(), walletId);
  }

  addCredits(walletId: string, amount: number): WalletRecord {
    this.db.prepare(`
      UPDATE wallets SET available_balance = available_balance + ?
      WHERE wallet_id = ? AND status = 'active'
    `).run(amount, walletId);
    const wallet = this.getWallet(walletId);
    if (!wallet) throw new Error('Wallet not found');
    return wallet;
  }

  getWallet(walletId: string): WalletRecord | null {
    const row = this.db.prepare(`
      SELECT wallet_id, account_id, app_account_token, available_balance,
             reserved_balance, spent_balance, status
      FROM wallets WHERE wallet_id = ?
    `).get(walletId) as Record<string, unknown> | undefined;
    if (!row) return null;
    return {
      walletId: String(row.wallet_id),
      accountId: String(row.account_id),
      appAccountToken: String(row.app_account_token),
      availableBalance: Number(row.available_balance),
      reservedBalance: Number(row.reserved_balance),
      spentBalance: Number(row.spent_balance),
      status: row.status === 'closed' ? 'closed' : 'active',
    };
  }

  reserve(walletId: string, runId: string, amount: number): CreditReservation {
    const existing = this.getReservationByRun(runId);
    if (existing) return existing;

    this.db.exec('BEGIN IMMEDIATE');
    try {
      const wallet = this.getWallet(walletId);
      if (!wallet || wallet.status !== 'active' || wallet.availableBalance < amount) {
        throw new InsufficientCreditsError();
      }
      const reservationId = randomUUID();
      const now = new Date().toISOString();
      this.db.prepare(`
        UPDATE wallets
        SET available_balance = available_balance - ?, reserved_balance = reserved_balance + ?
        WHERE wallet_id = ?
      `).run(amount, amount, walletId);
      this.db.prepare(`
        INSERT INTO credit_reservations (
          reservation_id, wallet_id, run_id, amount, status, created_at, updated_at
        ) VALUES (?, ?, ?, ?, 'reserved', ?, ?)
      `).run(reservationId, walletId, runId, amount, now, now);
      this.db.prepare(`
        INSERT INTO credit_ledger (entry_id, wallet_id, reservation_id, kind, amount, created_at)
        VALUES (?, ?, ?, 'reserve', ?, ?)
      `).run(randomUUID(), walletId, reservationId, -amount, now);
      this.db.exec('COMMIT');
      return this.getReservation(reservationId)!;
    } catch (error) {
      this.db.exec('ROLLBACK');
      throw error;
    }
  }

  commit(reservationId: string): CreditReservation {
    const existing = this.getReservation(reservationId);
    if (!existing) throw new Error('Credit reservation not found');
    if (existing.status === 'committed') return existing;
    if (existing.status === 'released') throw new Error('Released credit reservation cannot be committed');

    this.db.exec('BEGIN IMMEDIATE');
    try {
      const now = new Date().toISOString();
      this.db.prepare(`
        UPDATE wallets
        SET reserved_balance = reserved_balance - ?, spent_balance = spent_balance + ?
        WHERE wallet_id = ?
      `).run(existing.amount, existing.amount, existing.walletId);
      this.db.prepare(`
        UPDATE credit_reservations SET status = 'committed', updated_at = ?
        WHERE reservation_id = ?
      `).run(now, reservationId);
      this.db.prepare(`
        INSERT OR IGNORE INTO credit_ledger (entry_id, wallet_id, reservation_id, kind, amount, created_at)
        VALUES (?, ?, ?, 'commit', 0, ?)
      `).run(randomUUID(), existing.walletId, reservationId, now);
      this.db.exec('COMMIT');
      return this.getReservation(reservationId)!;
    } catch (error) {
      this.db.exec('ROLLBACK');
      throw error;
    }
  }

  release(reservationId: string): CreditReservation {
    const existing = this.getReservation(reservationId);
    if (!existing) throw new Error('Credit reservation not found');
    if (existing.status === 'released') return existing;
    if (existing.status === 'committed') throw new Error('Committed credit reservation cannot be released');

    this.db.exec('BEGIN IMMEDIATE');
    try {
      const now = new Date().toISOString();
      this.db.prepare(`
        UPDATE wallets
        SET reserved_balance = reserved_balance - ?, available_balance = available_balance + ?
        WHERE wallet_id = ?
      `).run(existing.amount, existing.amount, existing.walletId);
      this.db.prepare(`
        UPDATE credit_reservations SET status = 'released', updated_at = ?
        WHERE reservation_id = ?
      `).run(now, reservationId);
      this.db.prepare(`
        INSERT OR IGNORE INTO credit_ledger (entry_id, wallet_id, reservation_id, kind, amount, created_at)
        VALUES (?, ?, ?, 'release', ?, ?)
      `).run(randomUUID(), existing.walletId, reservationId, existing.amount, now);
      this.db.exec('COMMIT');
      return this.getReservation(reservationId)!;
    } catch (error) {
      this.db.exec('ROLLBACK');
      throw error;
    }
  }

  getReservation(reservationId: string): CreditReservation | null {
    const row = this.db.prepare(`
      SELECT reservation_id, wallet_id, run_id, amount, status
      FROM credit_reservations WHERE reservation_id = ?
    `).get(reservationId) as Record<string, unknown> | undefined;
    return row ? this.mapReservation(row) : null;
  }

  getReservationByRun(runId: string): CreditReservation | null {
    const row = this.db.prepare(`
      SELECT reservation_id, wallet_id, run_id, amount, status
      FROM credit_reservations WHERE run_id = ?
    `).get(runId) as Record<string, unknown> | undefined;
    return row ? this.mapReservation(row) : null;
  }

  private mapReservation(row: Record<string, unknown>): CreditReservation {
    return {
      reservationId: String(row.reservation_id),
      walletId: String(row.wallet_id),
      runId: String(row.run_id),
      amount: Number(row.amount),
      status: String(row.status) as CreditReservation['status'],
    };
  }
}

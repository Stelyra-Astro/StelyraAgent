import { randomUUID } from 'node:crypto';
import type { AstroDatabase } from '../db/sqlite-database.ts';

export interface IAPCreditInput {
  transactionId: string;
  walletId: string;
  appAccountToken: string;
  productId: string;
  credits: number;
}

export interface IAPTransactionRecord extends IAPCreditInput {
  status: 'credited';
  createdAt: string;
}

export class SqliteIAPRepository {
  private readonly db: AstroDatabase;

  constructor(db: AstroDatabase) {
    this.db = db;
  }

  get(transactionId: string): IAPTransactionRecord | null {
    const row = this.db.prepare(`
      SELECT transaction_id, wallet_id, app_account_token, product_id, credits, status, created_at
      FROM iap_transactions WHERE transaction_id = ?
    `).get(transactionId) as Record<string, unknown> | undefined;
    if (!row) return null;
    return {
      transactionId: String(row.transaction_id),
      walletId: String(row.wallet_id),
      appAccountToken: String(row.app_account_token),
      productId: String(row.product_id),
      credits: Number(row.credits),
      status: 'credited',
      createdAt: String(row.created_at),
    };
  }

  listByWallet(walletId: string, limit = 100): IAPTransactionRecord[] {
    const rows = this.db.prepare(`
      SELECT transaction_id, wallet_id, app_account_token, product_id, credits, status, created_at
      FROM iap_transactions WHERE wallet_id = ?
      ORDER BY created_at DESC LIMIT ?
    `).all(walletId, limit) as Array<Record<string, unknown>>;
    return rows.map((row) => ({
      transactionId: String(row.transaction_id),
      walletId: String(row.wallet_id),
      appAccountToken: String(row.app_account_token),
      productId: String(row.product_id),
      credits: Number(row.credits),
      status: 'credited' as const,
      createdAt: String(row.created_at),
    }));
  }

  recordAndCredit(input: IAPCreditInput): { status: 'credited' | 'already_processed'; transaction: IAPTransactionRecord } {
    const existing = this.get(input.transactionId);
    if (existing) return { status: 'already_processed', transaction: existing };

    this.db.exec('BEGIN IMMEDIATE');
    try {
      const wallet = this.db.prepare(`
        SELECT wallet_id, app_account_token, status FROM wallets WHERE wallet_id = ?
      `).get(input.walletId) as Record<string, unknown> | undefined;
      if (!wallet) throw new Error('Wallet not found');
      if (String(wallet.status) !== 'active') throw new Error('Wallet is closed');
      if (String(wallet.app_account_token) !== input.appAccountToken) {
        throw new Error('appAccountToken does not match wallet');
      }

      const now = new Date().toISOString();
      this.db.prepare(`
        INSERT INTO iap_transactions (
          transaction_id, wallet_id, app_account_token, product_id, credits, status, created_at
        ) VALUES (?, ?, ?, ?, ?, 'credited', ?)
      `).run(
        input.transactionId,
        input.walletId,
        input.appAccountToken,
        input.productId,
        input.credits,
        now,
      );
      this.db.prepare(`
        UPDATE wallets SET available_balance = available_balance + ? WHERE wallet_id = ?
      `).run(input.credits, input.walletId);
      this.db.prepare(`
        INSERT INTO credit_ledger (entry_id, wallet_id, reservation_id, kind, amount, created_at)
        VALUES (?, ?, NULL, ?, ?, ?)
      `).run(randomUUID(), input.walletId, `purchase:${input.transactionId}`, input.credits, now);
      this.db.exec('COMMIT');
      return { status: 'credited', transaction: this.get(input.transactionId)! };
    } catch (error) {
      this.db.exec('ROLLBACK');
      // A concurrent/idempotent retry can win the UNIQUE transaction insert.
      const existingAfter = this.get(input.transactionId);
      if (existingAfter) return { status: 'already_processed', transaction: existingAfter };
      throw error;
    }
  }
}

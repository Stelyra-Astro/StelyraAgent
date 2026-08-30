import { DatabaseSync } from 'node:sqlite';

export type AstroDatabase = DatabaseSync;

export function initializeSchema(db: AstroDatabase): AstroDatabase {
  db.exec(`
    PRAGMA foreign_keys = ON;


    CREATE TABLE IF NOT EXISTS apple_identities (
      identity_id TEXT PRIMARY KEY,
      apple_sub TEXT NOT NULL UNIQUE,
      apple_refresh_token_encrypted TEXT,
      status TEXT NOT NULL DEFAULT 'active',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS accounts (
      account_id TEXT PRIMARY KEY,
      identity_id TEXT NOT NULL REFERENCES apple_identities(identity_id),
      generation INTEGER NOT NULL CHECK (generation > 0),
      status TEXT NOT NULL DEFAULT 'active',
      created_at TEXT NOT NULL,
      reset_at TEXT,
      deleted_at TEXT,
      UNIQUE(identity_id, generation)
    );

    CREATE TABLE IF NOT EXISTS wallets (
      wallet_id TEXT PRIMARY KEY,
      account_id TEXT NOT NULL REFERENCES accounts(account_id),
      app_account_token TEXT NOT NULL UNIQUE,
      available_balance INTEGER NOT NULL DEFAULT 0 CHECK (available_balance >= 0),
      reserved_balance INTEGER NOT NULL DEFAULT 0 CHECK (reserved_balance >= 0),
      spent_balance INTEGER NOT NULL DEFAULT 0 CHECK (spent_balance >= 0),
      status TEXT NOT NULL DEFAULT 'active',
      created_at TEXT NOT NULL,
      closed_at TEXT
    );

    CREATE TABLE IF NOT EXISTS credit_reservations (
      reservation_id TEXT PRIMARY KEY,
      wallet_id TEXT NOT NULL REFERENCES wallets(wallet_id),
      run_id TEXT NOT NULL UNIQUE,
      amount INTEGER NOT NULL CHECK (amount > 0),
      status TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS credit_ledger (
      entry_id TEXT PRIMARY KEY,
      wallet_id TEXT NOT NULL REFERENCES wallets(wallet_id),
      reservation_id TEXT REFERENCES credit_reservations(reservation_id),
      kind TEXT NOT NULL,
      amount INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      UNIQUE(reservation_id, kind)
    );



    CREATE TABLE IF NOT EXISTS iap_transactions (
      transaction_id TEXT PRIMARY KEY,
      wallet_id TEXT NOT NULL REFERENCES wallets(wallet_id),
      app_account_token TEXT NOT NULL,
      product_id TEXT NOT NULL,
      credits INTEGER NOT NULL CHECK (credits > 0),
      status TEXT NOT NULL,
      created_at TEXT NOT NULL
    );


    CREATE TABLE IF NOT EXISTS sessions (
      session_id TEXT PRIMARY KEY,
      account_id TEXT NOT NULL,
      access_hash TEXT NOT NULL UNIQUE,
      refresh_hash TEXT NOT NULL UNIQUE,
      access_expires_at INTEGER NOT NULL,
      refresh_expires_at INTEGER NOT NULL,
      revoked_at INTEGER,
      created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS runs (
      run_id TEXT PRIMARY KEY,
      wallet_id TEXT,
      status TEXT NOT NULL,
      provider TEXT,
      model TEXT,
      payload_json TEXT,
      input_tokens INTEGER NOT NULL DEFAULT 0,
      output_tokens INTEGER NOT NULL DEFAULT 0,
      reasoning_tokens INTEGER NOT NULL DEFAULT 0,
      provider_cost REAL NOT NULL DEFAULT 0,
      tool_rounds INTEGER NOT NULL DEFAULT 0,
      interaction_count INTEGER NOT NULL DEFAULT 0,
      chart_request_count INTEGER NOT NULL DEFAULT 0,
      budget_limited INTEGER NOT NULL DEFAULT 0,
      failure_reason TEXT,
      created_at TEXT NOT NULL,
      completed_at TEXT
    );

    CREATE TABLE IF NOT EXISTS run_actions (
      run_id TEXT NOT NULL REFERENCES runs(run_id) ON DELETE CASCADE,
      action_id TEXT NOT NULL,
      result_json TEXT NOT NULL,
      created_at TEXT NOT NULL,
      PRIMARY KEY (run_id, action_id)
    );
  `);
  ensureColumn(db, 'runs', 'interaction_count', 'INTEGER NOT NULL DEFAULT 0');
  ensureColumn(db, 'runs', 'chart_request_count', 'INTEGER NOT NULL DEFAULT 0');
  ensureColumn(db, 'runs', 'budget_limited', 'INTEGER NOT NULL DEFAULT 0');
  return db;
}

export function createDatabase(path: string): AstroDatabase {
  return initializeSchema(new DatabaseSync(path));
}

export function createTestDatabase(): AstroDatabase {
  return initializeSchema(new DatabaseSync(':memory:'));
}

function ensureColumn(db: AstroDatabase, table: string, column: string, definition: string): void {
  const columns = db.prepare(`PRAGMA table_info(${table})`).all() as Array<{ name: string }>;
  if (!columns.some((item) => item.name === column)) db.exec(`ALTER TABLE ${table} ADD COLUMN ${column} ${definition}`);
}

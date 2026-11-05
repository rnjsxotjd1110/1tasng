// 테스트용 D1 대역: node:sqlite(실제 SQLite)로 D1 API 의 필요한 부분만 흉내 낸다.
// 실제 schema.sql 과 SQL 문을 그대로 실행하므로 쿼리 오류도 잡힌다.
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";

type SqlValue = string | number | null;
interface SqliteStatement {
  all(...params: SqlValue[]): Record<string, unknown>[];
  run(...params: SqlValue[]): { changes: number | bigint; lastInsertRowid: number | bigint };
}
interface SqliteDatabase {
  prepare(sql: string): SqliteStatement;
  exec(sql: string): void;
}

// vite 가 node:sqlite 를 번들하려다 실패하지 않도록 require 로 불러온다.
const require = createRequire(import.meta.url);
const { DatabaseSync } = require("node:sqlite") as { DatabaseSync: new (path: string) => SqliteDatabase };

const SCHEMA_PATH = fileURLToPath(new URL("../../schema.sql", import.meta.url));

function toSql(v: unknown): SqlValue {
  if (v === undefined) throw new Error("D1_TYPE_ERROR: undefined is not a supported bind value");
  if (typeof v === "boolean") return v ? 1 : 0;
  if (v === null || typeof v === "string" || typeof v === "number") return v;
  throw new Error(`unsupported bind value: ${String(v)}`);
}

function plain(row: Record<string, unknown>): Record<string, unknown> {
  return { ...row };
}

const READS_ROWS = /^\s*(SELECT|WITH)\b|\bRETURNING\b/i;

interface Meta {
  changes: number;
  last_row_id: number;
  duration: number;
}
interface Result<T> {
  success: true;
  results: T[];
  meta: Meta;
}

export class FakeStatement {
  constructor(
    private readonly db: SqliteDatabase,
    readonly sql: string,
    private readonly params: SqlValue[] = [],
  ) {}

  bind(...values: unknown[]): FakeStatement {
    return new FakeStatement(this.db, this.sql, values.map(toSql));
  }

  execute<T>(): Result<T> {
    const stmt = this.db.prepare(this.sql);
    if (READS_ROWS.test(this.sql)) {
      const rows = stmt.all(...this.params).map(plain) as T[];
      return { success: true, results: rows, meta: { changes: rows.length, last_row_id: 0, duration: 0 } };
    }
    const r = stmt.run(...this.params);
    return {
      success: true,
      results: [],
      meta: { changes: Number(r.changes), last_row_id: Number(r.lastInsertRowid), duration: 0 },
    };
  }

  async first<T>(column?: string): Promise<T | null> {
    const row = this.execute<Record<string, unknown>>().results[0];
    if (!row) return null;
    return (column ? row[column] : row) as T;
  }

  async all<T>(): Promise<Result<T>> {
    return this.execute<T>();
  }

  async run<T>(): Promise<Result<T>> {
    return this.execute<T>();
  }
}

export class FakeD1 {
  readonly sqlite: SqliteDatabase;

  constructor() {
    this.sqlite = new DatabaseSync(":memory:");
    this.sqlite.exec(readFileSync(SCHEMA_PATH, "utf8"));
  }

  prepare(sql: string): FakeStatement {
    return new FakeStatement(this.sqlite, sql);
  }

  /** D1 처럼 batch 는 하나의 트랜잭션으로 실행하고, 실패하면 전부 되돌린다. */
  async batch<T>(stmts: FakeStatement[]): Promise<Result<T>[]> {
    this.sqlite.exec("BEGIN");
    try {
      const out = stmts.map((s) => s.execute<T>());
      this.sqlite.exec("COMMIT");
      return out;
    } catch (err) {
      this.sqlite.exec("ROLLBACK");
      throw err;
    }
  }

  async exec(sql: string): Promise<{ count: number; duration: number }> {
    this.sqlite.exec(sql);
    return { count: 1, duration: 0 };
  }

  /** 테스트 확인용 동기 조회 */
  rows<T = Record<string, unknown>>(sql: string, ...params: SqlValue[]): T[] {
    return this.sqlite.prepare(sql).all(...params).map(plain) as T[];
  }
}

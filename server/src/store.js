// 튼튼이 동기화 저장소. 앱의 drift 스키마(activities)와 events 테이블을 그대로 두고,
// 서버에서만 쓰는 seq(변경 순번)를 붙여 "이 번호 이후 바뀐 것"을 내려준다.
// 시각은 모두 초 단위 유닉스 타임스탬프(앱 DB와 동일).
import { DatabaseSync } from 'node:sqlite';

const ACTIVITY_COLS = ['id', 'type', 'started_at', 'ended_at', 'payload', 'created_by', 'created_at', 'updated_at', 'deleted_at'];
const EVENT_COLS = ['id', 'title', 'start_at', 'end_at', 'all_day', 'color', 'memo', 'created_by', 'created_at', 'updated_at', 'deleted_at'];

const ACTIVITY_TYPES = new Set(['formula', 'breast', 'sleep', 'solid', 'diaper', 'bath', 'temperature', 'medicine']);

// 앱 ↔ 서버 JSON 필드 이름(camelCase) ↔ 컬럼 이름(snake_case)
const toCamel = (c) => c.replace(/_([a-z])/g, (_, x) => x.toUpperCase());

export class ValidationError extends Error {}

function int(v, name, { nullable = false } = {}) {
  if (v === null || v === undefined) {
    if (nullable) return null;
    throw new ValidationError(`${name} 값이 없어요`);
  }
  if (typeof v !== 'number' || !Number.isInteger(v)) throw new ValidationError(`${name}는 정수여야 해요`);
  return v;
}
function str(v, name, { nullable = false, max = 2000 } = {}) {
  if (v === null || v === undefined) {
    if (nullable) return null;
    throw new ValidationError(`${name} 값이 없어요`);
  }
  if (typeof v !== 'string') throw new ValidationError(`${name}는 문자열이어야 해요`);
  if (v.length > max) throw new ValidationError(`${name}가 너무 길어요`);
  return v;
}

export function parseActivity(o) {
  if (!o || typeof o !== 'object') throw new ValidationError('activity 형식이 아니에요');
  const type = str(o.type, 'type', { max: 32 });
  if (!ACTIVITY_TYPES.has(type)) throw new ValidationError(`알 수 없는 type: ${type}`);
  const payload = str(o.payload ?? '{}', 'payload', { max: 20000 });
  try { JSON.parse(payload); } catch { throw new ValidationError('payload가 JSON이 아니에요'); }
  return {
    id: str(o.id, 'id', { max: 64 }),
    type,
    started_at: int(o.startedAt, 'startedAt'),
    ended_at: int(o.endedAt, 'endedAt', { nullable: true }),
    payload,
    created_by: str(o.createdBy ?? 'me', 'createdBy', { max: 40 }),
    created_at: int(o.createdAt, 'createdAt'),
    updated_at: int(o.updatedAt, 'updatedAt'),
    deleted_at: int(o.deletedAt, 'deletedAt', { nullable: true }),
  };
}

export function parseEvent(o) {
  if (!o || typeof o !== 'object') throw new ValidationError('event 형식이 아니에요');
  const allDay = o.allDay === true || o.allDay === 1 ? 1 : 0;
  return {
    id: str(o.id, 'id', { max: 64 }),
    title: str(o.title, 'title', { max: 200 }),
    start_at: int(o.startAt, 'startAt'),
    end_at: int(o.endAt, 'endAt', { nullable: true }),
    all_day: allDay,
    color: str(o.color ?? 'blue', 'color', { max: 20 }),
    memo: str(o.memo, 'memo', { nullable: true, max: 5000 }),
    created_by: str(o.createdBy ?? 'me', 'createdBy', { max: 40 }),
    created_at: int(o.createdAt, 'createdAt'),
    updated_at: int(o.updatedAt, 'updatedAt'),
    deleted_at: int(o.deletedAt, 'deletedAt', { nullable: true }),
  };
}

function toWire(row, cols) {
  const out = {};
  for (const c of cols) out[toCamel(c)] = row[c];
  if ('all_day' in row) out.allDay = row.all_day === 1;
  return out;
}

export class SyncStore {
  constructor(path) {
    this.db = new DatabaseSync(path);
    this.db.exec(`
      PRAGMA journal_mode = WAL;
      CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value INTEGER NOT NULL);
      INSERT OR IGNORE INTO meta (key, value) VALUES ('seq', 0);
      CREATE TABLE IF NOT EXISTS activities (
        id TEXT PRIMARY KEY, type TEXT NOT NULL, started_at INTEGER NOT NULL, ended_at INTEGER,
        payload TEXT NOT NULL DEFAULT '{}', created_by TEXT NOT NULL DEFAULT 'me',
        created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER,
        seq INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_activities_seq ON activities (seq);
      CREATE TABLE IF NOT EXISTS events (
        id TEXT PRIMARY KEY, title TEXT NOT NULL, start_at INTEGER NOT NULL, end_at INTEGER,
        all_day INTEGER NOT NULL DEFAULT 0, color TEXT NOT NULL DEFAULT 'blue', memo TEXT,
        created_by TEXT NOT NULL DEFAULT 'me',
        created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER,
        seq INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_events_seq ON events (seq);
    `);
    this.stmts = {
      nextSeq: this.db.prepare(`UPDATE meta SET value = value + 1 WHERE key = 'seq' RETURNING value`),
      curSeq: this.db.prepare(`SELECT value FROM meta WHERE key = 'seq'`),
      upsert: {
        activities: this._upsertStmt('activities', ACTIVITY_COLS),
        events: this._upsertStmt('events', EVENT_COLS),
      },
      since: {
        activities: this.db.prepare(`SELECT * FROM activities WHERE seq > ? ORDER BY seq LIMIT ?`),
        events: this.db.prepare(`SELECT * FROM events WHERE seq > ? ORDER BY seq LIMIT ?`),
      },
    };
  }

  // 마지막 수정이 이긴다: 들어온 updated_at이 더 클 때만 덮어쓴다(같으면 무시 → 핑퐁 방지).
  _upsertStmt(table, cols) {
    const names = [...cols, 'seq'];
    const updates = [...cols.filter((c) => c !== 'id'), 'seq'].map((c) => `${c} = excluded.${c}`).join(', ');
    return this.db.prepare(`
      INSERT INTO ${table} (${names.join(', ')}) VALUES (${names.map(() => '?').join(', ')})
      ON CONFLICT(id) DO UPDATE SET ${updates}
      WHERE excluded.updated_at > ${table}.updated_at
    `);
  }

  get cursor() {
    return Number(this.stmts.curSeq.get().value);
  }

  /**
   * 한 번의 동기화: 받은 변경을 반영하고, cursor 이후 바뀐 것을 돌려준다.
   * @returns {{cursor:number, hasMore:boolean, accepted:number, activities:object[], events:object[]}}
   */
  sync({ cursor = 0, activities = [], events = [] }, { limit = 1000 } = {}) {
    cursor = int(cursor, 'cursor');
    if (!Array.isArray(activities) || !Array.isArray(events)) throw new ValidationError('activities/events는 배열이어야 해요');
    if (activities.length + events.length > 5000) throw new ValidationError('한 번에 5000건까지 보낼 수 있어요');
    const parsed = {
      activities: activities.map(parseActivity),
      events: events.map(parseEvent),
    };

    let accepted = 0;
    this.db.exec('BEGIN IMMEDIATE');
    try {
      for (const [table, cols] of [['activities', ACTIVITY_COLS], ['events', EVENT_COLS]]) {
        for (const row of parsed[table]) {
          const seq = Number(this.stmts.nextSeq.get().value);
          const r = this.stmts.upsert[table].run(...cols.map((c) => row[c]), seq);
          if (r.changes > 0) accepted++;
        }
      }
      this.db.exec('COMMIT');
    } catch (e) {
      this.db.exec('ROLLBACK');
      throw e;
    }

    // 두 테이블을 seq 순으로 합쳐 limit만큼 내려준다.
    const a = this.stmts.since.activities.all(cursor, limit + 1).map((r) => ({ t: 'activities', r }));
    const e = this.stmts.since.events.all(cursor, limit + 1).map((r) => ({ t: 'events', r }));
    const merged = [...a, ...e].sort((x, y) => Number(x.r.seq) - Number(y.r.seq));
    const hasMore = merged.length > limit;
    const page = merged.slice(0, limit);
    const out = { activities: [], events: [] };
    for (const { t, r } of page) out[t].push(toWire(r, t === 'activities' ? ACTIVITY_COLS : EVENT_COLS));
    const next = page.length ? Number(page[page.length - 1].r.seq) : Math.max(cursor, 0);
    // 반영 안 된(더 오래된) 변경에도 seq가 소모되므로, 더 가져올 게 없으면 현재 seq로 맞춘다.
    return { cursor: hasMore ? next : Math.max(next, this.cursor), hasMore, accepted, ...out };
  }

  close() {
    this.db.close();
  }
}

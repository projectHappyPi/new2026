import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from '../src/server.js';
import { SyncStore } from '../src/store.js';

const CODE = 'test-family-code-0123456789';
const act = (id, updatedAt, extra = {}) => ({
  id, type: 'formula', startedAt: 1000, endedAt: null, payload: '{"ml":230}', createdBy: '엄마',
  createdAt: 1000, updatedAt, deletedAt: null, ...extra,
});
const evt = (id, updatedAt, extra = {}) => ({
  id, title: '예방접종', startAt: 2000, endAt: 3800, allDay: false, color: 'red', memo: null,
  createdBy: '아빠', createdAt: 2000, updatedAt, ...extra,
});

test('두 기기: A가 올린 기록·일정을 B가 받는다', () => {
  const s = new SyncStore(':memory:');
  const a1 = s.sync({ cursor: 0, activities: [act('a1', 1000)], events: [evt('e1', 2000)] });
  assert.equal(a1.accepted, 2);
  const b1 = s.sync({ cursor: 0 });
  assert.deepEqual(b1.activities.map((x) => x.id), ['a1']);
  assert.deepEqual(b1.events.map((x) => x.id), ['e1']);
  assert.equal(b1.events[0].allDay, false);
  assert.equal(b1.activities[0].createdBy, '엄마');
  const b2 = s.sync({ cursor: b1.cursor });
  assert.equal(b2.activities.length + b2.events.length, 0, '이미 받은 건 다시 안 옴');
});

test('마지막 수정이 이긴다, 같은 시각 재전송은 무시(핑퐁 없음)', () => {
  const s = new SyncStore(':memory:');
  s.sync({ activities: [act('a1', 1000)] });
  const c = s.cursor;
  const same = s.sync({ cursor: c, activities: [act('a1', 1000)] });
  assert.equal(same.accepted, 0);
  assert.equal(same.activities.length, 0);
  const older = s.sync({ cursor: c, activities: [act('a1', 900, { payload: '{"ml":1}' })] });
  assert.equal(older.accepted, 0);
  const newer = s.sync({ cursor: c, activities: [act('a1', 1100, { deletedAt: 1100 })] });
  assert.equal(newer.accepted, 1);
  assert.equal(newer.activities[0].deletedAt, 1100);
});

test('페이지 나눔', () => {
  const s = new SyncStore(':memory:');
  s.sync({ activities: Array.from({ length: 5 }, (_, i) => act(`a${i}`, 1000 + i)) });
  const p1 = s.sync({ cursor: 0 }, { limit: 3 });
  assert.equal(p1.activities.length, 3);
  assert.equal(p1.hasMore, true);
  const p2 = s.sync({ cursor: p1.cursor }, { limit: 3 });
  assert.equal(p2.activities.length, 2);
  assert.equal(p2.hasMore, false);
});

test('잘못된 값은 400', () => {
  const s = new SyncStore(':memory:');
  assert.throws(() => s.sync({ activities: [act('x', 1, { type: 'hack' })] }), /알 수 없는 type/);
  assert.throws(() => s.sync({ activities: [act('x', 1, { payload: '{' })] }), /JSON/);
  assert.throws(() => s.sync({ events: [evt('x', 'soon')] }), /정수/);
});

test('HTTP: 가족 코드 확인 + 동기화', async () => {
  const server = createServer({ familyCode: CODE, dbPath: ':memory:' });
  await new Promise((r) => server.listen(0, r));
  const url = `http://127.0.0.1:${server.address().port}`;
  try {
    assert.equal((await fetch(`${url}/health`)).status, 200);
    const bad = await fetch(`${url}/v1/sync`, { method: 'POST', headers: { authorization: 'Bearer nope' }, body: '{}' });
    assert.equal(bad.status, 401);
    const ok = await fetch(`${url}/v1/sync`, {
      method: 'POST',
      headers: { authorization: `Bearer ${CODE}`, 'content-type': 'application/json' },
      body: JSON.stringify({ cursor: 0, events: [evt('e1', 5)] }),
    });
    assert.equal(ok.status, 200);
    const j = await ok.json();
    assert.equal(j.events[0].title, '예방접종');
    const junk = await fetch(`${url}/v1/sync`, { method: 'POST', headers: { authorization: `Bearer ${CODE}` }, body: 'not json' });
    assert.equal(junk.status, 400);
  } finally {
    await new Promise((r) => server.close(r));
  }
});

test('짧은 가족 코드는 거부', () => {
  assert.throws(() => createServer({ familyCode: 'short', dbPath: ':memory:' }), /16자/);
});

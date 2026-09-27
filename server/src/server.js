// 튼튼이 가족 동기화 서버.
//   POST /v1/sync   Authorization: Bearer <FAMILY_CODE>
//   GET  /health
// 환경변수: FAMILY_CODE(필수, 16자 이상), PORT(기본 8787), DB_PATH(기본 ./data/tunteuni.sqlite)
import http from 'node:http';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { timingSafeEqual } from 'node:crypto';
import { SyncStore, ValidationError } from './store.js';

const MAX_BODY = 5 * 1024 * 1024;

export function createServer({ familyCode, dbPath }) {
  if (!familyCode || familyCode.length < 16) {
    throw new Error('FAMILY_CODE는 16자 이상이어야 해요 (예: openssl rand -hex 16)');
  }
  if (dbPath !== ':memory:') mkdirSync(dirname(dbPath), { recursive: true });
  const store = new SyncStore(dbPath);
  const expected = Buffer.from(familyCode);

  const authorized = (req) => {
    const h = req.headers.authorization || '';
    const m = /^Bearer (.+)$/.exec(h);
    if (!m) return false;
    const got = Buffer.from(m[1]);
    return got.length === expected.length && timingSafeEqual(got, expected);
  };

  const send = (res, status, body) => {
    const data = JSON.stringify(body);
    res.writeHead(status, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' });
    res.end(data);
  };

  const server = http.createServer((req, res) => {
    if (req.method === 'GET' && req.url === '/health') return send(res, 200, { ok: true });
    if (req.url !== '/v1/sync') return send(res, 404, { error: '없는 주소예요' });
    if (req.method !== 'POST') return send(res, 405, { error: 'POST만 받아요' });
    if (!authorized(req)) return send(res, 401, { error: '가족 코드가 맞지 않아요' });

    let size = 0;
    const chunks = [];
    req.on('data', (c) => {
      size += c.length;
      if (size > MAX_BODY) {
        send(res, 413, { error: '요청이 너무 커요' });
        req.destroy();
        return;
      }
      chunks.push(c);
    });
    req.on('end', () => {
      if (res.writableEnded) return;
      let body;
      try {
        body = JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}');
      } catch {
        return send(res, 400, { error: 'JSON 형식이 아니에요' });
      }
      try {
        send(res, 200, store.sync(body));
      } catch (e) {
        if (e instanceof ValidationError) return send(res, 400, { error: e.message });
        console.error(e);
        send(res, 500, { error: '서버 오류' });
      }
    });
  });
  server.on('close', () => store.close());
  return server;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const port = Number(process.env.PORT || 8787);
  const server = createServer({
    familyCode: process.env.FAMILY_CODE,
    dbPath: process.env.DB_PATH || './data/tunteuni.sqlite',
  });
  server.listen(port, () => console.log(`튼튼이 동기화 서버: http://0.0.0.0:${port}`));
  const stop = () => server.close(() => process.exit(0));
  process.on('SIGTERM', stop);
  process.on('SIGINT', stop);
}

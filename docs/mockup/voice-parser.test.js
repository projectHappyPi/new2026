// node docs/mockup/voice-parser.test.js  — test/voice_cases.json 케이스를 JS 파서로 검증
const assert = require('assert');
const path = require('path');
const { parseVoiceCommand } = require('./voice-parser.js');
const { cases } = require(path.join(__dirname, '../../test/voice_cases.json'));
let failed = 0;
for (const c of cases) {
  const r = parseVoiceCommand(c.say, { babyName: c.babyName });
  try {
    if (c.expect === null) {
      assert.strictEqual(r.command, null, `실패여야 함: ${JSON.stringify(r.command)}`);
      assert.ok(r.error);
    } else {
      assert.ok(r.command, `성공이어야 함: ${r.error}`);
      const want = { ml: null, minutes: null, celsius: null, diaper: null, medicine: null, ...c.expect };
      const got = { ml: null, minutes: null, celsius: null, diaper: null, medicine: null, ...r.command };
      for (const k of Object.keys(want)) {
        const g = got[k] === undefined ? null : got[k];
        assert.deepStrictEqual(g, want[k], `${k}: ${g} != ${want[k]}`);
      }
    }
    console.log('ok  ', c.say, '→', r.command ? JSON.stringify(r.command) : r.error);
  } catch (e) {
    failed++;
    console.log('FAIL', c.say, '→', e.message);
  }
}
console.log(`\n${cases.length - failed}/${cases.length} passed`);
process.exit(failed ? 1 : 0);

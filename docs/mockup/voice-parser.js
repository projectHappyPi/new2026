// lib/core/voice/voice_command.dart 를 그대로 옮긴 JS 버전.
// 목업(index.html)과 node 테스트(voice-parser.test.js)에서 같이 쓴다.
// Dart 쪽 규칙을 바꾸면 이 파일도 같이 바꾼다.
(function (root) {
  const LIMITS = {
    formulaMinMl: 10, formulaMaxMl: 400,
    solidMinMl: 10, solidMaxMl: 500,
    breastMinMin: 1, breastMaxMin: 180,
    tempMin: 34.0, tempMax: 43.0,
  };
  const PEE = ['소변', '쉬야', '오줌', '쉬했', '쉬 했'];
  const POOP = ['대변', '응가', '똥', '큰일'];
  const SLEEP_END = ['깼', '깻', '깨어났', '일어났', '기상', '잠깸', '잠에서깸'];
  const SLEEP_START = ['잠들', '재웠', '잠이들', '잠시작', '자기시작', '낮잠시작', '밤잠시작'];
  const BATH = ['목욕', '씻겼', '샤워'];
  const BREAST = ['모유', '직수', '젖먹'];
  const MEDS = ['해열제', '타이레놀', '챔프', '맥시부펜', '부루펜', '이부프로펜', '아세트아미노펜',
    '유산균', '비타민디', '비타민', '항생제', '소화제', '철분제'];
  const DEFAULT_NAMES = ['튼튼이', '튼튼'];
  const HELP = '알아듣지 못했어요. 예) "분유 230ml 먹었어", "모유 10분 먹었어", ' +
    '"소변 갈았어", "잠들었어", "체온 38도야"';
  const DIAPER_LABEL = { pee: '소변', poop: '대변', both: '소변+대변' };

  function formatCelsius(c) {
    const r = Math.round(c * 10) / 10;
    return Number.isInteger(r) ? String(r) : r.toFixed(1);
  }

  function koreanNumber(s) {
    const digits = { 영: 0, 공: 0, 일: 1, 이: 2, 삼: 3, 사: 4, 오: 5, 육: 6, 칠: 7, 팔: 8, 구: 9 };
    const units = { 십: 10, 백: 100, 천: 1000 };
    let total = 0, current = 0, lastWasDigit = false;
    for (const ch of s) {
      if (ch in digits) {
        current = lastWasDigit ? current * 10 + digits[ch] : digits[ch];
        lastWasDigit = true;
        continue;
      }
      if (!(ch in units)) return null;
      total += (current === 0 ? 1 : current) * units[ch];
      current = 0;
      lastWasDigit = false;
    }
    return total + current;
  }

  const digit = (s) => (/\d/.test(s) ? s : String(koreanNumber(s)));

  function normalizeVoiceText(input, babyName) {
    let t = input.toLowerCase().replace(/[^\w\s.가-힣]/g, ' ');
    const names = new Set();
    if (babyName && babyName.trim().length >= 2) names.add(babyName.trim());
    DEFAULT_NAMES.forEach((n) => names.add(n));
    [...names].sort((a, b) => b.length - a.length).forEach((n) => {
      t = t.split(n.toLowerCase()).join(' ');
    });
    t = t.replace(
      /(?<![가-힣])([영공일이삼사오육칠팔구십백천]+)(?=\s*(?:밀리|미리|씨씨|시시|ml|cc|분(?!유)|시간|도|점|부))/g,
      (m, g) => { const n = koreanNumber(g); return n == null ? g : String(n); });
    t = t.replace(/(\d+)\s*점\s*([영공일이삼사오육칠팔구]|\d)/g, (m, a, b) => `${a}.${digit(b)}`);
    t = t.replace(/(\d+)\s*도\s*([일이삼사오육칠팔구]|\d)\s*부/g, (m, a, b) => `${a}.${digit(b)}도`);
    return t.replace(/\s+/g, ' ').trim();
  }

  function firstMl(text) {
    const m = /(\d{1,4})\s*(?:ml|밀리리터|밀리|미리|cc|씨씨|시시)?/.exec(text);
    return m ? parseInt(m[1], 10) : null;
  }

  function minutesOf(compact) {
    const h = /(\d{1,2})시간/.exec(compact);
    const m = /(\d{1,3})분(?!유)/.exec(compact);
    if (!h && !m) return null;
    return (h ? parseInt(h[1], 10) : 0) * 60 + (m ? parseInt(m[1], 10) : 0);
  }

  function parseMedicine(compact) {
    for (const name of MEDS) if (compact.includes(name)) return name;
    if (compact.includes('투약')) return '';
    const m = /([가-힣]{0,6}?)약(?:을|를|도)?(?:먹|복용|줬|주었|투여|넣)/.exec(compact);
    if (!m) return null;
    let prefix = m[1];
    const particles = new Set(['가', '이', '는', '은', '도', '한테', '에게']);
    if (particles.has(prefix) || prefix.includes('먹') || prefix.includes('했') || prefix.endsWith('고')) {
      prefix = '';
    }
    return prefix === '' ? '' : `${prefix}약`;
  }

  const ok = (command) => ({ command, error: null });
  const fail = (error) => ({ command: null, error });

  function parseVoiceCommand(input, opts) {
    const babyName = opts && opts.babyName;
    const text = normalizeVoiceText(input, babyName);
    const compact = text.replace(/\s+/g, '');
    if (!compact) return fail(HELP);
    const has = (words) => words.some((w) => compact.includes(w));

    const tempMatch = /(\d{2}(?:\.\d+)?)도/.exec(compact);
    const saysTemp = compact.includes('체온') || compact.includes('열');
    const otherActivity = has(['분유', '이유식', '목욕', ...BREAST]);
    if (saysTemp || (tempMatch && !otherActivity)) {
      if (!tempMatch) {
        if (compact.includes('체온')) return fail('체온은 숫자와 함께 말해 주세요. 예) "체온 38도야"');
      } else {
        const c = parseFloat(tempMatch[1]);
        if (c < LIMITS.tempMin || c > LIMITS.tempMax) return fail(`체온 ${formatCelsius(c)}도는 범위를 벗어났어요`);
        return ok({ kind: 'temperature', celsius: Math.round(c * 10) / 10 });
      }
    }

    const med = parseMedicine(compact);
    if (med !== null) return ok({ kind: 'medicine', medicine: med === '' ? null : med });

    if (compact.includes('분유')) {
      const ml = firstMl(text);
      if (ml != null && (ml < LIMITS.formulaMinMl || ml > LIMITS.formulaMaxMl)) return fail(`분유 ${ml}ml는 범위를 벗어났어요`);
      return ok({ kind: 'formula', ml });
    }
    if (compact.includes('이유식')) {
      const ml = firstMl(text);
      if (ml != null && (ml < LIMITS.solidMinMl || ml > LIMITS.solidMaxMl)) return fail(`이유식 ${ml}ml는 범위를 벗어났어요`);
      return ok({ kind: 'solid', ml });
    }
    if (has(BREAST)) {
      const minutes = minutesOf(compact);
      if (minutes == null) return fail('모유는 시간과 함께 말해 주세요. 예) "모유 10분 먹었어"');
      if (minutes < LIMITS.breastMinMin || minutes > LIMITS.breastMaxMin) return fail(`모유 ${minutes}분은 범위를 벗어났어요`);
      return ok({ kind: 'breast', minutes });
    }
    const pee = has(PEE), poop = has(POOP);
    if (pee || poop || compact.includes('기저귀')) {
      const diaper = pee && poop ? 'both' : poop ? 'poop' : pee ? 'pee' : null;
      return ok({ kind: 'diaper', diaper });
    }
    if (has(SLEEP_END)) return ok({ kind: 'sleepEnd' });
    if (has(SLEEP_START)) return ok({ kind: 'sleepStart' });
    if (has(BATH)) return ok({ kind: 'bath' });
    return fail(HELP);
  }

  function confirmation(c) {
    switch (c.kind) {
      case 'formula': return c.ml != null ? `분유 ${c.ml}ml 기록했어요` : '분유 기록했어요';
      case 'breast': return `모유 ${c.minutes}분 기록했어요`;
      case 'solid': return c.ml != null ? `이유식 ${c.ml}ml 기록했어요` : '이유식 기록했어요';
      case 'diaper': return `${c.diaper ? DIAPER_LABEL[c.diaper] : '기저귀'} 기록했어요`;
      case 'sleepStart': return '수면 시작을 기록했어요';
      case 'sleepEnd': return '수면 종료를 기록했어요';
      case 'bath': return '목욕 기록했어요';
      case 'temperature': return `체온 ${formatCelsius(c.celsius)}도 기록했어요`;
      case 'medicine': return c.medicine ? `${c.medicine} 투약 기록했어요` : '투약 기록했어요';
    }
    return '';
  }

  const api = { parseVoiceCommand, normalizeVoiceText, koreanNumber, formatCelsius, confirmation };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.VoiceParser = api;
})(typeof window !== 'undefined' ? window : globalThis);

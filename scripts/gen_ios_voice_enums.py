#!/usr/bin/env python3
"""ios/Runner/VoiceIntentEnums.swift 생성기.

App Shortcuts 문구 안의 매개변수는 AppEnum/AppEntity만 가능하고,
caseDisplayRepresentations는 빌드 시 추출되므로 리터럴이어야 한다.
숫자 범위를 바꾸려면 아래 range만 고치고 다시 실행한다:
    python3 scripts/gen_ios_voice_enums.py
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def kor(n: int) -> str:
    """230 → 이백삼십"""
    d = ['', '일', '이', '삼', '사', '오', '육', '칠', '팔', '구']
    out = ''
    for unit, uname in [(1000, '천'), (100, '백'), (10, '십')]:
        q = n // unit
        n %= unit
        if q:
            out += ('' if q == 1 else d[q]) + uname
    return out + d[n]


def enum_block(name, type_title, cases):
    lines = [f"enum {name}: String, AppEnum {{"]
    lines += [f"  case {c}" for c, _, _ in cases]
    lines.append("")
    lines.append(f'  static var typeDisplayRepresentation: TypeDisplayRepresentation = "{type_title}"')
    lines.append(f"  static var caseDisplayRepresentations: [{name}: DisplayRepresentation] = [")
    for c, t, syn in cases:
        s = ", ".join(f'"{x}"' for x in syn)
        lines.append(f'    .{c}: DisplayRepresentation(title: "{t}", synonyms: [{s}]),')
    lines.append("  ]")
    return lines


formula = [(f"ml{v}", f"{v}ml", [f"{v}", f"{v} ml", f"{v}밀리", f"{v}미리", f"{v}cc", kor(v)])
           for v in range(60, 261, 10)]
solid = [(f"ml{v}", f"{v}ml", [f"{v}", f"{v} ml", f"{v}밀리", f"{v}미리", kor(v)])
         for v in range(10, 301, 10)]
breast = [(f"min{v}", f"{v}분", [f"{v} 분", kor(v) + "분"]) for v in range(1, 61)]
temps = []
for t10 in range(350, 411):
    whole, frac = divmod(t10, 10)
    if frac == 0:
        temps.append((f"c{t10}", f"{whole}도", [f"{whole}.0도"]))
    else:
        # 시리 문구 수(로케일당 최대 1,000개)를 넉넉히 남기기 위해 동의어는 2개만 둔다.
        temps.append((f"c{t10}", f"{whole}.{frac}도",
                      [f"{whole}점{frac}도", f"{whole}도 {frac}부"]))
diaper = [("pee", "소변", ["쉬", "쉬야", "오줌"]),
          ("poop", "대변", ["응가", "똥"]),
          ("both", "소변 대변", ["둘 다", "소변이랑 대변"])]

out = [
    "// 자동 생성: scripts/gen_ios_voice_enums.py — 직접 고치지 말고 스크립트를 고쳐서 다시 만든다.",
    "//",
    "// App Shortcuts 문구(\"튼튼이 분유 230ml 먹었어\") 안에 들어갈 수 있는 매개변수는",
    "// AppEnum/AppEntity뿐이라, 자주 쓰는 숫자 값을 열거형 케이스로 미리 만들어 둔다.",
    "// caseDisplayRepresentations는 빌드 시 메타데이터로 추출되므로 반드시 리터럴이어야 한다.",
    "",
    "import AppIntents",
    "",
]
out += enum_block("FormulaAmount", "분유 용량", formula)
out += ["", "  var ml: Int { Int(rawValue.dropFirst(2))! }", "}", ""]
out += enum_block("SolidAmount", "이유식 용량", solid)
out += ["", "  var ml: Int { Int(rawValue.dropFirst(2))! }", "}", ""]
out += enum_block("BreastMinutes", "모유 시간", breast)
out += ["", "  var minutes: Int { Int(rawValue.dropFirst(3))! }", "}", ""]
out += enum_block("BodyTemperature", "체온", temps)
out += ["", "  var celsius: Double { Double(Int(rawValue.dropFirst(1))!) / 10 }", "}", ""]
out += enum_block("DiaperKind", "기저귀 종류", diaper)
out += ["}", ""]

(ROOT / "ios/Runner/VoiceIntentEnums.swift").write_text("\n".join(out), encoding="utf8")
print("wrote ios/Runner/VoiceIntentEnums.swift")

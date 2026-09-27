// 자동 생성: scripts/gen_ios_voice_enums.py — 직접 고치지 말고 스크립트를 고쳐서 다시 만든다.
//
// App Shortcuts 문구("튼튼이 분유 230ml 먹었어") 안에 들어갈 수 있는 매개변수는
// AppEnum/AppEntity뿐이라, 자주 쓰는 숫자 값을 열거형 케이스로 미리 만들어 둔다.
// caseDisplayRepresentations는 빌드 시 메타데이터로 추출되므로 반드시 리터럴이어야 한다.

import AppIntents

enum FormulaAmount: String, AppEnum {
  case ml60
  case ml70
  case ml80
  case ml90
  case ml100
  case ml110
  case ml120
  case ml130
  case ml140
  case ml150
  case ml160
  case ml170
  case ml180
  case ml190
  case ml200
  case ml210
  case ml220
  case ml230
  case ml240
  case ml250
  case ml260

  static var typeDisplayRepresentation: TypeDisplayRepresentation = "분유 용량"
  static var caseDisplayRepresentations: [FormulaAmount: DisplayRepresentation] = [
    .ml60: DisplayRepresentation(title: "60ml", synonyms: ["60", "60 ml", "60밀리", "60미리", "60cc", "육십"]),
    .ml70: DisplayRepresentation(title: "70ml", synonyms: ["70", "70 ml", "70밀리", "70미리", "70cc", "칠십"]),
    .ml80: DisplayRepresentation(title: "80ml", synonyms: ["80", "80 ml", "80밀리", "80미리", "80cc", "팔십"]),
    .ml90: DisplayRepresentation(title: "90ml", synonyms: ["90", "90 ml", "90밀리", "90미리", "90cc", "구십"]),
    .ml100: DisplayRepresentation(title: "100ml", synonyms: ["100", "100 ml", "100밀리", "100미리", "100cc", "백"]),
    .ml110: DisplayRepresentation(title: "110ml", synonyms: ["110", "110 ml", "110밀리", "110미리", "110cc", "백십"]),
    .ml120: DisplayRepresentation(title: "120ml", synonyms: ["120", "120 ml", "120밀리", "120미리", "120cc", "백이십"]),
    .ml130: DisplayRepresentation(title: "130ml", synonyms: ["130", "130 ml", "130밀리", "130미리", "130cc", "백삼십"]),
    .ml140: DisplayRepresentation(title: "140ml", synonyms: ["140", "140 ml", "140밀리", "140미리", "140cc", "백사십"]),
    .ml150: DisplayRepresentation(title: "150ml", synonyms: ["150", "150 ml", "150밀리", "150미리", "150cc", "백오십"]),
    .ml160: DisplayRepresentation(title: "160ml", synonyms: ["160", "160 ml", "160밀리", "160미리", "160cc", "백육십"]),
    .ml170: DisplayRepresentation(title: "170ml", synonyms: ["170", "170 ml", "170밀리", "170미리", "170cc", "백칠십"]),
    .ml180: DisplayRepresentation(title: "180ml", synonyms: ["180", "180 ml", "180밀리", "180미리", "180cc", "백팔십"]),
    .ml190: DisplayRepresentation(title: "190ml", synonyms: ["190", "190 ml", "190밀리", "190미리", "190cc", "백구십"]),
    .ml200: DisplayRepresentation(title: "200ml", synonyms: ["200", "200 ml", "200밀리", "200미리", "200cc", "이백"]),
    .ml210: DisplayRepresentation(title: "210ml", synonyms: ["210", "210 ml", "210밀리", "210미리", "210cc", "이백십"]),
    .ml220: DisplayRepresentation(title: "220ml", synonyms: ["220", "220 ml", "220밀리", "220미리", "220cc", "이백이십"]),
    .ml230: DisplayRepresentation(title: "230ml", synonyms: ["230", "230 ml", "230밀리", "230미리", "230cc", "이백삼십"]),
    .ml240: DisplayRepresentation(title: "240ml", synonyms: ["240", "240 ml", "240밀리", "240미리", "240cc", "이백사십"]),
    .ml250: DisplayRepresentation(title: "250ml", synonyms: ["250", "250 ml", "250밀리", "250미리", "250cc", "이백오십"]),
    .ml260: DisplayRepresentation(title: "260ml", synonyms: ["260", "260 ml", "260밀리", "260미리", "260cc", "이백육십"]),
  ]

  var ml: Int { Int(rawValue.dropFirst(2))! }
}

enum SolidAmount: String, AppEnum {
  case ml10
  case ml20
  case ml30
  case ml40
  case ml50
  case ml60
  case ml70
  case ml80
  case ml90
  case ml100
  case ml110
  case ml120
  case ml130
  case ml140
  case ml150
  case ml160
  case ml170
  case ml180
  case ml190
  case ml200
  case ml210
  case ml220
  case ml230
  case ml240
  case ml250
  case ml260
  case ml270
  case ml280
  case ml290
  case ml300

  static var typeDisplayRepresentation: TypeDisplayRepresentation = "이유식 용량"
  static var caseDisplayRepresentations: [SolidAmount: DisplayRepresentation] = [
    .ml10: DisplayRepresentation(title: "10ml", synonyms: ["10", "10 ml", "10밀리", "10미리", "십"]),
    .ml20: DisplayRepresentation(title: "20ml", synonyms: ["20", "20 ml", "20밀리", "20미리", "이십"]),
    .ml30: DisplayRepresentation(title: "30ml", synonyms: ["30", "30 ml", "30밀리", "30미리", "삼십"]),
    .ml40: DisplayRepresentation(title: "40ml", synonyms: ["40", "40 ml", "40밀리", "40미리", "사십"]),
    .ml50: DisplayRepresentation(title: "50ml", synonyms: ["50", "50 ml", "50밀리", "50미리", "오십"]),
    .ml60: DisplayRepresentation(title: "60ml", synonyms: ["60", "60 ml", "60밀리", "60미리", "육십"]),
    .ml70: DisplayRepresentation(title: "70ml", synonyms: ["70", "70 ml", "70밀리", "70미리", "칠십"]),
    .ml80: DisplayRepresentation(title: "80ml", synonyms: ["80", "80 ml", "80밀리", "80미리", "팔십"]),
    .ml90: DisplayRepresentation(title: "90ml", synonyms: ["90", "90 ml", "90밀리", "90미리", "구십"]),
    .ml100: DisplayRepresentation(title: "100ml", synonyms: ["100", "100 ml", "100밀리", "100미리", "백"]),
    .ml110: DisplayRepresentation(title: "110ml", synonyms: ["110", "110 ml", "110밀리", "110미리", "백십"]),
    .ml120: DisplayRepresentation(title: "120ml", synonyms: ["120", "120 ml", "120밀리", "120미리", "백이십"]),
    .ml130: DisplayRepresentation(title: "130ml", synonyms: ["130", "130 ml", "130밀리", "130미리", "백삼십"]),
    .ml140: DisplayRepresentation(title: "140ml", synonyms: ["140", "140 ml", "140밀리", "140미리", "백사십"]),
    .ml150: DisplayRepresentation(title: "150ml", synonyms: ["150", "150 ml", "150밀리", "150미리", "백오십"]),
    .ml160: DisplayRepresentation(title: "160ml", synonyms: ["160", "160 ml", "160밀리", "160미리", "백육십"]),
    .ml170: DisplayRepresentation(title: "170ml", synonyms: ["170", "170 ml", "170밀리", "170미리", "백칠십"]),
    .ml180: DisplayRepresentation(title: "180ml", synonyms: ["180", "180 ml", "180밀리", "180미리", "백팔십"]),
    .ml190: DisplayRepresentation(title: "190ml", synonyms: ["190", "190 ml", "190밀리", "190미리", "백구십"]),
    .ml200: DisplayRepresentation(title: "200ml", synonyms: ["200", "200 ml", "200밀리", "200미리", "이백"]),
    .ml210: DisplayRepresentation(title: "210ml", synonyms: ["210", "210 ml", "210밀리", "210미리", "이백십"]),
    .ml220: DisplayRepresentation(title: "220ml", synonyms: ["220", "220 ml", "220밀리", "220미리", "이백이십"]),
    .ml230: DisplayRepresentation(title: "230ml", synonyms: ["230", "230 ml", "230밀리", "230미리", "이백삼십"]),
    .ml240: DisplayRepresentation(title: "240ml", synonyms: ["240", "240 ml", "240밀리", "240미리", "이백사십"]),
    .ml250: DisplayRepresentation(title: "250ml", synonyms: ["250", "250 ml", "250밀리", "250미리", "이백오십"]),
    .ml260: DisplayRepresentation(title: "260ml", synonyms: ["260", "260 ml", "260밀리", "260미리", "이백육십"]),
    .ml270: DisplayRepresentation(title: "270ml", synonyms: ["270", "270 ml", "270밀리", "270미리", "이백칠십"]),
    .ml280: DisplayRepresentation(title: "280ml", synonyms: ["280", "280 ml", "280밀리", "280미리", "이백팔십"]),
    .ml290: DisplayRepresentation(title: "290ml", synonyms: ["290", "290 ml", "290밀리", "290미리", "이백구십"]),
    .ml300: DisplayRepresentation(title: "300ml", synonyms: ["300", "300 ml", "300밀리", "300미리", "삼백"]),
  ]

  var ml: Int { Int(rawValue.dropFirst(2))! }
}

enum BreastMinutes: String, AppEnum {
  case min1
  case min2
  case min3
  case min4
  case min5
  case min6
  case min7
  case min8
  case min9
  case min10
  case min11
  case min12
  case min13
  case min14
  case min15
  case min16
  case min17
  case min18
  case min19
  case min20
  case min21
  case min22
  case min23
  case min24
  case min25
  case min26
  case min27
  case min28
  case min29
  case min30
  case min31
  case min32
  case min33
  case min34
  case min35
  case min36
  case min37
  case min38
  case min39
  case min40
  case min41
  case min42
  case min43
  case min44
  case min45
  case min46
  case min47
  case min48
  case min49
  case min50
  case min51
  case min52
  case min53
  case min54
  case min55
  case min56
  case min57
  case min58
  case min59
  case min60

  static var typeDisplayRepresentation: TypeDisplayRepresentation = "모유 시간"
  static var caseDisplayRepresentations: [BreastMinutes: DisplayRepresentation] = [
    .min1: DisplayRepresentation(title: "1분", synonyms: ["1 분", "일분"]),
    .min2: DisplayRepresentation(title: "2분", synonyms: ["2 분", "이분"]),
    .min3: DisplayRepresentation(title: "3분", synonyms: ["3 분", "삼분"]),
    .min4: DisplayRepresentation(title: "4분", synonyms: ["4 분", "사분"]),
    .min5: DisplayRepresentation(title: "5분", synonyms: ["5 분", "오분"]),
    .min6: DisplayRepresentation(title: "6분", synonyms: ["6 분", "육분"]),
    .min7: DisplayRepresentation(title: "7분", synonyms: ["7 분", "칠분"]),
    .min8: DisplayRepresentation(title: "8분", synonyms: ["8 분", "팔분"]),
    .min9: DisplayRepresentation(title: "9분", synonyms: ["9 분", "구분"]),
    .min10: DisplayRepresentation(title: "10분", synonyms: ["10 분", "십분"]),
    .min11: DisplayRepresentation(title: "11분", synonyms: ["11 분", "십일분"]),
    .min12: DisplayRepresentation(title: "12분", synonyms: ["12 분", "십이분"]),
    .min13: DisplayRepresentation(title: "13분", synonyms: ["13 분", "십삼분"]),
    .min14: DisplayRepresentation(title: "14분", synonyms: ["14 분", "십사분"]),
    .min15: DisplayRepresentation(title: "15분", synonyms: ["15 분", "십오분"]),
    .min16: DisplayRepresentation(title: "16분", synonyms: ["16 분", "십육분"]),
    .min17: DisplayRepresentation(title: "17분", synonyms: ["17 분", "십칠분"]),
    .min18: DisplayRepresentation(title: "18분", synonyms: ["18 분", "십팔분"]),
    .min19: DisplayRepresentation(title: "19분", synonyms: ["19 분", "십구분"]),
    .min20: DisplayRepresentation(title: "20분", synonyms: ["20 분", "이십분"]),
    .min21: DisplayRepresentation(title: "21분", synonyms: ["21 분", "이십일분"]),
    .min22: DisplayRepresentation(title: "22분", synonyms: ["22 분", "이십이분"]),
    .min23: DisplayRepresentation(title: "23분", synonyms: ["23 분", "이십삼분"]),
    .min24: DisplayRepresentation(title: "24분", synonyms: ["24 분", "이십사분"]),
    .min25: DisplayRepresentation(title: "25분", synonyms: ["25 분", "이십오분"]),
    .min26: DisplayRepresentation(title: "26분", synonyms: ["26 분", "이십육분"]),
    .min27: DisplayRepresentation(title: "27분", synonyms: ["27 분", "이십칠분"]),
    .min28: DisplayRepresentation(title: "28분", synonyms: ["28 분", "이십팔분"]),
    .min29: DisplayRepresentation(title: "29분", synonyms: ["29 분", "이십구분"]),
    .min30: DisplayRepresentation(title: "30분", synonyms: ["30 분", "삼십분"]),
    .min31: DisplayRepresentation(title: "31분", synonyms: ["31 분", "삼십일분"]),
    .min32: DisplayRepresentation(title: "32분", synonyms: ["32 분", "삼십이분"]),
    .min33: DisplayRepresentation(title: "33분", synonyms: ["33 분", "삼십삼분"]),
    .min34: DisplayRepresentation(title: "34분", synonyms: ["34 분", "삼십사분"]),
    .min35: DisplayRepresentation(title: "35분", synonyms: ["35 분", "삼십오분"]),
    .min36: DisplayRepresentation(title: "36분", synonyms: ["36 분", "삼십육분"]),
    .min37: DisplayRepresentation(title: "37분", synonyms: ["37 분", "삼십칠분"]),
    .min38: DisplayRepresentation(title: "38분", synonyms: ["38 분", "삼십팔분"]),
    .min39: DisplayRepresentation(title: "39분", synonyms: ["39 분", "삼십구분"]),
    .min40: DisplayRepresentation(title: "40분", synonyms: ["40 분", "사십분"]),
    .min41: DisplayRepresentation(title: "41분", synonyms: ["41 분", "사십일분"]),
    .min42: DisplayRepresentation(title: "42분", synonyms: ["42 분", "사십이분"]),
    .min43: DisplayRepresentation(title: "43분", synonyms: ["43 분", "사십삼분"]),
    .min44: DisplayRepresentation(title: "44분", synonyms: ["44 분", "사십사분"]),
    .min45: DisplayRepresentation(title: "45분", synonyms: ["45 분", "사십오분"]),
    .min46: DisplayRepresentation(title: "46분", synonyms: ["46 분", "사십육분"]),
    .min47: DisplayRepresentation(title: "47분", synonyms: ["47 분", "사십칠분"]),
    .min48: DisplayRepresentation(title: "48분", synonyms: ["48 분", "사십팔분"]),
    .min49: DisplayRepresentation(title: "49분", synonyms: ["49 분", "사십구분"]),
    .min50: DisplayRepresentation(title: "50분", synonyms: ["50 분", "오십분"]),
    .min51: DisplayRepresentation(title: "51분", synonyms: ["51 분", "오십일분"]),
    .min52: DisplayRepresentation(title: "52분", synonyms: ["52 분", "오십이분"]),
    .min53: DisplayRepresentation(title: "53분", synonyms: ["53 분", "오십삼분"]),
    .min54: DisplayRepresentation(title: "54분", synonyms: ["54 분", "오십사분"]),
    .min55: DisplayRepresentation(title: "55분", synonyms: ["55 분", "오십오분"]),
    .min56: DisplayRepresentation(title: "56분", synonyms: ["56 분", "오십육분"]),
    .min57: DisplayRepresentation(title: "57분", synonyms: ["57 분", "오십칠분"]),
    .min58: DisplayRepresentation(title: "58분", synonyms: ["58 분", "오십팔분"]),
    .min59: DisplayRepresentation(title: "59분", synonyms: ["59 분", "오십구분"]),
    .min60: DisplayRepresentation(title: "60분", synonyms: ["60 분", "육십분"]),
  ]

  var minutes: Int { Int(rawValue.dropFirst(3))! }
}

enum BodyTemperature: String, AppEnum {
  case c350
  case c351
  case c352
  case c353
  case c354
  case c355
  case c356
  case c357
  case c358
  case c359
  case c360
  case c361
  case c362
  case c363
  case c364
  case c365
  case c366
  case c367
  case c368
  case c369
  case c370
  case c371
  case c372
  case c373
  case c374
  case c375
  case c376
  case c377
  case c378
  case c379
  case c380
  case c381
  case c382
  case c383
  case c384
  case c385
  case c386
  case c387
  case c388
  case c389
  case c390
  case c391
  case c392
  case c393
  case c394
  case c395
  case c396
  case c397
  case c398
  case c399
  case c400
  case c401
  case c402
  case c403
  case c404
  case c405
  case c406
  case c407
  case c408
  case c409
  case c410

  static var typeDisplayRepresentation: TypeDisplayRepresentation = "체온"
  static var caseDisplayRepresentations: [BodyTemperature: DisplayRepresentation] = [
    .c350: DisplayRepresentation(title: "35도", synonyms: ["35.0도"]),
    .c351: DisplayRepresentation(title: "35.1도", synonyms: ["35점1도", "35도 1부"]),
    .c352: DisplayRepresentation(title: "35.2도", synonyms: ["35점2도", "35도 2부"]),
    .c353: DisplayRepresentation(title: "35.3도", synonyms: ["35점3도", "35도 3부"]),
    .c354: DisplayRepresentation(title: "35.4도", synonyms: ["35점4도", "35도 4부"]),
    .c355: DisplayRepresentation(title: "35.5도", synonyms: ["35점5도", "35도 5부"]),
    .c356: DisplayRepresentation(title: "35.6도", synonyms: ["35점6도", "35도 6부"]),
    .c357: DisplayRepresentation(title: "35.7도", synonyms: ["35점7도", "35도 7부"]),
    .c358: DisplayRepresentation(title: "35.8도", synonyms: ["35점8도", "35도 8부"]),
    .c359: DisplayRepresentation(title: "35.9도", synonyms: ["35점9도", "35도 9부"]),
    .c360: DisplayRepresentation(title: "36도", synonyms: ["36.0도"]),
    .c361: DisplayRepresentation(title: "36.1도", synonyms: ["36점1도", "36도 1부"]),
    .c362: DisplayRepresentation(title: "36.2도", synonyms: ["36점2도", "36도 2부"]),
    .c363: DisplayRepresentation(title: "36.3도", synonyms: ["36점3도", "36도 3부"]),
    .c364: DisplayRepresentation(title: "36.4도", synonyms: ["36점4도", "36도 4부"]),
    .c365: DisplayRepresentation(title: "36.5도", synonyms: ["36점5도", "36도 5부"]),
    .c366: DisplayRepresentation(title: "36.6도", synonyms: ["36점6도", "36도 6부"]),
    .c367: DisplayRepresentation(title: "36.7도", synonyms: ["36점7도", "36도 7부"]),
    .c368: DisplayRepresentation(title: "36.8도", synonyms: ["36점8도", "36도 8부"]),
    .c369: DisplayRepresentation(title: "36.9도", synonyms: ["36점9도", "36도 9부"]),
    .c370: DisplayRepresentation(title: "37도", synonyms: ["37.0도"]),
    .c371: DisplayRepresentation(title: "37.1도", synonyms: ["37점1도", "37도 1부"]),
    .c372: DisplayRepresentation(title: "37.2도", synonyms: ["37점2도", "37도 2부"]),
    .c373: DisplayRepresentation(title: "37.3도", synonyms: ["37점3도", "37도 3부"]),
    .c374: DisplayRepresentation(title: "37.4도", synonyms: ["37점4도", "37도 4부"]),
    .c375: DisplayRepresentation(title: "37.5도", synonyms: ["37점5도", "37도 5부"]),
    .c376: DisplayRepresentation(title: "37.6도", synonyms: ["37점6도", "37도 6부"]),
    .c377: DisplayRepresentation(title: "37.7도", synonyms: ["37점7도", "37도 7부"]),
    .c378: DisplayRepresentation(title: "37.8도", synonyms: ["37점8도", "37도 8부"]),
    .c379: DisplayRepresentation(title: "37.9도", synonyms: ["37점9도", "37도 9부"]),
    .c380: DisplayRepresentation(title: "38도", synonyms: ["38.0도"]),
    .c381: DisplayRepresentation(title: "38.1도", synonyms: ["38점1도", "38도 1부"]),
    .c382: DisplayRepresentation(title: "38.2도", synonyms: ["38점2도", "38도 2부"]),
    .c383: DisplayRepresentation(title: "38.3도", synonyms: ["38점3도", "38도 3부"]),
    .c384: DisplayRepresentation(title: "38.4도", synonyms: ["38점4도", "38도 4부"]),
    .c385: DisplayRepresentation(title: "38.5도", synonyms: ["38점5도", "38도 5부"]),
    .c386: DisplayRepresentation(title: "38.6도", synonyms: ["38점6도", "38도 6부"]),
    .c387: DisplayRepresentation(title: "38.7도", synonyms: ["38점7도", "38도 7부"]),
    .c388: DisplayRepresentation(title: "38.8도", synonyms: ["38점8도", "38도 8부"]),
    .c389: DisplayRepresentation(title: "38.9도", synonyms: ["38점9도", "38도 9부"]),
    .c390: DisplayRepresentation(title: "39도", synonyms: ["39.0도"]),
    .c391: DisplayRepresentation(title: "39.1도", synonyms: ["39점1도", "39도 1부"]),
    .c392: DisplayRepresentation(title: "39.2도", synonyms: ["39점2도", "39도 2부"]),
    .c393: DisplayRepresentation(title: "39.3도", synonyms: ["39점3도", "39도 3부"]),
    .c394: DisplayRepresentation(title: "39.4도", synonyms: ["39점4도", "39도 4부"]),
    .c395: DisplayRepresentation(title: "39.5도", synonyms: ["39점5도", "39도 5부"]),
    .c396: DisplayRepresentation(title: "39.6도", synonyms: ["39점6도", "39도 6부"]),
    .c397: DisplayRepresentation(title: "39.7도", synonyms: ["39점7도", "39도 7부"]),
    .c398: DisplayRepresentation(title: "39.8도", synonyms: ["39점8도", "39도 8부"]),
    .c399: DisplayRepresentation(title: "39.9도", synonyms: ["39점9도", "39도 9부"]),
    .c400: DisplayRepresentation(title: "40도", synonyms: ["40.0도"]),
    .c401: DisplayRepresentation(title: "40.1도", synonyms: ["40점1도", "40도 1부"]),
    .c402: DisplayRepresentation(title: "40.2도", synonyms: ["40점2도", "40도 2부"]),
    .c403: DisplayRepresentation(title: "40.3도", synonyms: ["40점3도", "40도 3부"]),
    .c404: DisplayRepresentation(title: "40.4도", synonyms: ["40점4도", "40도 4부"]),
    .c405: DisplayRepresentation(title: "40.5도", synonyms: ["40점5도", "40도 5부"]),
    .c406: DisplayRepresentation(title: "40.6도", synonyms: ["40점6도", "40도 6부"]),
    .c407: DisplayRepresentation(title: "40.7도", synonyms: ["40점7도", "40도 7부"]),
    .c408: DisplayRepresentation(title: "40.8도", synonyms: ["40점8도", "40도 8부"]),
    .c409: DisplayRepresentation(title: "40.9도", synonyms: ["40점9도", "40도 9부"]),
    .c410: DisplayRepresentation(title: "41도", synonyms: ["41.0도"]),
  ]

  var celsius: Double { Double(Int(rawValue.dropFirst(1))!) / 10 }
}

enum DiaperKind: String, AppEnum {
  case pee
  case poop
  case both

  static var typeDisplayRepresentation: TypeDisplayRepresentation = "기저귀 종류"
  static var caseDisplayRepresentations: [DiaperKind: DisplayRepresentation] = [
    .pee: DisplayRepresentation(title: "소변", synonyms: ["쉬", "쉬야", "오줌"]),
    .poop: DisplayRepresentation(title: "대변", synonyms: ["응가", "똥"]),
    .both: DisplayRepresentation(title: "소변 대변", synonyms: ["둘 다", "소변이랑 대변"]),
  ]
}

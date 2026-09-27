import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import '../models/activity_type.dart';
import 'shared_container.dart';
import 'tables.dart';

part 'database.g.dart';

/// 달력 일정 테이블 이름. 코드 생성 대상이 아니라서 문자열로 참조한다.
const kEventsTable = 'events';

/// 시각은 activities와 같이 초 단위 유닉스 타임스탬프. all_day는 0/1.
const kCreateEventsSql = '''
CREATE TABLE IF NOT EXISTS events (
  id TEXT NOT NULL PRIMARY KEY,
  title TEXT NOT NULL,
  start_at INTEGER NOT NULL,
  end_at INTEGER,
  all_day INTEGER NOT NULL DEFAULT 0,
  color TEXT NOT NULL DEFAULT 'blue',
  memo TEXT,
  created_by TEXT NOT NULL DEFAULT 'me',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER
)''';

const kCreateEventsIndexSql =
    'CREATE INDEX IF NOT EXISTS idx_events_start_at ON events (start_at)';

@DriftDatabase(tables: [Activities])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// 테스트 등에서 메모리 DB나 다른 실행기를 주입할 때 사용.
  AppDatabase.withExecutor(super.executor);

  /// v2: 달력 일정(events) 테이블 추가. events는 drift 코드 생성 없이 SQL로만
  /// 다룬다(lib/data/repositories/event_repository.dart). iOS 위젯·안드로이드
  /// 위젯도 같은 파일을 직접 읽으므로 컬럼을 바꾸면 네이티브 쪽도 같이 바꾼다.
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(kCreateEventsSql);
      await customStatement(kCreateEventsIndexSql);
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await customStatement(kCreateEventsSql);
        await customStatement(kCreateEventsIndexSql);
      }
    },
    beforeOpen: (details) async {
      // 시리(App Intent)·위젯이 같은 파일을 쓰는 동안 잠깐 기다린다.
      await customStatement('PRAGMA busy_timeout = 3000');
    },
  );

  /// 시리 App Intent·위젯이 앱 밖에서(별도 프로세스로) 같은 DB 파일에 직접
  /// 쓴 기록을 화면에 반영하기 위해, 앱이 다시 포그라운드로 돌아올 때 호출한다.
  /// drift는 자기 자신을 거치지 않은 쓰기를 모르기 때문에 명시적으로 알려줘야 한다.
  void notifyExternalWrite() {
    markTablesUpdated({activities});
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await sharedDataDirectory();
    final file = File(p.join(dir.path, 'parenting_log.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import '../models/activity_type.dart';
import 'shared_container.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Activities])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// 테스트 등에서 메모리 DB나 다른 실행기를 주입할 때 사용.
  AppDatabase.withExecutor(super.executor);

  @override
  int get schemaVersion => 1;

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

import 'package:drift/drift.dart';

import '../models/activity_type.dart';

/// payload는 JSON 문자열로 둔다. 유형별 컬럼을 늘리면 항목 추가 때마다
/// 스키마 마이그레이션이 필요해지므로, 컬럼을 유형별로 늘리지 않는다.
@DataClassName('ActivityRow')
@TableIndex(name: 'idx_activities_started_at', columns: {#startedAt})
@TableIndex(name: 'idx_activities_deleted_at', columns: {#deletedAt})
class Activities extends Table {
  TextColumn get id => text()();
  TextColumn get type => textEnum<ActivityType>()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get payload => text().withDefault(const Constant('{}'))();
  TextColumn get createdBy => text().withDefault(const Constant('me'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

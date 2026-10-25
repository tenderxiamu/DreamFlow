import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'db.g.dart';

/// §7-D 一期本地数据：情绪记录（B 屏对话产物）与睡眠会话（D 报告数据源）。
/// 离线优先：全部数据先落本地，云端同步留二期。
class MoodRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get moodLabel => text()(); // 情绪标签，如「平静」「焦虑」
  IntColumn get intensity => integer()(); // 1-5 强度
  TextColumn get source => text().withDefault(const Constant('chat'))(); // chat | manual
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class SleepSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get score => integer().nullable()(); // 睡眠分 0-100
  IntColumn get deepMinutes => integer().withDefault(const Constant(0))();
  IntColumn get awakenings => integer().withDefault(const Constant(0))();
  TextColumn get note => text().nullable()();
}

@DriftDatabase(tables: [MoodRecords, SleepSessions])
class DreamFlowDb extends _$DreamFlowDb {
  DreamFlowDb() : super(driftDatabase(name: 'dreamflow'));

  @override
  int get schemaVersion => 1;

  // ---- 查询骨架（M3-M5 逐屏接数据） ----

  /// D 报告屏：最近 N 次会话（按开始时间倒序）
  Future<List<SleepSession>> recentSessions({int limit = 7}) {
    final Selectable<SleepSession> q = select(sleepSessions)
      ..orderBy([($SleepSessionsTable tbl) => OrderingTerm.desc(tbl.startedAt)])
      ..limit(limit);
    return q.get();
  }

  /// B 对话屏：今日情绪记录
  Future<List<MoodRecord>> todayMoods() {
    final DateTime now = DateTime.now();
    final DateTime start = DateTime(now.year, now.month, now.day);
    final Selectable<MoodRecord> q = select(moodRecords)
      ..where(($MoodRecordsTable tbl) => tbl.createdAt.isBiggerOrEqualValue(start))
      ..orderBy([($MoodRecordsTable tbl) => OrderingTerm.desc(tbl.createdAt)]);
    return q.get();
  }

  Future<int> addMood(String label, int intensity, {String source = 'chat'}) =>
      into(moodRecords).insert(MoodRecordsCompanion.insert(
        moodLabel: label,
        intensity: intensity,
        source: Value(source),
      ));

  Future<int> addSession(SleepSessionsCompanion entry) =>
      into(sleepSessions).insert(entry);
}

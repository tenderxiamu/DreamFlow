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

/// M4：对话历史（B 屏）。离线优先：LLM 对话上下文与历史回放都在本地。
class ChatMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  BoolColumn get mine => boolean()(); // true=用户，false=梦洄
  TextColumn get body => text()(); // 消息正文（列名不能用 text，与 Table.text 冲突）
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [MoodRecords, SleepSessions, ChatMessages])
class DreamFlowDb extends _$DreamFlowDb {
  DreamFlowDb() : super(driftDatabase(name: 'dreamflow'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.createTable(chatMessages);
          }
        },
      );

  /// 全局单例（UI 直接取用；一次 app 生命周期一个库连接）
  static final DreamFlowDb instance = DreamFlowDb();

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

  // ---- M4：对话历史 ----

  Future<int> addChatMessage({required bool mine, required String text}) =>
      into(chatMessages).insert(ChatMessagesCompanion.insert(
        mine: mine,
        body: text,
      ));

  /// 最近 N 条（升序返回，直接可作为 LLM messages 上下文）
  Future<List<ChatMessage>> recentMessages({int limit = 12}) async {
    final Selectable<ChatMessage> q = select(chatMessages)
      ..orderBy([($ChatMessagesTable tbl) => OrderingTerm.desc(tbl.createdAt)])
      ..limit(limit);
    final List<ChatMessage> rows = await q.get();
    return rows.reversed.toList();
  }
}

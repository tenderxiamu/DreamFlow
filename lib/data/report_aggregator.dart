import '../screens/df_report_screen.dart';
import 'db.dart';
import 'light_sleep.dart';

/// M5：本地报告聚合 —— 把 Drift 里的会话/情绪行折算成报告屏快照。
Future<DfReportData?> aggregateLatestReport() async {
  final List<SleepSession> sessions =
      await DreamFlowDb.instance.recentSessions(limit: 1);
  if (sessions.isEmpty) return null;
  final SleepSession s = sessions.first;

  final List<MoodRecord> moods = await DreamFlowDb.instance.recentMoods(days: 7);

  // 近 7 天情绪条：按星期聚合，值为平均强度映射到 0-100
  final Map<int, List<int>> byWeekday = <int, List<int>>{};
  for (final MoodRecord m in moods) {
    byWeekday.putIfAbsent(m.createdAt.weekday, () => <int>[]).add(m.intensity);
  }
  const List<String> weekdayLabels = <String>[
    '周一', '周二', '周三', '周四', '周五', '周六', '周日',
  ];
  // 从「今天」往前铺满 7 天，保证条目连续可读
  final DateTime now = DateTime.now();
  final List<({String label, int value})> bars = <({String label, int value})>[];
  for (int i = 6; i >= 0; i--) {
    final DateTime day = now.subtract(Duration(days: i));
    final List<int>? list = byWeekday[day.weekday];
    if (list == null || list.isEmpty) continue;
    final double avg =
        list.fold<int>(0, (int a, int b) => a + b) / list.length;
    bars.add((
      label: weekdayLabels[day.weekday - 1],
      value: (avg / 5 * 100).round().clamp(0, 100),
    ));
  }

  final Duration duration =
      (s.endedAt ?? DateTime.now()).difference(s.startedAt);
  final int score = s.score ?? estimateScore(duration: duration, snoozes: s.awakenings);
  final int deep = s.deepMinutes;
  final String deepLabel =
      '${deep ~/ 60}:${(deep % 60).toString().padLeft(2, '0')}';

  // 标题日期必须跟着真实会话走：跨夜（睡够 3h 且上午结束）才叫「昨夜」，
  // 白天临时试跑的一次会话就是「今天」，不能再无脑写「昨夜」。
  final DateTime ended = s.endedAt ?? DateTime.now();
  final bool overnight =
      ended.hour < 12 && duration.inHours >= 3;
  final String dayPrefix = overnight ? '昨夜' : '今天';

  return DfReportData(
    dateLabel: '$dayPrefix · ${s.startedAt.month}月${s.startedAt.day}日',
    score: score,
    summary: summarizeScore(score),
    deepLabel: deepLabel,
    awakenings: s.awakenings,
    durationLabel: (duration.inMinutes / 60).toStringAsFixed(1),
    moodCount: moods.length,
    moodBars: bars,
  );
}

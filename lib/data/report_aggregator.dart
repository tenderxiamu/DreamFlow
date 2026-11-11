import '../screens/df_report_screen.dart';
import 'db.dart';
import 'df_health.dart';
import 'health_sleep.dart';
import 'light_sleep.dart';
import 'sleep_analysis.dart';

/// M5 / M11 / M13：本地报告聚合 —— 把 Drift 里的睡眠会话、情绪行，
/// 以及（授权后）系统健康库里的实测睡眠，折算成报告屏快照。
///
/// M11 起不再「取最近一行为王」，而是把最近 30 晚一起交给 [buildSleepReport]：
/// 由纯函数算出周环比、作息波动、连续天数与洞察句，聚合层只做 date→行 的搬运。
///
/// M13 起多了一路数据源：**同一晚只认一个来源，绝不混用**。
/// 健康库里有这天的实测记录，就用实测；没有才用本机交互推算。
/// 理由很实际 —— 两条来源的「夜醒次数」口径完全不同（手环数得到 1 分钟微觉醒，
/// 用户只点过两次「再睡 5 分钟」），混在一张趋势图上比缺数据更误导人。
Future<DfReportData?> aggregateLatestReport() async {
  final List<SleepSession> sessions =
      await DreamFlowDb.instance.recentSessions(limit: 30);

  // 健康数据拿不到时 status 会是 unsupported/denied，nights 为空，
  // 整条链路自然退回「推算」，不会抛异常、也不会空转。
  final DfHealthSnapshot health = await DfHealth.snapshot();

  final List<DfNightInput> estimated = <DfNightInput>[
    for (final SleepSession s in sessions)
      DfNightInput(
        bedTime: s.startedAt,
        wakeTime: s.endedAt ?? s.startedAt,
        awakenings: s.awakenings,
        storedScore: s.score,
      ),
  ];

  final List<DfNightInput> inputs = mergeNightSources(
    estimated: estimated,
    measured: <DfNightInput>[
      for (final DfMeasuredNight night in health.nights) toNightInput(night),
    ],
  );

  final DfSleepReport? report = buildSleepReport(inputs);
  if (report == null) return null;

  final List<MoodRecord> moods = await DreamFlowDb.instance.recentMoods(days: 7);

  // 按自然日聚合情绪强度：同一周几在 8 天窗口里可能出现两次，
  // 早期按 weekday 分组会把两天混成一条，这里改为按日期分组。
  final Map<String, List<int>> byDay = <String, List<int>>{};
  for (final MoodRecord m in moods) {
    final String key = dayKeyOf(m.createdAt);
    byDay.putIfAbsent(key, () => <int>[]).add(m.intensity);
  }
  final DateTime today = DateTime.now();
  final List<({String label, int value})> bars = <({String label, int value})>[];
  for (int i = 6; i >= 0; i--) {
    final DateTime day = today.subtract(Duration(days: i));
    final List<int>? list = byDay[dayKeyOf(day)];
    if (list == null || list.isEmpty) continue;
    final double avg =
        list.fold<int>(0, (int a, int b) => a + b) / list.length;
    bars.add((
      label: weekdayLabelOf(day),
      value: (avg / 5 * 100).round().clamp(0, 100),
    ));
  }

  final DfNightStat latest = report.latest;
  // 「昨夜」= 晚上入睡或睡够 3 小时且上午结束；白天试跑的一次会话是「今天」
  final bool overnight =
      latest.bedTime.hour >= 18 ||
          (latest.wakeTime.hour < 12 && latest.duration.inHours >= 3);
  final String dayPrefix = overnight ? '昨夜' : '今天';

  return DfReportData(
    dateLabel: '$dayPrefix · ${latest.day.month}月${latest.day.day}日',
    score: latest.score,
    summary: summarizeScore(latest.score),
    durationLabel: latest.hours.toStringAsFixed(1),
    awakenings: latest.awakenings,
    cycles: report.cycles,
    moodCount: moods.length,
    moodBars: bars,
    bedLabel: report.bedLabel,
    wakeLabel: report.wakeLabel,
    bedSpreadMinutes: report.bedSpreadMinutes,
    breakdown: report.breakdown,
    trend: report.trend,
    insights: report.insights,
    avgHoursLabel: report.avgHours.toStringAsFixed(1),
    avgScore: report.avgScore,
    scoreDelta: report.delta,
    streak: report.streak,
    nightCount: report.nights.length,
    health: health.status,
    measured: latest.measured,
    hasStages: latest.hasStages,
    deepMinutes: latest.deepMinutes ?? 0,
    lightMinutes: latest.lightMinutes ?? 0,
    remMinutes: latest.remMinutes ?? 0,
    awakeMinutes: latest.awakeMinutes ?? 0,
    measuredNights:
        report.nights.where((DfNightStat n) => n.measured).length,
  );
}

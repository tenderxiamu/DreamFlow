/// M11：睡眠分析（纯函数，不依赖 drift / UI）。
///
/// 设计原则（与 M10 情绪卡一致）：**只用真实记录**。
/// 一期没有心率 / 体动传感器，因此这里不产出「深睡比例」这类无法测量的指标，
/// 只做能从 `SleepSessions` 行诚实算出来的东西：
///
/// - 时长、入睡/醒来时刻（实测）
/// - 夜醒次数（用户点「再睡 5 分钟」的真实次数）
/// - 入睡时刻波动（规律性，实测推导）
/// - 评分拆解（复现 `estimateScore` 的公式，让分数可解释）
/// - 周环比、连续记录天数
///
/// 所有阈值都写在这里，UI 只负责排版。
library;

import 'dart:math' as math;

import 'light_sleep.dart';

/// 一晚睡眠的原始输入（由 `SleepSessions` 行投影而来）。
class DfNightInput {
  const DfNightInput({
    required this.bedTime,
    required this.wakeTime,
    required this.awakenings,
    this.storedScore,
  });

  final DateTime bedTime;
  final DateTime wakeTime;

  /// 夜间「再睡 5 分钟」的次数
  final int awakenings;

  /// 落库时算好的分（历史数据可能为 null）
  final int? storedScore;
}

/// 一晚的派生统计。
class DfNightStat {
  const DfNightStat({
    required this.bedTime,
    required this.wakeTime,
    required this.duration,
    required this.awakenings,
    required this.score,
    required this.scoreFromStore,
  });

  factory DfNightStat.from(DfNightInput input) {
    final Duration raw = input.wakeTime.difference(input.bedTime);
    final Duration duration = raw.isNegative ? Duration.zero : raw;
    final int awakenings = input.awakenings < 0 ? 0 : input.awakenings;

    final int? stored = input.storedScore;
    final int score = stored != null
        ? stored.clamp(0, 100)
        : estimateScore(duration: duration, snoozes: awakenings);

    return DfNightStat(
      bedTime: input.bedTime,
      wakeTime: input.wakeTime,
      duration: duration,
      awakenings: awakenings,
      score: score,
      scoreFromStore: stored != null,
    );
  }

  final DateTime bedTime;
  final DateTime wakeTime;
  final Duration duration;
  final int awakenings;
  final int score;

  /// 分数是落库时算的（false = 这里补算，用于旧数据缺分）
  final bool scoreFromStore;

  double get hours => duration.inMinutes / 60.0;

  /// 归属日：以**醒来那天**为准（跨夜睡眠算到第二天，符合「昨夜」的语感）
  DateTime get day => DateTime(wakeTime.year, wakeTime.month, wakeTime.day);

  /// 唯一键，用于和情绪按天对齐
  String get dayKey => _dayKey(day);

  /// 趋势图上的单字标签（一 / 二 / … / 日）
  String get weekdayShort => _weekdayShort[day.weekday - 1];

  String get dateLabel => '${day.month}月${day.day}日';
}

/// 评分拆解的一项。
class DfScorePart {
  const DfScorePart({
    required this.label,
    required this.value,
    required this.max,
    this.negative = false,
  });

  final String label;

  /// 分值；[negative] 时是扣分（正数表示扣了多少）
  final int value;
  final int max;
  final bool negative;
}

/// 趋势图上的一个点（score = null 表示那晚没有记录）
class DfNightPoint {
  const DfNightPoint({
    required this.label,
    required this.score,
    required this.dayKey,
  });

  final String label;
  final int? score;
  final String dayKey;

  bool get hasData => score != null;
}

/// 报告聚合结果。
class DfSleepReport {
  const DfSleepReport({
    required this.nights,
    required this.latest,
    required this.breakdown,
    required this.trend,
    required this.bedLabel,
    required this.wakeLabel,
    required this.bedSpreadMinutes,
    required this.avgHours,
    required this.avgScore,
    required this.streak,
    required this.cycles,
    required this.insights,
    this.prevAvgScore,
  });

  /// 最近若干晚，按时间**升序**（旧 → 新）
  final List<DfNightStat> nights;
  final DfNightStat latest;

  /// 最近一晚的评分构成
  final List<DfScorePart> breakdown;

  /// 最近 7 个自然日（含空缺）
  final List<DfNightPoint> trend;

  final String bedLabel;
  final String wakeLabel;

  /// 入睡时刻的总体标准差（分钟）；不足 2 晚为 0
  final int bedSpreadMinutes;

  final double avgHours;
  final int avgScore;

  /// 连续记录天数（以最近一晚为终点往前数）
  final int streak;

  /// 最近一晚包含的完整睡眠周期数（90 分钟一个，向下取整）
  final int cycles;

  final List<String> insights;

  /// 前一个 7 天的平均分（样本不足为 null）
  final int? prevAvgScore;

  /// 周环比（正 = 变好）；无上期样本为 null
  int? get delta {
    final int? prev = prevAvgScore;
    if (prev == null) return null;
    return avgScore - prev;
  }

  /// 参与本次统计的夜晚数
  int get nightCount => nights.length;
}

/// 窗口大小：趋势与均值都看最近 7 晚
const int kSleepWindowNights = 7;

/// 规律性判定阈值：入睡时刻标准差超过这个值就算「在漂」
const int kBedtimeDriftMinutes = 45;

/// 偏短睡眠阈值（小时）
const double kShortSleepHours = 6.5;

/// 生成报告。输入为空返回 null（UI 走空态）。
DfSleepReport? buildSleepReport(
  List<DfNightInput> inputs, {
  DateTime? now,
}) {
  if (inputs.isEmpty) return null;

  final List<DfNightStat> all = inputs.map(DfNightStat.from).toList()
    ..sort((DfNightStat a, DfNightStat b) => a.wakeTime.compareTo(b.wakeTime));

  final DateTime anchor = now ?? DateTime.now();
  final DfNightStat latest = all.last;

  // 最近 7 晚（按记录条数，不是自然日）
  final List<DfNightStat> window = all.length <= kSleepWindowNights
      ? all
      : all.sublist(all.length - kSleepWindowNights);

  final double avgHours =
      window.fold<int>(0, (int a, DfNightStat n) => a + n.duration.inMinutes) /
          window.length /
          60.0;
  final int avgScore =
      (window.fold<int>(0, (int a, DfNightStat n) => a + n.score) / window.length)
          .round();

  // 前一个 7 天：只看落在 [最近一晚 -13 天, 最近一晚 -7 天) 的会话
  final DateTime latestDay = latest.day;
  final List<DfNightStat> prev = all.where((DfNightStat n) {
    final int diff = latestDay.difference(n.day).inDays;
    return diff >= 7 && diff < 14;
  }).toList();
  final int? prevAvg = prev.isEmpty
      ? null
      : (prev.fold<int>(0, (int a, DfNightStat n) => a + n.score) / prev.length)
          .round();

  // 规律性：入睡时刻以 18:00 为一天起点，跨零点不会算错
  final List<int> bedMinutes =
      window.map((DfNightStat n) => _nightMinutes(n.bedTime)).toList();
  final int spread = _stdDev(bedMinutes).round();

  return DfSleepReport(
    nights: window,
    latest: latest,
    breakdown: _breakdown(latest),
    trend: _trend(all, anchor),
    bedLabel: _hhmm(latest.bedTime),
    wakeLabel: _hhmm(latest.wakeTime),
    bedSpreadMinutes: spread,
    avgHours: avgHours,
    avgScore: avgScore,
    streak: _streak(all),
    cycles: latest.duration.inMinutes ~/ kSleepCycleMinutes,
    insights: _insights(
      window: window,
      latest: latest,
      avgHours: avgHours,
      avgScore: avgScore,
      prevAvg: prevAvg,
      spread: spread,
    ),
    prevAvgScore: prevAvg,
  );
}

/// 复现 [estimateScore] 的公式，把分数拆成看得懂的三项。
List<DfScorePart> _breakdown(DfNightStat n) {
  final int durationPart = (n.hours / 8 * 70).round().clamp(0, 70);
  return <DfScorePart>[
    DfScorePart(label: '睡眠时长', value: durationPart, max: 70),
    const DfScorePart(label: '基础分', value: 30, max: 30),
    DfScorePart(
      label: '夜间醒来',
      value: (n.awakenings * 6).clamp(0, 100),
      max: 100,
      negative: true,
    ),
  ];
}

/// 最近 7 个自然日（含没有记录的夜晚），锚定在 [anchor]。
List<DfNightPoint> _trend(List<DfNightStat> all, DateTime anchor) {
  final Map<String, DfNightStat> byDay = <String, DfNightStat>{};
  for (final DfNightStat n in all) {
    // 同一天有多次会话时，取分数最高的那次（完整夜通常分更高，小睡不会盖掉）
    final DfNightStat? old = byDay[n.dayKey];
    if (old == null || n.score >= old.score) byDay[n.dayKey] = n;
  }

  final DateTime today = DateTime(anchor.year, anchor.month, anchor.day);
  final List<DfNightPoint> points = <DfNightPoint>[];
  for (int i = kSleepWindowNights - 1; i >= 0; i--) {
    final DateTime d = today.subtract(Duration(days: i));
    final String key = _dayKey(d);
    points.add(DfNightPoint(
      label: _weekdayShort[d.weekday - 1],
      score: byDay[key]?.score,
      dayKey: key,
    ));
  }
  return points;
}

/// 连续记录天数：从最近一晚往前数，每天都有记录才算
int _streak(List<DfNightStat> all) {
  final Set<String> days = all.map((DfNightStat n) => n.dayKey).toSet();
  int count = 1;
  DateTime cursor = all.last.day.subtract(const Duration(days: 1));
  while (days.contains(_dayKey(cursor))) {
    count++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return count;
}

List<String> _insights({
  required List<DfNightStat> window,
  required DfNightStat latest,
  required double avgHours,
  required int avgScore,
  required int? prevAvg,
  required int spread,
}) {
  final List<String> out = <String>[];
  final int awakeTotal =
      window.fold<int>(0, (int a, DfNightStat n) => a + n.awakenings);

  if (latest.awakenings >= 2 || awakeTotal >= window.length) {
    final String when = latest.awakenings >= 2
        ? '昨晚醒了 ${latest.awakenings} 次'
        : '近 ${window.length} 晚一共醒了 $awakeTotal 次';
    out.add('$when，连续性是目前最弱的一环。睡前少喝水、把手机放远些，会比早点躺下更有用。');
  }

  if (spread > kBedtimeDriftMinutes) {
    out.add('入睡时刻前后差了约 $spread 分钟，作息在漂。固定上床时刻，比某一天睡够更重要。');
  }

  if (avgHours < kShortSleepHours) {
    out.add(
      '近 ${window.length} 晚平均只睡了 ${avgHours.toStringAsFixed(1)} 小时，偏短。'
      '今晚试着比平时早半小时关灯。',
    );
  }

  final int? delta = prevAvg == null ? null : avgScore - prevAvg;
  if (delta != null && delta >= 5) {
    out.add('比上一周平均高 $delta 分，这个节奏在变好，别急着改。');
  } else if (delta != null && delta <= -5) {
    out.add('比上一周平均低 ${-delta} 分，最近是不是有点累？今晚早点躺下。');
  }

  if (out.isEmpty) {
    out.add('节奏稳，睡得也够。保持现在的上床时刻就好。');
  }
  return out.take(3).toList();
}

// ---- 小工具 ----

const List<String> _weekdayShort = <String>['一', '二', '三', '四', '五', '六', '日'];

/// 自然日键（格式与 [DfNightStat.dayKey] 一致），供情绪记录按天对齐。
String dayKeyOf(DateTime d) =>
    _dayKey(DateTime(d.year, d.month, d.day));

/// 周几单字标签（一 / 二 / … / 日），供图表横轴使用。
String weekdayLabelOf(DateTime d) => _weekdayShort[d.weekday - 1];

String _dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// 以 18:00 为一天起点，把时刻压成 0-1439 的分钟数（跨零点连续）。
///
/// 23:40 → 340，00:30 → 390：相差 50 分钟，而不是 −1390。
int _nightMinutes(DateTime t) {
  final int m = t.hour * 60 + t.minute;
  return m >= 18 * 60 ? m - 18 * 60 : m + 6 * 60;
}

/// 总体标准差（样本为空返回 0；单样本为 0）
double _stdDev(List<int> xs) {
  if (xs.length < 2) return 0;
  final double mean = xs.fold<int>(0, (int a, int b) => a + b) / xs.length;
  final double variance = xs.fold<double>(
        0,
        (double a, int x) => a + (x - mean) * (x - mean),
      ) /
      xs.length;
  return math.sqrt(variance < 0 ? 0 : variance);
}

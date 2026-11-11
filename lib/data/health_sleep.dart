/// M13：把系统健康库（Health Connect / HealthKit）里的原始睡眠会话
/// 聚合成「一夜」。全部是纯函数，不碰平台通道、不碰数据库，便于单测。
///
/// 为什么单独一层：手环厂商写进健康库的记录长什么样，各家都不一样 ——
/// 有的一次给一整夜带分期，有的拆成「入睡段 + 夜醒段 + 回笼段」三条，
/// 有的只给一个 start/end 不带分期。把这些差异全部收在这里，
/// 上层（报告聚合、报告屏）只面对一种形状：[DfMeasuredNight]。
library;

import 'sleep_analysis.dart' show DfNightInput, dayKeyOf;

/// 一段连续的睡眠分期。
enum DfStageKind {
  /// 清醒（含离床）
  awake,

  /// 浅睡 / N1-N2
  light,

  /// 深睡 / N3
  deep,

  /// 快速眼动
  rem,

  /// 厂商未标注的睡眠段
  unknown;

  /// Health Connect 的 `SleepSessionRecord.STAGE_*` 常量 → 本地枚举。
  ///
  /// 1=AWAKE 2=SLEEPING 3=OUT_OF_BED 4=LIGHT 5=DEEP 6=REM 7=UNKNOWN
  static DfStageKind fromHealthConnect(int raw) {
    switch (raw) {
      case 1:
      case 3:
        return DfStageKind.awake;
      case 4:
        return DfStageKind.light;
      case 5:
        return DfStageKind.deep;
      case 6:
        return DfStageKind.rem;
      default:
        return DfStageKind.unknown;
    }
  }
}

/// 一个分期片段（时间区间 + 类型）。
class DfStageSpan {
  const DfStageSpan({
    required this.start,
    required this.end,
    required this.kind,
  });

  final DateTime start;
  final DateTime end;
  final DfStageKind kind;

  int get minutes => end.difference(start).inMinutes;
}

/// 健康库里的一条原始睡眠会话（可能只是半晚）。
class DfHealthSession {
  const DfHealthSession({
    required this.start,
    required this.end,
    this.stages = const <DfStageSpan>[],
  });

  final DateTime start;
  final DateTime end;

  /// 分期明细；为空表示该来源只给了起止时间
  final List<DfStageSpan> stages;

  bool get hasStages => stages.isNotEmpty;
}

/// 聚合后的一夜（报告与趋势图只认这个）。
class DfMeasuredNight {
  const DfMeasuredNight({
    required this.bedTime,
    required this.wakeTime,
    required this.deepMinutes,
    required this.lightMinutes,
    required this.remMinutes,
    required this.awakeMinutes,
    required this.awakenings,
    required this.hasStages,
  });

  final DateTime bedTime;
  final DateTime wakeTime;
  final int deepMinutes;
  final int lightMinutes;
  final int remMinutes;

  /// 夜里清醒的总分钟数（不含入睡前与起床后）
  final int awakeMinutes;

  /// 夜醒次数（≥ [kAwakeningMinMinutes] 分钟的清醒段，不含首尾）
  final int awakenings;

  /// 来源是否带分期明细（false 时只能给时长，结构卡不显示）
  final bool hasStages;

  Duration get duration => wakeTime.difference(bedTime);

  int get asleepMinutes => deepMinutes + lightMinutes + remMinutes;

  /// 分期总时长（睡眠 + 夜醒），结构条按它算占比
  int get stagedMinutes => asleepMinutes + awakeMinutes;

  double get asleepHours => asleepMinutes / 60.0;

  double get deepRatio =>
      asleepMinutes == 0 ? 0 : deepMinutes / asleepMinutes;

  DateTime get day => DateTime(wakeTime.year, wakeTime.month, wakeTime.day);

  String get dayKey => dayKeyOf(wakeTime);
}

/// 把实测夜转成报告输入。
DfNightInput toNightInput(DfMeasuredNight night) => DfNightInput(
      bedTime: night.bedTime,
      wakeTime: night.wakeTime,
      awakenings: night.awakenings,
      measured: true,
      deepMinutes: night.deepMinutes,
      lightMinutes: night.lightMinutes,
      remMinutes: night.remMinutes,
      awakeMinutes: night.awakeMinutes,
    );

/// 合并两种来源的夜晚：**同一晚只留一个来源，实测优先**。
///
/// 为什么不混：手环的「夜醒」是数出来的（含用户无感的微觉醒），
/// App 的「夜醒」是用户自己点出来的（只算他真觉得被打断的那几次）。
/// 两个口径混进同一张趋势图，等于拿两把尺子量同一件事。
List<DfNightInput> mergeNightSources({
  required List<DfNightInput> estimated,
  required List<DfNightInput> measured,
}) {
  final Map<String, DfNightInput> byDay = <String, DfNightInput>{
    for (final DfNightInput n in measured) dayKeyOf(n.wakeTime): n,
  };
  return <DfNightInput>[
    for (final DfNightInput n in estimated)
      if (!byDay.containsKey(dayKeyOf(n.wakeTime))) n,
    ...byDay.values,
  ];
}

/// 短于这个时长的不算「一夜」，按小睡丢弃（避免午睡把趋势图打乱）。
const int kNightMinSleepMinutes = 90;

/// 单次清醒不短于这个时长才计一次「夜醒」。
///
/// 手环能记到 1-2 分钟的微觉醒，人自己根本感觉不到；
/// 用 5 分钟这条线（WASO 的常用口径）算出来的次数，才和「昨晚醒了几次」对得上。
const int kAwakeningMinMinutes = 5;

/// 首尾这段清醒不算夜醒（那是入睡前和起床后）。
const int _edgeToleranceMinutes = 2;

/// 单条会话超过这个时长视为脏数据（跨了两天的错误记录）。
const int _maxSessionHours = 20;

/// 把原始会话聚合成按夜排列的结果（升序，旧 → 新）。
List<DfMeasuredNight> buildMeasuredNights(List<DfHealthSession> sessions) {
  final Map<String, _NightAcc> byDay = <String, _NightAcc>{};

  for (final DfHealthSession session in sessions) {
    if (!session.end.isAfter(session.start)) continue;
    if (session.end.difference(session.start).inHours > _maxSessionHours) {
      continue;
    }

    final _NightAcc part = _summarize(session);
    if (part.asleepMinutes < kNightMinSleepMinutes) continue; // 小睡

    byDay
        .putIfAbsent(dayKeyOf(session.end), () => _NightAcc.empty())
        .merge(part);
  }

  final List<DfMeasuredNight> nights =
      byDay.values.map((_NightAcc a) => a.toNight()).toList()
        ..sort((DfMeasuredNight a, DfMeasuredNight b) =>
            a.wakeTime.compareTo(b.wakeTime));
  return nights;
}

/// 单条会话的分期汇总。
_NightAcc _summarize(DfHealthSession session) {
  final _NightAcc acc = _NightAcc(
    start: session.start,
    end: session.end,
    hasStages: session.hasStages,
  );

  if (!session.hasStages) {
    // 只给了起止时间：整段按睡眠算，没有分期就不编分期
    acc.light = session.end.difference(session.start).inMinutes;
    return acc;
  }

  for (final DfStageSpan span in session.stages) {
    final int minutes = span.minutes;
    if (minutes <= 0) continue;
    switch (span.kind) {
      case DfStageKind.deep:
        acc.deep += minutes;
      case DfStageKind.rem:
        acc.rem += minutes;
      case DfStageKind.light:
      case DfStageKind.unknown:
        acc.light += minutes;
      case DfStageKind.awake:
        acc.awake += minutes;
        if (minutes >= kAwakeningMinMinutes && !_isEdge(span, session)) {
          acc.awakenings += 1;
        }
    }
  }
  return acc;
}

/// 贴着会话首尾的清醒段是「还没睡着」或「已经醒了」，不算夜醒。
bool _isEdge(DfStageSpan span, DfHealthSession session) {
  return span.start
              .difference(session.start)
              .inMinutes
              .abs() <=
          _edgeToleranceMinutes ||
      span.end.difference(session.end).inMinutes.abs() <= _edgeToleranceMinutes;
}

/// 同一夜的多条会话（如「上半夜 + 回笼觉」）合并成一夜。
class _NightAcc {
  _NightAcc({
    required this.start,
    required this.end,
    required this.hasStages,
  });

  factory _NightAcc.empty() => _NightAcc(
        start: DateTime.fromMillisecondsSinceEpoch(0),
        end: DateTime.fromMillisecondsSinceEpoch(0),
        hasStages: true,
      );

  DateTime start;
  DateTime end;
  bool hasStages;
  int deep = 0;
  int light = 0;
  int rem = 0;
  int awake = 0;
  int awakenings = 0;

  /// 第一次 merge 之前 start/end 是占位值，不能拿来比较大小
  bool _initialized = false;

  int get asleepMinutes => deep + light + rem;

  void merge(_NightAcc other) {
    if (!_initialized) {
      start = other.start;
      end = other.end;
      _initialized = true;
    } else {
      if (other.start.isBefore(start)) start = other.start;
      if (other.end.isAfter(end)) end = other.end;
    }
    deep += other.deep;
    light += other.light;
    rem += other.rem;
    awake += other.awake;
    awakenings += other.awakenings;
    // 只要有一段没有分期，整夜就不展示结构（不拿半套数据充数）
    hasStages = hasStages && other.hasStages;
  }

  DfMeasuredNight toNight() => DfMeasuredNight(
        bedTime: start,
        wakeTime: end,
        deepMinutes: deep,
        lightMinutes: light,
        remMinutes: rem,
        awakeMinutes: awake,
        awakenings: awakenings,
        hasStages: hasStages,
      );
}

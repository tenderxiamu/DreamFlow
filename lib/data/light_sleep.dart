/// M5 浅睡窗口启发式（一期无传感器数据的本地估算，全部为纯函数）。
///
/// 设计依据（§7 E）：在 90 分钟睡眠周期边界附近唤醒最轻松；
/// 一期没有 HealthKit / Health Connect 数据，用「入睡时刻 + 周期对齐」估算，
/// 并在 UI 上明示这是估算值（合规：不做医疗断言）。
library;

/// 睡眠周期时长（分钟）。业界常用 90 分钟 ± 个体差异。
const int kSleepCycleMinutes = 90;

/// 允许把唤醒时刻吸附到周期边界的最大偏移（分钟）。
/// 超出此范围则尊重用户设定的时刻，不做调整。
const int kCycleToleranceMinutes = 20;

/// 把 [target]（期望唤醒时刻）吸附到 [bedtime] 起算的周期边界。
///
/// 从入睡时刻起每 90 分钟是一个周期边界（浅睡窗口）。
/// 若 target 与最近边界的偏差 ≤ [toleranceMinutes]，返回边界时刻；否则原样返回。
DateTime alignToLightWindow(
  DateTime bedtime,
  DateTime target, {
  int cycleMinutes = kSleepCycleMinutes,
  int toleranceMinutes = kCycleToleranceMinutes,
}) {
  final Duration elapsed = target.difference(bedtime);
  if (elapsed.isNegative) return target;
  final int cycles = (elapsed.inMinutes / cycleMinutes).round();
  final int boundaryMinutes = cycles * cycleMinutes;
  if ((elapsed.inMinutes - boundaryMinutes).abs() > toleranceMinutes) {
    return target;
  }
  return bedtime.add(Duration(minutes: boundaryMinutes));
}

/// 估算入睡后第 [cycles] 个周期边界的唤醒时刻（浅睡窗口中点）。
DateTime lightWindowAfter(DateTime bedtime, {int cycles = 5}) {
  return bedtime.add(Duration(minutes: cycles * kSleepCycleMinutes));
}

/// 本地睡眠分估算（0-100，透明启发式，非医疗指标）。
///
/// - 时长：8 小时封顶 70 分
/// - 基础 30 分（有会话即给）
/// - 「再睡 5 分钟」每 +1 次 −6 分（碎片化唤醒）
int estimateScore({required Duration duration, required int snoozes}) {
  final double hours = duration.inMinutes / 60.0;
  final int durationScore = (hours / 8 * 70).round().clamp(0, 70);
  return (durationScore + 30 - snoozes * 6).clamp(0, 100);
}

/// 由睡眠分生成一句话摘要（报告副标题用）。
String summarizeScore(int score) {
  if (score >= 85) return '睡得又沉又稳，身体充电充足';
  if (score >= 70) return '入睡平稳，整体睡眠质量不错';
  if (score >= 55) return '睡眠尚可，中途有些许波动';
  return '昨晚睡得比较浅，今晚早点休息';
}

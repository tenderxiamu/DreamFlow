import 'dart:async';

import 'package:drift/drift.dart' show Value;

import 'db.dart';
import 'light_sleep.dart';
import 'sleep_schedule.dart';
import 'wake_alarm.dart';

/// M5 / M6.8：睡眠会话记录器 —— C 助眠流程开始 → E 唤醒「我醒了」之间的会话闭环。
///
/// - [begin] 在进入 C 屏时调用，记入睡时刻，并**重排用户设定的起床闹钟**
/// - [complete] 在 E 屏点「我醒了」时调用，落库 SleepSessions 并返回会话行
///
/// M6.8 改动：入睡时不再自动预约「入睡 + 7.5 小时」的固定唤醒。唤醒时刻唯一
/// 来源是 [SleepSchedule] 里用户设定的闹钟（可吸附浅睡窗口），音景播完不会唤醒。
class SleepSessionRecorder {
  SleepSessionRecorder._();

  static final SleepSessionRecorder instance = SleepSessionRecorder._();

  DateTime? _startedAt;
  Timer? _alarmTimer;

  /// 会话是否进行中
  bool get isActive => _startedAt != null;

  /// 入睡时刻（未开始时 null；报告屏用它做标题日期）
  DateTime? get startedAt => _startedAt;

  /// 开始会话。重复调用以最早一次为准（B 屏 → C 屏多次导航不重置）。
  ///
  /// 同时按用户设定的起床时刻重排闹钟（智能唤醒开启时会吸附到周期边界）。
  void begin() {
    _startedAt ??= DateTime.now();
    unawaited(SleepSchedule.instance.rescheduleAlarm());
  }

  /// 结束会话并落库。返回写入的会话行；失败/未开始返回 null。
  Future<SleepSession?> complete({int snoozes = 0}) async {
    final DateTime? start = _startedAt;
    _startedAt = null;
    cancelAlarm();
    unawaited(WakeAlarm.cancel());
    if (start == null) return null;
    final DateTime end = DateTime.now();
    final int score = estimateScore(
      duration: end.difference(start),
      snoozes: snoozes,
    );
    try {
      final int id = await DreamFlowDb.instance
          .addSession(SleepSessionsCompanion.insert(
        startedAt: start,
        endedAt: Value(end),
        score: Value(score),
        deepMinutes: Value((end.difference(start).inMinutes * 0.25).round()),
        awakenings: Value(snoozes),
      ));
      return SleepSession(
        id: id,
        startedAt: start,
        endedAt: end,
        score: score,
        deepMinutes: (end.difference(start).inMinutes * 0.25).round(),
        awakenings: snoozes,
        note: null,
      );
    } catch (_) {
      return null;
    }
  }

  // ---- 唤醒提醒（应用在前台时用 Timer 兜底；精确闹钟由平台通知负责，见 wake_alarm） ----

  /// 预约应用内唤醒回调（浅睡窗口对齐后的时刻）
  void scheduleInAppAlarm(DateTime at, void Function() onWake) {
    _alarmTimer?.cancel();
    final Duration delay = at.difference(DateTime.now());
    if (delay.isNegative) return;
    _alarmTimer = Timer(delay, () {
      if (_startedAt != null) onWake();
    });
  }

  void cancelAlarm() {
    _alarmTimer?.cancel();
    _alarmTimer = null;
  }
}

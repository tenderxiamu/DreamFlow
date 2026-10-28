import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'light_sleep.dart';
import 'sleep_session_recorder.dart';
import 'wake_alarm.dart';

/// M6.8：睡眠日程 —— **起床闹钟 + 睡眠定时关闭**，两者的唯一真相来源。
///
/// 为什么单独建一层（对应真机反馈「没有设置闹钟」「唤醒模式在音频播放结束后开启」）：
/// 旧实现的唤醒是挂在音景播放结束上的（`onFinished → /wakeup`），而虚拟时间轴
/// 的步长写错（step 0.02 / 1s）导致 **50 秒**就「播完」，于是用户刚躺下就被拉进
/// 唤醒流程。唤醒的唯一合法触发源只能是**时间**，绝不能是音频播放状态。
///
/// 规则：
/// - 音景结束（含定时关闭到点）→ 只停止播放，不唤醒
/// - 唤醒只由 [alarmEnabled] + [nextAlarmAt] 触发（系统通知 + 应用内 Timer 双保险）
/// - [smartWake] 开启时，把用户设定的时刻吸附到睡眠周期边界（浅睡窗口），
///   吸附范围 ±[kCycleToleranceMinutes]，超出则尊重用户原设定
class SleepSchedule {
  SleepSchedule._();

  static final SleepSchedule instance = SleepSchedule._();

  // ── 用户设定（持久化） ────────────────────────────────────────────────
  int alarmHour = 7;
  int alarmMinute = 30;
  bool alarmEnabled = true;

  /// 智能唤醒：把时刻吸附到 90 分钟周期边界（浅睡窗口）
  bool smartWake = true;

  // ── 运行期状态（不持久化） ────────────────────────────────────────────
  DateTime? _stopAt;
  Timer? _stopTimer;
  Timer? _alarmTimer;
  final StreamController<DateTime> _alarmFired =
      StreamController<DateTime>.broadcast();

  /// 闹钟真正响起的时刻（应用在前台时由 Timer 直接推）
  Stream<DateTime> get alarmFired => _alarmFired.stream;

  /// 音景停止时刻（null = 不自动停止）
  DateTime? get stopAt => _stopAt;

  /// 距离音景停止还剩多久
  Duration? get stopIn {
    final DateTime? at = _stopAt;
    if (at == null) return null;
    final Duration d = at.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  String get alarmLabel =>
      '${alarmHour.toString().padLeft(2, '0')}:${alarmMinute.toString().padLeft(2, '0')}';

  /// 起床时刻（今天或明天，取决于是否已过）；智能唤醒开启时做周期吸附
  DateTime nextAlarmAt({DateTime? from}) {
    final DateTime now = from ?? DateTime.now();
    DateTime at = DateTime(now.year, now.month, now.day, alarmHour, alarmMinute);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    if (!smartWake) return at;
    final DateTime? bedtime = SleepSessionRecorder.instance.startedAt;
    if (bedtime == null) return at;
    // 只在「入睡 → 闹钟」区间内吸附，且不早于现在
    final DateTime aligned = alignToLightWindow(bedtime, at);
    return aligned.isAfter(now) ? aligned : at;
  }

  // ── 持久化 ───────────────────────────────────────────────────────────

  Future<File> _file() async {
    final Directory dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}sleep_schedule.json');
  }

  Future<void> load() async {
    try {
      final File f = await _file();
      if (!await f.exists()) return;
      final Map<String, dynamic> m =
          jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      alarmHour = (m['alarmHour'] as num?)?.toInt() ?? alarmHour;
      alarmMinute = (m['alarmMinute'] as num?)?.toInt() ?? alarmMinute;
      alarmEnabled = m['alarmEnabled'] as bool? ?? alarmEnabled;
      smartWake = m['smartWake'] as bool? ?? smartWake;
    } catch (_) {
      // 读不到就用默认值，不阻断启动
    }
  }

  Future<void> save() async {
    try {
      final File f = await _file();
      await f.writeAsString(jsonEncode(<String, dynamic>{
        'alarmHour': alarmHour,
        'alarmMinute': alarmMinute,
        'alarmEnabled': alarmEnabled,
        'smartWake': smartWake,
      }));
    } catch (_) {/* 落盘失败不影响本次使用 */}
  }

  // ── 闹钟调度 ─────────────────────────────────────────────────────────

  /// 重新调度起床闹钟（设定变化 / 入睡开始时调用）
  Future<void> rescheduleAlarm() async {
    _alarmTimer?.cancel();
    _alarmTimer = null;
    if (!alarmEnabled) {
      await WakeAlarm.cancel();
      return;
    }
    final DateTime at = nextAlarmAt();
    final Duration delay = at.difference(DateTime.now());
    if (delay.isNegative) return;
    unawaited(WakeAlarm.scheduleAt(at));
    // Timer 只在应用进程存活时有效；后台/杀进程靠系统通知
    _alarmTimer = Timer(delay, () {
      _alarmFired.add(at);
      unawaited(WakeAlarm.cancel());
    });
  }

  Future<void> setAlarm({required int hour, required int minute, bool? enabled}) async {
    alarmHour = hour;
    alarmMinute = minute;
    if (enabled != null) alarmEnabled = enabled;
    await save();
    await rescheduleAlarm();
  }

  Future<void> setAlarmEnabled(bool on) async {
    alarmEnabled = on;
    await save();
    await rescheduleAlarm();
  }

  Future<void> setSmartWake(bool on) async {
    smartWake = on;
    await save();
    await rescheduleAlarm();
  }

  Future<void> cancelAlarm() async {
    _alarmTimer?.cancel();
    _alarmTimer = null;
    await WakeAlarm.cancel();
  }

  // ── 睡眠定时关闭 ─────────────────────────────────────────────────────

  /// 到点后回调一次（UI 收到后做淡出停止）；[duration] 为 null 表示取消
  void startSleepTimer(Duration? duration, {required VoidCallback onStop}) {
    _stopTimer?.cancel();
    _stopTimer = null;
    if (duration == null) {
      _stopAt = null;
      return;
    }
    _stopAt = DateTime.now().add(duration);
    _stopTimer = Timer(duration, () {
      _stopAt = null;
      _stopTimer = null;
      onStop();
    });
  }

  void cancelSleepTimer() {
    _stopTimer?.cancel();
    _stopTimer = null;
    _stopAt = null;
  }

  /// 定时关闭的展示文案：剩余 25 分钟 → 「25 分钟后停止」
  String? get stopLabel {
    final Duration? d = stopIn;
    if (d == null) return null;
    if (d.inMinutes >= 1) return '${d.inMinutes} 分钟后停止';
    return '${d.inSeconds} 秒后停止';
  }
}

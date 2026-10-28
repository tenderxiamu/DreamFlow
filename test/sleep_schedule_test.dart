import 'package:flutter_test/flutter_test.dart';

import 'package:dreamflow/data/light_sleep.dart';
import 'package:dreamflow/data/sleep_schedule.dart';

/// M6.8：起床闹钟的时间推导。
///
/// 唯一要求：**唤醒时刻必须是「下一个还没到的那个时刻」**，绝不能是已经过去的
/// 今天那个点（那会导致用户设完闹钟立刻被叫醒，或当晚永远等不到）。
void main() {
  final SleepSchedule s = SleepSchedule.instance;

  setUp(() {
    s.alarmHour = 7;
    s.alarmMinute = 30;
    s.alarmEnabled = true;
    s.smartWake = false;
  });

  test('还没到今天那个时刻 → 取今天', () {
    final DateTime now = DateTime(2026, 10, 28, 6, 0);
    expect(s.nextAlarmAt(from: now), DateTime(2026, 10, 28, 7, 30));
  });

  test('已经过了今天那个时刻 → 取明天', () {
    final DateTime now = DateTime(2026, 10, 28, 20, 0);
    expect(s.nextAlarmAt(from: now), DateTime(2026, 10, 29, 7, 30));
  });

  test('正好等于该时刻 → 也算过期，推到明天', () {
    final DateTime now = DateTime(2026, 10, 28, 7, 30);
    expect(s.nextAlarmAt(from: now), DateTime(2026, 10, 29, 7, 30));
  });

  test('label 补零格式化', () {
    s.alarmHour = 6;
    s.alarmMinute = 5;
    expect(s.alarmLabel, '06:05');
  });

  test('浅睡窗口吸附只在 ±20 分钟内生效', () {
    final DateTime bedtime = DateTime(2026, 10, 28, 23, 0);
    // 23:00 + 8 个 90 分钟周期 = 11:00 次日；10:50 距边界 10 分钟 → 吸附到 11:00
    expect(
      alignToLightWindow(bedtime, DateTime(2026, 10, 29, 10, 50)),
      DateTime(2026, 10, 29, 11, 0),
    );
    // 10:20 距边界 40 分钟 → 尊重用户设定，不吸附
    expect(
      alignToLightWindow(bedtime, DateTime(2026, 10, 29, 10, 20)),
      DateTime(2026, 10, 29, 10, 20),
    );
  });

  test('音景停止时刻：设定后 30 分钟', () {
    s.startSleepTimer(const Duration(minutes: 30), onStop: () {});
    final Duration? left = s.stopIn;
    expect(left, isNotNull);
    expect(left!.inMinutes, inInclusiveRange(29, 30));
    s.cancelSleepTimer();
    expect(s.stopIn, isNull);
    expect(s.stopAt, isNull);
  });
}

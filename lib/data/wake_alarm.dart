import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// M5：唤醒提醒 —— 到点用系统通知把用户带回 E 屏（浅睡窗口时刻）。
///
/// - Android：AlarmManager 精确闹钟（exactAllowWhileIdle），点通知进 /wakeup
/// - iOS：UNUserNotificationCenter 定时通知（后台音频 + 通知组合拳，见方案 §8）
///
/// 全部 fire-and-forget：通知失败只影响后台提醒，不阻断助眠主链路。
class WakeAlarm {
  WakeAlarm._();

  static const int _wakeNotificationId = 1001;
  static const String _channelId = 'com.dreamflow.dreamflow.wake';
  static bool _initialized = false;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// 初始化（main 启动时调用一次）。[onTap] 收到通知点击回调（payload 为路由）。
  static Future<void> init({void Function(String? payload)? onTap}) async {
    if (_initialized) return;
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (NotificationResponse r) =>
            onTap?.call(r.payload),
      );
      final AndroidFlutterLocalNotificationsPlugin? android =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
      _initialized = true;
    } catch (_) {
      // 初始化失败静默降级：应用内 Timer 仍可用
    }
  }

  /// 预约唤醒通知
  static Future<void> scheduleAt(DateTime at) async {
    if (!_initialized) return;
    try {
      await _plugin.zonedSchedule(
        _wakeNotificationId,
        '梦洄',
        '现在是浅睡窗口，该轻轻醒了',
        tz.TZDateTime.from(at, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            '渐进式唤醒',
            channelDescription: '到点轻轻唤醒你',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: '/wakeup',
      );
    } catch (_) {/* 静默降级 */}
  }

  /// 取消预约（会话提前结束时）
  static Future<void> cancel() async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(_wakeNotificationId);
    } catch (_) {/* ignore */}
  }
}

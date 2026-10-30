import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/router.dart';
import 'audio/df_soundscape.dart';
import 'data/df_account.dart';
import 'data/df_wallpaper.dart';
import 'data/sleep_schedule.dart';
import 'data/wake_alarm.dart';

/// DreamFlow 梦洄 · App 正式入口。
/// 陈列板（5 屏横排 + 一键切主题）入口见 lib/showcase/showcase_main.dart：
///   flutter run -t lib/showcase/showcase_main.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // M7：账号必须在首帧之前读回来，否则会先闪一下登录弹窗再消失
  await DfAccount.instance.load();
  // M3：后台音频服务（锁屏控制中心 + 通知栏前台服务）
  await initDfAudioService();
  // M6.8：读回用户设定的起床闹钟 / 智能唤醒开关
  await SleepSchedule.instance.load();
  // M7.2：壁纸选择。同样要在首帧前读回，否则会先纯色闪一下再出图
  await DfWallpapers.instance.load();
  // M5：唤醒通知（点通知回到 E 屏；失败静默降级为应用内 Timer）
  unawaited(WakeAlarm.init(onTap: handleNotificationTap));
  unawaited(SleepSchedule.instance.rescheduleAlarm());
  runApp(const ProviderScope(child: DreamFlowApp()));
}

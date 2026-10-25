import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'audio/df_soundscape.dart';

/// DreamFlow 梦洄 · App 正式入口。
/// 陈列板（5 屏横排 + 一键切主题）入口见 lib/showcase/showcase_main.dart：
///   flutter run -t lib/showcase/showcase_main.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // M3：后台音频服务（锁屏控制中心 + 通知栏前台服务）
  await initDfAudioService();
  runApp(const ProviderScope(child: DreamFlowApp()));
}

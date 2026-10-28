import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../audio/df_soundscape.dart';
import '../data/sleep_schedule.dart';
import '../design_system/df_theme.dart';
import 'router.dart';
import 'theme_provider.dart';

/// DreamFlow 梦洄 App 根组件。
/// 主题切换 = 换 ThemeData（DfPalette lerp 插值，§5.2），组件零改动。
class DreamFlowApp extends ConsumerWidget {
  const DreamFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DfAppTheme mode = ref.watch(themeProvider);
    return MaterialApp.router(
      title: '梦洄',
      debugShowCheckedModeBanner: false,
      theme: mode == DfAppTheme.night
          ? DfTheme.nightTheme(context)
          : DfTheme.paperTheme(context),
      routerConfig: ref.watch(routerProvider),
      // 关键修复：`MaterialApp` 会把 `_errorTextStyle`（黄色 + 双下划线 + monospace）
      // 作为整棵树的根级 `DefaultTextStyle`（flutter/src/material/app.dart）。
      // 本 App 的页面是自绘 `DfScreenScaffold`（DecoratedBox），没有 Material 覆盖它，
      // 于是每条 Text 都继承了那条黄双线。这里在根部显式清空装饰。
      builder: (BuildContext context, Widget? child) {
        return DefaultTextStyle(
          style: const TextStyle(decoration: TextDecoration.none),
          child: _AlarmGate(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}

/// M6.8：闹钟入口 —— **唤醒的唯一触发源**。
///
/// 旧实现把唤醒挂在音景播放结束上（`onFinished → /wakeup`），而虚拟时间轴的
/// 步长写错导致 50 秒就「播完」，用户刚躺下就被拉进唤醒页。现在只有
/// [SleepSchedule.alarmFired]（到点）才会跳转；音景播完只停播。
class _AlarmGate extends StatefulWidget {
  const _AlarmGate({required this.child});

  final Widget child;

  @override
  State<_AlarmGate> createState() => _AlarmGateState();
}

class _AlarmGateState extends State<_AlarmGate> {
  StreamSubscription<DateTime>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = SleepSchedule.instance.alarmFired.listen((DateTime at) {
      // 闹钟一响就停音景，避免音景和唤醒页抢音频焦点
      unawaited(dfSoundscapeController?.pause());
      SleepSchedule.instance.cancelSleepTimer();
      final BuildContext? ctx = rootNavigatorKey.currentContext;
      if (ctx != null) {
        GoRouter.of(ctx).go('/wakeup');
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

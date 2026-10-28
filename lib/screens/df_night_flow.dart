import 'dart:async';

import 'package:flutter/material.dart';

import 'package:dreamflow/audio/df_soundscape.dart';
import 'package:dreamflow/data/sleep_schedule.dart';
import 'package:dreamflow/design_system/df_theme.dart';
import 'package:dreamflow/screens/df_sleep_flow.dart';
import 'package:dreamflow/screens/df_wake_flow.dart';

/// C→E→D 的夜间主链路（陈列板 / 端到端演示用）：
///
/// ```
/// C 沉浸助眠  --起床闹钟到点-->  E 渐进式唤醒  --我醒了-->  D 睡眠报告
///                                       └--再睡 5 分钟-->  倒计时 --> 回到 E
/// ```
///
/// **M6.8 语义修正**：旧版是「C 播完 → E」，但那要求音景必须「播完」才唤醒，
/// 与现实完全相反（用户可能才躺下 5 分钟）。现在 C 只负责播放，
/// 唤醒唯一由 [SleepSchedule] 的起床闹钟触发；音景播完只停播。
class DfNightFlow extends StatefulWidget {
  const DfNightFlow({
    super.key,
    this.startPlaying = true,
    this.snoozeDuration = const Duration(minutes: 5),
    this.loadDuration = const Duration(milliseconds: 900),
    this.onEnterWake,
  });

  final bool startPlaying;
  final Duration snoozeDuration;
  final Duration loadDuration;

  /// 进入唤醒时的回调（宿主页面可做导航）
  final VoidCallback? onEnterWake;

  @override
  State<DfNightFlow> createState() => _DfNightFlowState();
}

enum _NightPhase { sleep, wake }

class _DfNightFlowState extends State<DfNightFlow> {
  _NightPhase _phase = _NightPhase.sleep;
  StreamSubscription<DateTime>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = SleepSchedule.instance.alarmFired.listen((_) => _enterWake());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _enterWake() {
    if (!mounted) return;
    // 进唤醒即停音景（音景与唤醒不同时占用音频焦点）
    dfSoundscapeController?.pause();
    setState(() => _phase = _NightPhase.wake);
    widget.onEnterWake?.call();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final bool night = _phase == _NightPhase.sleep;

    final Widget child = night
        ? DfSleepFlow(
            key: const ValueKey<String>('sleep'),
            startPlaying: widget.startPlaying,
          )
        : DfWakeFlow(
            key: const ValueKey<String>('wake'),
            snoozeDuration: widget.snoozeDuration,
            loadDuration: widget.loadDuration,
          );

    return Theme(
      data: night ? DfTheme.nightTheme(context) : DfTheme.paperTheme(context),
      child: AnimatedSwitcher(
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        // §8：仅透明度，不做布局位移
        transitionBuilder: (Widget child, Animation<double> animation) =>
            FadeTransition(opacity: animation, child: child),
        child: child,
      ),
    );
  }
}

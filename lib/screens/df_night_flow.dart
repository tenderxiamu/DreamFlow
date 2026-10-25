import 'package:flutter/material.dart';

import 'package:dreamflow/audio/df_soundscape.dart';
import 'package:dreamflow/design_system/df_theme.dart';
import 'package:dreamflow/screens/df_sleep_flow.dart';
import 'package:dreamflow/screens/df_wake_flow.dart';

/// C→E→D 的**夜间主链路**（§7 三屏之间的下一级流转）：
///
/// ```
/// C 沉浸助眠  --播完-->  E 渐进式唤醒  --我醒了-->  D 睡眠报告（loading → 正文）
///                              └--再睡 5 分钟-->  倒计时 --> 回到 E
/// ```
///
/// 主题归属（§5）：C 走 `t-night`，E / D 走 `t-paper`；链路内部按阶段切换，
/// 切换动画**只有 opacity**（§8：允许属性仅 transform / opacity，200ms），
/// 且在 `prefers-reduced-motion` 下降为 0ms。
class DfNightFlow extends StatefulWidget {
  const DfNightFlow({
    super.key,
    this.startPlaying = true,
    this.startProgress = 0.38,
    this.tickInterval = const Duration(seconds: 1),
    this.step = 0.02,
    this.snoozeDuration = const Duration(minutes: 5),
    this.loadDuration = const Duration(milliseconds: 900),
    this.onEnterWake,
  });

  final bool startPlaying;
  final double startProgress;
  final Duration tickInterval;
  final double step;
  final Duration snoozeDuration;
  final Duration loadDuration;

  /// 播放结束、进入渐进式唤醒时回调（§7 C 注脚的落地）
  final VoidCallback? onEnterWake;

  @override
  State<DfNightFlow> createState() => _DfNightFlowState();
}

enum _NightPhase { sleep, wake }

class _DfNightFlowState extends State<DfNightFlow> {
  _NightPhase _phase = _NightPhase.sleep;

  void _enterWake() {
    if (!mounted) return;
    // M3：进入唤醒即停音景（§7 C 注脚：播完进入渐进式唤醒）
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
            startProgress: widget.startProgress,
            tickInterval: widget.tickInterval,
            step: widget.step,
            onFinished: _enterWake,
          )
        : DfWakeFlow(
            key: const ValueKey<String>('wake'),
            snoozeDuration: widget.snoozeDuration,
            tickInterval: widget.tickInterval,
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

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:dreamflow/data/sleep_session_recorder.dart';
import 'package:dreamflow/design_system/df_tokens.dart';
import 'package:dreamflow/design_system/df_type.dart';
import 'package:dreamflow/design_system/widgets/df_controls.dart';
import 'package:dreamflow/design_system/widgets/df_data.dart';
import 'package:dreamflow/design_system/widgets/df_scene.dart';
import 'package:dreamflow/design_system/widgets/df_screen.dart';
import 'package:dreamflow/design_system/widgets/df_surfaces.dart';
import 'package:dreamflow/design_system/widgets/df_states.dart';
import 'package:dreamflow/screens/df_report_screen.dart';
import 'package:dreamflow/screens/df_wake_screen.dart';

/// 渐进式唤醒（§7 E）的**两个出口**：
/// - 我醒了 → 睡眠报告（先 loading，数据就绪后切正文）
/// - 再睡 5 分钟 → 倒计时 → 重新回到唤醒态（时刻 +5 分钟）
enum DfWakePhase { waking, snoozing, reportLoading, reportReady }

/// §7 E 渐进式唤醒 —— **可交互版**（视觉规格不变，只接上两个出口）。
///
/// - [waking]  渲染 [DfWakeScreen]，底部主按钮「我醒了」/ 次按钮「再睡 5 分钟」
/// - [snoozing] 倒计时屏：日出场景 + 毛笔字倒计时 + 「现在就醒」可随时中断
/// - [reportLoading] → [reportReady]：报告依赖昨夜数据，是**最需要**加载态的页面
///   （§12 缺口 4），因此这里走的是 `DfReportScreen(state: …)` 而非自定义转圈
///
/// 时长参数化（[snoozeDuration] / [tickInterval] / [loadDuration]），
/// 测试可注入毫秒级跑完整分支而不改变展示的虚拟时刻（恒为 05:00 → 00:00）。
class DfWakeFlow extends StatefulWidget {
  const DfWakeFlow({
    super.key,
    this.wakeTime,
    this.snoozeDuration = const Duration(minutes: 5),
    this.tickInterval = const Duration(seconds: 1),
    this.loadDuration = const Duration(milliseconds: 900),
    this.onRetryReport,
    this.recordSession = false,
    this.reportLoader,
  });

  /// 首次唤醒时刻（HH:mm）；null → 取系统当前时刻，绝不写死假时间
  final String? wakeTime;

  final Duration snoozeDuration;
  final Duration tickInterval;

  /// 报告加载时长（模拟取昨夜数据）
  final Duration loadDuration;

  /// 报告异常态的重试回调（§12 缺口 4：异常态必须给出可操作出口）
  final VoidCallback? onRetryReport;

  /// M5：true 时「我醒了」会把本次会话（含再睡次数）落库 SleepSessions
  final bool recordSession;

  /// M5：报告数据加载器（本地聚合）；null = 静态演示稿
  final DfReportLoader? reportLoader;

  @override
  State<DfWakeFlow> createState() => _DfWakeFlowState();
}

class _DfWakeFlowState extends State<DfWakeFlow> {
  DfWakePhase _phase = DfWakePhase.waking;
  int _snoozes = 0;
  Timer? _timer;
  int _remainingTicks = 0;
  int _totalTicks = 1;
  Timer? _loadTimer;

  @override
  void dispose() {
    _timer?.cancel();
    _loadTimer?.cancel();
    super.dispose();
  }

  int get _baseMinutes {
    final String given = widget.wakeTime ?? '';
    if (given.isEmpty) {
      final DateTime n = DateTime.now();
      return n.hour * 60 + n.minute;
    }
    final List<String> parts = given.split(':');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  /// 本次陪伴的真实时长（无进行中会话 → null，页面不显示该卡）
  String? get _companionLabel {
    final DateTime? start = SleepSessionRecorder.instance.startedAt;
    if (start == null) return null;
    final Duration d = DateTime.now().difference(start);
    if (d.isNegative) return null;
    return '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}';
  }

  /// 起 6:42 → 再睡一次 6:47 ……（§7 E「再睡 5 分钟」语义）
  String get _currentWakeTime {
    final int total = _baseMinutes + 5 * _snoozes;
    final int h = (total ~/ 60) % 24;
    final int m = total % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  void _snooze() {
    _timer?.cancel();
    _totalTicks = (widget.snoozeDuration.inMilliseconds /
            widget.tickInterval.inMilliseconds)
        .round()
        .clamp(1, 100000);
    _remainingTicks = _totalTicks;
    setState(() => _phase = DfWakePhase.snoozing);
    _timer = Timer.periodic(widget.tickInterval, (_) => _tickSnooze());
  }

  void _tickSnooze() {
    if (!mounted) return;
    final int next = _remainingTicks - 1;
    if (next <= 0) {
      _timer?.cancel();
      setState(() {
        _snoozes += 1;
        _phase = DfWakePhase.waking;
      });
      return;
    }
    setState(() => _remainingTicks = next);
  }

  void _wakeNow() {
    _timer?.cancel();
    setState(() => _phase = DfWakePhase.waking);
  }

  /// 我醒了 → 报告（先 loading，取到数据后切正文）
  void _openReport() {
    // M5：会话闭环落库（含再睡次数），失败不阻断报告
    if (widget.recordSession) {
      SleepSessionRecorder.instance.complete(snoozes: _snoozes);
    }
    setState(() => _phase = DfWakePhase.reportLoading);
    _loadTimer?.cancel();
    _loadTimer = Timer(widget.loadDuration, () {
      if (!mounted) return;
      setState(() => _phase = DfWakePhase.reportReady);
    });
  }

  /// 倒计时展示的虚拟剩余时间：恒按 5 分钟换算，与测试步长无关
  String get _remainingLabel {
    final double ratio = _remainingTicks / _totalTicks;
    final int seconds = (widget.snoozeDuration.inSeconds * ratio).ceil();
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case DfWakePhase.waking:
        return DfWakeScreen(
          wakeTime: _currentWakeTime,
          companionLabel: _companionLabel,
          onWakeUp: _openReport,
          onSnooze: _snooze,
        );
      case DfWakePhase.snoozing:
        return _SnoozeView(
          remaining: _remainingLabel,
          wakeTime: _currentWakeTime,
          onCancel: _wakeNow,
        );
      case DfWakePhase.reportLoading:
        return DfReportScreen(
          state: DfStateKind.loading,
          onRetry: widget.onRetryReport,
        );
      case DfWakePhase.reportReady:
        return DfReportScreen(loader: widget.reportLoader);
    }
  }
}

/// 再睡 5 分钟的倒计时屏：视觉沿用 §7 E 的日出场景，只是把「时刻」换成倒计时。
/// （设计侧未单独出稿，属框架层缺省实现，出稿后可无痛替换。）
class _SnoozeView extends StatelessWidget {
  const _SnoozeView({
    required this.remaining,
    required this.wakeTime,
    required this.onCancel,
  });

  final String remaining;
  final String wakeTime;
  final VoidCallback onCancel;

  /// 屏上时刻取系统时间
  static String _nowHm() {
    final DateTime n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:'
        '${n.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);

    return DfScreenScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 2),
          DfScene(
            height: 196,
            variant: DfSceneVariant.sunrise,
            overlay: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Semantics(
                  liveRegion: true,
                  child: Text(remaining, style: DfType.display(context, p.text)),
                ),
                const SizedBox(height: 8),
                Text(
                  '梦洄会轻轻地再叫你一次',
                  style: DfType.sub(context, p.text2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Text('再睡一会儿', style: DfType.bodyS(context, p.text)),
                    Text(
                      _nowHm(),
                      style: DfType.caption(context, p.mistGreen).copyWith(
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                // 剩余进度：`remaining` 已格式化，这里按秒反算比例绘制
                DfBarLine(value: _ratioOf(remaining), success: true),
                const SizedBox(height: 10),
                Text(
                  '将于 $wakeTime 再次用最轻的光唤醒你',
                  // §3 注：卡内弱信息用 `--text-2`（`--text-3` 夜墨下对卡片仅 4.06:1）
                  style: DfType.caption(context, p.text2),
                ),
              ],
            ),
          ),
        ],
      ),
      bottom: DfGhostButton(label: '现在就醒', onPressed: onCancel),
    );
  }

  /// "04:35" → 剩余比例（相对 5 分钟）
  static double _ratioOf(String label) {
    final List<String> parts = label.split(':');
    if (parts.length != 2) return 1;
    final int seconds =
        (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
    return (seconds / 300).clamp(0.0, 1.0);
  }
}

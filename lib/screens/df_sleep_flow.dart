import 'dart:async';

import 'package:flutter/material.dart';

import 'package:dreamflow/audio/df_soundscape.dart';
import 'package:dreamflow/data/sleep_session_recorder.dart';
import 'package:dreamflow/design_system/df_tokens.dart';
import 'package:dreamflow/design_system/df_type.dart';
import 'package:dreamflow/design_system/widgets/df_controls.dart';
import 'package:dreamflow/design_system/widgets/df_data.dart';
import 'package:dreamflow/design_system/widgets/df_icons.dart';
import 'package:dreamflow/design_system/widgets/df_scene.dart';
import 'package:dreamflow/design_system/widgets/df_screen.dart';
import 'package:dreamflow/design_system/widgets/df_surfaces.dart';
import 'package:dreamflow/screens/df_sleep_screen.dart';

/// §7 C 沉浸助眠 —— **可交互版**（同一屏，只是把静态数据换成播放状态机）。
///
/// 相对 [DfSleepScreen] 的增量（均为「下一级功能」，不动视觉规格）：
/// - 播放 / 暂停切换：播放键字形 `play ⇄ pause`，语义标签恒为「播放 / 暂停」（§9.4）
/// - 时间轴推进：38% 起按 tick 前进，时间行随之刷新（tabular-nums，§9.2）
/// - 前后曲：三套音景循环切换，波形与标题同步
/// - 播完自动回调 [onFinished]（§7 C 注脚「播放结束后将进入渐进式唤醒」的落地）
///
/// 时长全部参数化（[tickInterval] / [step]），测试可注入极短步长跑完整链路。
class DfSleepFlow extends StatefulWidget {
  const DfSleepFlow({
    super.key,
    this.startPlaying = true,
    this.startProgress = 0.38,
    this.tickInterval = const Duration(seconds: 1),
    this.step = 0.02,
    this.onFinished,
    this.recordSession = false,
  });

  final bool startPlaying;

  /// 0–1 起始进度
  final double startProgress;

  /// 每次推进的间隔（真实播放为 1s；测试可注入毫秒级）
  final Duration tickInterval;

  /// 每次推进的进度增量
  final double step;

  /// 播完（进度到 1.0）时回调一次
  final VoidCallback? onFinished;

  /// M5：true 时开启睡眠会话记录（记入睡时刻 + 预约唤醒通知）。
  /// 测试 / 画廊保持 false，不触碰数据库。
  final bool recordSession;

  /// 音景库（§6.13 场景 + §7 C 标题）
  static const List<String> soundscapes = <String>['深海洄游', '远山松风', '檐下雨声'];

  @override
  State<DfSleepFlow> createState() => _DfSleepFlowState();
}

class _DfSleepFlowState extends State<DfSleepFlow> {
  int _index = 0;
  bool _playing = false;
  double _progress = 0;
  Timer? _timer;
  bool _finished = false;
  StreamSubscription<bool>? _playingSub;

  /// 真实音频控制器（main 初始化后可用）；测试 / 陈列板为 null → 虚拟播放。
  DfSoundscapeController? get _audio => dfSoundscapeController;

  /// 音景总时长（虚拟）：24:00 = 1440s
  static const int _totalSeconds = 1440;

  @override
  void initState() {
    super.initState();
    _progress = widget.startProgress.clamp(0.0, 1.0);
    _playing = widget.startPlaying;
    // M5：开启会话记录（记入睡时刻 + 预约浅睡窗口唤醒通知）
    if (widget.recordSession) SleepSessionRecorder.instance.begin();
    // M3：有真实音频控制器时，跟随播放器状态（含锁屏/通知栏控制）
    final DfSoundscapeController? audio = _audio;
    if (audio != null) {
      _playingSub = audio.playingStream.listen((bool playing) {
        if (!mounted || playing == _playing) return;
        setState(() => _playing = playing);
        if (playing) {
          _startTimer();
        } else {
          _stopTimer();
        }
      });
      audio.toggle(); // 起播（含 setAsset 预载）
    } else if (_playing) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(DfSleepFlow old) {
    super.didUpdateWidget(old);
    if (old.startProgress != widget.startProgress) {
      _progress = widget.startProgress.clamp(0.0, 1.0);
    }
  }

  @override
  void dispose() {
    _playingSub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.tickInterval, (_) => _tick());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _tick() {
    if (!mounted) return;
    final double next = _progress + widget.step;
    if (next >= 1) {
      setState(() => _progress = 1);
      _stopTimer();
      if (!_finished) {
        _finished = true;
        widget.onFinished?.call();
      }
      return;
    }
    setState(() => _progress = next);
  }

  void _togglePlay() {
    final DfSoundscapeController? audio = _audio;
    if (audio != null) {
      audio.toggle();
      return; // UI 状态由 playingStream 回调驱动
    }
    setState(() => _playing = !_playing);
    if (_playing) {
      // 已播完再点播放 → 从头开始
      if (_finished) {
        _finished = false;
        _progress = 0;
      }
      _startTimer();
    } else {
      _stopTimer();
    }
  }

  void _shift(int delta) {
    final int n = DfSleepFlow.soundscapes.length;
    final int next = (_index + delta + n) % n;
    setState(() => _index = next);
    _audio?.next(); // 真实音源按 dfTracks 顺序切换
  }

  String _format(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    final int elapsed = (_progress * _totalSeconds).round();

    return DfScreenScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      DfSleepFlow.soundscapes[_index],
                      style: DfType.titleS(context, p.text),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '千人千面 · 依你的情绪生成',
                      style: DfType.sub(context, p.text2),
                    ),
                  ],
                ),
              ),
              Text('23:07', style: DfType.caption(context, p.text3)),
            ],
          ),
          const SizedBox(height: 16),
          const DfScene(height: 250),
          const SizedBox(height: 16),
          DfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '音景层次 · 低频潮汐 × 远海雨声',
                  style: DfType.bodyS(context, p.text2),
                ),
                const SizedBox(height: 12),
                // 播放时波形随之起伏（§8：仅 opacity/transform 类，不挂布局动效）
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: _playing ? 1.0 : 0.4),
                  duration: DfMotion.dur,
                  builder: (BuildContext context, double v, Widget? child) =>
                      Opacity(opacity: v, child: child),
                  child: const DfWave(),
                ),
              ],
            ),
          ),
        ],
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DfTimeline(progress: _progress),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                _format(elapsed),
                style: DfType.caption(context, p.text2).copyWith(
                      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                    ),
              ),
              Text(
                _format(_totalSeconds),
                style: DfType.caption(context, p.text2).copyWith(
                      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                    ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              DfGhostButton(
                round: true,
                glyph: DfGlyph.prev,
                semanticLabel: '上一曲',
                onPressed: () => _shift(-1),
              ),
              const SizedBox(width: 26),
              DfIconButton(
                glyph: _playing ? DfGlyph.pause : DfGlyph.play,
                semanticLabel: '播放 / 暂停',
                size: DfTouch.play,
                onPressed: _togglePlay,
              ),
              const SizedBox(width: 26),
              DfGhostButton(
                round: true,
                glyph: DfGlyph.next,
                semanticLabel: '下一曲',
                onPressed: () => _shift(1),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _finished ? '这一夜已经播完 · 即将进入唤醒' : '播放结束后将进入渐进式唤醒',
            textAlign: TextAlign.center,
            style: DfType.caption(context, p.text3),
          ),
        ],
      ),
    );
  }
}

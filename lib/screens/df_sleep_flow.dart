import 'dart:async';

import 'package:flutter/material.dart';

import 'package:dreamflow/audio/df_soundscape.dart';
import 'package:dreamflow/data/sleep_schedule.dart';
import 'package:dreamflow/data/sleep_session_recorder.dart';
import 'package:dreamflow/design_system/df_theme.dart';
import 'package:dreamflow/design_system/df_tokens.dart';
import 'package:dreamflow/design_system/df_type.dart';
import 'package:dreamflow/design_system/widgets/df_controls.dart';
import 'package:dreamflow/design_system/widgets/df_data.dart';
import 'package:dreamflow/design_system/widgets/df_icons.dart';
import 'package:dreamflow/design_system/widgets/df_scene.dart';
import 'package:dreamflow/design_system/widgets/df_screen.dart';
import 'package:dreamflow/design_system/widgets/df_surfaces.dart';

/// §7 C 沉浸助眠 —— 真实音景播放页。
///
/// **M6.8 重做**（真机反馈逐条落地）：
/// 1. 进度条绑定**真实音频** `position / duration`，可点击可拖动 seek
///    （旧版是虚拟 1440 秒时间轴 + `startProgress: 0.38`，一进来就停在 09:07，
///    而且 step 0.02 让 50 秒就跑满 —— 这正是「每次都从 10 秒左右开始」和
///    「每个音频都只有 24 秒」的来源）
/// 2. 底部补 [DfTabs]，随时能切走（音景继续后台播），不再「进去出不来」
/// 3. 定时关闭：15/30/45/60/90 分钟，到点淡出停止，不是硬切
/// 4. 起床闹钟：独立设置，**唤醒只由时间触发**；音景播完只停播、绝不唤醒
class DfSleepFlow extends StatefulWidget {
  const DfSleepFlow({
    super.key,
    this.startPlaying = true,
    this.recordSession = false,
    this.onTab,
  });

  final bool startPlaying;

  /// true 时开启睡眠会话记录（记入睡时刻 + 重排起床闹钟）
  final bool recordSession;

  /// 底部 tab 切换（0 首页 / 1 对话 / 2 助眠 / 3 我的）
  final ValueChanged<int>? onTab;

  /// 音景库（与 dfTracks 顺序一致）
  static const List<String> soundscapes = <String>[
    '深海洄游', '远山松风', '檐下雨声', '空谷白噪',
  ];

  /// 定时关闭档位（分钟）
  static const List<int> timerChoices = <int>[15, 30, 45, 60, 90];

  /// 底部 tab 项
  static const List<DfTabItem> tabs = <DfTabItem>[
    DfTabItem(DfGlyph.home, '首页'),
    DfTabItem(DfGlyph.chat, '对话'),
    DfTabItem(DfGlyph.moon, '助眠'),
    DfTabItem(DfGlyph.profile, '我的'),
  ];

  @override
  State<DfSleepFlow> createState() => _DfSleepFlowState();
}

class _DfSleepFlowState extends State<DfSleepFlow> {
  DfSoundscapeController? get _audio => dfSoundscapeController;

  int _timerMinutes = 0; // 0 = 不关
  double? _preview; // 拖动中的进度预览
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    if (widget.recordSession) {
      SleepSessionRecorder.instance.begin();
    }
    final DfSoundscapeController? a = _audio;
    if (a != null) {
      a.state.addListener(_onPlaybackChanged);
      if (widget.startPlaying) unawaited(a.play());
    }
    // 1s 心跳：刷新当前时刻 / 定时剩余（进度本身由 ValueListenable 驱动）
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _audio?.state.removeListener(_onPlaybackChanged);
    _clock?.cancel();
    // 切走页面不停音频：音景要继续放
    super.dispose();
  }

  void _onPlaybackChanged() {
    if (mounted) setState(() {});
  }

  static String _mmss(Duration d) {
    final int m = d.inMinutes;
    final int s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _toggle() async {
    await _audio?.toggle();
    if (mounted) setState(() {});
  }

  Future<void> _shift(int delta) async {
    final DfSoundscapeController? a = _audio;
    if (a == null) return;
    final int n = DfSleepFlow.soundscapes.length;
    await a.select((a.index + delta + n) % n);
    if (mounted) setState(() {});
  }

  void _pickTimer(int minutes) {
    setState(() => _timerMinutes = minutes);
    SleepSchedule.instance.startSleepTimer(
      minutes <= 0 ? null : Duration(minutes: minutes),
      onStop: _onTimerStop,
    );
  }

  /// 定时到点：淡出 12 秒后停播。**不进入唤醒流程**（用户大概率还在睡）
  Future<void> _onTimerStop() async {
    final DfSoundscapeController? a = _audio;
    if (a == null) return;
    await a.fadeOutAndStop(onDone: () {
      if (mounted) setState(() => _timerMinutes = 0);
    });
  }

  Future<void> _pickAlarm() async {
    final SleepSchedule s = SleepSchedule.instance;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: s.alarmHour, minute: s.alarmMinute),
      helpText: '设置起床闹钟',
      cancelText: '取消',
      confirmText: '设定',
      builder: (BuildContext context, Widget? child) => Theme(
        data: DfTheme.paperTheme(context),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked == null || !mounted) return;
    await s.setAlarm(
      hour: picked.hour,
      minute: picked.minute,
      enabled: true,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final DfSoundscapeController? a = _audio;
    if (a == null) return _buildBody(context, const DfPlayback(), null);
    return ValueListenableBuilder<DfPlayback>(
      valueListenable: a.state,
      builder: (BuildContext context, DfPlayback pb, Widget? _) =>
          _buildBody(context, pb, a),
    );
  }

  Widget _buildBody(
    BuildContext context,
    DfPlayback pb,
    DfSoundscapeController? a,
  ) {
    final DfPalette p = DfPalette.of(context);
    final SleepSchedule schedule = SleepSchedule.instance;

    final Duration total = pb.duration;
    final double ratio = _preview ?? pb.progress;
    final Duration shown = _preview == null
        ? pb.position
        : Duration(milliseconds: (total.inMilliseconds * _preview!).round());
    final String title = DfSleepFlow.soundscapes[
        pb.index.clamp(0, DfSleepFlow.soundscapes.length - 1)];

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
                    Text(title, style: DfType.titleS(context, p.text)),
                    const SizedBox(height: 4),
                    Text(
                      '千人千面 · 依你的情绪生成',
                      style: DfType.sub(context, p.text2),
                    ),
                  ],
                ),
              ),
              Text(_hhmm(DateTime.now()), style: DfType.caption(context, p.text3)),
            ],
          ),
          const SizedBox(height: 14),
          const DfScene(height: 176),
          const SizedBox(height: 14),
          DfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '音景层次 · 低频潮汐 × 远海雨声',
                  style: DfType.bodyS(context, p.text2),
                ),
                const SizedBox(height: 12),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: pb.playing ? 1.0 : 0.4),
                  duration: DfMotion.dur,
                  builder: (BuildContext context, double v, Widget? child) =>
                      Opacity(opacity: v, child: child),
                  child: const DfWave(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _TimerCard(
            selected: _timerMinutes,
            remaining: schedule.stopLabel,
            onPick: _pickTimer,
          ),
          const SizedBox(height: 12),
          _AlarmCard(
            enabled: schedule.alarmEnabled,
            label: schedule.alarmLabel,
            smartWake: schedule.smartWake,
            onPick: _pickAlarm,
            onToggle: (bool on) async {
              await schedule.setAlarmEnabled(on);
              if (mounted) setState(() {});
            },
            onSmart: (bool on) async {
              await schedule.setSmartWake(on);
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DfSpace.padX),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
          DfSeekBar(
            progress: ratio,
            onPreview: (double? f) => setState(() => _preview = f),
            onSeek: (double f) => a?.seekFraction(f),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                _mmss(shown),
                style: DfType.caption(context, p.text2).copyWith(
                      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                    ),
              ),
              Text(
                total == Duration.zero ? '--:--' : _mmss(total),
                style: DfType.caption(context, p.text2).copyWith(
                      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              DfGhostButton(
                round: true,
                glyph: DfGlyph.prev,
                semanticLabel: '上一曲',
                onPressed: a == null ? null : () => _shift(-1),
              ),
              const SizedBox(width: 26),
              DfIconButton(
                glyph: pb.playing ? DfGlyph.pause : DfGlyph.play,
                semanticLabel: pb.playing ? '暂停' : '播放',
                size: DfTouch.play,
                onPressed: a == null ? null : _toggle,
              ),
              const SizedBox(width: 26),
              DfGhostButton(
                round: true,
                glyph: DfGlyph.next,
                semanticLabel: '下一曲',
                onPressed: a == null ? null : () => _shift(1),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            pb.playing
                ? '音景在后台继续播放 · 可随时切到别的页面'
                : '轻点播放，让这一夜慢慢沉下去',
            textAlign: TextAlign.center,
            style: DfType.caption(context, p.text3),
          ),
              ],
            ),
          ),
          DfTabs(
            items: DfSleepFlow.tabs,
            currentIndex: 2,
            onTap: widget.onTab,
            bordered: false,
          ),
        ],
      ),
      bottomFullBleed: true,
    );
  }
}

/// 定时关闭卡片
class _TimerCard extends StatelessWidget {
  const _TimerCard({
    required this.selected,
    required this.remaining,
    required this.onPick,
  });

  final int selected;
  final String? remaining;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    return DfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('定时关闭', style: DfType.bodyS(context, p.text)),
              Text(
                remaining ?? '不自动停止',
                style: DfType.caption(
                  context,
                  remaining == null ? p.text3 : p.mistGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              DfChip(
                label: '不关',
                selected: selected == 0,
                onTap: () => onPick(0),
              ),
              for (final int m in DfSleepFlow.timerChoices)
                DfChip(
                  label: '$m 分钟',
                  selected: selected == m,
                  onTap: () => onPick(m),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 起床闹钟卡片
class _AlarmCard extends StatelessWidget {
  const _AlarmCard({
    required this.enabled,
    required this.label,
    required this.smartWake,
    required this.onPick,
    required this.onToggle,
    required this.onSmart,
  });

  final bool enabled;
  final String label;
  final bool smartWake;
  final VoidCallback onPick;
  final ValueChanged<bool> onToggle;
  final ValueChanged<bool> onSmart;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    final SleepSchedule s = SleepSchedule.instance;
    final DateTime at = s.nextAlarmAt();

    return DfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('起床闹钟', style: DfType.bodyS(context, p.text)),
                  const SizedBox(height: 6),
                  Text(
                    enabled
                        ? '$label · 明天或今天 ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}'
                        : '已关闭，这一夜不会被叫醒',
                    style: DfType.caption(
                      context,
                      enabled ? p.mistGreen : p.text3,
                    ),
                  ),
                ],
              ),
              DfGhostButton(
                label: enabled ? '修改' : '设置',
                height: DfTouch.min,
                onPressed: onPick,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              DfChip(
                label: enabled ? '闹钟 开' : '闹钟 关',
                selected: enabled,
                onTap: () => onToggle(!enabled),
              ),
              const SizedBox(width: 8),
              DfChip(
                label: '智能唤醒',
                selected: smartWake,
                onTap: () => onSmart(!smartWake),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            smartWake
                ? '智能唤醒：在你设定的时刻前后 20 分钟内的浅睡窗口叫醒，比睡到自然醒更轻'
                : '按设定时刻准时叫醒',
            style: DfType.caption(context, p.text3),
          ),
        ],
      ),
    );
  }
}

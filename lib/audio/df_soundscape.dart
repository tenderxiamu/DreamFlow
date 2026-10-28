import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// M3 / M6.8 音景播放层。
///
/// **M6.8 重做要点**（对应真机反馈）：
/// 1. 进度以**真实音频**为准（`position / duration`），不再是虚拟的 1440 秒时间轴
/// 2. 支持 `seek`（进度条可拖动）
/// 3. 双播放器交叉淡化：tide_low 只有 24.7s，靠 `LoopMode.one` 会出现可听的接缝；
///    这里用两个 player 交替，在剩余 [crossfade] 时淡入对方、淡出自己，做到无缝
/// 4. `fadeOutAndStop`：定时关闭到点时淡出停止（不是硬切）
///
/// 状态用 [ValueNotifier] 暴露，UI 直接 listen，避免 Stream 生命周期管理。
class DfTrack {
  const DfTrack({required this.asset, required this.title, required this.artist});

  /// asset 路径，如 assets/audio/tide_low.mp3
  final String asset;

  /// C 屏标题（与 DfSleepFlow.soundscapes 对齐）
  final String title;
  final String artist;
}

/// 音景库：顺序与 DfSleepFlow.soundscapes 一一对应。
const List<DfTrack> dfTracks = <DfTrack>[
  DfTrack(asset: 'assets/audio/tide_low.mp3', title: '深海洄游', artist: 'DreamFlow 音景'),
  DfTrack(asset: 'assets/audio/forest.mp3', title: '远山松风', artist: 'DreamFlow 音景'),
  DfTrack(asset: 'assets/audio/rain_far.mp3', title: '檐下雨声', artist: 'DreamFlow 音景'),
  DfTrack(asset: 'assets/audio/white_noise.mp3', title: '空谷白噪', artist: 'DreamFlow 音景'),
];

/// 播放器对外快照
class DfPlayback {
  const DfPlayback({
    this.playing = false,
    this.loading = true,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.index = 0,
    this.volume = 1,
  });

  final bool playing;
  final bool loading;
  final Duration position;
  final Duration duration;
  final int index;

  /// 定时关闭淡出期间的音量（1 → 0）
  final double volume;

  double get progress {
    final int total = duration.inMilliseconds;
    if (total <= 0) return 0;
    return (position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  DfPlayback copyWith({
    bool? playing,
    bool? loading,
    Duration? position,
    Duration? duration,
    int? index,
    double? volume,
  }) {
    return DfPlayback(
      playing: playing ?? this.playing,
      loading: loading ?? this.loading,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      index: index ?? this.index,
      volume: volume ?? this.volume,
    );
  }
}

/// 全局唯一 handler（main 里 AudioService.init 创建后经 [dfSoundscapeController] 暴露）。
DfAudioHandler? _handler;

DfAudioHandler get dfAudioHandler {
  final DfAudioHandler? h = _handler;
  if (h == null) {
    throw StateError('DfAudioHandler 未初始化：请先在 main() 中调用 initDfAudioService()');
  }
  return h;
}

Future<void> initDfAudioService() async {
  _handler ??= await AudioService.init<DfAudioHandler>(
    builder: DfAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.dreamflow.dreamflow.audio',
      androidNotificationChannelName: '梦洄音景播放',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
  dfSoundscapeController ??= DfSoundscapeController(_handler!);
}

/// UI 可用的全局控制器；未初始化（如测试环境）为 null，C 屏回退模拟播放。
DfSoundscapeController? dfSoundscapeController;

/// audio_service 后台音频 handler：锁屏 / 通知栏控制中心。
///
/// 内部持有两个 [AudioPlayer] 做交叉淡化无缝循环，[_active] 始终是出声的那个。
class DfAudioHandler extends BaseAudioHandler with SeekHandler {
  DfAudioHandler() {
    _a.setVolume(1);
    _b.setVolume(0);
    _active = _a;
    _idle = _b;
  }

  final AudioPlayer _a = AudioPlayer();
  final AudioPlayer _b = AudioPlayer();

  late AudioPlayer _active;
  late AudioPlayer _idle;

  /// 交叉淡化时长：短音频（24s）靠它听不出接缝
  static const Duration crossfade = Duration(milliseconds: 1400);

  final ValueNotifier<DfPlayback> state = ValueNotifier<DfPlayback>(
    const DfPlayback(),
  );

  int _index = 0;
  bool _loaded = false;
  bool _crossing = false;
  DateTime? _crossStart;
  Timer? _watcher;
  double _fade = 1; // 定时关闭淡出系数（1 = 正常）
  bool _stopping = false;

  int get index => _index;
  Duration get duration => state.value.duration;
  Duration get position => _active.position;

  void _push({bool? playing, bool? loading}) {
    final DfPlayback s = state.value;
    state.value = s.copyWith(
      playing: playing ?? (_active.playing && !_stopping),
      loading: loading,
      position: _active.position,
      duration: s.duration,
      index: _index,
      volume: _fade,
    );
    _pushMediaState(state.value);
  }

  void _pushMediaState(DfPlayback s) {
    final MediaItem? item = mediaItem.value;
    playbackState.add(
      playbackState.value.copyWith(
        controls: <MediaControl>[
          if (s.playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.skipToPrevious,
        ],
        systemActions: const <MediaAction>{MediaAction.seek},
        androidCompactActionIndices: const <int>[0, 1, 2],
        processingState: s.loading
            ? AudioProcessingState.loading
            : AudioProcessingState.ready,
        playing: s.playing,
        updatePosition: s.position,
        bufferedPosition: item?.duration ?? s.duration,
      ),
    );
  }

  Future<void> _ensureLoaded({bool force = false}) async {
    final DfTrack t = dfTracks[_index];
    if (_loaded && !force && mediaItem.value?.id == t.asset) return;
    _loaded = false;
    state.value = state.value.copyWith(loading: true);
    _push(loading: true);

    _watcher?.cancel();
    _watcher = null;
    await _a.stop();
    await _b.stop();

    final Duration? d1 = await _a.setAsset(t.asset, preload: true);
    await _b.setAsset(t.asset, preload: true);
    await _a.setLoopMode(LoopMode.off);
    await _b.setLoopMode(LoopMode.off);
    await _a.seek(Duration.zero);
    await _b.seek(Duration.zero);
    await _a.setVolume(_fade);
    await _b.setVolume(0);
    _active = _a;
    _idle = _b;
    _crossing = false;
    _loaded = true;

    mediaItem.add(
      MediaItem(
        id: t.asset,
        album: '梦洄 · 助眠音景',
        title: t.title,
        artist: t.artist,
        duration: d1,
      ),
    );
    state.value = DfPlayback(
      duration: d1 ?? Duration.zero,
      index: _index,
      volume: _fade,
    );
    _push(playing: false, loading: false);
  }

  /// 80ms 轮询：推进 UI 进度 + 判断是否该开始交叉
  void _startWatcher() {
    _watcher?.cancel();
    _watcher = Timer.periodic(const Duration(milliseconds: 150), (_) => _tick());
  }

  void _tick() {
    if (!_loaded) return;
    final Duration total = state.value.duration;
    final Duration pos = _active.position;

    if (_crossing) {
      final DateTime? start = _crossStart;
      if (start != null) {
        final double t =
            DateTime.now().difference(start).inMilliseconds / crossfade.inMilliseconds;
        final double k = t.clamp(0.0, 1.0);
        _active.setVolume((1 - k) * _fade);
        _idle.setVolume(k * _fade);
        if (k >= 1) _finishCross();
      }
    } else if (total > Duration.zero) {
      final Duration remain = total - pos;
      if (remain <= crossfade && remain > Duration.zero && _idle.playing == false) {
        _beginCross();
      }
    }

    final DfPlayback s = state.value;
    state.value = s.copyWith(
      position: _active.position,
      // 交叉淡化期间仍在出声：主播放器即便已经 completed，也不能让 UI 闪成「已暂停」
      playing: (_crossing || _active.playing) && !_stopping,
      duration: total,
      index: _index,
    );
  }

  void _beginCross() {
    _crossing = true;
    _crossStart = DateTime.now();
    _idle.seek(Duration.zero);
    _idle.setVolume(0);
    _idle.play();
  }

  void _finishCross() {
    final AudioPlayer done = _active;
    _active = _idle;
    _idle = done;
    _idle.pause();
    _idle.seek(Duration.zero);
    _idle.setVolume(0);
    _active.setVolume(_fade);
    _crossing = false;
    _crossStart = null;
  }

  Future<void> select(int index) async {
    final int n = dfTracks.length;
    final int next = (index % n + n) % n;
    if (next == _index && _loaded) return;
    final bool wasPlaying = _active.playing;
    _index = next;
    await _ensureLoaded(force: true);
    if (wasPlaying || _shouldAutoPlay) {
      await _startPlaying();
    }
  }

  bool _shouldAutoPlay = false;

  Future<void> _startPlaying() async {
    if (!_loaded) await _ensureLoaded();
    _stopping = false;
    _fade = 1;
    await _active.setVolume(1);
    unawaited(_active.play());
    _startWatcher();
    _push(playing: true, loading: false);
  }

  Future<void> toggle() async {
    if (_active.playing) {
      await pause();
    } else {
      _shouldAutoPlay = true;
      await _startPlaying();
    }
  }

  Future<void> playAll() async {
    _shouldAutoPlay = true;
    await _startPlaying();
  }

  @override
  Future<void> play() => _startPlaying();

  @override
  Future<void> pause() async {
    await _active.pause();
    _watcher?.cancel();
    _watcher = null;
    state.value = state.value.copyWith(playing: false, position: _active.position);
    _push(playing: false);
  }

  @override
  Future<void> seek(Duration position) async {
    if (!_loaded) return;
    await _active.seek(position);
    state.value = state.value.copyWith(position: position);
    _push();
  }

  /// 拖动预览用（不实际改变播放位置）
  Future<void> seekFraction(double fraction) async {
    final Duration total = state.value.duration;
    if (total == Duration.zero) return;
    final int ms = (total.inMilliseconds * fraction.clamp(0.0, 1.0)).round();
    await seek(Duration(milliseconds: ms));
  }

  @override
  Future<void> skipToNext() => select(_index + 1);

  @override
  Future<void> skipToPrevious() => select(_index - 1);

  /// 定时关闭：在 [fade] 内线性淡出后停止（不硬切，避免半夜被「砰」一下惊醒）
  Future<void> fadeOutAndStop({
    Duration fade = const Duration(seconds: 12),
    VoidCallback? onDone,
  }) async {
    if (!_loaded) {
      onDone?.call();
      return;
    }
    _stopping = true;
    const int steps = 24;
    final int stepMs = (fade.inMilliseconds / steps).round().clamp(20, 5000);
    for (int i = steps; i >= 0; i--) {
      _fade = i / steps;
      await _active.setVolume(_fade);
      await _idle.setVolume(0);
      state.value = state.value.copyWith(volume: _fade);
      await Future<void>.delayed(Duration(milliseconds: stepMs));
    }
    await _active.pause();
    await _active.seek(Duration.zero);
    _watcher?.cancel();
    _watcher = null;
    _fade = 1;
    _stopping = false;
    _shouldAutoPlay = false;
    state.value = state.value.copyWith(
      playing: false,
      position: Duration.zero,
      volume: 1,
    );
    _push(playing: false);
    onDone?.call();
  }

  @override
  Future<void> stop() async {
    _watcher?.cancel();
    await _a.stop();
    await _b.stop();
    _loaded = false;
    await super.stop();
  }
}

/// UI 侧轻控制器：C 屏注入后即接管播放 / 暂停 / 切曲 / 进度。
class DfSoundscapeController {
  DfSoundscapeController(this._handler);

  final DfAudioHandler _handler;

  /// 播放状态 + 进度快照（80ms 刷新，只重绘用到它的那一小块）
  ValueListenable<DfPlayback> get state => _handler.state;

  DfPlayback get value => _handler.state.value;

  bool get isPlaying => _handler.state.value.playing;

  int get index => _handler.index;

  Future<void> play() => _handler.playAll();

  Future<void> toggle() => _handler.toggle();

  Future<void> pause() => _handler.pause();

  Future<void> next() => _handler.skipToNext();

  Future<void> previous() => _handler.skipToPrevious();

  Future<void> select(int i) => _handler.select(i);

  Future<void> seekFraction(double f) => _handler.seekFraction(f);

  Future<void> fadeOutAndStop({Duration fade = const Duration(seconds: 12), VoidCallback? onDone}) =>
      _handler.fadeOutAndStop(fade: fade, onDone: onDone);
}

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// M3 音景播放层。
///
/// - [dfTracks]：本地打包的 CC0 / Pixabay 授权音景（assets/audio/，授权见
///   assets/AUDIO_LICENSES.md）。
/// - [DfAudioHandler]：audio_service 后台音频服务，负责锁屏控制中心
///   （MediaSession）与前台服务保活；内部持有 just_audio 播放器，单曲循环。
/// - [DfSoundscapeController]：给 UI（C 屏 DfSleepFlow）用的轻控制器，
///   播放/暂停/切曲与播放状态流。
///
/// 测试友好：DfSleepFlow 在未注入控制器时保持原虚拟播放状态机（见 df_sleep_flow）。

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
];

/// 全局唯一 handler（main 里 AudioService.init 创建后经 [dfAudioHandlerRef] 暴露）。
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

/// UI 可用的全局控制器；未初始化（如测试环境）为 null，C 屏回退虚拟播放。
DfSoundscapeController? dfSoundscapeController;

/// audio_service 后台音频 handler：锁屏 / 通知栏控制中心。
class DfAudioHandler extends BaseAudioHandler with SeekHandler {
  DfAudioHandler() {
    player.playerStateStream.listen(_onPlayerStateChanged);
  }

  final AudioPlayer player = AudioPlayer();

  int _index = 0;

  int get index => _index;

  /// 预载当前曲目并循环播放。
  Future<void> _ensureLoaded() async {
    final DfTrack t = dfTracks[_index];
    final Duration? dur = await player.setAsset(
      t.asset,
      preload: true,
    );
    if (dur != null) {
      mediaItem.add(
        MediaItem(
          id: t.asset,
          album: '梦洄 · 助眠音景',
          title: t.title,
          artist: t.artist,
          duration: dur,
        ),
      );
    }
    await player.setLoopMode(LoopMode.one);
  }

  void _onPlayerStateChanged(PlayerState s) {
    final bool playing = s.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: <MediaControl>[
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.skipToPrevious,
        ],
        systemActions: const <MediaAction>{MediaAction.seek},
        processingState: switch (s.processingState) {
          ProcessingState.idle => AudioProcessingState.idle,
          ProcessingState.loading => AudioProcessingState.loading,
          ProcessingState.buffering => AudioProcessingState.buffering,
          ProcessingState.ready => AudioProcessingState.ready,
          ProcessingState.completed => AudioProcessingState.completed,
        },
        playing: playing,
        updatePosition: player.position,
      ),
    );
  }

  Future<void> select(int index) async {
    final int n = dfTracks.length;
    _index = (index % n + n) % n;
    await _ensureLoaded();
  }

  Future<void> toggle() async {
    if (player.playing) {
      await player.pause();
    } else {
      if (player.processingState == ProcessingState.idle) {
        await _ensureLoaded();
      }
      await player.play();
    }
  }

  @override
  Future<void> play() async {
    if (player.processingState == ProcessingState.idle) {
      await _ensureLoaded();
    }
    await player.play();
  }

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> skipToNext() => select(_index + 1);

  @override
  Future<void> skipToPrevious() => select(_index - 1);

  @override
  Future<void> stop() async {
    await player.stop();
    await super.stop();
  }
}

/// UI 侧轻控制器：C 屏注入后即接管播放/暂停/切曲。
class DfSoundscapeController {
  DfSoundscapeController(this._handler);

  final DfAudioHandler _handler;

  Stream<bool> get playingStream =>
      _handler.player.playerStateStream.map((PlayerState s) => s.playing);

  bool get isPlaying => _handler.player.playing;

  int get index => _handler.index;

  Future<void> toggle() => _handler.toggle();

  Future<void> pause() => _handler.pause();

  Future<void> next() => _handler.skipToNext();

  Future<void> previous() => _handler.skipToPrevious();
}

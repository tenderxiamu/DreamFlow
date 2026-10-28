import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../df_tokens.dart';

/// §6.13b 音景动态场景（M6.9）
///
/// 用一段**静音的循环短视频**替代静态墨山，让画面和正在响的声音对上：
/// 深海洄游配月光下的浪，远山松风配林间风动，檐下雨声配落雨，
/// 空谷白噪配流动的雾。
///
/// 三条硬约束（这是助眠场景，不是宣传片）：
/// 1. **音量恒为 0** —— 声音只有一个来源，就是音景本身
/// 2. **只在「音景在放 + 页面可见 + App 在前台」时推进**，锁屏或切到别的
///    tab 立刻暂停。否则整夜解码，电量撑不住
/// 3. 加载中 / 解码失败一律退回 [fallback]（原来的静态场景），绝不黑屏
///
/// 画面上再盖一层夜色遮罩，把视频的亮部压下去，让它和纸墨主题咬合，
/// 而不是像贴了一块屏幕在纸上。
class DfVideoScene extends StatefulWidget {
  const DfVideoScene({
    super.key,
    required this.asset,
    required this.height,
    this.playing = true,
    this.fallback,
  });

  /// 视频资源路径（assets/scene/*.mp4）
  final String asset;

  final double height;

  /// 音景是否在播放；false 时视频定格
  final bool playing;

  /// 视频未就绪时的兜底画面（通常是 [DfScene]）
  final Widget? fallback;

  @override
  State<DfVideoScene> createState() => _DfVideoSceneState();
}

class _DfVideoSceneState extends State<DfVideoScene>
    with WidgetsBindingObserver {
  VideoPlayerController? _c;

  /// 已初始化且首帧可显示
  bool _ready = false;

  /// 当前分支是否可见（StatefulShellRoute 用 IndexedStack，非当前分支 TickerMode=false）
  bool _visible = true;

  /// App 是否在前台
  bool _foreground = true;

  /// 加载序号：切曲时用它丢弃上一段的初始化结果，避免两段互相覆盖
  int _token = 0;

  bool get _shouldPlay =>
      widget.playing && _visible && _foreground && _ready;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load(widget.asset));
  }

  @override
  void didUpdateWidget(DfVideoScene old) {
    super.didUpdateWidget(old);
    if (old.asset != widget.asset) {
      unawaited(_load(widget.asset));
    } else if (old.playing != widget.playing) {
      _sync();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // StatefulShellRoute 用 IndexedStack 装各个分支，非当前分支 TickerMode=false。
    // 用它在切 tab 时暂停视频，比给每个页面传 active 标志省事，也不会漏。
    // ignore: deprecated_member_use
    final bool visible = TickerMode.of(context);
    if (visible != _visible) {
      _visible = visible;
      _sync();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bool foreground = state == AppLifecycleState.resumed;
    if (foreground != _foreground) {
      _foreground = foreground;
      _sync();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 加一，杜绝 dispose 之后还在等 initialize() 的那次把 controller 泄漏掉
    _token++;
    final VideoPlayerController? c = _c;
    _c = null;
    unawaited(c?.dispose() ?? Future<void>.value());
    super.dispose();
  }

  Future<void> _load(String asset) async {
    final int token = ++_token;
    final VideoPlayerController? old = _c;
    _c = null;
    if (mounted) {
      setState(() => _ready = false);
    }
    if (old != null) {
      unawaited(old.dispose());
    }

    final VideoPlayerController c = VideoPlayerController.asset(asset);
    try {
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(0);
      if (token != _token) {
        unawaited(c.dispose());
        return;
      }
      _c = c;
      if (!mounted) {
        unawaited(c.dispose());
        return;
      }
      setState(() => _ready = true);
      _sync();
    } catch (_) {
      // 解码不了就安静退回静态场景，不给用户看错误
      if (token == _token) {
        unawaited(c.dispose());
        if (mounted) setState(() => _ready = false);
      }
    }
  }

  void _sync() {
    final VideoPlayerController? c = _c;
    if (c == null || !c.value.isInitialized) return;
    if (_shouldPlay) {
      if (!c.value.isPlaying) unawaited(c.play());
    } else {
      if (c.value.isPlaying) unawaited(c.pause());
    }
  }

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    final VideoPlayerController? c = _c;

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DfRadius.card),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (widget.fallback != null) widget.fallback!,
            if (_ready && c != null)
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOut,
                builder: (BuildContext context, double v, Widget? child) =>
                    Opacity(opacity: v, child: child),
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: c.value.size.width,
                      height: c.value.size.height,
                      child: VideoPlayer(c),
                    ),
                  ),
                ),
              ),
            // 压亮 + 与纸墨主题融合：上暗下更暗，模拟夜色落下来
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    p.canvas.withValues(alpha: 0.42),
                    p.canvas.withValues(alpha: 0.16),
                    p.canvas.withValues(alpha: 0.58),
                  ],
                  stops: const <double>[0, 0.42, 1],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

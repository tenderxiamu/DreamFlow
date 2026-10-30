import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../df_tokens.dart';

// §6.13b 音景动态场景（M6.9）
//
// 用一段**静音的循环短视频**替代静态墨山，让画面和正在响的声音对上：
// 深海洄游配月光下的浪，远山松风配林间风动，檐下雨声配落雨，
// 空谷白噪配流动的雾。
//
// 三条硬约束（这是助眠场景，不是宣传片）：
// 1. **音量恒为 0** —— 声音只有一个来源，就是音景本身
// 2. **只在「音景在放 + 页面可见 + App 在前台」时推进**，锁屏或切到别的
//    tab 立刻暂停。否则整夜解码，电量撑不住
// 3. 加载中 / 解码失败一律退回 fallback（原来的静态场景），绝不黑屏

/// 亮度参数（M6.9.3）
///
/// 素材实测（第 2.5 秒抽帧，1344×768）：
///   p10=0  p25=7.8  p50=18.6  p75=24.2  p95=34.4  max=119  mean=17
/// 整帧几乎全挤在 0–35，连「白色泡沫」的最亮点都只有 119 —— 也就是说
/// **素材里根本不存在高光**，任何线性增益都救不回来（1.34/34 实测 mean 也只有 56）。
///
/// 所以改成两步，先开暗部再拉对比：
/// 1. [kScreenTint] 用 `BlendMode.screen` 垫一层蓝灰。screen 是非线性的：
///    `1-(1-a)(1-b)`，暗部被抬起最多、高光几乎不动，正好对上这种「全黑但有细节」的素材
/// 2. [kGain] 再线性乘一道，把 screen 压平的对比拉回来
///
/// 实测这一组：mean 27→78、p50 80、max 216（不过曝），对比度仍有 1.37。
/// 顺序要紧：里面 screen，外面 gain。
const double kGain = 1.60;
const int kScreenR = 28;
const int kScreenG = 36;
const int kScreenB = 46;

/// 边缘遮罩透明度：上 / 下。到这个亮度已经不需要压边了，只留一丝让卡片咬合。
const double kScrimTop = 0.02;
const double kScrimBottom = 0.06;

/// 画面放大倍数。
///
/// 素材左上角烧了一个「AI生成」水印（约 78×38 px，位于左上 6% 内）。
/// 放大 1.14 后可见区域收窄到 87.7%，左右各切掉 6.1%、上下各切 46 px，水印正好被裁掉。
/// 顺带把 1344×768 的素材填得更满，240 高的卡片里细节更大一点。
const double kSceneZoom = 1.14;

/// 音景动态场景：静音循环视频 + 亮度提升 + 上下边缘夜色。
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

    // **必须传 mixWithOthers: true**，否则视频一开播就抢走音频焦点，
    // 正在播的音景会被系统打断并暂停（表现为「点了播放没声音」）。
    //
    // 依据 video_player_android 的 VideoPlayer.java:99：
    //   exoPlayer.setAudioAttributes(attrs, /* handleAudioFocus= */ !isMixMode);
    // 默认 isMixMode=false → handleAudioFocus=true → 请求焦点。
    // 置 true 后变成 false，视频只出画面，完全不碰音频栈。
    final VideoPlayerController c = VideoPlayerController.asset(
      asset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
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
                  // 两步提亮，见文件头 kGain / kScreenTint 的说明：
                  // 里面 screen 垫暗部，外面 gain 拉回对比。
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.matrix(<double>[
                      kGain, 0, 0, 0, 0, //
                      0, kGain, 0, 0, 0, //
                      0, 0, kGain, 0, 0, //
                      0, 0, 0, 1, 0, //
                    ]),
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        const Color.fromARGB(255, kScreenR, kScreenG, kScreenB),
                        BlendMode.screen,
                      ),
                      child: FittedBox(
                        fit: BoxFit.cover,
                        clipBehavior: Clip.hardEdge,
                        child: Transform.scale(
                          // 裁掉左上角水印，顺便让细节在 240 高的卡片里更大
                          scale: kSceneZoom,
                          child: SizedBox(
                            width: c.value.size.width,
                            height: c.value.size.height,
                            child: VideoPlayer(c),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // 只在上下边缘压一点夜色，让画面和卡片咬合；
            // 中间完全不加遮罩 —— 之前压到 0.42/0.16/0.58，浪花细节全被吃掉了。
            //
            // 遮罩固定用纯黑，不再取 p.canvas：宣纸主题的 canvas 是奶油白
            // (0xFFF4F2EC)，盖上去等于给画面糊了一层雾，越盖越脏。
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.black.withValues(alpha: kScrimTop),
                      Colors.black.withValues(alpha: 0),
                      Colors.black.withValues(alpha: kScrimBottom),
                    ],
                    stops: const <double>[0, 0.38, 1],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

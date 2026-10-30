import 'dart:io';

import 'package:flutter/material.dart';

import 'package:dreamflow/data/df_wallpaper.dart';
import 'package:dreamflow/design_system/df_tokens.dart';

/// §2 壁纸层（M7.2）
///
/// 铺在画布色之上、墨晕和纸纹之下。只有两件事：
///
/// 1. **画图**：素材已经预先竖切 + 重模糊，这里只负责 cover 铺满
/// 2. **压一层画布色**：用 canvas 色的垂直渐变糊上去，比例由主题定 ——
///    夜墨压得狠（否则白字读不清），宣纸本身是奶白，糊完自然变成水彩。
///    这一层顺带保证「换了壁纸，对比度不会崩」，所以不需要为每张图单独调色。
///
/// 为什么不给壁纸加 `Opacity`：`Opacity` 会强制离屏合成，整屏每帧一次。
/// 用「半透明色块盖在上面」在数学上等价（canvas·α + image·(1-α)），
/// 但走的是普通混合，省掉一次 render target。
class DfWallpaper extends StatelessWidget {
  const DfWallpaper({super.key});

  /// 压暗曲线：透明度 + 停点，一一对应。**必须单调递增**。
  ///
  /// 三条来自真机的教训：
  ///
  /// 1. **不能只有三个停点**。第一版是 `[0.66, 0.48, 0.74] @ [0, 0.46, 1]`，
  ///    斜率突变处人眼会看到一条横线（马赫带，不是真接缝）。现在六个点。
  /// 2. **不能中间浅、两头深**。第二版把中段压到 0.44 想多露点云，
  ///    结果屏幕中间浮出一条浅灰雾带 —— 因为照片在中段本来就比顶部亮，
  ///    再给它最少的遮罩，它就成了全屏最亮的一条。**遮罩要一路加码**。
  /// 3. **62% 之后收满**。首页下半屏是空白区，露出模糊照片只会像起雾，
  ///    和上面的墨山卡片气质也打架。壁纸只待在上半屏，下面交还画布。
  static const List<double> _stops = <double>[
    0, 0.14, 0.30, 0.46, 0.62, 1,
  ];
  static const List<double> _scrimDark = <double>[
    0.58, 0.58, 0.62, 0.72, 0.93, 1.0,
  ];
  /// 浅色压得比深色轻得多：宣纸画布本身是奶白（0xFFF4F2EC），
  /// 用它盖 82% 等于把照片糊成一张白纸，云全没了。64% 时背景落在一张
  /// 暖灰（约 #D0CCC6）上 —— 云隐约可见，深色正文压上去对比度还是 9:1 左右。
  static const List<double> _scrimLight = <double>[
    0.64, 0.64, 0.70, 0.82, 0.94, 1.0,
  ];

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    final bool dark = p.brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: DfWallpapers.instance,
      builder: (BuildContext context, Widget? _) {
        final DfWallpapers wps = DfWallpapers.instance;
        final DfWall resolved = wps.resolve(dark: dark);
        // 相册壁纸是文件不是资源，两个出口分开问
        final String? file = wps.filePathFor(resolved);
        final String? asset = wps.assetFor(resolved);
        if (file == null && asset == null) return const SizedBox.shrink();

        final List<double> scrim = dark ? _scrimDark : _scrimLight;
        return RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (file != null)
                Image.file(
                  File(file),
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.35),
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                  // 私有目录被系统清掉（存储紧张时可能发生）就退回纯色，别让整屏报错
                  errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
                      const SizedBox.shrink(),
                )
              else
                Image.asset(
                  asset!,
                  fit: BoxFit.cover,
                  // 天在上、地在下：往上看一点，别把最漂亮的云挤出去
                  alignment: const Alignment(0, -0.35),
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                ),
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        for (int i = 0; i < _stops.length; i++)
                          p.canvas.withValues(alpha: scrim[i]),
                      ],
                      stops: _stops,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

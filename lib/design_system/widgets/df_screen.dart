import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../df_tokens.dart';
import '../df_type.dart';
import 'df_controls.dart';
import 'df_sheep.dart';

/// §2 屏幕结构：状态栏（按系统 safe-area）→ 内容区（纵向流）→ 底部锚定区。
/// 背景 = 画布底 + 右上/左下墨晕 + 纸纹颗粒。
class DfScreenScaffold extends StatelessWidget {
  const DfScreenScaffold({
    super.key,
    required this.body,
    this.bottom,
    this.bottomFullBleed = false,
    this.centerBody = false,
    this.scrollable = true,
    this.scrollController,
  });

  final Widget body;
  final Widget? bottom;

  /// Tab 栏等需要通栏的元素（不加左右留白）
  final bool bottomFullBleed;
  final bool centerBody;
  final bool scrollable;

  /// 需要跟随内容自动滚动（对话流）时从外部注入
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);

    Widget content = Padding(
      padding: const EdgeInsets.fromLTRB(
        DfSpace.padX,
        DfSpace.contentTop,
        DfSpace.padX,
        0,
      ),
      child: body,
    );

    if (scrollable && !centerBody) {
      content = SingleChildScrollView(
        controller: scrollController,
        child: content,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(color: p.canvas),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _WashPainter(wash1: p.wash1, wash2: p.wash2),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _GrainPainter(
                  // night 走 CSS `soft-light` 的飞白亮颗粒；paper 走 `multiply` 的暗颗粒
                  color: p.brightness == Brightness.light
                      ? Colors.black
                      : Colors.white,
                  opacity: p.grain *
                      (p.brightness == Brightness.light ? 0.22 : 0.16),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: <Widget>[
                Expanded(
                  child: centerBody
                      ? Center(child: content)
                      : content,
                ),
                if (bottom != null)
                  bottomFullBleed
                      ? bottom!
                      : Padding(
                          padding: EdgeInsets.only(
                            left: DfSpace.padX,
                            right: DfSpace.padX,
                            bottom: 16 + MediaQuery.paddingOf(context).bottom,
                          ),
                          child: bottom,
                        ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WashPainter extends CustomPainter {
  _WashPainter({required this.wash1, required this.wash2});

  final Color wash1;
  final Color wash2;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(1.0, -1.0),
          radius: 1.25,
          colors: <Color>[wash1, wash1.withValues(alpha: 0)],
          stops: const <double>[0, 0.58],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-1.0, 1.0),
          radius: 1.3,
          colors: <Color>[wash2, wash2.withValues(alpha: 0)],
          stops: const <double>[0, 0.60],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_WashPainter old) =>
      old.wash1 != wash1 || old.wash2 != wash2;
}

/// 纸纹 / 飞白颗粒：确定性伪随机，避免每帧抖动。
class _GrainPainter extends CustomPainter {
  _GrainPainter({required this.color, required this.opacity});

  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final math.Random rnd = math.Random(20261011);
    final int count = ((size.width * size.height) / 900).round().clamp(0, 900);
    final Paint paint = Paint()..isAntiAlias = false;
    for (int i = 0; i < count; i++) {
      final double x = rnd.nextDouble() * size.width;
      final double y = rnd.nextDouble() * size.height;
      paint.color = color.withValues(alpha: opacity * rnd.nextDouble());
      canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), paint);
    }
  }

  @override
  bool shouldRepaint(_GrainPainter old) =>
      old.opacity != opacity || old.color != color;
}

/// 主按钮区：小羊悬浮于按钮左上（§7 A/E）
class DfHeroButton extends StatelessWidget {
  const DfHeroButton({
    super.key,
    required this.label,
    required this.sheepHeight,
    this.onPressed,
  });

  final String label;
  final double sheepHeight;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: sheepHeight * 0.26),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            left: 8,
            top: 0,
            child: DfSheep(height: sheepHeight),
          ),
          DfCloudButton(label: label, onPressed: onPressed),
        ],
      ),
    );
  }
}

/// 演示用状态栏（生产环境请用系统状态栏，§2）
class DfStatusBar extends StatelessWidget {
  const DfStatusBar({super.key, this.time = '22:14'});

  final String time;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DfSpace.padX),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              time,
              style: DfType.sub(context, p.text).copyWith(
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
            CustomPaint(
              size: const Size(64, 12),
              painter: _StatusIconsPainter(p.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusIconsPainter extends CustomPainter {
  _StatusIconsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color.withValues(alpha: 0.9);
    // 信号 4 格
    for (int i = 0; i < 4; i++) {
      final double h = 4 + i * 2.6;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * 4.6, 12 - h, 2.8, h),
          const Radius.circular(1),
        ),
        paint,
      );
    }
    // WiFi 三段弧
    final Paint arc = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    const Offset wifiCenter = Offset(33, 11);
    canvas.drawArc(Rect.fromCircle(center: wifiCenter, radius: 6), math.pi * 1.15, math.pi * 0.7, false, arc);
    canvas.drawArc(Rect.fromCircle(center: wifiCenter, radius: 3.6), math.pi * 1.2, math.pi * 0.6, false, arc);
    canvas.drawCircle(wifiCenter, 1.0, paint);
    // 电池
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(46, 2.4, 15, 7.2), const Radius.circular(2)),
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(47.4, 3.8, 10, 4.4), const Radius.circular(1)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_StatusIconsPainter old) => old.color != color;
}

/// 原型陈列用手机框（仅演示；生产直接使用页面 Widget）
class DfPhoneFrame extends StatelessWidget {
  const DfPhoneFrame({
    super.key,
    required this.child,
    this.time = '22:14',
    this.width = 320,
    this.height = 694,
  });

  final Widget child;
  final String time;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: DfPalette.of(context).canvas,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          DfStatusBar(time: time),
          Expanded(child: child),
        ],
      ),
    );
  }
}

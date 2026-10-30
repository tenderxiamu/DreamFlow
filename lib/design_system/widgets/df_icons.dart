import 'package:flutter/material.dart';

import '../df_tokens.dart';

/// §9.5：不使用 `fill="var(...)"` 那类跨引擎失效的写法。
/// Flutter 侧统一用 [CustomPainter] + 主题令牌绘制，天然规避。
/// `pause` 为播放键的**第二态**（§7 C 播放 / 暂停切换），非新图标：
/// 与 `play` 共用同一个圆形按钮位与语义标签「播放 / 暂停」。
/// `back` 为二级页返回键所需（设计稿未包含返回控件，属落地必补件）。
enum DfGlyph { home, chat, moon, profile, mic, play, pause, prev, next, back, send }

class DfIcon extends StatelessWidget {
  const DfIcon(this.glyph, {super.key, this.size = 20, this.color, this.strokeWidth = 1.6});

  final DfGlyph glyph;
  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final Color c = color ??
        IconTheme.of(context).color ??
        DfPalette.of(context).text;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DfGlyphPainter(glyph, c, strokeWidth),
        isComplex: false,
      ),
    );
  }
}

class _DfGlyphPainter extends CustomPainter {
  _DfGlyphPainter(this.glyph, this.color, this.strokeWidth);

  final DfGlyph glyph;
  final Color color;
  final double strokeWidth;

  /// 实心字形：播放 / 前后曲（其余为描边）
  bool get _filled =>
      glyph == DfGlyph.play ||
      glyph == DfGlyph.pause ||
      glyph == DfGlyph.prev ||
      glyph == DfGlyph.next;

  @override
  void paint(Canvas canvas, Size size) {
    const double design = 24;
    canvas.save();
    canvas.scale(size.width / design, size.height / design);

    final Path p = Path();
    switch (glyph) {
      case DfGlyph.home:
        p.moveTo(3, 10.6);
        p.lineTo(12, 3.4);
        p.lineTo(21, 10.6);
        p.moveTo(5.6, 9.6);
        p.lineTo(5.6, 20);
        p.lineTo(18.4, 20);
        p.lineTo(18.4, 9.6);
      case DfGlyph.chat:
        p.moveTo(4.2, 5.4);
        p.lineTo(19.8, 5.4);
        p.lineTo(19.8, 16);
        p.lineTo(9.2, 16);
        p.lineTo(4.2, 20);
        p.close();
      case DfGlyph.moon:
        p.moveTo(20.6, 13.4);
        p.arcToPoint(
          const Offset(10.6, 3.4),
          radius: const Radius.circular(8.2),
          largeArc: true,
          clockwise: false,
        );
        p.arcToPoint(
          const Offset(20.6, 13.4),
          radius: const Radius.circular(6.4),
          clockwise: false,
        );
        p.close();
      case DfGlyph.profile:
        p.addOval(Rect.fromCircle(center: const Offset(12, 8.2), radius: 3.6));
        p.moveTo(5.2, 20);
        p.arcToPoint(
          const Offset(18.8, 20),
          radius: const Radius.circular(6.8),
          clockwise: true,
        );
      case DfGlyph.mic:
        p.addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(9, 3, 6, 11),
            const Radius.circular(3),
          ),
        );
        p.moveTo(5.2, 11.2);
        p.arcToPoint(
          const Offset(18.8, 11.2),
          radius: const Radius.circular(6.8),
          clockwise: false,
        );
        p.moveTo(12, 18);
        p.lineTo(12, 21);
      case DfGlyph.play:
        p.moveTo(8, 5);
        p.lineTo(19.5, 12);
        p.lineTo(8, 19);
        p.close();
      case DfGlyph.pause:
        p.addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(8, 5.5, 2.6, 13),
            const Radius.circular(1),
          ),
        );
        p.addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(13.4, 5.5, 2.6, 13),
            const Radius.circular(1),
          ),
        );
      case DfGlyph.prev:
        p.addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(6, 5.5, 2.4, 13),
            const Radius.circular(1),
          ),
        );
        p.moveTo(18.5, 6);
        p.lineTo(18.5, 18);
        p.lineTo(9.5, 12);
        p.close();
      case DfGlyph.next:
        p.addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(15.6, 5.5, 2.4, 13),
            const Radius.circular(1),
          ),
        );
        p.moveTo(5.5, 6);
        p.lineTo(5.5, 18);
        p.lineTo(14.5, 12);
        p.close();
      case DfGlyph.back:
        p.moveTo(20, 12);
        p.lineTo(5, 12);
        p.moveTo(11, 5.5);
        p.lineTo(4.5, 12);
        p.lineTo(11, 18.5);
      case DfGlyph.send:
        // 上箭头。和其余字形同一套细线，不用纸飞机 ——
        // 这个按钮的作用就是"发出去"，箭头比飞机少一层解读
        p.moveTo(12, 19.6);
        p.lineTo(12, 5);
        p.moveTo(5.6, 11.4);
        p.lineTo(12, 5);
        p.lineTo(18.4, 11.4);
    }

    final Paint paint = Paint()
      ..color = color
      ..isAntiAlias = true;
    if (_filled) {
      paint.style = PaintingStyle.fill;
    } else {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
    }
    canvas.drawPath(p, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DfGlyphPainter old) =>
      old.glyph != glyph || old.color != color || old.strokeWidth != strokeWidth;
}

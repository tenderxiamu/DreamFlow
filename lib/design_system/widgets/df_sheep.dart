import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../df_tokens.dart';
import '../df_type.dart';

/// §6.14 水墨小羊（吉祥物，全局贯穿）
///
/// - viewBox `0 0 112 78`，按**高度**缩放使用：头像 30 / 洞察卡 34 / 唤醒 48 / 主按钮 56 / 陈列 58
/// - 主题化走令牌：羊毛 `sheepWool`、墨线 `sheepLine`、腮红 `blush`
/// - 唯一常驻动效：3.6s 上下 5px 漂浮（`prefers-reduced-motion` 时自动关闭）
/// - `aria-hidden` 等价实现：`ExcludeSemantics`
class DfSheep extends StatefulWidget {
  const DfSheep({super.key, this.height = 56, this.animate = true});

  /// 期望高度（pt），宽度按 112:78 自动推导
  final double height;

  /// 是否播放漂浮动效（列表 / 静态陈列场景可关）
  final bool animate;

  @override
  State<DfSheep> createState() => _DfSheepState();
}

class _DfSheepState extends State<DfSheep> with SingleTickerProviderStateMixin {
  // 必须在 initState 中立即创建：若用 `late final` 懒初始化，当 animate=false 时
  // 控制器从未被访问，dispose() 里的首次访问会触发创建，而此处的 createTicker
  // 需要查询 TickerMode 祖先——此时 element 已 deactivate，会抛
  // "Looking up a deactivated widget's ancestor is unsafe."
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: DfMotion.sheepFloat,
    );
    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant DfSheep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final double w = widget.height * 112 / 78;

    final Widget painted = CustomPaint(
      size: Size(w, widget.height),
      painter: _SheepPainter(wool: p.sheepWool, line: p.sheepLine, blush: p.blush),
    );

    final Widget body = (widget.animate && !reduceMotion)
        ? AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? child) => Transform.translate(
              offset: Offset(0, -5 * Curves.easeInOut.transform(_controller.value)),
              child: child,
            ),
            child: painted,
          )
        : painted;

    return ExcludeSemantics(
      child: RepaintBoundary(child: body),
    );
  }
}

class _SheepPainter extends CustomPainter {
  _SheepPainter({required this.wool, required this.line, required this.blush});

  final Color wool;
  final Color line;
  final Color blush;

  @override
  void paint(Canvas canvas, Size size) {
    const double bw = 112;
    const double bh = 78;
    canvas.save();
    canvas.scale(size.width / bw, size.height / bh);

    final Path clip = Path()..addRect(const Rect.fromLTWH(-2, -2, bw + 4, bh + 4));
    canvas.clipPath(clip);

    // 腿（墨线）
    final Paint legPaint = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawLine(const Offset(44, 56), const Offset(44, 70), legPaint);
    canvas.drawLine(const Offset(55, 57), const Offset(55, 71), legPaint);
    canvas.drawLine(const Offset(66, 56), const Offset(66, 70), legPaint);
    canvas.drawLine(const Offset(76, 55), const Offset(76, 69), legPaint);

    // 羊毛（填充 + 墨线勾边）
    final Paint woolPaint = Paint()
      ..color = wool
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final Paint woolStroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..isAntiAlias = true;

    const List<List<double>> puffs = <List<double>>[
      <double>[42, 40, 15],
      <double>[56, 33, 15],
      <double>[70, 41, 13.5],
      <double>[50, 48, 13.5],
      <double>[64, 49, 12.5],
    ];
    for (final List<double> puff in puffs) {
      final Offset center = Offset(puff[0], puff[1]);
      canvas.drawCircle(center, puff[2], woolPaint);
      canvas.drawCircle(center, puff[2], woolStroke);
    }

    // 头
    const Offset head = Offset(83, 40);
    canvas.drawCircle(head, 11.5, woolPaint);
    canvas.drawCircle(head, 11.5, woolStroke);

    // 嘴（墨线弧）
    final Paint facePaint = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final Path mouth = Path()
      ..moveTo(80, 42.5)
      ..quadraticBezierTo(83, 45.5, 86, 42.5);
    canvas.drawPath(mouth, facePaint);

    // 眼
    final Paint eyePaint = Paint()
      ..color = line
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(const Offset(79.4, 37.4), 1.05, eyePaint);
    canvas.drawCircle(const Offset(86.6, 37.4), 1.05, eyePaint);

    // 腮红
    final Paint blushPaint = Paint()
      ..color = blush
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(78.6, 44), width: 6.2, height: 4.2),
      blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(87.4, 44), width: 6.2, height: 4.2),
      blushPaint,
    );

    // zzz（毛笔字体）
    _drawZ(canvas, 'z', const Offset(97, 24), 13, line);
    _drawZ(canvas, 'z', const Offset(103, 15), 10, line);

    canvas.restore();
  }

  void _drawZ(Canvas canvas, String text, Offset at, double fontSize, Color color) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontFamily: 'MaShanZheng',
          fontFamilyFallback: DfFonts.fallbackBrush,
          decoration: TextDecoration.none,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_SheepPainter old) =>
      old.wool != wool || old.line != line || old.blush != blush;
}

/// 头像底：小羊居中于圆形面（§9.4 装饰性，语义排除）
class DfAvatar extends StatelessWidget {
  const DfAvatar({super.key, this.diameter = 38, this.sheepHeight = 30});

  final double diameter;
  final double sheepHeight;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(color: p.surface2, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: DfSheep(height: sheepHeight, animate: false),
    );
  }
}

/// 供 [DfSheep] 内部复用：把设计稿角度换算成弧度
double deg(double d) => d * math.pi / 180;

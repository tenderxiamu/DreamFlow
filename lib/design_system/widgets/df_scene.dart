import 'package:flutter/material.dart';

import '../df_tokens.dart';

/// §6.13 场景（墨山 / 日出）
///
/// - 天空渐变走 Flutter 装饰层（等价于「渐变在 CSS、不进 SVG」）
/// - 三层山 path：远山 .45 / 中景 .72 / 近山 .92（近山即重墨点睛）
/// - 飞白：3 条 2px 圆头弧线，色 `flywhite`
/// - 月亮 / 日出光晕：径向渐变的暖色 rgba(212,200,168,…)
enum DfSceneVariant { mountain, sunrise }

class DfScene extends StatelessWidget {
  const DfScene({
    super.key,
    required this.height,
    this.variant = DfSceneVariant.mountain,
    this.overlay,
  });

  final double height;
  final DfSceneVariant variant;

  /// 场景上的叠加内容（如唤醒屏的时刻大字）
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DfRadius.card),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  // 178° ≈ 近垂直向下，略有横向偏移
                  begin: const Alignment(0.06, -1),
                  end: const Alignment(-0.06, 1),
                  colors: <Color>[p.sceneA, p.sceneB],
                ),
              ),
            ),
            CustomPaint(
              painter: _DfScenePainter(
                variant: variant,
                m1: p.m1,
                m2: p.m2,
                m3: p.m3,
                moon: p.mistYellow,
                fly: p.flywhite,
              ),
            ),
            if (overlay != null)
              Positioned.fill(
                child: Center(child: overlay),
              ),
          ],
        ),
      ),
    );
  }
}

class _DfScenePainter extends CustomPainter {
  _DfScenePainter({
    required this.variant,
    required this.m1,
    required this.m2,
    required this.m3,
    required this.moon,
    required this.fly,
  });

  final DfSceneVariant variant;
  final Color m1;
  final Color m2;
  final Color m3;
  final Color moon;
  final Color fly;

  /// §12-5：光晕为固定暖色，不随主题切换（光源自带色温）
  static const Color _warm = Color(0xFFD4C8A8);

  @override
  void paint(Canvas canvas, Size size) {
    if (variant == DfSceneVariant.mountain) {
      _paintMountain(canvas, size);
    } else {
      _paintSunrise(canvas, size);
    }
  }

  void _paintMountain(Canvas canvas, Size size) {
    const double vw = 320;
    const double vh = 220;
    canvas.save();
    canvas.scale(size.width / vw, size.height / vh);

    // 月亮光晕（径向淡出）
    _radial(canvas, center: const Offset(74, 58), radius: 95, alpha: 0.40);
    // 月亮
    canvas.drawCircle(
      const Offset(74, 58),
      17,
      Paint()..color = moon.withValues(alpha: 0.9)..isAntiAlias = true,
    );

    _flyArcs(canvas, const <List<double>>[
      <double>[198, 46, 92, -20],
      <double>[176, 78, 80, -14],
      <double>[212, 108, 66, -10],
    ]);

    _mountainLayer(
      canvas,
      m1,
      0.45,
      <Offset>[
        const Offset(-20, 168), const Offset(58, 96), const Offset(112, 142),
        const Offset(168, 88), const Offset(236, 152), const Offset(286, 118),
        const Offset(348, 176), const Offset(348, 232), const Offset(-20, 232),
      ],
    );
    _mountainLayer(
      canvas,
      m2,
      0.72,
      <Offset>[
        const Offset(-20, 198), const Offset(46, 138), const Offset(104, 182),
        const Offset(160, 132), const Offset(214, 184), const Offset(268, 146),
        const Offset(348, 204), const Offset(348, 232), const Offset(-20, 232),
      ],
    );
    _mountainLayer(
      canvas,
      m3,
      0.92,
      <Offset>[
        const Offset(-20, 226), const Offset(38, 186), const Offset(92, 220),
        const Offset(150, 178), const Offset(206, 222), const Offset(262, 190),
        const Offset(348, 228), const Offset(348, 240), const Offset(-20, 240),
      ],
    );

    canvas.restore();
  }

  void _paintSunrise(Canvas canvas, Size size) {
    const double vw = 320;
    const double vh = 200;
    canvas.save();
    canvas.scale(size.width / vw, size.height / vh);

    _radial(canvas, center: const Offset(160, 190), radius: 120, alpha: 0.50);
    _radial(canvas, center: const Offset(160, 194), radius: 66, alpha: 0.36);
    canvas.drawCircle(
      const Offset(160, 192),
      30,
      Paint()..color = moon.withValues(alpha: 0.92)..isAntiAlias = true,
    );

    _flyArcs(canvas, const <List<double>>[
      <double>[196, 52, 96, -18],
      <double>[180, 84, 84, -12],
    ]);

    _mountainLayer(
      canvas,
      m1,
      0.45,
      <Offset>[
        const Offset(-20, 150), const Offset(66, 104), const Offset(120, 138),
        const Offset(182, 96), const Offset(246, 140), const Offset(300, 112),
        const Offset(348, 148), const Offset(348, 210), const Offset(-20, 210),
      ],
    );
    _mountainLayer(
      canvas,
      m2,
      0.72,
      <Offset>[
        const Offset(-20, 178), const Offset(70, 138), const Offset(140, 172),
        const Offset(206, 136), const Offset(272, 172), const Offset(348, 148),
        const Offset(348, 210), const Offset(-20, 210),
      ],
    );
    _mountainLayer(
      canvas,
      m3,
      0.92,
      <Offset>[
        const Offset(-20, 196), const Offset(44, 164), const Offset(104, 194),
        const Offset(168, 158), const Offset(232, 196), const Offset(292, 168),
        const Offset(348, 198), const Offset(348, 210), const Offset(-20, 210),
      ],
    );

    canvas.restore();
  }

  void _mountainLayer(Canvas canvas, Color color, double opacity, List<Offset> pts) {
    final Path path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  /// 飞白：[x, y, 长度, 纵向偏移]
  void _flyArcs(Canvas canvas, List<List<double>> arcs) {
    final Paint paint = Paint()
      ..color = fly
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    for (final List<double> a in arcs) {
      final Path path = Path()
        ..moveTo(a[0], a[1])
        ..quadraticBezierTo(
          a[0] + a[2] / 2,
          a[1] + a[3],
          a[0] + a[2],
          a[1] + a[3] * 0.3,
        );
      canvas.drawPath(path, paint);
    }
  }

  void _radial(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required double alpha,
  }) {
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    final Paint paint = Paint()
      ..isAntiAlias = true
      ..shader = RadialGradient(
        colors: <Color>[
          _warm.withValues(alpha: alpha),
          _warm.withValues(alpha: alpha * 0.35),
          _warm.withValues(alpha: 0),
        ],
        stops: const <double>[0, 0.55, 1],
      ).createShader(rect);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_DfScenePainter old) =>
      old.variant != variant ||
      old.m1 != m1 ||
      old.m2 != m2 ||
      old.m3 != m3 ||
      old.moon != moon ||
      old.fly != fly;
}

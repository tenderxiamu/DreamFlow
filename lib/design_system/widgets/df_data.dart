import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../df_tokens.dart';
import '../df_type.dart';

// ─────────────────────────────────────────────────────────────────────────────
// §6.9 环形睡眠分 ring —— 落地按 score/100 × 360deg 动态生成（非固定 295deg）
// ─────────────────────────────────────────────────────────────────────────────
class DfRing extends StatelessWidget {
  const DfRing({
    super.key,
    this.score = 82,
    this.size = 112,
    this.label = '睡眠分',
  });

  final int score;
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    final double deg = (score.clamp(0, 100) / 100) * 360;

    return Semantics(
      image: true,
      label: '$label$score',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            CustomPaint(
              size: Size(size, size),
              painter: _RingPainter(
                progress: p.mistBlue,
                track: p.ringBg,
                deg: deg,
                thickness: 9,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '$score',
                  style: DfType.number(context, DfFontSize.display, p.text),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: DfType.caption(context, p.text2).copyWith(
                    letterSpacing: DfFontSize.caption * 0.16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.track,
    required this.deg,
    required this.thickness,
  });

  final Color progress;
  final Color track;
  final double deg;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = (size.shortestSide - thickness) / 2;
    final Rect rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: radius,
    );

    final Paint trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;
    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);

    final Paint progressPaint = Paint()
      ..color = progress
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;
    // 从 12 点方向顺时针
    canvas.drawArc(rect, -math.pi / 2, deg * math.pi / 180, false, progressPaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.deg != deg ||
      old.progress != progress ||
      old.track != track ||
      old.thickness != thickness;
}

// ─────────────────────────────────────────────────────────────────────────────
// §6.11 进度条 bar-line（高 8 · 药丸）
// ─────────────────────────────────────────────────────────────────────────────
class DfBarLine extends StatelessWidget {
  const DfBarLine({super.key, required this.value, this.success = false});

  /// 0–1
  final double value;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    final Color fill = success ? p.mistGreen : p.mistBlue;
    final double v = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(DfRadius.pill),
      child: SizedBox(
        height: 8,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            return Stack(
              children: <Widget>[
                Positioned.fill(child: ColoredBox(color: p.track)),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: c.maxWidth * v,
                  child: ColoredBox(color: fill),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// §6.11 时间轴 timeline（高 2 · 已播 38% · 手柄 11×11 + 4px 外圈）
// ─────────────────────────────────────────────────────────────────────────────
class DfTimeline extends StatelessWidget {
  const DfTimeline({super.key, this.progress = 0.38});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    const double handle = 11;
    return SizedBox(
      height: handle + 8,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          final double w = c.maxWidth;
          final double x = (w * progress.clamp(0, 1)).clamp(handle / 2, w - handle / 2);
          return Stack(
            alignment: Alignment.centerLeft,
            children: <Widget>[
              Positioned(
                left: 0,
                right: 0,
                child: Container(height: 2, color: p.track),
              ),
              Positioned(
                left: 0,
                width: x,
                child: Container(height: 2, color: p.mistBlue),
              ),
              Positioned(
                left: x - handle / 2,
                child: Container(
                  width: handle,
                  height: handle,
                  decoration: BoxDecoration(
                    color: p.mistBlue,
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(color: p.cardTint, spreadRadius: 4),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// §6.11 波形 wave（高 42 · 条 gap 3 · 高度 34–96%）
// ─────────────────────────────────────────────────────────────────────────────
class DfWave extends StatelessWidget {
  const DfWave({super.key, this.height = 42, this.bars});

  final double height;

  /// 0–1 的归一化高度；缺省使用确定性示例数据
  final List<double>? bars;

  static const List<double> _default = <double>[
    0.46, 0.62, 0.78, 0.54, 0.88, 0.70, 0.96, 0.58, 0.40, 0.74,
    0.66, 0.90, 0.52, 0.80, 0.44, 0.68, 0.86, 0.56, 0.72, 0.48,
  ];

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    final List<double> data = bars ?? _default;
    final Color barColor = p.mistBlue.withValues(alpha: 0.75);
    return SizedBox(
      height: height,
      child: Row(
        children: List<Widget>.generate(data.length, (int i) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == data.length - 1 ? 0 : 3),
              child: Align(
                alignment: Alignment.center,
                child: FractionallySizedBox(
                  widthFactor: 1,
                  heightFactor: data[i].clamp(0.0, 1.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// §6.11 关联条形 brow（标签列 46 右对齐 · 条高 9 药丸 · 数值列 34 右对齐）
// ─────────────────────────────────────────────────────────────────────────────
class DfBrow extends StatelessWidget {
  const DfBrow({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });

  final String label;
  final double value;
  final double max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.5),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 46,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: DfType.caption(context, p.text2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(DfRadius.pill),
              child: SizedBox(
                height: 9,
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints c) {
                    return Stack(
                      children: <Widget>[
                        Positioned.fill(child: ColoredBox(color: p.track)),
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: c.maxWidth * (value / max).clamp(0.0, 1.0),
                          child: ColoredBox(color: color),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 34,
            child: Text(
              value.round().toString(),
              textAlign: TextAlign.right,
              style: DfType.number(
                context,
                DfFontSize.small,
                p.text2,
                weight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

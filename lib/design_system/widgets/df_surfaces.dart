import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../df_tokens.dart';
import '../df_type.dart';

// ─────────────────────────────────────────────────────────────────────────────
// §6.5 卡片 card
// ─────────────────────────────────────────────────────────────────────────────
class DfCard extends StatelessWidget {
  const DfCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    this.borderColor,
    this.dashed = false,
    this.fill,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final bool dashed;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    final BorderRadius radius = BorderRadius.circular(DfRadius.card);

    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _CardBackgroundPainter(
                fill: fill ?? p.surface,
                border: borderColor ?? p.line,
                wash: p.wash1.withValues(alpha: p.wash1.a * 0.7),
                radius: DfRadius.card,
                dashed: dashed,
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class _CardBackgroundPainter extends CustomPainter {
  _CardBackgroundPainter({
    required this.fill,
    required this.border,
    required this.wash,
    required this.radius,
    required this.dashed,
  });

  final Color fill;
  final Color border;
  final Color wash;
  final double radius;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    canvas.drawRRect(rrect, Paint()..color = fill);

    // 左上墨晕（120°）
    final Rect rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[wash, wash.withValues(alpha: 0)],
          stops: const <double>[0, 0.52],
        ).createShader(rect),
    );
    canvas.restore();

    final Paint borderPaint = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    if (!dashed) {
      canvas.drawRRect(rrect, borderPaint);
      return;
    }

    // 虚线描边（洞察卡）
    final Path path = Path()..addRRect(rrect);
    const double dash = 4;
    const double gap = 3;
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double next = (distance + dash).clamp(0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), borderPaint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_CardBackgroundPainter old) =>
      old.fill != fill ||
      old.border != border ||
      old.wash != wash ||
      old.radius != radius ||
      old.dashed != dashed;
}

// ─────────────────────────────────────────────────────────────────────────────
// §6.6 对话气泡 bubble
// ─────────────────────────────────────────────────────────────────────────────
class DfBubble extends StatelessWidget {
  const DfBubble({super.key, required this.text, this.mine = false, this.rich});

  final String text;
  final bool mine;

  /// 需要局部强调（`--mist-green`）时传入富文本
  final TextSpan? rich;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 236),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          decoration: BoxDecoration(
            color: mine ? p.mistBlue : p.surface,
            border: mine ? null : Border.all(color: p.line),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(mine ? 16 : 6),
              topRight: Radius.circular(mine ? 6 : 16),
              bottomLeft: const Radius.circular(16),
              bottomRight: const Radius.circular(16),
            ),
          ),
          child: rich != null
              ? Text.rich(rich!)
              : Text(
                  text,
                  style: DfType.bubble(context, mine ? p.onMist : p.text),
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// §6.10 指标格 metric（双列网格，gap 10）
// ─────────────────────────────────────────────────────────────────────────────
class DfMetric extends StatelessWidget {
  const DfMetric({
    super.key,
    required this.label,
    required this.value,
    this.unit,
  });

  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(DfRadius.metric),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: DfType.caption(context, p.text2)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: value,
                    style: DfType.number(context, DfFontSize.titleS, p.text),
                  ),
                  if (unit != null)
                    TextSpan(
                      text: ' $unit',
                      style: DfType.caption(context, p.text2),
                    ),
                ],
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class DfMetricGrid extends StatelessWidget {
  const DfMetricGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.72,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: children,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// §6.12 洞察卡 insight（虚线边 + 小羊 34）
// ─────────────────────────────────────────────────────────────────────────────
class DfInsight extends StatelessWidget {
  const DfInsight({super.key, required this.child, this.leading});

  final Widget child;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    return DfCard(
      dashed: true,
      fill: p.surface2,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (leading != null) ...<Widget>[
            leading!,
            const SizedBox(width: 12),
          ],
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// 洞察卡正文：关键词用 `text` 加重（不加粗字号）
class DfInsightText extends StatelessWidget {
  const DfInsightText(this.spans, {super.key});

  /// 交替 [普通文本, 关键词, 普通文本, …]
  final List<String> spans;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    return Text.rich(
      TextSpan(
        children: List<InlineSpan>.generate(spans.length, (int i) {
          final bool emphasize = i.isOdd;
          return TextSpan(
            text: spans[i],
            style: DfType.insight(context, emphasize ? p.text : p.text2),
          );
        }),
      ),
    );
  }
}

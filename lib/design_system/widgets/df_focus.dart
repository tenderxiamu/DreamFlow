import 'package:flutter/material.dart';

import '../df_tokens.dart';

/// §9.3 聚焦态 —— `:focus-visible` 的 Flutter 等价实现（P1 必做）。
///
/// 键盘 / 外接开关聚焦时描 2px `--mist-blue` 外框（offset 2），
/// 鼠标点击不显示（`onShowFocusHighlight` 已按 Flutter 的输入模态判定）。
class DfFocusRing extends StatefulWidget {
  const DfFocusRing({
    super.key,
    required this.child,
    this.radius = DfRadius.pill,
    this.onActivate,
    this.enabled = true,
  });

  final Widget child;

  /// 与宿主控件外轮廓一致的圆角（圆形按钮传 `size / 2`）
  final double radius;

  /// Enter / Space 激活，等价 `<button>` 的键盘语义
  final VoidCallback? onActivate;

  final bool enabled;

  @override
  State<DfFocusRing> createState() => _DfFocusRingState();
}

class _DfFocusRingState extends State<DfFocusRing> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    return FocusableActionDetector(
      enabled: widget.enabled,
      onShowFocusHighlight: (bool v) {
        if (v != _focused) setState(() => _focused = v);
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (ActivateIntent _) {
            widget.onActivate?.call();
            return null;
          },
        ),
      },
      child: CustomPaint(
        foregroundPainter: _FocusRingPainter(
          color: p.mistBlue,
          radius: widget.radius,
          visible: _focused,
        ),
        child: widget.child,
      ),
    );
  }
}

class _FocusRingPainter extends CustomPainter {
  _FocusRingPainter({
    required this.color,
    required this.radius,
    required this.visible,
  });

  final Color color;
  final double radius;
  final bool visible;

  /// §9.3 `outline-offset: 2px`
  static const double _offset = 2;

  @override
  void paint(Canvas canvas, Size size) {
    if (!visible) return;
    final Rect rect = Rect.fromLTWH(
      -_offset,
      -_offset,
      size.width + _offset * 2,
      size.height + _offset * 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius + _offset)),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_FocusRingPainter old) =>
      old.color != color || old.radius != radius || old.visible != visible;
}

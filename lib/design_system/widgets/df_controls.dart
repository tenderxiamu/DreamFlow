import 'package:flutter/material.dart';

import '../df_tokens.dart';
import '../df_type.dart';
import 'df_focus.dart';
import 'df_icons.dart';

// ─────────────────────────────────────────────────────────────────────────────
// §6.1 云墨主按钮 btn-cloud —— 全场唯一莫兰迪实心面
// ─────────────────────────────────────────────────────────────────────────────
class DfCloudButton extends StatefulWidget {
  const DfCloudButton({
    super.key,
    required this.label,
    this.onPressed,
    this.height = DfTouch.primaryH,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  State<DfCloudButton> createState() => _DfCloudButtonState();
}

class _DfCloudButtonState extends State<DfCloudButton> {
  bool _pressed = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    final bool enabled = widget.onPressed != null;
    final Color bg = enabled ? p.mistBlue : p.surface;
    final Color fg = enabled ? p.onMist : p.ink500;

    return DfFocusRing(
      enabled: enabled,
      onActivate: widget.onPressed,
      child: LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double w = c.maxWidth.isFinite ? c.maxWidth : 320;
        return MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
            onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
            onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
            onTap: widget.onPressed,
            child: AnimatedContainer(
              duration: DfMotion.dur,
              curve: DfMotion.ease,
              transform: Matrix4.translationValues(
                0,
                (enabled && _hover) ? -2 : 0,
                0,
              ),
              child: Semantics(
                button: true,
                enabled: enabled,
                label: widget.label,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    // 云朵鼓包：22×14(left 16%, top −7)、16×11(left 24%, top −9)，op .9
                    Positioned(
                      left: w * 0.16,
                      top: -7,
                      child: _Bump(width: 22, height: 14, color: bg),
                    ),
                    Positioned(
                      left: w * 0.24,
                      top: -9,
                      child: _Bump(width: 16, height: 11, color: bg),
                    ),
                    AnimatedScale(
                      scale: _pressed ? 0.985 : 1,
                      duration: DfMotion.dur,
                      curve: DfMotion.ease,
                      child: Container(
                        height: widget.height,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(DfRadius.pill),
                          boxShadow: enabled
                              ? <BoxShadow>[
                                  BoxShadow(
                                    color: (enabled && _hover)
                                        ? p.glow.withValues(alpha: 0.3)
                                        : p.glow,
                                    blurRadius: 26,
                                    offset: const Offset(0, 10),
                                  ),
                                ]
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(DfRadius.pill),
                          child: Stack(
                            fit: StackFit.expand,
                            children: <Widget>[
                              ColoredBox(color: bg),
                              // inset 0 -3px 0 rgba(...)：底部内阴影
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: SizedBox(
                                  height: 14,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: <Color>[
                                          Colors.transparent,
                                          p.btnInner,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Center(
                                child: Text(
                                  widget.label,
                                  style: DfType.buttonPrimary(context, fg),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      ),
    );
  }
}

class _Bump extends StatelessWidget {
  const _Bump({required this.width, required this.height, required this.color});

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.all(Radius.elliptical(width / 2, height / 2)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// §6.2 描边次按钮 btn-ghost（含圆形变体）
// ─────────────────────────────────────────────────────────────────────────────
class DfGhostButton extends StatefulWidget {
  const DfGhostButton({
    super.key,
    this.label,
    this.glyph,
    this.onPressed,
    this.height,
    this.round = false,
    this.semanticLabel,
  });

  final String? label;
  final DfGlyph? glyph;
  final VoidCallback? onPressed;
  final double? height;
  final bool round;

  /// §9.4：纯图标（圆形）变体必须带 aria-label，如「上一曲 / 下一曲」。
  /// 有 [label] 时以文本为准，本字段仅在圆形变体上生效。
  final String? semanticLabel;

  @override
  State<DfGhostButton> createState() => _DfGhostButtonState();
}

class _DfGhostButtonState extends State<DfGhostButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    final double h = widget.round
        ? (widget.height ?? 48)
        : (widget.height ?? DfTouch.secondaryH);
    final Color border = _hover ? p.mistBlue : p.line;

    return DfFocusRing(
      enabled: widget.onPressed != null,
      onActivate: widget.onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: AnimatedScale(
            scale: _pressed ? 0.985 : 1,
            duration: DfMotion.dur,
            curve: DfMotion.ease,
            child: AnimatedContainer(
              duration: DfMotion.dur,
              curve: DfMotion.ease,
              width: widget.round ? h : null,
              height: h,
              decoration: BoxDecoration(
                color: _hover ? p.cardTint : Colors.transparent,
                borderRadius: BorderRadius.circular(DfRadius.pill),
                border: Border.all(color: border),
              ),
              child: Center(
                child: widget.label != null
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          widget.label!,
                          style: DfType.buttonSecondary(context, p.text),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : Semantics(
                        button: true,
                        enabled: widget.onPressed != null,
                        label: widget.semanticLabel ?? '播放 / 暂停',
                        child: DfIcon(
                          widget.glyph ?? DfGlyph.play,
                          size: 18,
                          color: p.text,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// §6.3 圆形图标按钮 mic / play
// ─────────────────────────────────────────────────────────────────────────────
class DfIconButton extends StatefulWidget {
  const DfIconButton({
    super.key,
    required this.glyph,
    required this.semanticLabel,
    this.onPressed,
    this.size = DfTouch.min,
  });

  final DfGlyph glyph;
  final String semanticLabel;
  final VoidCallback? onPressed;

  /// 44（话筒）/ 66（播放键）
  final double size;

  @override
  State<DfIconButton> createState() => _DfIconButtonState();
}

class _DfIconButtonState extends State<DfIconButton> {
  bool _pressed = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    final bool big = widget.size >= DfTouch.play;

    return DfFocusRing(
      radius: widget.size / 2,
      enabled: widget.onPressed != null,
      onActivate: widget.onPressed,
      child: Semantics(
        button: true,
        label: widget.semanticLabel,
        child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: AnimatedScale(
            scale: _pressed ? 0.96 : 1,
            duration: DfMotion.dur,
            curve: DfMotion.ease,
            child: AnimatedContainer(
              duration: DfMotion.dur,
              curve: DfMotion.ease,
              transform: Matrix4.translationValues(0, _hover ? -1 : 0, 0),
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: p.mistBlue,
                shape: BoxShape.circle,
                boxShadow: big
                    ? <BoxShadow>[
                        BoxShadow(
                          color: p.glow,
                          blurRadius: 26,
                          offset: const Offset(0, 10),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: DfIcon(
                widget.glyph,
                size: big ? 24 : 20,
                color: p.onMist,
                strokeWidth: 1.7,
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// §6.4 Tab 栏 —— 仅颜色变化，不加粗不放大
// ─────────────────────────────────────────────────────────────────────────────
class DfTabItem {
  const DfTabItem(this.glyph, this.label);

  final DfGlyph glyph;
  final String label;
}

class DfTabs extends StatelessWidget {
  const DfTabs({
    super.key,
    required this.items,
    this.currentIndex = 0,
    this.onTap,
    this.bordered = true,
  });

  final List<DfTabItem> items;
  final int currentIndex;
  final ValueChanged<int>? onTap;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        border: bordered ? Border(top: BorderSide(color: p.line)) : null,
      ),
      padding: EdgeInsets.only(
        top: 12,
        bottom: 16 + MediaQuery.paddingOf(context).bottom,
        left: 6,
        right: 6,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List<Widget>.generate(items.length, (int i) {
          final DfTabItem item = items[i];
          final bool on = i == currentIndex;
          final Color color = on ? p.mistBlue : p.text3;
          return Semantics(
            button: true,
            selected: on,
            label: item.label,
            child: DfFocusRing(
              radius: 12,
              enabled: onTap != null,
              onActivate: onTap == null ? null : () => onTap!(i),
              child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap == null ? null : () => onTap!(i),
              child: SizedBox(
                width: DfTouch.min,
                height: DfTouch.min,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    DfIcon(item.glyph, size: 20, color: color),
                    const SizedBox(height: 3),
                    Text(item.label, style: DfType.caption(context, color)),
                  ],
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

/// 二级页返回键（**设计稿未包含返回控件，属落地必补件**）。
/// 规格沿用 §6.2 `btn-ghost` 圆形变体，语义标签「返回」。
class DfBackButton extends StatelessWidget {
  const DfBackButton({super.key, required this.onPressed, this.label = '返回'});

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DfGhostButton(
      round: true,
      glyph: DfGlyph.back,
      semanticLabel: label,
      height: DfTouch.min,
      onPressed: onPressed,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// §6.7 情绪徽标 chip
// ─────────────────────────────────────────────────────────────────────────────
class DfChip extends StatelessWidget {
  const DfChip({super.key, required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    final Color c = selected ? p.mistGreen : p.mistBlue;
    final double borderAlpha = selected ? 0.4 : 0.28;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(DfRadius.pill),
        border: Border.all(color: c.withValues(alpha: borderAlpha)),
      ),
      child: Text(label, style: DfType.chip(context, c)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// §6.8 输入框 field（16px 硬性，防 iOS 聚焦缩放）
// ─────────────────────────────────────────────────────────────────────────────
class DfField extends StatelessWidget {
  const DfField({
    super.key,
    this.hint,
    this.controller,
    this.focusNode,
    this.onSubmitted,
    this.errorText,
  });

  final String? hint;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;

  /// §12 缺口 3：校验失败说明（12px）。非空时**描边转 `--mist-pink`**。
  ///
  /// 语义上通过 [Semantics] 挂 liveRegion，读屏会在校验状态变化时播报；
  /// 输入框本身用 `Semantics(textField: true)` 保持与原生一致。
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    final bool hasError = errorText != null && errorText!.isNotEmpty;
    final Color border = hasError ? p.mistPink : p.line;
    final Color focusBorder = hasError ? p.mistPink : p.mistBlue;

    final Widget input = TextField(
      controller: controller,
      focusNode: focusNode,
      onSubmitted: onSubmitted,
      style: TextStyle(
        fontSize: DfFontSize.input,
        color: p.text,
        fontFamily: DfFonts.body,
        fontFamilyFallback: DfFonts.fallbackBody,
      ),
      cursorColor: p.mistBlue,
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: DfFontSize.input,
          // 按 §6.8 组件规格保留 `--text-3`（占位符 16px）；
          // 注意其与 §3 注「禁止 text-3 上卡片面」冲突（夜墨 4.06:1），已上报设计侧
          color: p.text3,
          fontFamily: DfFonts.body,
          fontFamilyFallback: DfFonts.fallbackBody,
        ),
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DfRadius.pill),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DfRadius.pill),
          borderSide: BorderSide(color: focusBorder),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DfRadius.pill),
          borderSide: BorderSide(color: border),
        ),
      ),
    );

    if (!hasError) return input;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        input,
        const SizedBox(height: 6),
        Semantics(
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              errorText!,
              style: DfType.sub(context, p.mistPink),
            ),
          ),
        ),
      ],
    );
  }
}

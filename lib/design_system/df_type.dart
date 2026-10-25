import 'package:flutter/material.dart';

import 'df_tokens.dart';

/// §4.3 字体族 + §4.2 字号 / 行高。
///
/// 三套字体均可商用（OFL）：Ma Shan Zheng / LXGW WenKai / Cormorant Garamond。
/// 未随包分发字体文件时自动回退到系统衬线族，见 [fontFamilyFallback]。
class DfFonts {
  const DfFonts._();

  static const String brush = 'MaShanZheng';
  static const String body = 'LXGWWenKai';
  static const String num = 'CormorantGaramond';

  static const List<String> fallbackBrush = <String>[
    'LXGWWenKai', 'STKaiti', 'KaiTi', 'Noto Serif SC', 'serif',
  ];
  static const List<String> fallbackBody = <String>[
    'Songti SC', 'STSong', 'Noto Serif SC', 'serif',
  ];
  static const List<String> fallbackNum = <String>[
    'LXGWWenKai', 'serif',
  ];
}

/// 排版工厂：所有文本样式集中产出，页面不写裸 TextStyle。
class DfType {
  const DfType._();

  static const List<FontFeature> _tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static TextStyle _base(
    BuildContext context, {
    required double size,
    required double height,
    required Color color,
    String? family,
    List<String>? fallback,
    FontWeight weight = FontWeight.w400,
    double letterSpacing = 0,
    List<FontFeature>? features,
  }) {
    return TextStyle(
      fontSize: size,
      height: height,
      color: color,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      fontFamily: family ?? DfFonts.body,
      fontFamilyFallback: fallback ?? DfFonts.fallbackBody,
      fontFeatures: features,
    );
  }

  /// 页面主标题（毛笔）· 25
  static TextStyle title(BuildContext c, Color color) => _base(
        c,
        size: DfFontSize.title,
        height: DfLineHeight.title,
        color: color,
        family: DfFonts.brush,
        fallback: DfFonts.fallbackBrush,
        letterSpacing: 0.02 * DfFontSize.title,
      );

  /// 模块 / 卡片标题（毛笔）· 19
  static TextStyle titleS(BuildContext c, Color color) => _base(
        c,
        size: DfFontSize.titleS,
        height: DfLineHeight.title,
        color: color,
        family: DfFonts.brush,
        fallback: DfFonts.fallbackBrush,
        letterSpacing: 0.02 * DfFontSize.titleS,
      );

  /// 说明 / 副标 · 12
  static TextStyle sub(BuildContext c, Color color) =>
      _base(c, size: DfFontSize.small, height: DfLineHeight.body, color: color);

  /// 正文 · 13
  static TextStyle bodyS(BuildContext c, Color color) =>
      _base(c, size: DfFontSize.bodyS, height: DfLineHeight.body, color: color);

  /// 正文强调 · 13 / 1.7（洞察卡）
  static TextStyle insight(BuildContext c, Color color) =>
      _base(c, size: DfFontSize.bodyS, height: DfLineHeight.insight, color: color);

  /// 气泡 · 13 / 1.62
  static TextStyle bubble(BuildContext c, Color color) =>
      _base(c, size: DfFontSize.bodyS, height: DfLineHeight.bubble, color: color);

  /// 次级按钮字 · 14
  static TextStyle buttonSecondary(BuildContext c, Color color) => _base(
        c,
        size: DfFontSize.body,
        height: 1.0,
        color: color,
        letterSpacing: 0.08 * DfFontSize.body,
      );

  /// 主按钮字 · 16
  static TextStyle buttonPrimary(BuildContext c, Color color) => _base(
        c,
        size: DfFontSize.input,
        height: 1.0,
        color: color,
        letterSpacing: 0.1 * DfFontSize.input,
      );

  /// 注脚 / 单位 · 11
  static TextStyle caption(BuildContext c, Color color) => _base(
        c,
        size: DfFontSize.caption,
        height: 1.35,
        color: color,
        letterSpacing: 0.05 * DfFontSize.caption,
      );

  /// 徽标 · 12
  static TextStyle chip(BuildContext c, Color color) => _base(
        c,
        size: DfFontSize.small,
        height: 1.2,
        color: color,
        letterSpacing: 0.04 * DfFontSize.small,
      );

  /// 数字（Cormorant + tabular-nums）· 任意字号
  static TextStyle number(
    BuildContext c,
    double size,
    Color color, {
    FontWeight weight = FontWeight.w600,
  }) =>
      _base(
        c,
        size: size,
        height: 1.0,
        color: color,
        family: DfFonts.num,
        fallback: DfFonts.fallbackNum,
        weight: weight,
        features: _tabular,
      );

  /// 全局缺省文本样式
  static TextTheme textTheme(BuildContext c, DfPalette p) => TextTheme(
        displayLarge: number(c, DfFontSize.display, p.text),
        headlineLarge: title(c, p.text),
        titleMedium: titleS(c, p.text),
        bodyMedium: bodyS(c, p.text),
        bodySmall: sub(c, p.text2),
        labelSmall: caption(c, p.text3),
      );
}

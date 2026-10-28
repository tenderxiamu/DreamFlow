import 'package:flutter/material.dart';

import 'df_tokens.dart';

/// §4.3 字体族。
///
/// **M6.8 起正文不再使用打包的楷体**。原因：字体子集只覆盖 318 个汉字，而 lib/
/// 实际用到 983 个，缺的 680 个（「想 / 能 / 很 / 大 / 太 / 真 / 会 / 做」……）
/// 会被 Flutter 逐字回退到系统字体 —— 同一段话里一半楷体一半黑体，字面高度与字重
/// 都不同，看起来就是「字号忽大忽小」。LLM 动态回复更是几乎全量缺字。
///
/// 现在分三族，各司其职：
/// - [body]：**系统字体**（不指定 family，交给平台 CJK 字体），
///   覆盖 100%，动态内容一个生僻字都不会掉；正文 / 气泡 / 输入 / 说明全用它
/// - [brush]：毛笔体（MaShanZheng 子集 3911 字符，源码汉字零缺失），仅用于标题与大数字
/// - [num]：Cormorant Garamond，仅用于纯阿拉伯数字（ASCII 完整）
class DfFonts {
  const DfFonts._();

  /// 正文族：null = 平台默认字体（Android: MiSans/Noto Sans CJK；iOS: PingFang SC）
  static const String? body = null;

  static const String brush = 'MaShanZheng';
  static const String num = 'CormorantGaramond';

  /// 毛笔字兜底：万一系统缺 MaShanZheng 注册（如某些定制 ROM），
  /// 退到系统楷体，仍是同族观感，不会跳成黑体。
  static const List<String> fallbackBrush = <String>[
    'Kaiti SC', 'STKaiti', 'KaiTi', 'serif',
  ];

  /// 数字兜底：衬线拉丁，保持等宽观感即可
  static const List<String> fallbackNum = <String>['serif'];
}

/// 排版工厂：所有文本样式集中产出，页面不写裸 TextStyle。
///
/// **层级只有 7 档**（见 [DfFontSize]），且行高 / 字距按语义成组而非逐处微调，
/// 避免「同类文字大小忽大忽小」。页面里禁止再 `copyWith(fontSize:)`。
class DfType {
  const DfType._();

  static const List<FontFeature> _tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// 标题字距（毛笔字需要一点呼吸）
  static const double _trackTitle = 0.02;

  /// 功能字字距（按钮 / 徽标 / 注脚）
  static const double _trackWide = 0.04;

  /// 统一出口：任何文本都带 [TextDecoration.none]。
  ///
  /// 必须显式声明 —— `MaterialApp` 会把 Flutter 内置的 `_errorTextStyle`
  /// （黄色 + 双下划线 + monospace）注入为整棵树的根级 `DefaultTextStyle`，
  /// 而本 App 的页面是自绘 `DecoratedBox`（没有 `Scaffold` / `Material` 覆盖它），
  /// 于是 `Text` 在 merge 样式时会把那条「黄色双下划线」继承下来。
  /// 见 `flutter/lib/src/material/app.dart` 的 `_errorTextStyle`。
  static TextStyle _base(
    BuildContext context, {
    required double size,
    required double height,
    required Color color,
    String? family,
    List<String>? fallback,
    FontWeight weight = FontWeight.w400,
    double letterSpacingEm = 0,
    List<FontFeature>? features,
  }) {
    return TextStyle(
      fontSize: size,
      height: height,
      color: color,
      fontWeight: weight,
      letterSpacing: letterSpacingEm * size,
      fontFamily: family,
      fontFamilyFallback: fallback,
      fontFeatures: features,
      decoration: TextDecoration.none,
    );
  }

  /// 页面主标题（毛笔）· 26
  static TextStyle title(BuildContext c, Color color) => _base(
        c,
        size: DfFontSize.title,
        height: DfLineHeight.title,
        color: color,
        family: DfFonts.brush,
        fallback: DfFonts.fallbackBrush,
        letterSpacingEm: _trackTitle,
      );

  /// 模块 / 卡片标题（毛笔）· 20
  static TextStyle titleS(BuildContext c, Color color) => _base(
        c,
        size: DfFontSize.titleS,
        height: DfLineHeight.title,
        color: color,
        family: DfFonts.brush,
        fallback: DfFonts.fallbackBrush,
        letterSpacingEm: _trackTitle,
      );

  /// 场景大数字 / 大时刻（毛笔）· 34
  static TextStyle display(BuildContext c, Color color) => _base(
        c,
        size: DfFontSize.display,
        height: DfLineHeight.tight,
        color: color,
        family: DfFonts.brush,
        fallback: DfFonts.fallbackBrush,
        letterSpacingEm: _trackTitle,
      );

  /// 说明 / 副标 · 12
  static TextStyle sub(BuildContext c, Color color) =>
      _base(c, size: DfFontSize.small, height: DfLineHeight.body, color: color);

  /// 正文 · 14
  static TextStyle bodyS(BuildContext c, Color color) =>
      _base(c, size: DfFontSize.bodyS, height: DfLineHeight.body, color: color);

  /// 强调行 / 昵称 / 次按钮 · 16
  static TextStyle body(BuildContext c, Color color) =>
      _base(c, size: DfFontSize.body, height: DfLineHeight.body, color: color);

  /// 洞察卡正文 · 14 / 1.65
  static TextStyle insight(BuildContext c, Color color) =>
      _base(c, size: DfFontSize.bodyS, height: DfLineHeight.insight, color: color);

  /// 气泡 · 14 / 1.6
  static TextStyle bubble(BuildContext c, Color color) =>
      _base(c, size: DfFontSize.bodyS, height: DfLineHeight.bubble, color: color);

  /// 次级按钮字 · 16
  static TextStyle buttonSecondary(BuildContext c, Color color) => _base(
        c,
        size: DfFontSize.body,
        height: 1.0,
        color: color,
        letterSpacingEm: _trackWide,
      );

  /// 主按钮字 · 16
  static TextStyle buttonPrimary(BuildContext c, Color color) => _base(
        c,
        size: DfFontSize.input,
        height: 1.0,
        color: color,
        letterSpacingEm: _trackWide,
      );

  /// 注脚 / 单位 · 11
  static TextStyle caption(BuildContext c, Color color) => _base(
        c,
        size: DfFontSize.caption,
        height: DfLineHeight.caption,
        color: color,
        letterSpacingEm: _trackWide,
      );

  /// 徽标 · 12
  static TextStyle chip(BuildContext c, Color color) => _base(
        c,
        size: DfFontSize.small,
        height: DfLineHeight.tight,
        color: color,
        letterSpacingEm: _trackWide,
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
        bodyLarge: body(c, p.text),
        bodyMedium: bodyS(c, p.text),
        bodySmall: sub(c, p.text2),
        labelLarge: body(c, p.text),
        labelSmall: caption(c, p.text3),
      );
}

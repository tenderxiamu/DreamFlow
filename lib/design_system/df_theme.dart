import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'df_tokens.dart';
import 'df_type.dart';

/// §5 主题机制：`t-night` / `t-paper` 两个作用域 → 两个 ThemeData。
/// 页面归属：首页 / 对话 / 助眠 → [nightTheme]；报告 / 唤醒 → [paperTheme]。
class DfTheme {
  const DfTheme._();

  static ThemeData nightTheme(BuildContext context) => _build(context, DfPalette.night);

  static ThemeData paperTheme(BuildContext context) => _build(context, DfPalette.paper);

  static ThemeData _build(BuildContext context, DfPalette p) {
    final ColorScheme scheme = ColorScheme(
      brightness: p.brightness,
      primary: p.mistBlue,
      onPrimary: p.onMist,
      secondary: p.mistGreen,
      onSecondary: p.onMist,
      tertiary: p.mistPink,
      error: p.mistPink,
      onError: p.onMist,
      surface: p.surface,
      onSurface: p.text,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.canvas,
      canvasColor: p.canvas,
      extensions: <ThemeExtension<dynamic>>[p],
      textTheme: DfType.textTheme(context, p),
      // 组件自带按压反馈，禁用 Material 水波纹以保证「水墨」质感
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dividerColor: p.line,
    );
  }

  /// §5.3 主题切换过渡：仅对 background/color 挂 200ms，不动布局属性。
  static ThemeData animated(BuildContext context, ThemeData theme) =>
      theme.copyWith(
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      );
}

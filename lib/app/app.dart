import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design_system/df_theme.dart';
import 'router.dart';
import 'theme_provider.dart';

/// DreamFlow 梦洄 App 根组件。
/// 主题切换 = 换 ThemeData（DfPalette lerp 插值，§5.2），组件零改动。
class DreamFlowApp extends ConsumerWidget {
  const DreamFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DfAppTheme mode = ref.watch(themeProvider);
    return MaterialApp.router(
      title: '梦洄',
      debugShowCheckedModeBanner: false,
      theme: mode == DfAppTheme.night
          ? DfTheme.nightTheme(context)
          : DfTheme.paperTheme(context),
      routerConfig: ref.watch(routerProvider),
      // 关键修复：`MaterialApp` 会把 `_errorTextStyle`（黄色 + 双下划线 + monospace）
      // 作为整棵树的根级 `DefaultTextStyle`（flutter/src/material/app.dart）。
      // 本 App 的页面是自绘 `DfScreenScaffold`（DecoratedBox），没有 Material 覆盖它，
      // 于是每条 Text 都继承了那条黄双线。这里在根部显式清空装饰。
      builder: (BuildContext context, Widget? child) {
        return DefaultTextStyle(
          style: const TextStyle(decoration: TextDecoration.none),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

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
    );
  }
}

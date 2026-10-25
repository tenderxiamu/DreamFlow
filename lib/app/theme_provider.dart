import 'package:flutter_riverpod/flutter_riverpod.dart';

/// §5 双主题：夜墨（主）/ 宣纸（辅）。
/// M2 骨架先内存持有；M5 报告屏联动「报告=宣纸」时由路由钩子驱动。
enum DfAppTheme { night, paper }

class ThemeController extends Notifier<DfAppTheme> {
  @override
  DfAppTheme build() => DfAppTheme.night;

  void set(DfAppTheme t) => state = t;
  void toggle() => state = state == DfAppTheme.night ? DfAppTheme.paper : DfAppTheme.night;
}

final themeProvider = NotifierProvider<ThemeController, DfAppTheme>(ThemeController.new);

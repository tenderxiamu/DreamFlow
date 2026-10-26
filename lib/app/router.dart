import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/df_llm.dart';
import '../design_system/df_theme.dart';
import '../design_system/widgets/df_states.dart';
import '../screens/df_chat_session.dart';
import '../screens/df_home_screen.dart';
import '../screens/df_report_screen.dart';
import '../screens/df_sleep_flow.dart';
import '../screens/df_state_screen.dart';
import '../screens/df_wake_flow.dart';

/// 全局路由 Key（DfScreenScaffold 自绘界面不走 AppBar）。
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// M4：LLM 客户端（懒创建；请求失败时屏内自动回退规则引擎）
final DfLlmClient dfLlmClient = DfLlmClient();

/// §7 屏幕流转（落地区）：
/// - Tab 三分支（IndexedStack 保状态）：A 首页 / B 对话 / C 助眠
/// - B「就去睡吧」→ /sleep；C 播完 onFinished → /wakeup
/// - 二级页 E 唤醒 / D 报告 / 状态页：root navigator push，统一 t-paper
///   主题归属（§5：B/C=夜墨，E/D=宣纸），由 [_paperPage] 包裹。
/// Tab 切换由屏幕自身 onTab(int) 回调驱动 goBranch。
Widget _paperPage(BuildContext context, Widget child) {
  return Theme(data: DfTheme.paperTheme(context), child: child);
}

StatefulShellRoute buildShellRoute() {
  return StatefulShellRoute.indexedStack(
    builder:
        (BuildContext context, GoRouterState state, StatefulNavigationShell shell) =>
            shell,
    branches: <StatefulShellBranch>[
      StatefulShellBranch(routes: <RouteBase>[
        GoRoute(
          path: '/home',
          builder: (BuildContext context, GoRouterState state) {
            return DfHomeScreen(
              onStartChat: () => context.go('/chat'),
              onTab: (int i) => StatefulNavigationShell.of(context).goBranch(i),
            );
          },
        ),
      ]),
      StatefulShellBranch(routes: <RouteBase>[
        GoRoute(
          path: '/chat',
          builder: (BuildContext context, GoRouterState state) =>
              DfChatSession(
                  onEnterSleep: () => context.go('/sleep'),
                  llm: dfLlmClient),
        ),
      ]),
      StatefulShellBranch(routes: <RouteBase>[
        GoRoute(
          path: '/sleep',
          builder: (BuildContext context, GoRouterState state) =>
              DfSleepFlow(onFinished: () => context.go('/wakeup')),
        ),
      ]),
    ],
  );
}

final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/home',
    routes: <RouteBase>[
      buildShellRoute(),
      GoRoute(
        path: '/wakeup',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) => _paperPage(
          context,
          DfWakeFlow(
            onRetryReport: () => context.go('/report'),
          ),
        ),
      ),
      GoRoute(
        path: '/report',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            _paperPage(context, const DfReportScreen()),
      ),
      GoRoute(
        path: '/states/:kind',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          final DfStateKind kind = DfStateKind.values.firstWhere(
            (DfStateKind k) => k.name == state.pathParameters['kind'],
            orElse: () => DfStateKind.empty,
          );
          return DfStateScreen(kind: kind, onRetry: () => context.go('/home'));
        },
      ),
    ],
  );
});

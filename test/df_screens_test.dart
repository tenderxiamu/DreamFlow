import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dreamflow/design_system/df_theme.dart';
import 'package:dreamflow/design_system/df_tokens.dart';
import 'package:dreamflow/design_system/widgets/df_screen.dart';
import 'package:dreamflow/screens/df_chat_screen.dart';
import 'package:dreamflow/screens/df_home_screen.dart';
import 'package:dreamflow/screens/df_report_screen.dart';
import 'package:dreamflow/screens/df_sleep_screen.dart';
import 'package:dreamflow/screens/df_wake_screen.dart';

/// §11 验收：双主题 × 5 屏 全部可渲染且无异常。
void main() {
  const List<String> names = <String>[
    'A 首页 · 睡前模式',
    'B 情绪对话',
    'C 沉浸助眠',
    'D 睡眠报告',
    'E 渐进式唤醒',
  ];
  const List<Widget Function()> builders = <Widget Function()>[
    DfHomeScreen.new,
    DfChatScreen.new,
    DfSleepScreen.new,
    DfReportScreen.new,
    DfWakeScreen.new,
  ];

  Widget wrap(Widget child, {required bool night}) {
    return Builder(
      builder: (BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: night
            ? DfTheme.nightTheme(context)
            : DfTheme.paperTheme(context),
        home: Scaffold(body: child),
      ),
    );
  }

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 940);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('双主题渲染冒烟', () {
    for (final bool night in <bool>[true, false]) {
      final String themeName = night ? '夜墨 t-night' : '宣纸 t-paper';

      for (int i = 0; i < builders.length; i++) {
        testWidgets('$themeName · ${names[i]}', (WidgetTester tester) async {
          useTallSurface(tester);
          await tester.pumpWidget(wrap(builders[i](), night: night));
          await tester.pump(const Duration(milliseconds: 60));

          expect(tester.takeException(), isNull);
          expect(find.byType(DfScreenScaffold), findsOneWidget);
        });
      }
    }
  });

  testWidgets('主题切换：令牌随 ThemeData 变化，组件零改动', (WidgetTester tester) async {
    useTallSurface(tester);

    await tester.pumpWidget(wrap(const DfHomeScreen(), night: true));
    // MaterialApp 内置 AnimatedTheme（默认 200ms）。这里不能用 pumpAndSettle：
    // DfSheep 的漂浮动效是无限循环（repeat），永远 settle 不下来。
    // 因此显式推过过渡时长 + 一个额外帧。
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    BuildContext ctx = tester.element(find.byType(DfScreenScaffold));
    expect(DfPalette.of(ctx).canvas, const Color(0xFF14161A));
    expect(Theme.of(ctx).scaffoldBackgroundColor, const Color(0xFF14161A));

    await tester.pumpWidget(wrap(const DfHomeScreen(), night: false));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    ctx = tester.element(find.byType(DfScreenScaffold));
    expect(DfPalette.of(ctx).canvas, const Color(0xFFF4F2EC));
    expect(Theme.of(ctx).scaffoldBackgroundColor, const Color(0xFFF4F2EC));

    expect(tester.takeException(), isNull);
  });

  testWidgets('对话屏免责注脚必须存在（§11）', (WidgetTester tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrap(const DfChatScreen(), night: true));
    await tester.pump(const Duration(milliseconds: 60));

    expect(find.textContaining('不构成医疗建议'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dreamflow/data/df_account.dart';
import 'package:dreamflow/design_system/df_theme.dart';
import 'package:dreamflow/screens/df_account_gate.dart';
import 'package:dreamflow/screens/df_home_screen.dart';

/// M7：登录闸门 + 首页招呼语。
///
/// 闸门是自绘的（挂在 Navigator 之上），所以测试里直接把它当普通 widget 拼。
void main() {
  final DfAccount acc = DfAccount.instance;

  Widget wrap(Widget child) {
    return Builder(
      builder: (BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: DfTheme.nightTheme(context),
        home: Scaffold(body: child),
      ),
    );
  }

  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 940);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  setUp(() async {
    // 测试环境没有 path_provider，关掉落盘只验状态机
    DfAccount.persistenceEnabled = false;
    // 读一次，让 ready = true（测试环境没有 path_provider，内部会静默降级）
    await acc.load();
    acc.resetForTest();
  });

  testWidgets('未登录：登录弹窗盖在页面之上，且不能被点掉', (WidgetTester tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(wrap(
      const DfAccountGate(child: Text('底下的首页')),
    ));
    await tester.pump();

    expect(find.text('欢迎来到梦洄'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
    // 底下的页面仍然在树里（遮罩不是白屏）
    expect(find.text('底下的首页'), findsOneWidget);

    // 点遮罩空白处不应该关掉弹窗
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    expect(find.text('欢迎来到梦洄'), findsOneWidget);
  });

  testWidgets('填写用户名后弹窗消失，回到真实页面', (WidgetTester tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(wrap(
      const DfAccountGate(child: Text('底下的首页')),
    ));
    await tester.pump();

    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '林小满');
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(find.text('欢迎来到梦洄'), findsNothing);
    expect(find.text('底下的首页'), findsOneWidget);
    expect(acc.signedIn, isTrue);
    expect(acc.username, '林小满');
  });

  testWidgets('退出后重进：标题念出用户名，一步就回到页面', (WidgetTester tester) async {
    // 造出「用过一段时间后退出登录」的真实状态
    await acc.signIn('林小满');
    await acc.signOut();
    usePhoneSurface(tester);

    await tester.pumpWidget(wrap(
      const DfAccountGate(child: Text('底下的首页')),
    ));
    await tester.pump();

    expect(find.text('欢迎回来，林小满'), findsOneWidget);
    expect(find.text('欢迎来到梦洄'), findsNothing);

    // 「继续」就该是继续 —— 不该再让人确认一遍自己叫什么
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('底下的首页'), findsOneWidget);
    expect(acc.signedIn, isTrue);
    expect(acc.username, '林小满');
  });

  testWidgets('首页招呼语带上用户名，不再是写死的刘同学', (WidgetTester tester) async {
    await acc.signIn('林小满');
    usePhoneSurface(tester);

    await tester.pumpWidget(wrap(const DfHomeScreen()));
    await tester.pump(const Duration(milliseconds: 60));

    expect(find.textContaining('林小满'), findsOneWidget);
    expect(find.textContaining('刘同学'), findsNothing);
  });
}

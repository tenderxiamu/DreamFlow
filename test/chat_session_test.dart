import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dreamflow/design_system/df_theme.dart';
import 'package:dreamflow/design_system/widgets/df_controls.dart';
import 'package:dreamflow/screens/df_chat_session.dart';

/// 对话屏的两条产品红线：
/// 1. 危机信号出现时，求助电话必须在屏幕上、且不能再劝人去睡
/// 2. 「发送」按钮必须名实相符（旧版是麦克风图标 + 语义「按住说话」，
///    实际行为却是点一下发文本 —— 屏幕阅读器用户会去长按）
///
/// 用 `seed` 注入而不是打字：seed 分支不碰本地库（drift + path_provider
/// 在测试环境里会一直等下去），而 [DfChatSession] 的 seed 分支和真实链路
/// 走同一套 `_sentOnce` / `_crisis` 推导。
void main() {
  Widget wrap(Widget child) => Builder(
        builder: (BuildContext context) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: DfTheme.nightTheme(context),
          home: Scaffold(body: child),
        ),
      );

  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 940);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('危机干预', () {
    testWidgets('出现求助热线，且不再给「就去睡吧」出口', (WidgetTester tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(wrap(DfChatSession(
        seed: const <DfMessage>[
          DfMessage('我不想活了', mine: true),
          DfMessage('我听着，你继续说。'),
        ],
        onEnterSleep: () {},
      )));
      await tester.pump(const Duration(milliseconds: 60));

      expect(tester.takeException(), isNull);
      // 号码本身必须可见 —— 慌张的人只读得进数字
      expect(find.text('12356'), findsOneWidget);
      expect(find.textContaining('全国心理援助热线'), findsOneWidget);
      // 这种时候把人往床上送、然后说晚安，是最不该做的事
      expect(find.text('就去睡吧'), findsNothing);
    });

    testWidgets('普通情绪不报警，出口照常出现', (WidgetTester tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(wrap(DfChatSession(
        seed: const <DfMessage>[
          DfMessage('我今天好累', mine: true),
          DfMessage('身体已经在替你踩刹车了。'),
        ],
        onEnterSleep: () {},
      )));
      await tester.pump(const Duration(milliseconds: 60));

      expect(find.text('12356'), findsNothing);
      expect(find.text('就去睡吧'), findsOneWidget);
    });
  });

  testWidgets('发送按钮：语义是「发送」，不是「按住说话」', (WidgetTester tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(wrap(const DfChatSession(seed: <DfMessage>[
      DfMessage('昨晚没睡好', mine: true),
    ])));
    await tester.pump(const Duration(milliseconds: 60));

    final Finder sendBtn = find.byWidgetPredicate(
      (Widget w) => w is DfIconButton && w.semanticLabel == '发送',
    );
    expect(sendBtn, findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (Widget w) => w is DfIconButton && w.semanticLabel == '按住说话',
      ),
      findsNothing,
    );
  });
}

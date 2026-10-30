import 'dart:async';

import 'package:flutter/material.dart';

import 'package:dreamflow/data/df_account.dart';
import 'package:dreamflow/data/df_greeting.dart';
import 'package:dreamflow/design_system/df_tokens.dart';
import 'package:dreamflow/design_system/df_type.dart';
import 'package:dreamflow/design_system/widgets/df_controls.dart';
import 'package:dreamflow/design_system/widgets/df_data.dart';
import 'package:dreamflow/design_system/widgets/df_icons.dart';
import 'package:dreamflow/design_system/widgets/df_hero_poster.dart';
import 'package:dreamflow/design_system/widgets/df_screen.dart';
import 'package:dreamflow/design_system/widgets/df_surfaces.dart';

/// §7 A 首页 · 睡前模式（t-night）
/// 一屏一事：只服务「开始睡前对话」。
///
/// M7：招呼语不再写死。按当前时段取「早上好 / 下午好 / 晚上好…」，
/// 拼上 [DfAccount] 里的用户名；名字改了、退出登录了都会立刻跟着变。
class DfHomeScreen extends StatefulWidget {
  const DfHomeScreen({super.key, this.onStartChat, this.onTab});

  final VoidCallback? onStartChat;
  final ValueChanged<int>? onTab;

  @override
  State<DfHomeScreen> createState() => _DfHomeScreenState();
}

class _DfHomeScreenState extends State<DfHomeScreen> {
  /// 每分钟对一次表：跨到下一个时段时招呼语要自己换，不能等用户切页
  late final Timer _tick;
  DfDayPart _part = dfDayPart(DateTime.now());

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      final DfDayPart now = dfDayPart(DateTime.now());
      if (now != _part && mounted) setState(() => _part = now);
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);

    return ListenableBuilder(
      listenable: DfAccount.instance,
      builder: (BuildContext context, Widget? _) {
        final String? name = DfAccount.instance.username;
        return DfScreenScaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                dfGreetingLine(name, DateTime.now()),
                style: DfType.title(context, p.text),
              ),
              const SizedBox(height: 6),
              Text(dfGreetingSub(_part), style: DfType.sub(context, p.text2)),
              const SizedBox(height: 18),
              const DfHeroPoster(),
              const SizedBox(height: 16),
              DfCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Text('今日情绪', style: DfType.bodyS(context, p.text)),
                        Text.rich(
                          TextSpan(
                            children: <InlineSpan>[
                              TextSpan(
                                text: '62',
                                style: DfType.number(
                                  context,
                                  DfFontSize.titleS,
                                  p.text,
                                ),
                              ),
                              TextSpan(
                                text: '%',
                                style: DfType.caption(context, p.text2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 11),
                    const DfBarLine(value: 0.62),
                    const SizedBox(height: 10),
                    Text(
                      '平静偏多 · 睡前有一点心事的余温',
                      // §3 注：`--text-3` 禁止放入卡片面（夜墨下 4.06:1），卡内弱信息用 `--text-2`
                      style: DfType.caption(context, p.text2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomFullBleed: true,
          bottom: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(DfSpace.padX, 26, DfSpace.padX, 0),
                child: DfHeroButton(
                  label: '开始睡前对话',
                  sheepHeight: 56,
                  onPressed: widget.onStartChat,
                ),
              ),
              const SizedBox(height: 26),
              DfTabs(
                currentIndex: 0,
                onTap: widget.onTab,
                items: const <DfTabItem>[
                  DfTabItem(DfGlyph.home, '首页'),
                  DfTabItem(DfGlyph.chat, '对话'),
                  DfTabItem(DfGlyph.moon, '助眠'),
                  DfTabItem(DfGlyph.profile, '我的'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

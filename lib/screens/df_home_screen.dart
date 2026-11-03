import 'dart:async';

import 'package:flutter/material.dart';

import 'package:dreamflow/data/db.dart';
import 'package:dreamflow/data/df_account.dart';
import 'package:dreamflow/data/df_greeting.dart';
import 'package:dreamflow/data/df_mood_summary.dart';
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

class _DfHomeScreenState extends State<DfHomeScreen>
    with WidgetsBindingObserver {
  /// 每分钟对一次表：跨到下一个时段时招呼语要自己换，不能等用户切页
  late final Timer _tick;
  DfDayPart _part = dfDayPart(DateTime.now());

  /// 今日情绪（M10）。null = 还没读到（首帧占位，不先塞一个假数字）
  DfMoodSummary? _mood;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 对话落库后广播过来 —— 首页在 IndexedStack 里不会因切 Tab 重建
    DfMoodToday.instance.addListener(_loadMood);
    _loadMood();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      final DfDayPart now = dfDayPart(DateTime.now());
      if (now != _part && mounted) setState(() => _part = now);
      // 跨零点时「今日情绪」要归零重来
      _loadMood();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DfMoodToday.instance.removeListener(_loadMood);
    _tick.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 从后台回来（可能刚在别的设备/界面聊过）重读一次
    if (state == AppLifecycleState.resumed) _loadMood();
  }

  /// 读当天记录并折算。失败保持原值 —— 卡片不该因为一次查询失败而闪空。
  Future<void> _loadMood() async {
    try {
      final List<MoodRecord> rows = await DreamFlowDb.instance.todayMoods();
      final DfMoodSummary next = DfMoodSummary.fromEntries(<DfMoodEntry>[
        for (final MoodRecord m in rows)
          DfMoodEntry(
            label: m.moodLabel,
            intensity: m.intensity,
            createdAt: m.createdAt,
          ),
      ]);
      if (!mounted) return;
      if (_mood?.score != next.score ||
          _mood?.caption != next.caption ||
          _mood?.count != next.count) {
        setState(() => _mood = next);
      }
    } catch (_) {
      // 数据库没起来（首帧窗口期）或读失败：保持现状
    }
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
                                // 无记录时显示破折号：宁可承认「没有」，
                                // 也不给一个看起来像真数据的数字
                                text: _mood?.score?.toString() ?? '—',
                                style: DfType.number(
                                  context,
                                  DfFontSize.titleS,
                                  p.text,
                                ),
                              ),
                              if (_mood?.score != null)
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
                    DfBarLine(value: _mood?.ratio ?? 0),
                    const SizedBox(height: 10),
                    Text(
                      _mood?.caption ?? '正在读今天的记录…',
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

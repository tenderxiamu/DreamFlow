import 'package:flutter/material.dart';

import 'package:dreamflow/design_system/df_tokens.dart';
import 'package:dreamflow/design_system/df_type.dart';
import 'package:dreamflow/design_system/widgets/df_controls.dart';
import 'package:dreamflow/design_system/widgets/df_data.dart';
import 'package:dreamflow/design_system/widgets/df_icons.dart';
import 'package:dreamflow/design_system/widgets/df_scene.dart';
import 'package:dreamflow/design_system/widgets/df_screen.dart';
import 'package:dreamflow/design_system/widgets/df_surfaces.dart';

/// §7 A 首页 · 睡前模式（t-night）
/// 一屏一事：只服务「开始睡前对话」。
class DfHomeScreen extends StatelessWidget {
  const DfHomeScreen({super.key, this.onStartChat, this.onTab});

  final VoidCallback? onStartChat;
  final ValueChanged<int>? onTab;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);

    return DfScreenScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('晚安，刘同学', style: DfType.title(context, p.text)),
          const SizedBox(height: 6),
          Text('让梦洄陪你，慢慢沉入夜里', style: DfType.sub(context, p.text2)),
          const SizedBox(height: 18),
          const DfScene(height: 214),
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
              onPressed: onStartChat,
            ),
          ),
          const SizedBox(height: 26),
          DfTabs(
            currentIndex: 0,
            onTap: onTab,
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
  }
}

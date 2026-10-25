import 'package:flutter/material.dart';

import 'package:dreamflow/design_system/df_tokens.dart';
import 'package:dreamflow/design_system/df_type.dart';
import 'package:dreamflow/design_system/widgets/df_controls.dart';
import 'package:dreamflow/design_system/widgets/df_data.dart';
import 'package:dreamflow/design_system/widgets/df_scene.dart';
import 'package:dreamflow/design_system/widgets/df_screen.dart';
import 'package:dreamflow/design_system/widgets/df_surfaces.dart';

/// §7 E 渐进式唤醒（t-paper）
class DfWakeScreen extends StatelessWidget {
  const DfWakeScreen({
    super.key,
    this.onWakeUp,
    this.onSnooze,
    this.wakeTime = '06:42',
  });

  final VoidCallback? onWakeUp;
  final VoidCallback? onSnooze;
  final String wakeTime;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);

    return DfScreenScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 2),
          DfScene(
            height: 196,
            variant: DfSceneVariant.sunrise,
            overlay: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  wakeTime,
                  style: DfType.title(context, p.text).copyWith(
                    fontSize: DfFontSize.display,
                    letterSpacing: DfFontSize.display * 0.04,
                  ),
                ),
                const SizedBox(height: 8),
                Text('室温 24° · 湿度 52%', style: DfType.sub(context, p.text2)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DfCard(
            borderColor: p.mistGreen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Text('处于浅睡窗口', style: DfType.bodyS(context, p.text)),
                    Text('74%', style: DfType.caption(context, p.mistGreen)),
                  ],
                ),
                const SizedBox(height: 11),
                const DfBarLine(value: 0.74, success: true),
                const SizedBox(height: 10),
                Text(
                  '此刻醒来最不费力，起身后不易头晕',
                  // §3 注：卡内弱信息用 `--text-2`（`--text-3` 夜墨下对卡片仅 4.06:1）
                  style: DfType.caption(context, p.text2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          DfCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('陪伴时长', style: DfType.bodyS(context, p.text2)),
                Text(
                  '7:58',
                  style: DfType.number(context, DfFontSize.titleS, p.text),
                ),
              ],
            ),
          ),
        ],
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DfHeroButton(
            label: '我醒了',
            sheepHeight: 48,
            onPressed: onWakeUp,
          ),
          const SizedBox(height: 11),
          DfGhostButton(label: '再睡 5 分钟', onPressed: onSnooze),
        ],
      ),
    );
  }
}

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
    this.wakeTime = '',
    this.companionLabel,
  });

  final VoidCallback? onWakeUp;
  final VoidCallback? onSnooze;

  /// 唤醒时刻（HH:mm）；留空 → 取系统当前时刻（不写死假时间）
  final String wakeTime;

  /// 陪伴时长（如「7:58」）；null = 无进行中会话，整卡不显示
  final String? companionLabel;

  static String _nowHm() {
    final DateTime n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:'
        '${n.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    final String clock = wakeTime.isEmpty ? _nowHm() : wakeTime;

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
                Text(clock, style: DfType.display(context, p.text)),
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
          // 只有真的存在进行中会话时才显示陪伴时长，否则宁可不显示也不编数字
          if (companionLabel != null)
            DfCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('陪伴时长', style: DfType.bodyS(context, p.text2)),
                  Text(
                    companionLabel!,
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

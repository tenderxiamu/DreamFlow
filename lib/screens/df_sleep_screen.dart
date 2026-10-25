import 'package:flutter/material.dart';

import 'package:dreamflow/design_system/df_tokens.dart';
import 'package:dreamflow/design_system/df_type.dart';
import 'package:dreamflow/design_system/widgets/df_controls.dart';
import 'package:dreamflow/design_system/widgets/df_data.dart';
import 'package:dreamflow/design_system/widgets/df_icons.dart';
import 'package:dreamflow/design_system/widgets/df_scene.dart';
import 'package:dreamflow/design_system/widgets/df_screen.dart';
import 'package:dreamflow/design_system/widgets/df_surfaces.dart';

/// §7 C 沉浸助眠（t-night）
class DfSleepScreen extends StatelessWidget {
  const DfSleepScreen({
    super.key,
    this.soundscapeName = '深海洄游',
    this.onPlayToggle,
    this.onPrev,
    this.onNext,
  });

  final String soundscapeName;
  final VoidCallback? onPlayToggle;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);

    return DfScreenScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      soundscapeName,
                      style: DfType.titleS(context, p.text),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '千人千面 · 依你的情绪生成',
                      style: DfType.sub(context, p.text2),
                    ),
                  ],
                ),
              ),
              Text('23:07', style: DfType.caption(context, p.text3)),
            ],
          ),
          const SizedBox(height: 16),
          const DfScene(height: 250),
          const SizedBox(height: 16),
          DfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '音景层次 · 低频潮汐 × 远海雨声',
                  style: DfType.bodyS(context, p.text2),
                ),
                const SizedBox(height: 12),
                const DfWave(),
              ],
            ),
          ),
        ],
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const DfTimeline(progress: 0.38),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                '09:12',
                style: DfType.caption(context, p.text2).copyWith(
                  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '24:00',
                style: DfType.caption(context, p.text2).copyWith(
                  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              DfGhostButton(
                round: true,
                glyph: DfGlyph.prev,
                onPressed: onPrev,
              ),
              const SizedBox(width: 26),
              DfIconButton(
                glyph: DfGlyph.play,
                semanticLabel: '播放 / 暂停',
                size: DfTouch.play,
                onPressed: onPlayToggle,
              ),
              const SizedBox(width: 26),
              DfGhostButton(
                round: true,
                glyph: DfGlyph.next,
                onPressed: onNext,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '播放结束后将进入渐进式唤醒',
            textAlign: TextAlign.center,
            style: DfType.caption(context, p.text3),
          ),
        ],
      ),
    );
  }
}

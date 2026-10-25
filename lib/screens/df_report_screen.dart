import 'package:flutter/material.dart';

import 'package:dreamflow/design_system/df_tokens.dart';
import 'package:dreamflow/design_system/df_type.dart';
import 'package:dreamflow/design_system/widgets/df_data.dart';
import 'package:dreamflow/design_system/widgets/df_sheep.dart';
import 'package:dreamflow/design_system/widgets/df_screen.dart';
import 'package:dreamflow/design_system/widgets/df_states.dart';
import 'package:dreamflow/design_system/widgets/df_surfaces.dart';

/// §7 D 睡眠分析报告（t-paper）· 无 Tab，二级页
///
/// [state] 非 `null` 时整屏切到对应状态视图（§12 缺口 4）：
/// 报告依赖昨夜数据，是**最需要**空 / 加载 / 异常三态的页面。
class DfReportScreen extends StatelessWidget {
  const DfReportScreen({super.key, this.state, this.onRetry});

  /// `null` = 数据就绪，渲染正文
  final DfStateKind? state;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);

    return DfScreenScaffold(
      centerBody: state != null,
      body: DfStateSwitch(
        kind: state,
        onRetry: onRetry,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('昨夜 · 10月10日', style: DfType.title(context, p.text)),
          const SizedBox(height: 6),
          Text(
            '入睡平稳，深睡充足，凌晨有一次短暂觉醒',
            style: DfType.sub(context, p.text2),
          ),
          const SizedBox(height: 22),
          const Center(child: DfRing(score: 82)),
          const SizedBox(height: 20),
          DfMetricGrid(
            children: const <Widget>[
              DfMetric(label: '入睡用时', value: '21', unit: '分'),
              DfMetric(label: '深睡', value: '1:52', unit: '时'),
              DfMetric(label: '夜间醒来', value: '1', unit: '次'),
              DfMetric(label: '平均心率', value: '58', unit: 'bpm'),
            ],
          ),
          const SizedBox(height: 12),
          DfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Text(
                      '近 7 天 情绪 × 睡眠',
                      style: DfType.bodyS(context, p.text),
                    ),
                    // §3 注：卡内弱信息用 `--text-2`（`--text-3` 夜墨下对卡片仅 4.06:1）
                    Text('关联度 0.78', style: DfType.caption(context, p.text2)),
                  ],
                ),
                const SizedBox(height: 4),
                DfBrow(label: '周一', value: 42, max: 100, color: p.mistPink),
                DfBrow(label: '周三', value: 78, max: 100, color: p.mistBlue),
                DfBrow(label: '周五', value: 64, max: 100, color: p.mistGreen),
              ],
            ),
          ),
          const SizedBox(height: 10),
          DfInsight(
            leading: const DfSheep(height: 34, animate: false),
            child: const DfInsightText(<String>[
              '梦见',
              '「赶不上的列车」',
              '，多与白天的',
              '时间压力',
              '有关。昨夜你比前一周早入睡 18 分钟，身体正在慢慢调回来。',
            ]),
          ),
          const SizedBox(height: 20),
        ],
      ),
      ),
    );
  }
}

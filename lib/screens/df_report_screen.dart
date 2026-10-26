import 'package:flutter/material.dart';

import 'package:dreamflow/design_system/df_tokens.dart';
import 'package:dreamflow/design_system/df_type.dart';
import 'package:dreamflow/design_system/widgets/df_data.dart';
import 'package:dreamflow/design_system/widgets/df_sheep.dart';
import 'package:dreamflow/design_system/widgets/df_screen.dart';
import 'package:dreamflow/design_system/widgets/df_states.dart';
import 'package:dreamflow/design_system/widgets/df_surfaces.dart';

/// M5：报告数据快照（由本地 Drift 聚合而来；UI 不直接依赖 db 类型，便于测试）。
class DfReportData {
  const DfReportData({
    required this.dateLabel,
    required this.score,
    required this.summary,
    required this.deepLabel,
    required this.awakenings,
    required this.durationLabel,
    required this.moodCount,
    required this.moodBars,
  });

  /// 标题日期，如「昨夜 · 10月26日」
  final String dateLabel;
  final int score;
  final String summary;

  /// 深睡时长标签，如「1:52」+ 单位「时」
  final String deepLabel;
  final int awakenings;
  final String durationLabel;
  final int moodCount;

  /// 近 7 天情绪条（label + 0-100 值）
  final List<({String label, int value})> moodBars;
}

/// 报告数据加载器：注入则走本地聚合，null = 静态演示稿（测试 / 画廊用）
typedef DfReportLoader = Future<DfReportData?> Function();

/// §7 D 睡眠分析报告（t-paper）· 无 Tab，二级页
///
/// [loader] 注入时整屏数据驱动（M5）：加载/空/异常三态 + 真实聚合正文；
/// 未注入时渲染静态演示数据（设计稿验收 / 冒烟测试用）。
/// [state] 直接指定三态时优先于 loader（唤醒流程的 loading 过渡仍可用）。
class DfReportScreen extends StatefulWidget {
  const DfReportScreen({super.key, this.state, this.onRetry, this.loader});

  /// `null` = 数据就绪，渲染正文
  final DfStateKind? state;
  final VoidCallback? onRetry;

  /// M5：本地聚合数据加载器
  final DfReportLoader? loader;

  @override
  State<DfReportScreen> createState() => _DfReportScreenState();
}

class _DfReportScreenState extends State<DfReportScreen> {
  int _attempt = 0;

  void _retry() {
    setState(() => _attempt += 1);
    widget.onRetry?.call();
  }

  @override
  Widget build(BuildContext context) {
    final DfStateKind? state = widget.state;
    final DfReportLoader? loader = widget.loader;

    if (state == null && loader == null) {
      return DfScreenScaffold(
        centerBody: false,
        body: _ReportBody(
          data: _demoData(context),
          moodBarsDemo: _demoMoodBars,
        ),
      );
    }

    return DfScreenScaffold(
      centerBody: state != null,
      body: state != null
          ? DfStateSwitch(
              kind: state,
              onRetry: _retry,
              child: const SizedBox.shrink(),
            )
          : FutureBuilder<DfReportData?>(
              key: ValueKey<int>(_attempt),
              future: loader!(),
              builder: (BuildContext context, AsyncSnapshot<DfReportData?> snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return DfStateSwitch(
                    kind: DfStateKind.loading,
                    child: const SizedBox.shrink(),
                  );
                }
                if (snap.hasError) {
                  return DfStateSwitch(
                    kind: DfStateKind.error,
                    onRetry: _retry,
                    child: const SizedBox.shrink(),
                  );
                }
                final DfReportData? data = snap.data;
                if (data == null) {
                  return DfStateSwitch(
                    kind: DfStateKind.empty,
                    child: const SizedBox.shrink(),
                  );
                }
                return _ReportBody(
                  data: data,
                  moodBarsDemo: const <({String label, int value})>[],
                );
              },
            ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.data, required this.moodBarsDemo});

  final DfReportData data;
  final List<({String label, int value})> moodBarsDemo;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    final List<({String label, int value})> bars = data.moodBars.isNotEmpty
        ? data.moodBars
        : moodBarsDemo;

    return SingleChildScrollView(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(data.dateLabel, style: DfType.title(context, p.text)),
        const SizedBox(height: 6),
        Text(data.summary, style: DfType.sub(context, p.text2)),
        const SizedBox(height: 22),
        Center(child: DfRing(score: data.score)),
        const SizedBox(height: 20),
        DfMetricGrid(
          children: <Widget>[
            DfMetric(label: '睡眠时长', value: data.durationLabel, unit: '时'),
            DfMetric(label: '深睡', value: data.deepLabel, unit: '时'),
            DfMetric(label: '夜间醒来', value: '${data.awakenings}', unit: '次'),
            DfMetric(label: '情绪记录', value: '${data.moodCount}', unit: '条'),
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
                  Text(
                    bars.isEmpty ? '暂无记录' : '共 ${bars.length} 天',
                    style: DfType.caption(context, p.text2),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              for (int i = 0; i < bars.length; i++)
                DfBrow(
                  label: bars[i].label,
                  value: bars[i].value.toDouble(),
                  max: 100,
                  color: i.isOdd ? p.mistBlue : p.mistGreen,
                ),
              if (bars.isEmpty)
                Text(
                  '和梦洄聊聊天，情绪会化作这里的小花',
                  style: DfType.caption(context, p.text2),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        DfInsight(
          leading: const DfSheep(height: 34, animate: false),
          child: DfInsightText(<String>[
            '梦洄',
            '「${data.summary}」',
            '。睡眠分由入睡时刻与唤醒次数本地估算，仅供参考，不是医疗指标。',
          ]),
        ),
        const SizedBox(height: 20),
      ],
      ),
    );
  }
}

// ---- 演示数据（设计稿 §7-D 的静态稿内容） ----

const List<({String label, int value})> _demoMoodBars = <({String label, int value})>[
  (label: '周一', value: 42),
  (label: '周三', value: 78),
  (label: '周五', value: 64),
];

DfReportData _demoData(BuildContext context) {
  return DfReportData(
    dateLabel: '昨夜 · 10月10日',
    score: 82,
    summary: '入睡平稳，深睡充足，凌晨有一次短暂觉醒',
    deepLabel: '1:52',
    awakenings: 1,
    durationLabel: '7.6',
    moodCount: 5,
    moodBars: _demoMoodBars,
  );
}

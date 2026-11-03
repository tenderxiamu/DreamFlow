import 'package:flutter/material.dart';

import 'package:dreamflow/data/sleep_analysis.dart';
import 'package:dreamflow/design_system/df_tokens.dart';
import 'package:dreamflow/design_system/df_type.dart';
import 'package:dreamflow/design_system/widgets/df_data.dart';
import 'package:dreamflow/design_system/widgets/df_sheep.dart';
import 'package:dreamflow/design_system/widgets/df_screen.dart';
import 'package:dreamflow/design_system/widgets/df_states.dart';
import 'package:dreamflow/design_system/widgets/df_surfaces.dart';

/// M5 / M11：报告数据快照（由本地 Drift 聚合而来；UI 不直接依赖 db 类型，便于测试）。
class DfReportData {
  const DfReportData({
    required this.dateLabel,
    required this.score,
    required this.summary,
    required this.durationLabel,
    required this.awakenings,
    required this.moodCount,
    required this.moodBars,
    this.cycles = 0,
    this.bedLabel = '--:--',
    this.wakeLabel = '--:--',
    this.bedSpreadMinutes = 0,
    this.breakdown = const <DfScorePart>[],
    this.trend = const <DfNightPoint>[],
    this.insights = const <String>[],
    this.avgHoursLabel = '',
    this.avgScore = 0,
    this.scoreDelta,
    this.streak = 0,
    this.nightCount = 0,
  });

  /// 标题日期，如「昨夜 · 10月26日」
  final String dateLabel;
  final int score;
  final String summary;

  final String durationLabel;

  /// 完整睡眠周期数（90 分钟一个，由时长推算）
  final int cycles;

  final int awakenings;
  final int moodCount;

  /// 近 7 天情绪条（label + 0-100 值）
  final List<({String label, int value})> moodBars;

  /// 入睡 / 醒来时刻（实测）
  final String bedLabel;
  final String wakeLabel;

  /// 入睡时刻波动（分钟）；0 = 样本不足
  final int bedSpreadMinutes;

  /// 评分构成
  final List<DfScorePart> breakdown;

  /// 近 7 晚趋势
  final List<DfNightPoint> trend;

  /// 洞察句（最多 3 条）
  final List<String> insights;

  /// 近 7 晚平均时长 / 平均分
  final String avgHoursLabel;
  final int avgScore;

  /// 周环比（正 = 变好）；null = 上期样本不足
  final int? scoreDelta;

  /// 连续记录天数
  final int streak;

  /// 参与统计的夜晚数
  final int nightCount;
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
          if (data.scoreDelta != null) ...<Widget>[
            const SizedBox(height: 10),
            Center(child: _DeltaChip(delta: data.scoreDelta!)),
          ],
          const SizedBox(height: 20),
          DfMetricGrid(
            children: <Widget>[
              DfMetric(label: '睡眠时长', value: data.durationLabel, unit: '时'),
              // 无传感器时不编造「深睡分钟数」，只给能从时长诚实推算的周期数
              DfMetric(label: '睡眠周期', value: '${data.cycles}', unit: '个'),
              DfMetric(label: '夜间醒来', value: '${data.awakenings}', unit: '次'),
              DfMetric(label: '情绪记录', value: '${data.moodCount}', unit: '条'),
            ],
          ),
          if (data.trend.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            _TrendCard(data: data),
          ],
          if (data.breakdown.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            _BreakdownCard(data: data),
          ],
          const SizedBox(height: 10),
          _RoutineCard(data: data),
          const SizedBox(height: 10),
          _MoodCard(bars: bars),
          if (data.insights.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            _InsightCard(insights: data.insights),
          ],
          const SizedBox(height: 12),
          Text(
            '睡眠分由时长与夜醒次数本地估算，不是医疗指标。',
            style: DfType.caption(context, p.text2),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 周环比
// ─────────────────────────────────────────────────────────────────────────────
class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.delta});

  final int delta;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    final bool up = delta >= 0;
    final String text = up ? '比上一周高 $delta 分' : '比上一周低 ${-delta} 分';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (up ? p.mistGreen : p.mistPink).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(DfRadius.pill),
      ),
      child: Text(
        text,
        style: DfType.caption(context, up ? p.mistGreen : p.mistPink),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 近 7 晚趋势
// ─────────────────────────────────────────────────────────────────────────────
class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.data});

  final DfReportData data;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    final int recorded = data.trend.where((DfNightPoint e) => e.hasData).length;

    return DfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text('近 7 晚', style: DfType.bodyS(context, p.text)),
              Text(
                recorded == 0
                    ? '暂无记录'
                    : '平均 ${data.avgScore} 分 · $recorded 晚',
                style: DfType.caption(context, p.text2),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _NightTrend(points: data.trend),
        ],
      ),
    );
  }
}

class _NightTrend extends StatelessWidget {
  const _NightTrend({required this.points});

  final List<DfNightPoint> points;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    return SizedBox(
      height: 108,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (int i = 0; i < points.length; i++)
            Expanded(
              child: _TrendBar(
                point: points[i],
                latest: i == points.length - 1,
                track: p.track,
                color: p.mistBlue,
              ),
            ),
        ],
      ),
    );
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({
    required this.point,
    required this.latest,
    required this.track,
    required this.color,
  });

  final DfNightPoint point;
  final bool latest;
  final Color track;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    final int? score = point.score;
    // 高度映射：0 分也留 6px 底座，避免柱子消失后看不出「有这天」
    final double h = score == null ? 6 : 8 + (score / 100) * 52;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Text(
          score == null ? '' : '$score',
          style: DfType.number(
            context,
            DfFontSize.small,
            latest ? p.text : p.text2,
            weight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          width: 14,
          height: h,
          decoration: BoxDecoration(
            color: score == null
                ? track
                : (latest ? color : color.withValues(alpha: 0.45)),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          point.label,
          // §3 注：`--text-3` 禁止放入卡片面（夜墨下 4.06:1），卡内弱信息一律 `--text-2`
          style: DfType.caption(context, p.text2),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 评分构成
// ─────────────────────────────────────────────────────────────────────────────
class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.data});

  final DfReportData data;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    return DfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text('这个分怎么来的', style: DfType.bodyS(context, p.text)),
              Text('共 ${data.score} 分', style: DfType.caption(context, p.text2)),
            ],
          ),
          const SizedBox(height: 12),
          for (final DfScorePart part in data.breakdown)
            _PartRow(part: part),
          const SizedBox(height: 8),
          Text(
            '时长 8 小时封顶 70 分，基础 30 分，每醒来一次 −6 分。',
            style: DfType.caption(context, p.text2),
          ),
        ],
      ),
    );
  }
}

class _PartRow extends StatelessWidget {
  const _PartRow({required this.part});

  final DfScorePart part;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    final Color fill = part.negative ? p.mistPink : p.mistGreen;
    final String value =
        part.negative ? '−${part.value}' : '${part.value}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 64,
            child: Text(part.label, style: DfType.caption(context, p.text2)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(DfRadius.pill),
              child: SizedBox(
                height: 8,
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints c) {
                    final double ratio =
                        (part.value / part.max).clamp(0.0, 1.0);
                    return Stack(
                      children: <Widget>[
                        Positioned.fill(child: ColoredBox(color: p.track)),
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: c.maxWidth * ratio,
                          child: ColoredBox(color: fill),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 34,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: DfType.number(
                context,
                DfFontSize.small,
                part.negative ? p.mistPink : p.text2,
                weight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 作息
// ─────────────────────────────────────────────────────────────────────────────
class _RoutineCard extends StatelessWidget {
  const _RoutineCard({required this.data});

  final DfReportData data;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    final bool steady =
        data.bedSpreadMinutes > 0 && data.bedSpreadMinutes <= kBedtimeDriftMinutes;

    return DfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text('作息', style: DfType.bodyS(context, p.text)),
              Text(
                data.streak > 1 ? '连续记录 ${data.streak} 天' : '第 1 天',
                style: DfType.caption(context, p.text2),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(child: _TimeCell(label: '入睡', value: data.bedLabel)),
              Expanded(child: _TimeCell(label: '醒来', value: data.wakeLabel)),
              Expanded(
                child: _TimeCell(
                  label: '波动',
                  value: data.bedSpreadMinutes > 0
                      ? '±${data.bedSpreadMinutes}′'
                      : '—',
                  tint: data.bedSpreadMinutes == 0
                      ? null
                      : (steady ? p.mistGreen : p.mistPink),
                ),
              ),
            ],
          ),
          if (data.nightCount > 1) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              data.bedSpreadMinutes > kBedtimeDriftMinutes
                  ? '入睡时刻在漂，固定上床时刻比睡够时长更重要。'
                  : '入睡时刻稳定，这是睡眠质量里最值钱的一项。',
              style: DfType.caption(context, p.text2),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeCell extends StatelessWidget {
  const _TimeCell({required this.label, required this.value, this.tint});

  final String label;
  final String value;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: DfType.caption(context, p.text2)),
        const SizedBox(height: 4),
        Text(
          value,
          style: DfType.number(
            context,
            DfFontSize.titleS,
            tint ?? p.text,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 情绪 × 睡眠
// ─────────────────────────────────────────────────────────────────────────────
class _MoodCard extends StatelessWidget {
  const _MoodCard({required this.bars});

  final List<({String label, int value})> bars;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    return DfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text('近 7 天 情绪', style: DfType.bodyS(context, p.text)),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 洞察
// ─────────────────────────────────────────────────────────────────────────────
class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insights});

  final List<String> insights;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    return DfInsight(
      leading: const DfSheep(height: 34, animate: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const DfInsightText(<String>['梦洄', '看到这些']),
          const SizedBox(height: 6),
          for (final String s in insights)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                s,
                style: DfType.caption(context, p.text),
              ),
            ),
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
  final DateTime yesterday = DateTime.now().subtract(const Duration(days: 1));
  // 演示数字必须自洽：7.1 小时 → 62 + 30 − 6 = 86 分
  const List<int?> demoScores = <int?>[74, 80, null, 83, 88, 91, 86];
  final List<DfNightPoint> trend = <DfNightPoint>[
    for (int i = 0; i < demoScores.length; i++)
      DfNightPoint(
        label: weekdayLabelOf(
          yesterday.subtract(Duration(days: demoScores.length - 1 - i)),
        ),
        score: demoScores[i],
        dayKey: dayKeyOf(
          yesterday.subtract(Duration(days: demoScores.length - 1 - i)),
        ),
      ),
  ];

  return DfReportData(
    dateLabel: '昨夜 · ${yesterday.month}月${yesterday.day}日',
    score: 86,
    summary: '睡得又沉又稳，身体充电充足',
    durationLabel: '7.1',
    awakenings: 1,
    cycles: 4,
    moodCount: 5,
    moodBars: _demoMoodBars,
    bedLabel: '23:12',
    wakeLabel: '07:06',
    bedSpreadMinutes: 18,
    breakdown: const <DfScorePart>[
      DfScorePart(label: '睡眠时长', value: 62, max: 70),
      DfScorePart(label: '基础分', value: 30, max: 30),
      DfScorePart(label: '夜间醒来', value: 6, max: 100, negative: true),
    ],
    trend: trend,
    insights: const <String>[
      '入睡时刻稳定，这是睡眠质量里最值钱的一项。',
      '比上一周平均高 6 分，这个节奏在变好，别急着改。',
    ],
    avgHoursLabel: '7.0',
    avgScore: 86,
    scoreDelta: 6,
    streak: 6,
    nightCount: 7,
  );
}

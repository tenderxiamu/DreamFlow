import 'package:dreamflow/data/sleep_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

/// M11 睡眠分析的边界用例。
///
/// 这些数字会直接出现在用户面前的报告里，口径必须钉死：
/// 特别是「评分拆解必须和环形分数一致」——拆解和总分对不上，比不拆更伤信任。
void main() {
  final DateTime anchor = DateTime(2026, 11, 3, 9);

  DfNightInput night({
    required DateTime bed,
    required Duration slept,
    int awake = 0,
    int? score,
  }) {
    return DfNightInput(
      bedTime: bed,
      wakeTime: bed.add(slept),
      awakenings: awake,
      storedScore: score,
    );
  }

  DateTime day(int offset, int hour, [int minute = 0]) =>
      DateTime(2026, 11, 3, hour, minute).add(Duration(days: offset));

  group('单晚', () {
    test('7.1 小时 + 醒 1 次 → 86 分、4 个周期', () {
      final DfSleepReport r = buildSleepReport(
        <DfNightInput>[
          night(bed: day(0, 23, 12), slept: const Duration(minutes: 426), awake: 1),
        ],
        now: anchor,
      )!;
      expect(r.latest.score, 86);
      expect(r.cycles, 4);
      expect(r.bedLabel, '23:12');
      expect(r.wakeLabel, '06:18');
      expect(r.nights.length, 1);
    });

    test('落库分数优先，且钳到 0-100', () {
      final DfSleepReport ok = buildSleepReport(
        <DfNightInput>[night(bed: day(0, 23), slept: const Duration(hours: 7), score: 55)],
        now: anchor,
      )!;
      expect(ok.latest.score, 55);
      expect(ok.latest.scoreFromStore, isTrue);

      final DfSleepReport over = buildSleepReport(
        <DfNightInput>[night(bed: day(0, 23), slept: const Duration(hours: 7), score: 140)],
        now: anchor,
      )!;
      expect(over.latest.score, 100);
    });

    test('评分拆解三项相加等于总分', () {
      for (int minutes = 120; minutes <= 720; minutes += 60) {
        for (int awake = 0; awake <= 3; awake++) {
          final DfSleepReport r = buildSleepReport(
            <DfNightInput>[
              night(
                bed: day(0, 23),
                slept: Duration(minutes: minutes),
                awake: awake,
              ),
            ],
            now: anchor,
          )!;
          final int plus = r.breakdown
              .where((DfScorePart p) => !p.negative)
              .fold<int>(0, (int a, DfScorePart p) => a + p.value);
          final int minus = r.breakdown
              .where((DfScorePart p) => p.negative)
              .fold<int>(0, (int a, DfScorePart p) => a + p.value);
          expect(plus - minus, r.latest.score,
              reason: '${minutes}min / 醒 $awake 次 拆解与总分不符');
        }
      }
    });

    test('时长封顶：10 小时只给 70 分时长分', () {
      final DfSleepReport r = buildSleepReport(
        <DfNightInput>[night(bed: day(0, 22), slept: const Duration(hours: 10))],
        now: anchor,
      )!;
      expect(r.breakdown.first.value, 70);
      expect(r.latest.score, 100);
    });
  });

  group('趋势与均值', () {
    test('固定输出 7 个点，空缺标记为无数据', () {
      final DfSleepReport r = buildSleepReport(
        <DfNightInput>[
          night(bed: day(-2, 23), slept: const Duration(hours: 7), awake: 1),
          night(bed: day(-1, 23), slept: const Duration(hours: 8), awake: 0),
        ],
        now: anchor,
      )!;
      expect(r.trend.length, 7);
      expect(r.trend.last.dayKey, '2026-11-03');
      expect(r.trend.where((DfNightPoint p) => p.hasData).length, 2);
      // 最近一晚是「昨晚」，今天还没睡，所以最后一点就是昨晚
      expect(r.trend.last.hasData, isTrue);
      expect(r.trend.first.hasData, isFalse);
    });

    test('同一天多次会话取分数更高的那次（小睡不盖掉整夜）', () {
      final DfSleepReport r = buildSleepReport(
        <DfNightInput>[
          // 整夜：11-01 23:00 → 11-02 06:00
          night(bed: day(-2, 23), slept: const Duration(hours: 7), score: 88),
          // 次日下午小睡：11-02 13:00 → 13:40，同属 11-02
          night(bed: day(-1, 13), slept: const Duration(minutes: 40), score: 40),
        ],
        now: anchor,
      )!;
      final DfNightPoint p = r.trend
          .firstWhere((DfNightPoint e) => e.dayKey == '2026-11-02');
      expect(p.score, 88);
    });

    test('7 晚平均分与平均时长', () {
      final List<DfNightInput> nights = <DfNightInput>[
        for (int i = 1; i <= 7; i++)
          night(
            bed: day(-i, 23),
            slept: const Duration(hours: 7),
            score: 60 + i,
          ),
      ];
      final DfSleepReport r = buildSleepReport(nights, now: anchor)!;
      expect(r.avgScore, 64); // (61+..+67)/7
      expect(r.avgHours, closeTo(7.0, 0.01));
      expect(r.nightCount, 7);
    });

    test('周环比：上期样本不足时为 null', () {
      final DfSleepReport r = buildSleepReport(
        <DfNightInput>[night(bed: day(-1, 23), slept: const Duration(hours: 7), score: 70)],
        now: anchor,
      )!;
      expect(r.prevAvgScore, isNull);
      expect(r.delta, isNull);
    });

    test('周环比：与 7-13 天前的样本比较', () {
      final List<DfNightInput> nights = <DfNightInput>[
        for (int i = 1; i <= 7; i++)
          night(bed: day(-i, 23), slept: const Duration(hours: 7), score: 80),
        for (int i = 8; i <= 14; i++)
          night(bed: day(-i, 23), slept: const Duration(hours: 6), score: 60),
      ];
      final DfSleepReport r = buildSleepReport(nights, now: anchor)!;
      expect(r.prevAvgScore, 60);
      expect(r.avgScore, 80);
      expect(r.delta, 20);
    });
  });

  group('规律性', () {
    test('每天同一时刻上床 → 波动 0', () {
      final List<DfNightInput> nights = <DfNightInput>[
        for (int i = 1; i <= 5; i++)
          night(bed: day(-i, 23), slept: const Duration(hours: 7)),
      ];
      expect(buildSleepReport(nights, now: anchor)!.bedSpreadMinutes, 0);
    });

    test('跨零点的两个时刻不能算成 1400 分钟', () {
      final DfSleepReport r = buildSleepReport(
        <DfNightInput>[
          night(bed: day(-2, 23, 40), slept: const Duration(hours: 7)),
          night(bed: day(-1, 0, 30), slept: const Duration(hours: 7)),
        ],
        now: anchor,
      )!;
      // 23:40 → 340，00:30 → 390，标准差 25
      expect(r.bedSpreadMinutes, 25);
    });

    test('作息在漂（±90）会进洞察', () {
      final DfSleepReport r = buildSleepReport(
        <DfNightInput>[
          night(bed: day(-2, 22), slept: const Duration(hours: 8)),
          night(bed: day(-1, 1), slept: const Duration(hours: 7)),
        ],
        now: anchor,
      )!;
      expect(r.bedSpreadMinutes, 90);
      expect(r.insights.any((String s) => s.contains('作息在漂')), isTrue);
    });
  });

  group('连续性', () {
    test('连续 3 晚 → streak 3', () {
      final List<DfNightInput> nights = <DfNightInput>[
        for (int i = 2; i >= 0; i--)
          night(bed: day(-i - 1, 23), slept: const Duration(hours: 7)),
      ];
      expect(buildSleepReport(nights, now: anchor)!.streak, 3);
    });

    test('中间断一天就停', () {
      final List<DfNightInput> nights = <DfNightInput>[
        night(bed: day(-3, 23), slept: const Duration(hours: 7)),
        night(bed: day(-1, 23), slept: const Duration(hours: 7)),
      ];
      expect(buildSleepReport(nights, now: anchor)!.streak, 1);
    });
  });

  group('洞察', () {
    test('睡太短会给一句提醒', () {
      final List<DfNightInput> nights = <DfNightInput>[
        for (int i = 1; i <= 4; i++)
          night(bed: day(-i, 1), slept: const Duration(hours: 5)),
      ];
      final DfSleepReport r = buildSleepReport(nights, now: anchor)!;
      expect(r.insights.any((String s) => s.contains('偏短')), isTrue);
      expect(r.insights.length, lessThanOrEqualTo(3));
    });

    test('一切正常时也有话说', () {
      final List<DfNightInput> nights = <DfNightInput>[
        for (int i = 1; i <= 5; i++)
          night(bed: day(-i, 23), slept: const Duration(hours: 8)),
      ];
      final DfSleepReport r = buildSleepReport(nights, now: anchor)!;
      expect(r.insights, isNotEmpty);
      expect(r.insights.first, contains('节奏稳'));
    });

    test('夜醒多优先出现在最前面', () {
      final DfSleepReport r = buildSleepReport(
        <DfNightInput>[
          night(bed: day(-1, 23), slept: const Duration(hours: 5), awake: 3),
        ],
        now: anchor,
      )!;
      expect(r.insights.first, contains('连续性'));
    });
  });

  test('异常数据不炸：醒来早于入睡 → 时长为 0', () {
    final DfSleepReport r = buildSleepReport(
      <DfNightInput>[
        DfNightInput(
          bedTime: DateTime(2026, 11, 3, 8),
          wakeTime: DateTime(2026, 11, 3, 7),
          awakenings: -1,
        ),
      ],
      now: anchor,
    )!;
    expect(r.latest.duration, Duration.zero);
    expect(r.latest.awakenings, 0);
    expect(r.latest.score, 30); // 只有基础分
  });
}

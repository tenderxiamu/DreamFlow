import 'package:dreamflow/data/health_sleep.dart';
import 'package:dreamflow/data/light_sleep.dart';
import 'package:dreamflow/data/sleep_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-01 起算的时间点（偏移天数、时、分）
DateTime at(int dayOffset, int hour, [int minute = 0]) =>
    DateTime(2026, 11, 1 + dayOffset, hour, minute);

/// 按「(分钟数, 分期)」序列造一条带分期的会话
DfHealthSession build(
  DateTime start,
  List<(int, DfStageKind)> parts,
) {
  final List<DfStageSpan> spans = <DfStageSpan>[];
  DateTime cursor = start;
  for (final (int minutes, DfStageKind kind) in parts) {
    final DateTime next = cursor.add(Duration(minutes: minutes));
    spans.add(DfStageSpan(start: cursor, end: next, kind: kind));
    cursor = next;
  }
  return DfHealthSession(start: start, end: cursor, stages: spans);
}

void main() {
  group('buildMeasuredNights · 聚合', () {
    test('整夜分期：各阶段分钟数正确归位', () {
      final List<DfMeasuredNight> nights = buildMeasuredNights(<DfHealthSession>[
        build(at(1, 23), <(int, DfStageKind)>[
          (60, DfStageKind.light),
          (90, DfStageKind.deep),
          (120, DfStageKind.light),
          (12, DfStageKind.awake),
          (60, DfStageKind.deep),
          (90, DfStageKind.rem),
          (60, DfStageKind.light),
          (5, DfStageKind.awake),
        ]),
      ]);

      expect(nights, hasLength(1));
      final DfMeasuredNight n = nights.single;
      expect(n.deepMinutes, 150);
      expect(n.remMinutes, 90);
      expect(n.lightMinutes, 240);
      expect(n.awakeMinutes, 17);
      expect(n.hasStages, isTrue);
      expect(n.bedTime, at(1, 23));
      expect(n.wakeTime, at(2, 7, 17));
    });

    test('贴着首尾的清醒是「还没睡着 / 已经醒了」，不算夜醒', () {
      final List<DfMeasuredNight> nights = buildMeasuredNights(<DfHealthSession>[
        build(at(1, 23), <(int, DfStageKind)>[
          (20, DfStageKind.awake), // 上床刷手机
          (300, DfStageKind.light),
          (10, DfStageKind.awake), // 起床前赖着
        ]),
      ]);
      expect(nights.single.awakenings, 0);
      expect(nights.single.awakeMinutes, 30); // 时长照记
    });

    test('中间不足 5 分钟的微觉醒不计入夜醒', () {
      final List<DfMeasuredNight> nights = buildMeasuredNights(<DfHealthSession>[
        build(at(1, 23), <(int, DfStageKind)>[
          (300, DfStageKind.light),
          (3, DfStageKind.awake),
          (120, DfStageKind.light),
        ]),
      ]);
      expect(nights.single.awakenings, 0);
    });

    test('中间够长的清醒计一次夜醒', () {
      final List<DfMeasuredNight> nights = buildMeasuredNights(<DfHealthSession>[
        build(at(1, 23), <(int, DfStageKind)>[
          (300, DfStageKind.light),
          (12, DfStageKind.awake),
          (120, DfStageKind.light),
        ]),
      ]);
      expect(nights.single.awakenings, 1);
    });

    test('短于 90 分钟的小睡被丢弃', () {
      final List<DfMeasuredNight> nights = buildMeasuredNights(<DfHealthSession>[
        build(at(1, 23), <(int, DfStageKind)>[
          (300, DfStageKind.light),
        ]),
        build(at(2, 13), <(int, DfStageKind)>[
          (40, DfStageKind.light),
        ]),
      ]);
      expect(nights, hasLength(1));
      expect(nights.single.bedTime, at(1, 23));
    });

    test('同一夜被拆成两段时合并成一夜：取最早入睡、最晚醒来', () {
      final List<DfMeasuredNight> nights = buildMeasuredNights(<DfHealthSession>[
        build(at(1, 23), <(int, DfStageKind)>[
          (240, DfStageKind.light),
        ]),
        build(at(2, 4), <(int, DfStageKind)>[
          (180, DfStageKind.light),
        ]),
      ]);
      expect(nights, hasLength(1));
      expect(nights.single.bedTime, at(1, 23));
      expect(nights.single.wakeTime, at(2, 7));
      expect(nights.single.lightMinutes, 420);
    });

    test('同一夜只要有一段没分期，整体就不标分期（不拿半套数据充数）', () {
      final List<DfMeasuredNight> nights = buildMeasuredNights(<DfHealthSession>[
        build(at(1, 23), <(int, DfStageKind)>[
          (120, DfStageKind.deep),
          (120, DfStageKind.light),
        ]),
        DfHealthSession(start: at(2, 4), end: at(2, 7)), // 无分期
      ]);
      expect(nights.single.hasStages, isFalse);
      expect(nights.single.deepMinutes, 120); // 分期分钟数照留，只是不展示
    });

    test('只有起止时间的记录：整段算睡眠，不编造分期', () {
      final List<DfMeasuredNight> nights = buildMeasuredNights(<DfHealthSession>[
        DfHealthSession(start: at(1, 23), end: at(2, 6, 30)),
      ]);
      final DfMeasuredNight n = nights.single;
      expect(n.hasStages, isFalse);
      expect(n.deepMinutes, 0);
      expect(n.remMinutes, 0);
      expect(n.lightMinutes, 450);
      expect(n.awakenings, 0);
    });

    test('起止颠倒、超过 20 小时的脏记录被跳过', () {
      final List<DfMeasuredNight> nights = buildMeasuredNights(<DfHealthSession>[
        DfHealthSession(start: at(1, 7), end: at(1, 6)), // 颠倒
        DfHealthSession(start: at(1, 0), end: at(2, 20)), // 44 小时
        DfHealthSession(start: at(3, 23), end: at(4, 7)), // 正常
      ]);
      expect(nights, hasLength(1));
      expect(nights.single.bedTime, at(3, 23));
    });

    test('按醒来那天归日，且结果升序', () {
      final List<DfMeasuredNight> nights = buildMeasuredNights(<DfHealthSession>[
        DfHealthSession(start: at(3, 23), end: at(4, 7)),
        DfHealthSession(start: at(1, 23), end: at(2, 7)),
      ]);
      expect(nights.map((DfMeasuredNight n) => n.dayKey).toList(),
          <String>['2026-11-03', '2026-11-05']);
      expect(nights.first.wakeTime.isBefore(nights.last.wakeTime), isTrue);
    });

    test('空输入返回空列表', () {
      expect(buildMeasuredNights(const <DfHealthSession>[]), isEmpty);
    });
  });

  group('toNightInput', () {
    test('实测夜带 measured 标记与分期分钟数，分数仍走同一套公式', () {
      final DfMeasuredNight night = buildMeasuredNights(<DfHealthSession>[
        build(at(1, 23), <(int, DfStageKind)>[
          (300, DfStageKind.light),
          (12, DfStageKind.awake),
          (120, DfStageKind.deep),
        ]),
      ]).single;

      final DfNightInput input = toNightInput(night);
      expect(input.measured, isTrue);
      expect(input.deepMinutes, 120);
      expect(input.awakenings, 1);

      final DfNightStat stat = DfNightStat.from(input);
      expect(stat.measured, isTrue);
      expect(stat.hasStages, isTrue);
      expect(
        stat.score,
        estimateScore(duration: stat.duration, snoozes: 1),
      );
    });
  });

  group('mergeNightSources', () {
    final DfNightInput estimatedSameNight = DfNightInput(
      bedTime: at(1, 23),
      wakeTime: at(2, 7),
      awakenings: 1,
      storedScore: 80,
    );
    final DfNightInput estimatedOtherNight = DfNightInput(
      bedTime: at(0, 23),
      wakeTime: at(1, 7),
      awakenings: 0,
      storedScore: 90,
    );
    final DfNightInput measuredSameNight = DfNightInput(
      bedTime: at(1, 23),
      wakeTime: at(2, 6, 50),
      awakenings: 2,
      measured: true,
      deepMinutes: 100,
    );

    test('同一天有实测就丢掉推算，绝不混用', () {
      final List<DfNightInput> merged = mergeNightSources(
        estimated: <DfNightInput>[estimatedSameNight, estimatedOtherNight],
        measured: <DfNightInput>[measuredSameNight],
      );
      expect(merged, hasLength(2));
      expect(merged.where((DfNightInput n) => n.measured).length, 1);
      expect(
        merged.any((DfNightInput n) => !n.measured && n.storedScore == 80),
        isFalse,
      );
    });

    test('没有实测的日子保留推算', () {
      final List<DfNightInput> merged = mergeNightSources(
        estimated: <DfNightInput>[estimatedOtherNight],
        measured: <DfNightInput>[measuredSameNight],
      );
      expect(merged, hasLength(2));
    });

    test('没有实测时原样返回推算', () {
      final List<DfNightInput> merged = mergeNightSources(
        estimated: <DfNightInput>[estimatedOtherNight],
        measured: const <DfNightInput>[],
      );
      expect(merged.single, same(estimatedOtherNight));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:dreamflow/data/light_sleep.dart';

/// M5：浅睡窗口与睡眠分估算的纯函数验收。
void main() {
  final DateTime bedtime = DateTime(2026, 10, 26, 0, 0); // 00:00 入睡

  group('alignToLightWindow', () {
    test('正好在周期边界 → 原样返回', () {
      final DateTime target = bedtime.add(const Duration(minutes: 90 * 5));
      expect(alignToLightWindow(bedtime, target), target);
    });

    test('偏差在容差内 → 吸附到边界', () {
      final DateTime target =
          bedtime.add(const Duration(minutes: 90 * 5 - 15)); // 差 15 分钟
      final DateTime aligned = alignToLightWindow(bedtime, target);
      expect(
        aligned.difference(bedtime).inMinutes,
        90 * 5,
      );
    });

    test('偏差超出容差 → 尊重原时刻', () {
      final DateTime target =
          bedtime.add(const Duration(minutes: 90 * 5 - 40)); // 差 40 分钟
      expect(alignToLightWindow(bedtime, target), target);
    });

    test('target 早于入睡时刻 → 原样返回', () {
      final DateTime target = bedtime.subtract(const Duration(hours: 1));
      expect(alignToLightWindow(bedtime, target), target);
    });
  });

  group('estimateScore', () {
    test('8 小时无觉醒 → 满分区间（≥95）', () {
      final int score = estimateScore(
        duration: const Duration(hours: 8),
        snoozes: 0,
      );
      expect(score, greaterThanOrEqualTo(95));
      expect(score, lessThanOrEqualTo(100));
    });

    test('短时长 + 多次贪睡 → 显著降低', () {
      final int good = estimateScore(
        duration: const Duration(hours: 8),
        snoozes: 0,
      );
      final int bad = estimateScore(
        duration: const Duration(hours: 4),
        snoozes: 3,
      );
      expect(bad, lessThan(good - 30));
    });

    test('评分始终在 0-100', () {
      expect(
        estimateScore(duration: const Duration(minutes: 10), snoozes: 10),
        inInclusiveRange(0, 100),
      );
    });
  });

  group('summarizeScore', () {
    test('分档文案单调递进', () {
      final List<String> labels = <String>[
        summarizeScore(50),
        summarizeScore(60),
        summarizeScore(75),
        summarizeScore(90),
      ];
      expect(labels.toSet().length, 4);
    });
  });
}

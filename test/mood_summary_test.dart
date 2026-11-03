import 'package:dreamflow/data/df_mood_summary.dart';
import 'package:flutter_test/flutter_test.dart';

/// 今日情绪折算的边界用例。
///
/// 这张卡原来是写死的 62%，用户看到的就是「永远不变」；现在分数由当天
/// 记录折算，所以口径必须钉死，否则以后调表会悄悄改掉用户看到的东西。
void main() {
  DateTime at(int hour, [int minute = 0]) =>
      DateTime(2026, 11, 3, hour, minute);

  group('单条记录', () {
    test('平静·高 → 96', () {
      final DfMoodSummary s = DfMoodSummary.fromEntries(<DfMoodEntry>[
        DfMoodEntry(label: '平静', intensity: 5, createdAt: at(23)),
      ]);
      expect(s.score, 96);
      expect(s.count, 1);
      expect(s.dominant, '平静');
      expect(s.caption, '此刻是平静 · 今天的心是缓的');
    });

    test('低落·高 → 24（全表最低档）', () {
      final DfMoodSummary s = DfMoodSummary.fromEntries(<DfMoodEntry>[
        DfMoodEntry(label: '低落', intensity: 5, createdAt: at(22)),
      ]);
      expect(s.score, 24);
    });

    test('强度分档：1/2 → 低，3 → 中，4/5 → 高', () {
      int scoreOf(int intensity) => DfMoodSummary.scoreOf(
            DfMoodEntry(label: '焦虑', intensity: intensity, createdAt: at(22)),
          );
      expect(scoreOf(1), 46);
      expect(scoreOf(2), 46);
      expect(scoreOf(3), 38);
      expect(scoreOf(4), 28);
      expect(scoreOf(5), 28);
    });

    test('未收录的标签按「未知」处理，不抛', () {
      final DfMoodSummary s = DfMoodSummary.fromEntries(<DfMoodEntry>[
        DfMoodEntry(label: '某种新情绪', intensity: 3, createdAt: at(22)),
      ]);
      expect(s.score, 55);
      expect(s.caption, '此刻是某种新情绪 · 我在听');
    });
  });

  group('空态', () {
    test('没有记录 → 不给分数（不能假装一个数字）', () {
      final DfMoodSummary s = DfMoodSummary.fromEntries(<DfMoodEntry>[]);
      expect(s.score, isNull);
      expect(s.isEmpty, isTrue);
      expect(s.ratio, 0);
      expect(s.caption, contains('还没有记录'));
    });
  });

  group('多条记录', () {
    test('新近度加权：刚说的低落会压过早上那句平静', () {
      final DfMoodSummary s = DfMoodSummary.fromEntries(<DfMoodEntry>[
        DfMoodEntry(label: '平静', intensity: 3, createdAt: at(8)),
        DfMoodEntry(label: '低落', intensity: 3, createdAt: at(23)),
      ]);
      // (34×1.0 + 90×0.8) / 1.8 = 58.9 → 59，明显低于「平静 90」
      expect(s.score, 59);
      expect(s.count, 2);
      expect(s.caption, '低落偏多 · 今天记了 2 次');
    });

    test('乱序传入也按时间倒序算（结果与顺序无关）', () {
      final List<DfMoodEntry> asc = <DfMoodEntry>[
        DfMoodEntry(label: '焦虑', intensity: 5, createdAt: at(9)),
        DfMoodEntry(label: '平静', intensity: 5, createdAt: at(23)),
      ];
      final DfMoodSummary a = DfMoodSummary.fromEntries(asc);
      final DfMoodSummary b =
          DfMoodSummary.fromEntries(asc.reversed.toList());
      expect(a.score, b.score);
      expect(a.dominant, '平静'); // 最近一次是平静
    });

    test('主导标签取出现次数最多的那个', () {
      final DfMoodSummary s = DfMoodSummary.fromEntries(<DfMoodEntry>[
        DfMoodEntry(label: '焦虑', intensity: 3, createdAt: at(21)),
        DfMoodEntry(label: '焦虑', intensity: 3, createdAt: at(22)),
        DfMoodEntry(label: '平静', intensity: 5, createdAt: at(23)),
      ]);
      expect(s.dominant, '焦虑');
      expect(s.caption, '焦虑偏多 · 今天记了 3 次');
    });

    test('次数相同取最近一次（并列时的取舍要稳定）', () {
      final DfMoodSummary s = DfMoodSummary.fromEntries(<DfMoodEntry>[
        DfMoodEntry(label: '疲惫', intensity: 3, createdAt: at(21)),
        DfMoodEntry(label: '平静', intensity: 3, createdAt: at(23)),
      ]);
      expect(s.dominant, '平静');
    });

    test('分数恒在 0-100 内', () {
      final List<DfMoodEntry> list = <DfMoodEntry>[
        for (int i = 0; i < 40; i++)
          DfMoodEntry(label: '低落', intensity: 5, createdAt: at(0, i)),
      ];
      final DfMoodSummary s = DfMoodSummary.fromEntries(list);
      expect(s.score, inInclusiveRange(0, 100));
      expect(s.ratio, lessThanOrEqualTo(1.0));
    });
  });
}

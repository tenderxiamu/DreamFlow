import 'package:dreamflow/data/df_persona.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DfPersona 情绪标记', () {
    test('半角与全角括号都能解析', () {
      for (final String raw in <String>[
        '先躺下吧。\n[情绪:疲惫·强度:中]',
        '先躺下吧。\n【情绪:焦虑·强度:高】',
        '先躺下吧。\n[情绪：低落 · 强度：低]',
      ]) {
        final RegExpMatch? m = DfPersona.moodTag.firstMatch(raw);
        expect(m, isNotNull, reason: raw);
      }
      final RegExpMatch m =
          DfPersona.moodTag.firstMatch('[情绪:入睡困难·强度:高]')!;
      expect(m.group(1)!.trim(), '入睡困难');
      expect(m.group(2), '高');
    });

    test('未知情绪也是合法标记', () {
      final RegExpMatch m = DfPersona.moodTag.firstMatch('[情绪:未知·强度:中]')!;
      expect(m.group(1)!.trim(), '未知');
    });
  });

  group('DfPersona.hidePartialTag（流式渲染不能闪出标记）', () {
    test('完整标记被抹掉', () {
      expect(
        DfPersona.hidePartialTag('今天就到这儿。\n[情绪:平静·强度:低]'),
        '今天就到这儿。',
      );
    });

    test('吐到一半的标记不显示', () {
      expect(DfPersona.hidePartialTag('今天就到这儿。\n[情绪:平'), '今天就到这儿。');
      expect(DfPersona.hidePartialTag('今天就到这儿。\n【情绪'), '今天就到这儿。');
    });

    test('没有标记时原样返回', () {
      expect(DfPersona.hidePartialTag('嗯，我在。'), '嗯，我在。');
    });
  });

  group('DfPersona.system 拼装', () {
    test('包含此刻时间与深夜阶段提示', () {
      final String s =
          DfPersona.system(now: DateTime(2026, 10, 28, 23, 47));
      expect(s, contains('2026年10月28日 周三 23:47'));
      expect(s, contains('现在是深夜'));
    });

    test('首轮不出现「第几轮」提示，后续轮次才出现', () {
      final DateTime t = DateTime(2026, 10, 28, 23, 47);
      expect(DfPersona.system(now: t, round: 0), isNot(contains('之后的回复')));
      expect(DfPersona.system(now: t, round: 2), contains('第 2 轮'));
    });
  });
}

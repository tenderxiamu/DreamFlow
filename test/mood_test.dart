import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dreamflow/data/df_mood.dart';

/// 《DreamFlow Demo 测试报告 20261029》§八「4 个关键回归用例」的自动化版。
///
/// 为什么用纯 `test()` 而不是 `testWidgets()`：
/// 判定逻辑全在 [DfMood] 里，没有 Flutter 依赖；直接打函数能覆盖几十条
/// 边界，而挂 Widget 那条路要过 DB 初始化（drift + path_provider），
/// 在测试环境里会一直等下去。
///
/// 字符串是否含孤立代理，用 runes 判：合法的 emoji 代理对在 `runes`
/// 里会合并成一个 >0xFFFF 的码点，只有**半个**代理才会落到 D800~DFFF。
bool _hasLoneSurrogate(String s) =>
    s.runes.any((int c) => c >= 0xD800 && c <= 0xDFFF);

void main() {
  group('D-01 抑郁倾向表达不被判成提问', () {
    test('「我今天什么都不想做」→ 判低落，且不是提问', () {
      const String t = '我今天什么都不想做';
      // 这一条是报告里最严重的：旧实现命中「什么」→ 当提问 →
      // 回「这个我先记下，不急着答」，情绪标签也不更新。
      expect(DfMood.isQuestion(t), isFalse, reason: '这是在倾诉，不是在提问');
      expect(DfMood.hits(t), contains('低落'));
    });

    test('同族表达都能落到低落', () {
      for (final String t in <String>[
        '什么都不想做',
        '什么都没意思',
        '整晚提不起劲',
        '不想动，也不想理人',
        '心里空落落的',
      ]) {
        expect(DfMood.hits(t), contains('低落'), reason: t);
      }
    });

    test('「怎么都睡不着」是入睡困难，不是提问', () {
      const String t = '怎么都睡不着';
      expect(DfMood.isQuestion(t), isFalse);
      expect(DfMood.hits(t), contains('入睡困难'));
    });

    test('修 D-01 不能牺牲真提问', () {
      for (final String t in <String>[
        '你叫什么名字',
        '你是谁',
        '现在几点了',
        '这个 app 怎么用',
        '你能做什么',
        '这样就可以了吗？',
      ]) {
        expect(DfMood.isQuestion(t), isTrue, reason: t);
      }
    });

    test('「不想睡」是入睡困难，不是低落', () {
      // 「不想」是低落的词根，但「不想睡」是另一回事 ——
      // 词表里刻意用完整短语就是为了不误伤这类表达
      expect(DfMood.hits('我现在还不想睡'), isNot(contains('低落')));
    });
  });

  group('D-02 否定词不能反转语义', () {
    test('「我不怕，明天的手术我有信心」不许判焦虑', () {
      expect(DfMood.hits('我不怕，明天的手术我有信心'), isNot(contains('焦虑')));
    });

    test('常见否定都拦住', () {
      final Map<String, String> cases = <String, String>{
        '我不怕': '焦虑',
        '我并不焦虑': '焦虑',
        '没什么好担心的': '焦虑',
        '我不太累': '疲惫',
        '我不烦': '烦躁',
        '别紧张，都过去了': '焦虑',
        '我不难过，就是有点空': '低落',
      };
      cases.forEach((String text, String mood) {
        expect(DfMood.hits(text), isNot(contains(mood)), reason: text);
      });
    });

    test('「哪怕」里的「怕」不是「在怕」', () {
      expect(DfMood.hits('哪怕失败也没关系'), isNot(contains('焦虑')));
      expect(DfMood.hits('不管结果怎样我都不慌'), isNot(contains('焦虑')));
    });

    test('正面表达不能被误伤（否定词只有前缀才算）', () {
      final Map<String, String> cases = <String, String>{
        '我很怕明天的手术': '焦虑',
        '我有点紧张': '焦虑',
        '压力好大': '焦虑',
        '我很累': '疲惫',
        '心里烦得很': '烦躁',
      };
      cases.forEach((String text, String mood) {
        expect(DfMood.hits(text), contains(mood), reason: text);
      });
    });
  });

  group('§6.2 危机信号', () {
    test('明确的自伤/轻生表达必须命中', () {
      for (final String t in <String>[
        '我不想活了',
        '活着没意思',
        '我想死',
        '有时候想从楼上跳下去',
        '我就是想消失',
      ]) {
        expect(DfMood.isCrisis(t), isTrue, reason: t);
      }
    });

    test('日常负面情绪不许报警', () {
      // 误报一次，用户就再也不会说实话。词表只收「明确的意图」。
      for (final String t in <String>[
        '我今天好累',
        '压力好大，快撑不住了',
        '我很难过',
        '烦死了',
        '我睡不着',
      ]) {
        expect(DfMood.isCrisis(t), isFalse, reason: t);
      }
    });
  });

  group('D-04 引用片段按码点截断', () {
    test('emoji 不会被切成孤立代理', () {
      final String q = DfMood.quote('a😢😢😢😢');
      expect(_hasLoneSurrogate(q), isFalse, reason: '切出了半个代理对');
      expect(q.runes.length, lessThanOrEqualTo(8));
    });

    test('按码点算长度：8 个 emoji 全保留', () {
      expect(DfMood.quote('😢😢😢😢😢😢😢😢').runes.length, 8);
    });

    test('引用能被 jsonEncode 正常序列化', () {
      // 旧实现在这一步会产出 \ud83d 这种非法转义，下游（测试框架 / 上报）
      // 直接抛 surrogates not allowed
      final String q = DfMood.quote('aaaaaaaa😢');
      expect(() => jsonEncode(<String, String>{'q': q}), returnsNormally);
    });

    test('中文照常截 8 字，标点去掉', () {
      // 「我今天什么都不想做」是 9 个字，截到第 8 个
      expect(DfMood.quote('我今天什么都不想做，真的好累'), '我今天什么都不想');
      expect(DfMood.quote('嗯，'), '嗯');
      expect(DfMood.quote('   '), '这句话');
    });
  });
}

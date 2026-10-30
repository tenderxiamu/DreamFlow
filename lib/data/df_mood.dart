/// 情绪 / 风险识别 —— 纯 Dart，零 Flutter 依赖。
///
/// 为什么单独成文件：这里的规则是**产品风险**，不是界面细节。
/// 放在 State 的私有方法里，只能靠「挂 Widget → 打字 → 等 1.2 秒计时器」去验，
/// 边界条件根本测不过来；抽成纯函数后可以直接 `test()` 打，
/// 也不用碰 `testWidgets` 里 path_provider 那个永不返回的坑。
///
/// 三条规则直接对应《DreamFlow Demo 测试报告 20261029》：
/// - D-01 「我今天什么都不想做」被判成提问 → 回「这个我先记下，不急着答」，情绪标签不更新
/// - D-02 「我不怕，明天的手术我有信心」被判成焦虑 → 给术前用户反向暗示
/// - §6.2 危机信号完全没有识别与求助引导
class DfMood {
  const DfMood._();

  // ── 危机信号 ────────────────────────────────────────────────────────────

  /// 命中即走求助引导，**不参与其它任何判断**，同时关掉「就去睡吧」出口。
  ///
  /// 词表只收「明确的意图表达」，不收「难过 / 崩溃 / 撑不住 / 累」——
  /// 那些是日常情绪，误报一次，用户就再也不会说真话。宁可漏，不可滥报。
  static const List<String> crisisWords = <String>[
    '不想活',
    '活不下去',
    '活着没意思',
    '活着没意义',
    '不如死了',
    '想死',
    '自杀',
    '自残',
    '自伤',
    '伤害自己',
    '结束自己',
    '结束生命',
    '跳楼',
    '跳下去',
    '割腕',
    '不想醒来',
    '想消失',
  ];

  static bool isCrisis(String text) {
    final String s = _normalize(text);
    return crisisWords.any(s.contains);
  }

  // ── 情绪词表 ────────────────────────────────────────────────────────────

  /// 关键词 → 情绪。顺序即优先级（[hits] 按此顺序返回）。
  ///
  /// 「低落」组里刻意用「什么都不想做 / 不想动 / 提不起」这类**完整表达**，
  /// 而不是裸的「不想」——「我不想睡」是入睡困难，不是低落。
  static const Map<String, List<String>> rules = <String, List<String>>{
    '焦虑': <String>['焦虑', '紧张', '担心', '害怕', '怕', '慌', '压力', '不安', '悬着'],
    '疲惫': <String>['累', '疲惫', '没劲', '透支', '撑不住', '扛不住'],
    '入睡困难': <String>['睡不着', '失眠', '醒着', '躺了很久', '翻来覆去', '睁眼到'],
    '低落': <String>[
      '难过', '委屈', '低落', '想哭', '孤单', //
      '什么都不想做', '不想做', '不想动', '不想说话', '不想理人', //
      '提不起', '没意思', '空落落', '麻木', '没盼头', '无所谓',
    ],
    '烦躁': <String>['烦', '生气', '火大', '忍不住', '暴躁', '想摔'],
  };

  /// 命中的情绪（按 [rules] 顺序，最多不限；调用方自己 `take(n)`）。
  ///
  /// 带否定判断：「我不怕」「没精神但是不烦」不该判成焦虑 / 烦躁。
  static List<String> hits(String text) {
    final String s = _stripFakeNegation(_normalize(text));
    final List<String> out = <String>[];
    for (final MapEntry<String, List<String>> e in rules.entries) {
      bool hit = false;
      for (final String kw in e.value) {
        int i = s.indexOf(kw);
        while (i >= 0) {
          if (!_negated(s, i)) {
            hit = true;
            break;
          }
          i = s.indexOf(kw, i + kw.length);
        }
        if (hit) break;
      }
      if (hit) out.add(e.key);
    }
    return out;
  }

  // ── 否定判定（D-02）────────────────────────────────────────────────────
  //
  // 纯 `contains` 会把「不怕 / 没慌 / 不太累 / 哪怕」全部反过来。
  // 做法：先把「带否定字但其实不是否定」的词抹成等长空白（保持下标不变），
  // 再看关键词**前面这一小句**里有没有否定字。

  static final RegExp _fakeNegation = RegExp(
    r'哪怕|不管|无论|不然|不仅|不但|不光|不只|不停|不断|不过|'
    r'不好意思|差不多|忍不住|恨不得|巴不得',
  );

  /// 否定字。用纯字符匹配而不是 `$` 锚定：
  /// 「没什么**好**担心的」里，否定和关键词隔着「什么好」三个字，
  /// 只认紧邻会漏掉这类最自然的中文说法。
  static final RegExp _negWord = RegExp(r'[不没别无未非莫]');

  /// 句读边界：否定不跨越逗号，否则
  /// 「我不太想说，但还是很焦虑」里的「不」会把后半句的焦虑也否掉
  static final RegExp _clauseBreak = RegExp(r'[，。！？、；：,.!?;:]');

  static String _stripFakeNegation(String s) => s.replaceAllMapped(
        _fakeNegation,
        (Match m) => '\u3000' * m[0]!.length,
      );

  /// 取关键词前面同一小句里的一小段（最多 [span] 字），判有没有否定字
  static bool _negated(String s, int at) {
    if (at <= 0) return false;
    const int span = 4;
    final int from = at - span < 0 ? 0 : at - span;
    String lead = s.substring(from, at);
    final int cut = lead.lastIndexOf(_clauseBreak);
    if (cut >= 0) lead = lead.substring(cut + 1);
    return _negWord.hasMatch(lead);
  }

  // ── 提问判定（D-01）─────────────────────────────────────────────────────

  /// **明确在问**的句式。
  ///
  /// 不能把「什么 / 怎么 / 为什么」单独算进来：
  /// 「我今天什么都不想做」「怎么都睡不着」「为什么总是我」都是倾诉，
  /// 当成提问就会被「这个我先记下，不急着答」把情绪关掉。
  static final RegExp questionPattern = RegExp(
    r'[?？]\s*$'
    r'|你叫|叫什么|名字|你是谁|你是梦洄|你是人|你是ai|你几岁'
    r'|几点|什么时候|多久|多少'
    r'|怎么办|该怎么做|怎么做|怎么用|能做什么|会做什么'
    r'|能不能|可不可以|可以吗|可以不|会不会|有没有|是不是|对不对|好不好',
  );

  static bool isQuestion(String text) =>
      questionPattern.hasMatch(text.trim());

  // ── 引用片段（D-04）─────────────────────────────────────────────────────

  /// 从原话里取一段可引用的片段（去标点，最多 [max] 个**码点**）。
  ///
  /// 必须按 runes 截，不能按 code unit：emoji 是代理对，`substring(0, 8)`
  /// 会留下孤立高位代理（U+D83D）—— UI 上是 `�`，而且连测试框架的
  /// JSON 序列化都会直接抛 `surrogates not allowed`。
  static String quote(String text, {int max = 8}) {
    final String clean =
        text.replaceAll(RegExp(r'[，。！？、,.!?~…\s\u3000]'), '');
    if (clean.isEmpty) return '这句话';

    // 输入里若本来就有孤立代理（粘贴/输入法异常时会），先剔掉，
    // 否则截断再拼回来还是非法字符
    final List<int> rs = clean.runes
        .where((int c) => c < 0xD800 || c > 0xDFFF)
        .toList();
    if (rs.isEmpty) return '这句话';
    if (rs.length <= max) return String.fromCharCodes(rs);

    final String cut = String.fromCharCodes(rs.take(max));
    // 停在 ZWJ 上会渲染出半个合成 emoji，多削一格
    return cut.endsWith('\u200d') ? cut.substring(0, cut.length - 1) : cut;
  }

  static String _normalize(String s) => s.replaceAll(RegExp(r'[\s\u3000]'), '');
}

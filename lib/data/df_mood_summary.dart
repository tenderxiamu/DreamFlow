/// 今日情绪汇总 —— 纯 Dart，零 Flutter UI 依赖（只用到 ChangeNotifier）。
///
/// 为什么单独成文件：首页那张「今日情绪」卡原来写死了 `62` / `0.62` /
/// 「平静偏多 · 睡前有一点心事的余温」，跟真实记录毫无关系。折算规则属于
/// **产品语义**（哪个情绪算「好」、强度怎么放大），放在 Widget 里就只能靠
/// 挂界面点按去验；抽成纯函数后可以直接 `test()` 打边界。
///
/// 折算口径（与 `DfMood.rules` 的标签集合对齐）：
/// 1. 每个标签先给一个基准分（0-100），再按强度（低/中/高）微调；
/// 2. 今天所有记录按**新近度**加权平均（新的权重高：0.8^i）——
///    睡前刚说的话比早上那句更能代表「此刻」；
/// 3. 无记录时不给分数（null），由界面显示占位文案，不能假装一个数字。
library;

import 'package:flutter/foundation.dart';

/// 一条情绪记录的最小投影（不依赖 Drift 生成类型，便于纯逻辑测试）
@immutable
class DfMoodEntry {
  const DfMoodEntry({
    required this.label,
    required this.intensity,
    required this.createdAt,
  });

  /// 情绪标签：平静 / 焦虑 / 疲惫 / 低落 / 烦躁 / 入睡困难 / 未知
  final String label;

  /// 1-5（对话链路只会写 1 / 3 / 5）
  final int intensity;

  final DateTime createdAt;

  @override
  String toString() => 'DfMoodEntry($label, $intensity, $createdAt)';
}

/// 折算结果
@immutable
class DfMoodSummary {
  const DfMoodSummary({
    required this.score,
    required this.caption,
    required this.count,
    required this.dominant,
  });

  /// 0-100；[count] 为 0 时是 null（没有记录就不该有分数）
  final int? score;

  /// 卡内那行弱信息文案
  final String caption;

  /// 今天记了几条
  final int count;

  /// 出现最多的标签（并列时取最近一次）；无记录为 null
  final String? dominant;

  bool get isEmpty => count == 0;

  /// 进度条用的 0-1（空态给 0，不画假进度）
  double get ratio => (score ?? 0) / 100;

  // ── 折算表 ────────────────────────────────────────────────────────────

  /// 标签基准分：低 / 中 / 高 三档。
  ///
  /// 平静：越平静分越高；负面情绪：强度越大分越低。
  /// 「未知」取中性 55，但正常链路不会写未知（模型给未知时不落库）。
  static const Map<String, List<int>> _base = <String, List<int>>{
    '平静': <int>[82, 90, 96],
    '入睡困难': <int>[48, 42, 34],
    '疲惫': <int>[52, 45, 38],
    '焦虑': <int>[46, 38, 28],
    '烦躁': <int>[45, 37, 28],
    '低落': <int>[42, 34, 24],
    '未知': <int>[55, 55, 55],
  };

  /// 强度 1-5 → 三档索引（0 低 / 1 中 / 2 高）
  static int _tier(int intensity) {
    if (intensity <= 2) return 0;
    if (intensity <= 3) return 1;
    return 2;
  }

  /// 单条记录的分数（未收录的标签按「未知」处理，不抛）
  static int scoreOf(DfMoodEntry e) {
    final List<int> row = _base[e.label] ?? _base['未知']!;
    return row[_tier(e.intensity)];
  }

  /// 文案尾巴：一句人话，不要指标腔
  static const Map<String, String> _tail = <String, String>{
    '平静': '今天的心是缓的',
    '焦虑': '心里还悬着，可以慢慢说',
    '疲惫': '累了就早点放下',
    '低落': '不用急着好起来',
    '烦躁': '先深呼吸两次',
    '入睡困难': '躺着也没关系，我陪你',
    '未知': '我在听',
  };

  /// 由今天的记录折算。[entries] 可以乱序传入，内部按时间倒序处理。
  factory DfMoodSummary.fromEntries(List<DfMoodEntry> entries) {
    if (entries.isEmpty) {
      return const DfMoodSummary(
        score: null,
        caption: '今天还没有记录 · 聊两句就会亮起来',
        count: 0,
        dominant: null,
      );
    }

    final List<DfMoodEntry> sorted = List<DfMoodEntry>.of(entries)
      ..sort((DfMoodEntry a, DfMoodEntry b) => b.createdAt.compareTo(a.createdAt));

    // ① 新近度加权平均
    double weighted = 0;
    double weightSum = 0;
    double w = 1;
    for (final DfMoodEntry e in sorted) {
      weighted += scoreOf(e) * w;
      weightSum += w;
      w *= 0.8;
    }
    final int score = (weighted / weightSum).round().clamp(0, 100);

    // ② 主导标签：出现次数最多；并列取最近一次（sorted 已倒序，故先遇到的优先）
    final Map<String, int> freq = <String, int>{};
    for (final DfMoodEntry e in sorted) {
      freq[e.label] = (freq[e.label] ?? 0) + 1;
    }
    int best = -1;
    String? dominant;
    for (final DfMoodEntry e in sorted) {
      final int c = freq[e.label]!;
      if (c > best) {
        best = c;
        dominant = e.label;
      }
    }

    final String tail = _tail[dominant] ?? _tail['未知']!;
    final String caption = sorted.length == 1
        ? '此刻是$dominant · $tail'
        : '$dominant偏多 · 今天记了 ${sorted.length} 次';

    return DfMoodSummary(
      score: score,
      caption: caption,
      count: sorted.length,
      dominant: dominant,
    );
  }
}

/// 「今天有新的情绪记录」广播。
///
/// 首页挂在 IndexedStack 里，切 Tab 回来不会重建，所以不能靠「进入页面刷新」；
/// 对话落库成功后在这里敲一下，首页收到就重读当天记录。
class DfMoodToday extends ChangeNotifier {
  DfMoodToday._();

  static final DfMoodToday instance = DfMoodToday._();

  void recordAdded() => notifyListeners();
}

import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import 'package:dreamflow/data/db.dart';
import 'package:dreamflow/data/df_llm.dart';
import 'package:dreamflow/data/df_persona.dart';
import 'package:dreamflow/design_system/df_tokens.dart';
import 'package:dreamflow/design_system/df_type.dart';
import 'package:dreamflow/design_system/widgets/df_controls.dart';
import 'package:dreamflow/design_system/widgets/df_focus.dart';
import 'package:dreamflow/design_system/widgets/df_icons.dart';
import 'package:dreamflow/design_system/widgets/df_screen.dart';
import 'package:dreamflow/design_system/widgets/df_sheep.dart';
import 'package:dreamflow/design_system/widgets/df_states.dart';
import 'package:dreamflow/design_system/widgets/df_surfaces.dart';

/// 一条对话消息
class DfMessage {
  const DfMessage(this.text, {this.mine = false, this.emphasis, this.at});

  final String text;

  /// 我方（右对齐气泡）
  final bool mine;

  /// 需要强调的片段（渲染为 `--mist-green`，如呼吸引导）
  final String? emphasis;

  /// 消息时刻（历史回放用；引导开场为 null）
  final DateTime? at;
}

/// 会话引擎的裁决结果：回复文本 + 可选强调片段 + 可选 chip 更新
class _EngineReply {
  const _EngineReply(this.text, {this.emphasis, this.chips});

  final String text;

  /// 需要强调的片段（渲染为 `--mist-green`）
  final String? emphasis;

  /// 情绪 chip（null = 保持不变；提问 / 闲聊不应覆盖用户的情绪标签）
  final List<String>? chips;
}

/// §7 B 睡前情绪对话 —— **引导式、按天分会话**。
///
/// 与旧版（写死三条示例气泡）的区别：
/// - **进入即有引导**：当天第一次打开时，由梦洄主动开场（按时段换语气），
///   并给出 4 个可点的话题入口，用户不必先想「说什么」。
/// - **每天一个会话**：消息按自然日归属；跨天自动新开，昨天的不串到今天。
/// - **历史可回看**：右上「往期」→ 按天分组的对话列表 → 只读回放。
/// - **时间取系统**：顶部时刻与每条消息时间都来自 `DateTime.now()`，不写死。
/// - 视口底部保留 Tab 栏，随时可切到首页 / 助眠 / 我的。
class DfChatSession extends StatefulWidget {
  const DfChatSession({
    super.key,
    this.seed = const <DfMessage>[],
    this.replyDelay = const Duration(milliseconds: 1200),
    this.onEnterSleep,
    this.onTab,
    this.llm,
  });

  /// 开场消息（**测试注入口**；为空时走每日引导开场）
  final List<DfMessage> seed;

  /// 对方"正在输入"到回复落地的延时
  final Duration replyDelay;

  /// 进入 §7 C 沉浸助眠（交流两轮后出现「就去睡吧」出口）
  final VoidCallback? onEnterSleep;

  /// Tab 切换（0 首页 / 1 对话 / 2 助眠 / 3 我的）
  final ValueChanged<int>? onTab;

  /// 真实 LLM 客户端（M4）。null → 规则引擎虚拟回复（测试 / 离线兜底）。
  final DfLlmClient? llm;

  /// 模型上下文里的 system 消息由 [DfPersona.system] 运行时拼装
  /// （人格 +「此刻」时间 + 聊到第几轮），这里不再放静态字符串。
  /// 人设本身的约束见 `lib/data/df_persona.dart`。

  /// 引导话题：用户不想组织语言时，点一下就能开始
  static const List<String> topics = <String>[
    '今天有点累',
    '心里有事放不下',
    '就是睡不着',
    '不想说话，陪我待着',
  ];

  /// 按时段的引导开场（这就是「引导型对话」的第一句）。
  ///
  /// 每个时段两套说法，按日期奇偶轮换，避免每天打开都是同一句。
  static String greetingFor(DateTime now) {
    final int h = now.hour;
    final bool alt = now.day.isEven;
    if (h >= 5 && h < 11) {
      return alt
          ? '早上好。昨晚睡得还好吗？想说两句就说，不想说，我们也安静待一会儿。'
          : '早。刚醒的头几分钟脑子最容易翻旧账，先别急着看手机，跟我说一句就行。';
    }
    if (h >= 11 && h < 17) {
      return alt
          ? '下午好。这会儿心里还有什么挂着的事吗？说出来会轻一点。'
          : '下午了。白天按下去的那些，这会儿是不是又冒出来了？';
    }
    if (h >= 17 && h < 23) {
      return alt
          ? '晚上好。今天有什么放不下的，我们把它说完，再慢慢沉下去。'
          : '到晚上了。今天最想吐槽的是哪件事？先说它。';
    }
    return alt
        ? '还没睡着吗？不用强迫自己。跟我说说，现在脑子里在转的是什么。'
        : '这个点还醒着。别急，我也不催你睡，想说什么就说。';
  }

  @override
  State<DfChatSession> createState() => _DfChatSessionState();
}

class _DfChatSessionState extends State<DfChatSession> {
  final List<DfMessage> _messages = <DfMessage>[];
  final TextEditingController _input = TextEditingController();
  Timer? _replyTimer;
  Timer? _clock;
  bool _awaitingReply = false;
  bool _loading = true;

  /// 流式气泡的可见文本。用 [ValueNotifier] 而不是 setState：
  /// 每个 token 只重建这一个气泡，不重建整屏（否则长对话会明显掉帧，
  /// 体感上比模型本身还慢）。
  final ValueNotifier<String> _streamText = ValueNotifier<String>('');

  /// 是否正在流式输出（决定要不要渲染流式气泡）
  bool _streaming = false;

  /// 自动滚到底：流式增长时要一直能看到新字
  final ScrollController _scroll = ScrollController();
  Timer? _scrollTimer;
  bool _scrollPending = false;

  /// 引导话题条：仅当**今天还没说过话**时出现
  bool _showTopics = false;

  List<String> _chips = const <String>[];
  String? _errorText;

  /// 会话归属日（跨天检测用）
  late DateTime _sessionDay = _dayOf(DateTime.now());

  /// 本会话的对话关联 ID（应用自管；同一会话内复用）
  String _conversationId = 'df-00000000';

  /// 本次会话中用户是否发过消息（种子历史不计）
  bool _sentOnce = false;

  /// 今天已经聊过的轮数（喂给模型，避免每条回复都像刚认识）
  int get _rounds => _messages.where((DfMessage m) => m.mine).length;

  /// 是否已完成一轮对话（**本次会话**发过 + 已收到回复）——出现「就去睡吧」出口的条件。
  bool get _hadRound => _sentOnce && !_awaitingReply;

  static DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static String _dayKey(DateTime t) =>
      'df-${t.year}${t.month.toString().padLeft(2, '0')}${t.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _conversationId = _dayKey(_sessionDay);
    _clock = Timer.periodic(const Duration(seconds: 30), (_) => _tickClock());
    _streamText.addListener(_scheduleScrollToBottom);
    // 预热云端连接：首次发消息少一次 RTT（失败无副作用）
    widget.llm?.warmUp();
    _bootstrap();
  }

  @override
  void dispose() {
    _replyTimer?.cancel();
    _clock?.cancel();
    _scrollTimer?.cancel();
    _streamText.dispose();
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  /// 首次进入：恢复今天的会话；今天还没有消息 → 用引导开场新开一段
  Future<void> _bootstrap() async {
    if (widget.seed.isNotEmpty) {
      setState(() {
        _messages.addAll(widget.seed);
        _loading = false;
        _showTopics = false;
      });
      return;
    }

    List<ChatMessage> rows = const <ChatMessage>[];
    try {
      rows = await DreamFlowDb.instance
          .messagesOnDay(_sessionDay)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // 本地库不可用时仍然给出引导开场，保证陪伴不中断
    }

    if (!mounted) return;
    setState(() {
      _messages.clear();
      if (rows.isEmpty) {
        _messages.add(DfMessage(DfChatSession.greetingFor(DateTime.now())));
        _showTopics = true;
      } else {
        for (final ChatMessage m in rows) {
          _messages.add(DfMessage(m.body, mine: m.mine, at: m.createdAt));
        }
        final bool askedToday = rows.any((ChatMessage m) => m.mine);
        _showTopics = !askedToday;
        _sentOnce = askedToday;
      }
      _loading = false;
    });
    // 恢复今天的记录后直接停在最新一条
    _scheduleScrollToBottom();
  }

  /// 每 30s 走一次：刷新顶部时刻；跨过零点则自动新开一天的会话
  void _tickClock() {
    if (!mounted) return;
    final DateTime now = DateTime.now();
    if (_dayOf(now) != _sessionDay) {
      setState(() {
        _sessionDay = _dayOf(now);
        _conversationId = _dayKey(_sessionDay);
        _messages.clear();
        _chips = const <String>[];
        _sentOnce = false;
        _showTopics = true;
        _loading = false;
        _messages.add(DfMessage(DfChatSession.greetingFor(now)));
      });
      return;
    }
    setState(() {}); // 只为刷新 header 上的时刻
  }

  /// §12 缺口 3：空内容发起时走 field 错误态，而不是静默丢弃
  void _send() {
    // 上一条还在流式输出时不接新消息，避免两个回复交错
    if (_awaitingReply) return;
    final String text = _input.text.trim();
    if (text.isEmpty) {
      setState(() => _errorText = '至少说一句话');
      return;
    }
    setState(() {
      _errorText = null;
      _sentOnce = true;
      _showTopics = false;
      _messages.add(DfMessage(text, mine: true, at: DateTime.now()));
      _awaitingReply = true;
    });
    _input.clear();

    final DfLlmClient? llm = widget.llm;
    if (llm != null) {
      _sendViaLlm(llm, text);
    } else {
      // 规则引擎（离线 / 测试）：情绪命中即更新 chip
      final _EngineReply reply = _engine(text);
      if (reply.chips != null) {
        setState(() => _chips = reply.chips!);
      }
      _replyTimer?.cancel();
      _replyTimer = Timer(widget.replyDelay, () {
        if (!mounted) return;
        setState(() {
          _awaitingReply = false;
          _messages.add(DfMessage(
            reply.text,
            emphasis: reply.emphasis,
            at: DateTime.now(),
          ));
        });
        _scheduleScrollToBottom();
      });
    }
  }

  /// 点引导话题 → 相当于用户说了这句
  void _sendTopic(String topic) {
    _input.text = topic;
    _send();
  }

  // ── 滚动跟随 ──────────────────────────────────────────────────────────
  //
  // 流式输出时内容一直在长，如果不跟着滚，"新字"落在屏幕外，用户会以为
  // 卡住了 —— 这是体感「慢」的一大来源，比模型本身更影响观感。

  void _scheduleScrollToBottom() {
    if (!mounted || _scrollPending) return;
    _scrollPending = true;
    _scrollTimer?.cancel();
    // 80ms 合并一次，避免每个 token 都触发一次布局
    _scrollTimer = Timer(const Duration(milliseconds: 80), () {
      _scrollPending = false;
      if (!mounted || !_scroll.hasClients) return;
      final double target = _scroll.position.maxScrollExtent;
      if ((_scroll.offset - target).abs() < 4) return;
      _scroll.jumpTo(target);
    });
  }

  // ── M4：真实模型链路 ──────────────────────────────────────────────────

  Future<void> _sendViaLlm(DfLlmClient llm, String userText) async {
    // ── 关键路径上只做一件事：把请求发出去 ──────────────────────────────
    //
    // 上下文直接从内存里的 [_messages] 拼（本轮用户消息已在 _send 里入列），
    // 不再等数据库 —— 旧实现先 await 查库、再 await 落库，然后才发请求，
    // 冷启动时白等几百毫秒。落库改成 fire-and-forget。
    final List<DfLlmMessage> context = _buildContext();
    _persistChat(mine: true, text: userText);
    setState(() {
      _streaming = true;
      _streamText.value = '';
    });
    _scheduleScrollToBottom();

    final StringBuffer acc = StringBuffer();
    try {
      await for (final String delta
          in llm.chat(messages: context, conversationId: _conversationId)) {
        if (!mounted) break; // 用户切走页面 → 停止渲染（notifier 已销毁）
        acc.write(delta);
        // 只推进 notifier，不触发整屏重建
        _streamText.value = DfPersona.hidePartialTag(acc.toString());
      }
      if (!mounted) return;
      await _finishLlmReply(acc.toString());
    } on DfLlmException catch (e) {
      if (acc.isEmpty) {
        // 一个字都没到 → 规则引擎兜底，保证陪伴不中断
        await _finishLlmReply(null, fallback: _engine(userText), error: e.message);
      } else {
        // 已有部分回复 → 保留已渲染文本，仅提示
        await _finishLlmReply(acc.toString(),
            error: '${e.message}（以上内容已保留）');
      }
    } catch (_) {
      await _finishLlmReply(
        acc.isEmpty ? null : acc.toString(),
        fallback: acc.isEmpty ? _engine(userText) : null,
        error: '网络出了点状况',
      );
    }
  }

  /// 从内存消息拼上下文：system（人格 + 此刻 + 轮数）+ 最近 20 条。
  ///
  /// 只取最近 20 条是为了控制 prefill 体积（体积直接影响首字延迟），
  /// 20 条足够覆盖一晚的睡前对话。
  List<DfLlmMessage> _buildContext() {
    const int keep = 20;
    final List<DfMessage> recent = _messages.length > keep
        ? _messages.sublist(_messages.length - keep)
        : _messages;
    return <DfLlmMessage>[
      DfLlmMessage(
        'system',
        // _rounds 已包含本轮刚说的话，减 1 才是「之前聊过几轮」
        DfPersona.system(
          now: DateTime.now(),
          round: _rounds > 0 ? _rounds - 1 : 0,
        ),
      ),
      for (final DfMessage m in recent)
        if (m.text.trim().isNotEmpty)
          DfLlmMessage(m.mine ? 'user' : 'assistant', m.text),
    ];
  }

  /// 落库不阻塞对话（失败也不影响这一晚的陪伴）
  void _persistChat({required bool mine, required String text}) {
    DreamFlowDb.instance
        .addChatMessage(mine: mine, text: text)
        .timeout(const Duration(seconds: 3))
        .catchError((Object _) => 0);
  }

  /// 收尾：解析情绪标记 → chip + MoodRecords 落库；持久化助手消息；恢复输入
  Future<void> _finishLlmReply(
    String? text, {
    _EngineReply? fallback,
    String? error,
  }) async {
    String? emphasis;
    String shown = text ?? '';
    List<String>? chips;

    if (text != null) {
      final RegExpMatch? tag = DfPersona.moodTag.firstMatch(text);
      if (tag != null) {
        final String label = tag.group(1)!.trim();
        final String strength = tag.group(2)!;
        chips = label == '未知' ? null : <String>[label];
        shown = text.replaceFirst(tag.group(0)!, '').trim();
        if (label != '未知') {
          final int intensity =
              strength == '高' ? 5 : (strength == '中' ? 3 : 1);
          DreamFlowDb.instance
              .addMood(label, intensity)
              .timeout(const Duration(seconds: 3))
              .catchError((Object _) => 0);
        }
      }
    }

    if (fallback != null) {
      shown = fallback.text;
      emphasis = fallback.emphasis;
      if (chips == null && fallback.chips != null) chips = fallback.chips;
    }

    if (!mounted) return;
    setState(() {
      _streaming = false;
      _streamText.value = '';
      _awaitingReply = false;
      if (error != null) _errorText = error;
      if (shown.isNotEmpty) {
        _messages.add(DfMessage(shown, emphasis: emphasis, at: DateTime.now()));
      }
      if (chips != null) _chips = chips;
    });
    _scheduleScrollToBottom();

    if (text != null && shown.isNotEmpty) {
      _persistChat(mine: false, text: shown);
    }
  }


  // ───────────────────────────────────────────────────────────────────────
  // 会话引擎（确定性规则，不联网、不调模型；接真实 NLP 时只需替换 [_engine]）
  // ───────────────────────────────────────────────────────────────────────

  static final RegExp _questionPattern = RegExp(
    r'[?？]|你叫|名字|你是谁|你是|什么|怎么|为什么|能不能|可以吗|可以不|会不会|有没有|几点|多少|哪里|在哪|干嘛|干啥',
  );

  _EngineReply _engine(String text) {
    // ① 提问意图
    if (_questionPattern.hasMatch(text)) return _answerQuestion(text);

    // ② 情绪倾诉
    final List<String> moods = _moodHits(text);
    if (moods.isNotEmpty) {
      return _EngineReply(_moodReply(moods.first), chips: moods.take(2).toList());
    }

    // ③ 兜底：回声式共情
    return _EngineReply(
      '「${_quote(text)}」——我记下了。不用急着解释它，愿意的话，说说它是什么感受？',
    );
  }

  static bool _isAboutName(String text) =>
      RegExp('你叫|名字|你是梦洄|怎么称呼').hasMatch(text);

  _EngineReply _answerQuestion(String text) {
    if (_isAboutName(text)) {
      return _EngineReply(
        '我叫梦洄——「梦」是夜里的梦，「洄」是水的洄游，绕一圈、回到安静。今晚由我陪你。',
        emphasis: '梦洄',
      );
    }
    if (RegExp('你是谁|你能|干嘛|干啥|功能|怎么用|这是什么|这个app|这个软件').hasMatch(text)) {
      return _EngineReply(
        '我是你的睡前陪伴：先陪你把心里的事说完，再用音景和呼吸帮你沉下去。今晚想从哪件说起？',
        emphasis: '睡前陪伴',
      );
    }
    if (RegExp('几点|时间|钟点|现在多晚').hasMatch(text)) {
      return _EngineReply(
        '时间就按你手机走的来。今晚不用盯紧它——慢下来，才是这里唯一的日程。',
      );
    }
    return _EngineReply(
      '这个我先记下，不急着答——今晚我更擅长陪你把心放下。你刚说到「${_quote(text)}」，想多听一点。',
    );
  }

  /// 从原话中截取可引用的片段（去标点，最多 8 字）
  static String _quote(String text) {
    final String clean = text.replaceAll(RegExp(r'[，。！？、,.!?~…\s]'), '');
    if (clean.isEmpty) return '这句话';
    return clean.length <= 8 ? clean : clean.substring(0, 8);
  }

  /// 关键词 → 情绪命中（确定性规则；接真实模型时改这里）
  static const Map<String, List<String>> _moodRules = <String, List<String>>{
    '焦虑': <String>['焦虑', '紧张', '担心', '怕', '慌', '压力'],
    '疲惫': <String>['累', '疲惫', '没劲', '透支'],
    '入睡困难': <String>['睡不着', '失眠', '醒着', '躺了很久'],
    '低落': <String>['难过', '委屈', '低落', '想哭', '孤单'],
    '烦躁': <String>['烦', '生气', '火大', '忍不住'],
  };

  List<String> _moodHits(String text) {
    final List<String> hit = <String>[];
    for (final MapEntry<String, List<String>> e in _moodRules.entries) {
      if (e.value.any(text.contains)) hit.add(e.key);
    }
    return hit;
  }

  String _moodReply(String primary) {
    switch (primary) {
      case '焦虑':
        return '焦虑的时候，大脑会把「还没发生的事」当成正在发生。先把它写下来交给明天的你，今晚只负责呼吸。';
      case '疲惫':
        return '身体已经在替你踩刹车了。让肩膀沉下去，我陪你慢慢把节奏降下来。';
      case '入睡困难':
        return '不强迫入睡反而更快。跟着我数呼吸：一、二、三……走神了也没关系，回来就好。';
      case '低落':
        return '今晚不用解决它。我在这儿陪你坐一会儿，等重的东西先落地。';
      case '烦躁':
        return '烦躁是被压缩的能量。跟着我把呼气拉长到吸气的两倍，它就会慢慢松开。';
      default:
        return '我在这儿。不想说也没关系，我们就这样安静地待一会儿。';
    }
  }

  // ── 历史回看 ────────────────────────────────────────────────────────────

  Future<void> _openHistory() async {
    List<ChatMessage> rows = const <ChatMessage>[];
    try {
      rows = await DreamFlowDb.instance
          .latestMessages(limit: 400)
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
    if (!mounted) return;
    final DfPalette p = DfPalette.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DfRadius.card)),
      ),
      builder: (BuildContext ctx) => FractionallySizedBox(
        heightFactor: 0.74,
        child: _HistorySheet(rows: rows),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    final DateTime now = DateTime.now();

    return DfScreenScaffold(
      scrollController: _scroll,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // ── 会话头 ──────────────────────────────────────────────
          Row(
            children: <Widget>[
              const DfAvatar(diameter: 38, sheepHeight: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('梦洄', style: DfType.body(context, p.text)),
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: p.mistGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _awaitingReply ? '正在想…' : '在线 · 陪你入睡',
                          style: DfType.caption(context, p.text2),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  // 时刻取系统时间，每 30s 刷新
                  Text(_hhmm(now), style: DfType.caption(context, p.text3)),
                  const SizedBox(height: 2),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _openHistory,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      child: Text('往期 ›', style: DfType.caption(context, p.text3)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_loading)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: DfStateSwitch(
                kind: DfStateKind.loading,
                child: const SizedBox.shrink(),
              ),
            )
          else ...<Widget>[
            for (int i = 0; i < _messages.length; i++) ...<Widget>[
              _bubbleOf(_messages[i]),
              const SizedBox(height: 12),
            ],

            // 流式气泡：只有它自己监听 notifier，整屏不跟着重建
            if (_streaming) ...<Widget>[
              _StreamBubble(text: _streamText),
              const SizedBox(height: 12),
            ],

            // 引导话题：今天还没开口时出现，点一下就发送
            if (_showTopics && !_awaitingReply) ...<Widget>[
              const SizedBox(height: 2),
              Text('不想打太多字的话，从这儿挑一句：',
                  style: DfType.caption(context, p.text3)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final String topic in DfChatSession.topics)
                    _TopicChip(label: topic, onTap: () => _sendTopic(topic)),
                ],
              ),
              const SizedBox(height: 4),
            ],

            // 情绪卡：识别到才出现（首次进入不占屏）
            if (_chips.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              DfCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('此刻识别到的情绪',
                        style: DfType.bodyS(context, p.text2)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (int i = 0; i < _chips.length; i++)
                          DfChip(label: _chips[i], selected: i == 0),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // 完成一轮对话后给出「去睡」出口：对话不是无限聊天，终点是入睡
            if (_hadRound && widget.onEnterSleep != null) ...<Widget>[
              const SizedBox(height: 14),
              const _SleepExitHint(),
              const SizedBox(height: 12),
              DfCloudButton(
                label: '就去睡吧',
                height: DfTouch.secondaryH,
                onPressed: widget.onEnterSleep,
              ),
            ],
          ],
        ],
      ),
      bottomFullBleed: true,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DfSpace.padX),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: DfField(
                    hint: '说点什么…',
                    controller: _input,
                    errorText: _errorText,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 10),
                DfIconButton(
                  glyph: DfGlyph.mic,
                  semanticLabel: '按住说话',
                  onPressed: _send,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // §11 该注脚必须保留
          Text(
            '内容仅用于情绪陪伴，不构成医疗建议',
            textAlign: TextAlign.center,
            style: DfType.caption(context, p.text3),
          ),
          const SizedBox(height: 2),
          // Tab 栏：对话页也需要能切走，不能把用户困在这儿
          DfTabs(
            currentIndex: 1,
            onTap: widget.onTab,
            items: const <DfTabItem>[
              DfTabItem(DfGlyph.home, '首页'),
              DfTabItem(DfGlyph.chat, '对话'),
              DfTabItem(DfGlyph.moon, '助眠'),
              DfTabItem(DfGlyph.profile, '我的'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bubbleOf(DfMessage m) {
    if (m.emphasis == null || !m.text.contains(m.emphasis!)) {
      return DfBubble(text: m.text, mine: m.mine);
    }
    // 含强调片段 → 富文本气泡。强调片段可在句中任意位置（如自我介绍里的名字），
    // 按 emphasis 切成前 / 强调 / 后三段，而不是只截头部。
    final List<String> parts = m.text.split(m.emphasis!);
    final DfPalette p = DfPalette.of(context);
    final TextStyle base = DfType.bubble(context, p.text);
    final TextStyle strong = DfType.bubble(context, p.mistGreen);
    final List<InlineSpan> spans = <InlineSpan>[
      if (parts.first.isNotEmpty) TextSpan(text: parts.first, style: base),
      TextSpan(text: m.emphasis, style: strong),
      if (parts.length > 1 && parts.last.isNotEmpty)
        TextSpan(text: parts.skip(1).join(m.emphasis!), style: base),
    ];
    return DfBubble(
      // `text` 为 required；走富文本分支时传空串，仅用 [rich]
      text: '',
      rich: TextSpan(children: spans),
    );
  }
}

/// 正在流式输出的气泡。
///
/// 独立成 StatefulWidget 之外的关键：它只订阅 [_streamText]，
/// 每个 token 只重绘本气泡，整屏（头部、Tab、历史气泡）不参与重建。
class _StreamBubble extends StatelessWidget {
  const _StreamBubble({required this.text});

  final ValueListenable<String> text;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    return ValueListenableBuilder<String>(
      valueListenable: text,
      builder: (BuildContext c, String v, Widget? _) {
        if (v.isEmpty) {
          // 等第一个 token 的那一两秒也要有反馈，否则像卡住了
          return DfBubble(
            text: '·  ·  ·',
            rich: TextSpan(
              text: '·  ·  ·',
              style: DfType.bubble(context, p.text3),
            ),
          );
        }
        return DfBubble(text: v);
      },
    );
  }
}

/// 引导话题 chip（可点即发，弱化边框，让「挑一句」比「打字」更轻）
class _TopicChip extends StatelessWidget {
  const _TopicChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    return DfFocusRing(
      radius: DfRadius.pill,
      onActivate: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: p.mistBlue.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(DfRadius.pill),
            border: Border.all(color: p.mistBlue.withValues(alpha: 0.28)),
          ),
          child: Text(label, style: DfType.chip(context, p.text2)),
        ),
      ),
    );
  }
}

/// 往期会话：按自然日分组 → 点某天只读回放
class _HistorySheet extends StatefulWidget {
  const _HistorySheet({required this.rows});

  final List<ChatMessage> rows;

  @override
  State<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<_HistorySheet> {
  DateTime? _openDay;

  static const List<String> _week = <String>['一', '二', '三', '四', '五', '六', '日'];

  String _label(DateTime d) {
    final DateTime today = DateTime.now();
    final int diff = DateTime(today.year, today.month, today.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
    final String base = '${d.month}月${d.day}日 · 周${_week[d.weekday - 1]}';
    if (diff == 0) return '今天 · $base';
    if (diff == 1) return '昨天 · $base';
    return base;
  }

  Map<DateTime, List<ChatMessage>> _grouped() {
    final Map<DateTime, List<ChatMessage>> out = <DateTime, List<ChatMessage>>{};
    for (final ChatMessage m in widget.rows) {
      final DateTime d =
          DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);
      out.putIfAbsent(d, () => <ChatMessage>[]).add(m);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    final Map<DateTime, List<ChatMessage>> grouped = _grouped();
    final List<DateTime> days = grouped.keys.toList()
      ..sort((DateTime a, DateTime b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Row(
            children: <Widget>[
              if (_openDay != null) ...<Widget>[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _openDay = null),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Text('‹ 返回', style: DfType.caption(context, p.text2)),
                  ),
                ),
              ],
              Expanded(
                child: Text(
                  _openDay == null ? '往期对话' : _label(_openDay!),
                  style: DfType.titleS(context, p.text),
                ),
              ),
              Text(
                _openDay == null
                    ? '${days.length} 天'
                    : '${grouped[_openDay!]?.length ?? 0} 条',
                style: DfType.caption(context, p.text3),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(height: 1, color: p.line),
        ),
        Expanded(
          child: _openDay == null
              ? _dayList(p, grouped, days)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  itemCount: grouped[_openDay!]!.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (BuildContext c, int i) {
                    final ChatMessage m = grouped[_openDay!]![i];
                    return Column(
                      crossAxisAlignment: m.mine
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: <Widget>[
                        DfBubble(text: m.body, mine: m.mine),
                        const SizedBox(height: 3),
                        Text(
                          '${m.createdAt.hour.toString().padLeft(2, '0')}:'
                          '${m.createdAt.minute.toString().padLeft(2, '0')}',
                          style: DfType.caption(context, p.text3),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _dayList(
    DfPalette p,
    Map<DateTime, List<ChatMessage>> grouped,
    List<DateTime> days,
  ) {
    if (days.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '还没有往期对话。今晚聊过之后，这里会留下痕迹。',
            textAlign: TextAlign.center,
            style: DfType.bodyS(context, p.text2),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: days.length,
      separatorBuilder: (_, __) => Container(height: 1, color: p.line),
      itemBuilder: (BuildContext c, int i) {
        final DateTime d = days[i];
        final List<ChatMessage> rows = grouped[d]!;
        final ChatMessage? firstMine = rows.cast<ChatMessage?>().firstWhere(
              (ChatMessage? m) => m!.mine,
              orElse: () => null,
            );
        final String excerpt = (firstMine?.body ?? rows.first.body)
            .replaceAll(RegExp(r'\s+'), ' ');
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _openDay = d),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(_label(d), style: DfType.bodyS(context, p.text)),
                      const SizedBox(height: 5),
                      Text(
                        excerpt.length <= 22
                            ? excerpt
                            : '${excerpt.substring(0, 22)}…',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DfType.caption(context, p.text3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text('${rows.length} 条', style: DfType.caption(context, p.text3)),
                const SizedBox(width: 6),
                Text('›', style: DfType.caption(context, p.text3)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 出口提示卡（§7 C 的前导说明）
class _SleepExitHint extends StatelessWidget {
  const _SleepExitHint();

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    return DfCard(
      borderColor: p.mistGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('可以放下今天了', style: DfType.bodyS(context, p.text)),
          const SizedBox(height: 8),
          Text(
            '我按你此刻的情绪，生成了一份专属音景。现在就去躺着听吧。',
            style: DfType.caption(context, p.text2),
          ),
        ],
      ),
    );
  }
}

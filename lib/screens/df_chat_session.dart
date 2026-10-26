import 'dart:async';

import 'package:flutter/material.dart';

import 'package:dreamflow/data/db.dart';
import 'package:dreamflow/data/df_llm.dart';
import 'package:dreamflow/design_system/df_tokens.dart';
import 'package:dreamflow/design_system/df_type.dart';
import 'package:dreamflow/design_system/widgets/df_controls.dart';
import 'package:dreamflow/design_system/widgets/df_icons.dart';
import 'package:dreamflow/design_system/widgets/df_screen.dart';
import 'package:dreamflow/design_system/widgets/df_sheep.dart';
import 'package:dreamflow/design_system/widgets/df_surfaces.dart';
import 'package:dreamflow/screens/df_chat_screen.dart';

/// 一条对话消息
class DfMessage {
  const DfMessage(this.text, {this.mine = false, this.emphasis});

  final String text;

  /// 我方（右对齐气泡）
  final bool mine;

  /// 需要强调的片段（渲染为 `--mist-green`，如呼吸引导）
  final String? emphasis;
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

/// §7 B 睡前情绪对话 —— **可交互版**。
///
/// 与静态稿 [DfChatScreen] 的关系：视觉规格一致（同款气泡 / chip / 输入区 / 免责注脚），
/// 只是把写死的三条示例气泡换成会话状态：
/// - 输入并发送 → 我方气泡上屏 → [llm] 非空时流式调真实模型（M4），否则走规则引擎
/// - 回复末尾的情绪标记解析为「此刻识别到的情绪」chip，并落 MoodRecords 表
/// - 对话历史持久化到 ChatMessages 表，作为后续轮次的模型上下文
/// - 交流两轮后给出「就去睡吧」出口（接入 §7 C 沉浸助眠）
///
/// 网络失败 / 无可用模型时回退到确定性规则引擎（不联网、不调用模型），
/// 并在输入区给出错误提示；保证离线时核心陪伴体验可用。
class DfChatSession extends StatefulWidget {
  const DfChatSession({
    super.key,
    this.seed = const <DfMessage>[],
    this.replyDelay = const Duration(milliseconds: 1200),
    this.onEnterSleep,
    this.chatTime = '22:41',
    this.llm,
  });

  /// 开场消息（缺省为设计稿示例三条）
  final List<DfMessage> seed;

  /// 对方"正在输入"到回复落地的延时
  final Duration replyDelay;

  /// 进入 §7 C 沉浸助眠（交流两轮后出现「就去睡吧」出口）
  final VoidCallback? onEnterSleep;
  final String chatTime;

  /// 真实 LLM 客户端（M4）。null → 规则引擎虚拟回复（测试 / 离线兜底）。
  final DfLlmClient? llm;

  /// 模型上下文里的 system 消息（B 屏人设 + 免责边界 + 情绪标记格式）
  static const String systemPrompt =
      '你是「梦洄」，睡前情绪陪伴应用里的虚拟伙伴。语气温柔、克制、口语化，每次回复不超过 80 字。'
      '原则：共情优先，不诊断、不给医疗建议；用户表达自我伤害念头时，温和地建议联系专业帮助。'
      '每次回复末尾必须另起一行输出情绪识别结果，格式严格为：【情绪:标签·强度:低|中|高】，'
      '标签从 焦虑/疲惫/低落/烦躁/入睡困难/平静 中选最贴切的一个，无法判断时用【情绪:未知·强度:中】。';

  /// 设计稿示例开场（§7 B）
  static const List<DfMessage> opening = <DfMessage>[
    DfMessage('看起来今天有些累呢，愿意和我说说，今天发生了什么让你放不下的事吗？'),
    DfMessage('工作上有点急，脑子里停不下来。', mine: true),
    DfMessage(
      '我懂的。那我们先不解决问题——跟着我，吸气四拍，再用更长的六拍呼出去，重复三次。',
      emphasis: '吸气四拍，再用更长的六拍呼出去，重复三次。',
    ),
  ];

  @override
  State<DfChatSession> createState() => _DfChatSessionState();
}

class _DfChatSessionState extends State<DfChatSession> {
  late final List<DfMessage> _messages;
  final TextEditingController _input = TextEditingController();
  Timer? _replyTimer;
  bool _awaitingReply = false;
  List<String> _chips = const <String>['焦虑', '疲惫'];
  String? _errorText;
  StreamSubscription<String>? _replySub;

  /// 本会话的对话关联 ID（应用自管；同一会话内复用）
  late final String _conversationId =
      'df-${DateTime.now().microsecondsSinceEpoch}';

  /// 本次会话中用户是否发过消息（种子历史不计）
  bool _sentOnce = false;

  /// 是否已完成一轮对话（**本次会话**发过 + 已收到回复）——出现「就去睡吧」出口的条件。
  /// 只认本次动作：种子历史里虽有我方气泡，但用户还没开口就不该诱导离开。
  bool get _hadRound => _sentOnce && !_awaitingReply;

  @override
  void initState() {
    super.initState();
    _messages = List<DfMessage>.of(
      widget.seed.isEmpty ? DfChatSession.opening : widget.seed,
    );
  }

  @override
  void dispose() {
    _replySub?.cancel();
    _replyTimer?.cancel();
    _input.dispose();
    super.dispose();
  }

  /// §12 缺口 3：空内容发起时走 field 错误态，而不是静默丢弃
  void _send() {
    final String text = _input.text.trim();
    if (text.isEmpty) {
      setState(() => _errorText = '至少说一句话');
      return;
    }
    setState(() {
      _errorText = null;
      _sentOnce = true;
      _messages.add(DfMessage(text, mine: true));
      _awaitingReply = true;
    });
    _input.clear();

    final DfLlmClient? llm = widget.llm;
    if (llm != null) {
      _replySub?.cancel();
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
          _messages.add(DfMessage(reply.text, emphasis: reply.emphasis));
        });
      });
    }
  }

  // ── M4：真实模型链路 ──────────────────────────────────────────────────

  /// 情绪标记（回复末尾）：【情绪:标签·强度:低|中|高】
  static final RegExp _moodTagPattern =
      RegExp(r'【情绪[:：]([^·|】]+)·\s*强度[:：](低|中|高)】');

  Future<void> _sendViaLlm(DfLlmClient llm, String userText) async {
    // 历史持久化 + 上下文（本地库是上下文来源；失败不阻塞对话）
    List<DfLlmMessage> context = <DfLlmMessage>[
      const DfLlmMessage('system', DfChatSession.systemPrompt),
      DfLlmMessage('user', userText),
    ];
    try {
      final List<ChatMessage> recent = await DreamFlowDb.instance
          .recentMessages(limit: 12)
          .timeout(const Duration(seconds: 2), onTimeout: () => <ChatMessage>[]);
      if (recent.isNotEmpty) {
        context = <DfLlmMessage>[
          const DfLlmMessage('system', DfChatSession.systemPrompt),
          for (final ChatMessage m in recent)
            DfLlmMessage(m.mine ? 'user' : 'assistant', m.body),
          DfLlmMessage('user', userText),
        ];
      }
      await DreamFlowDb.instance
          .addChatMessage(mine: true, text: userText)
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      // 本地库不可用不阻断对话
    }

    // 占位气泡，流式追加
    final int bubbleIndex = _messages.length;
    setState(() => _messages.add(const DfMessage('')));
    final StringBuffer acc = StringBuffer();

    try {
      await for (final String delta
          in llm.chat(messages: context, conversationId: _conversationId)) {
        acc.write(delta);
        if (mounted) {
          setState(() => _messages[bubbleIndex] = DfMessage(acc.toString()));
        }
      }
      await _finishLlmReply(acc.toString(), bubbleIndex: bubbleIndex);
    } on DfLlmException catch (e) {
      if (acc.isEmpty) {
        // 一个字都没到 → 规则引擎兜底，保证陪伴不中断
        await _finishLlmReply(null,
            bubbleIndex: bubbleIndex, fallback: _engine(userText), error: e.message);
      } else {
        // 已有部分回复 → 保留已渲染文本，仅提示
        await _finishLlmReply(acc.toString(),
            bubbleIndex: bubbleIndex, error: '${e.message}（以上内容已保留）');
      }
    } catch (_) {
      await _finishLlmReply(
        acc.isEmpty ? null : acc.toString(),
        bubbleIndex: bubbleIndex,
        fallback: acc.isEmpty ? _engine(userText) : null,
        error: '网络出了点状况',
      );
    }
  }

  /// 收尾：解析情绪标记 → chip + MoodRecords 落库；持久化助手消息；恢复输入
  Future<void> _finishLlmReply(
    String? text, {
    required int bubbleIndex,
    _EngineReply? fallback,
    String? error,
  }) async {
    String? emphasis;
    String shown = text ?? '';
    List<String>? chips;

    if (text != null) {
      final RegExpMatch? tag = _moodTagPattern.firstMatch(text);
      if (tag != null) {
        final String label = tag.group(1)!.trim();
        final String strength = tag.group(2)!;
        chips = label == '未知' ? null : <String>[label];
        shown = text.replaceFirst(tag.group(0)!, '').trim();
        if (label != '未知') {
          final int intensity =
              strength == '高' ? 5 : (strength == '中' ? 3 : 1);
          try {
            await DreamFlowDb.instance
                .addMood(label, intensity)
                .timeout(const Duration(seconds: 2));
          } catch (_) {/* 落库失败不阻断 */}
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
      _awaitingReply = false;
      if (error != null) _errorText = error;
      // 占位气泡（无论真实回复还是兜底回复）都原位替换
      if (shown.isNotEmpty) {
        _messages[bubbleIndex] = DfMessage(shown, emphasis: emphasis);
      }
      if (chips != null) _chips = chips;
    });

    if (text != null && shown.isNotEmpty) {
      try {
        await DreamFlowDb.instance
            .addChatMessage(mine: false, text: shown)
            .timeout(const Duration(seconds: 2));
      } catch (_) {/* 落库失败不阻断 */}
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // 会话引擎（确定性规则，不联网、不调模型；接真实 NLP 时只需替换 [_engine]）
  //
  // 分诊顺序：**提问 → 情绪 → 兜底**。
  // 用户在问问题（如「你叫什么名字」）时绝不能用情绪模板去答——那等于自说自话。
  // 兜底也不是模板句，而是回声式共情：引用用户原话，把话题还给用户。
  // ───────────────────────────────────────────────────────────────────────

  /// 引擎裁决结果：回复文本 + 可选的强调片段 + 可选的 chip 更新
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
    // 其余问题：承认边界，把话题接回用户身上（而不是硬答）
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

  /// 情绪回复（同一主情绪稳定同一句，便于测试断言）
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

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);

    return DfScreenScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const DfAvatar(diameter: 38, sheepHeight: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '梦洄',
                      style: DfType.bodyS(context, p.text).copyWith(fontSize: 16),
                    ),
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
              Text(widget.chatTime, style: DfType.caption(context, p.text3)),
            ],
          ),
          const SizedBox(height: 22),
          for (int i = 0; i < _messages.length; i++) ...<Widget>[
            _bubbleOf(_messages[i]),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 4),
          DfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '此刻识别到的情绪',
                  style: DfType.bodyS(context, p.text2),
                ),
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
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
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
          const SizedBox(height: 12),
          // §11 该注脚必须保留
          Text(
            '内容仅用于情绪陪伴，不构成医疗建议',
            textAlign: TextAlign.center,
            style: DfType.caption(context, p.text3),
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

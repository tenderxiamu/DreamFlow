import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cloud_config.dart';

/// M4：WorkBuddy 云服务 LLM 客户端（Flutter 无 JS SDK，走同协议 REST）。
///
/// 协议要点（与服务端 SDK `@tencent-ai/workbuddy-cloud-sdk` 完全一致）：
/// - 鉴权：`x-wb-webapp-access-key: <publishableKey>`（应用级公开标识，免模型密钥）
/// - 仅支持流式（`stream: true`），SSE `data:` 帧逐段吐 `choices[0].delta.content`
/// - 会话关联：`X-Conversation-ID` 头（应用自管 ID，仅用于路由/计量关联）
/// - messages[0] 必须是 system 消息（由调用方保证）
///
/// ## M6.7 提速改造（为什么这么写）
///
/// 旧实现有三个串在关键路径上的等待，首字延迟被硬生生拉长：
/// 1. `await listModels()` —— 每次冷启动第一条消息都多一次 RTT；
/// 2. 服务端默认模型是 `auto`，它是 **high 档推理模型**：实测 19 秒吐不出一个
///    content token（全花在 reasoning 上）。这是「回复特别慢」的主因；
/// 3. 调用方在发请求前还串了两次数据库 await。
///
/// 现在：模型固定为实测最快的对话模型（见 [defaultModel]），不再查模型表；
/// 主模型不可用时自动降级到 [fallbackModel]，只重试一次。
class DfLlmMessage {
  const DfLlmMessage(this.role, this.content);

  final String role; // system | user | assistant
  final String content;
}

class DfLlmException implements Exception {
  DfLlmException(this.code, this.message);

  /// 与 SDK 错误码前缀对齐：request_ / auth_ / quota_ / gateway_ / model_ / internal_
  final String code;
  final String message;

  /// 换模型重试还有意义吗（模型下线 / 参数不被接受都算）
  bool get retryableWithAnotherModel =>
      code.startsWith('model_') || code.startsWith('internal_http_4');

  @override
  String toString() => 'DfLlmException($code): $message';
}

class DfLlmClient {
  DfLlmClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// 主模型：glm-5.3-flash。
  ///
  /// 2026-10 实测（6 轮真实睡前对话，含共情 / 极短回复 / 事实问答 / 建议）：
  /// 首字 2.2-2.3s、整段 2.7-4.0s，回复具体、不套模板，是质量与速度的最优点。
  static const String defaultModel = 'glm-5.3-flash';

  /// 兜底模型：实测首字更快（~1.8s），文风略平，仅在主模型不可用时使用。
  static const String fallbackModel = 'minimax-m3';

  /// 输出上限。人设要求 ≤120 字（危机话术可更长），320 token 足够，
  /// 同时把最坏耗时兜住，避免模型越写越长把「慢」写回来。
  static const int defaultMaxTokens = 320;

  List<String>? _cachedModels;

  /// 预热：提前把模型表（顺带 TLS 连接）拉起来，让用户第一次发消息时少一次 RTT。
  /// 失败无所谓，纯优化，不抛出。
  Future<void> warmUp() async {
    try {
      await listModels().timeout(const Duration(seconds: 8));
    } catch (_) {/* 预热失败不影响对话 */}
  }

  /// 可用模型列表（首个成功请求后缓存）。空列表是合法结果。
  Future<List<String>> listModels() async {
    final List<String>? cached = _cachedModels;
    if (cached != null) return cached;
    final http.Response resp = await _client.get(
      Uri.parse('${DfCloudConfig.endpoint}${DfCloudConfig.llmModelsPath}'),
      headers: <String, String>{
        'x-wb-webapp-access-key': DfCloudConfig.publishableKey,
      },
    );
    if (resp.statusCode != 200) {
      throw DfLlmException('internal_http_${resp.statusCode}', '模型列表请求失败');
    }
    final dynamic body = jsonDecode(utf8.decode(resp.bodyBytes));
    final List<dynamic> items =
        body is List ? body : (body['models'] as List<dynamic>? ?? <dynamic>[]);
    final List<String> ids = <String>[
      for (final dynamic m in items)
        if (m is Map && m['disabled'] != true && m['id'] != null) m['id'] as String,
    ];
    _cachedModels = ids;
    return ids;
  }

  /// 流式对话：逐段 yield 增量文本，直到 [DONE]。
  ///
  /// 网络中断 / 非 2xx / 帧解析失败抛 [DfLlmException]；已产出的片段由调用方保留。
  /// 主模型报「模型不可用」且一个字都还没吐时，自动换 [fallbackModel] 重试一次。
  Stream<String> chat({
    required List<DfLlmMessage> messages,
    String? conversationId,
    String? model,
    double temperature = 0.85,
    int maxTokens = defaultMaxTokens,
  }) async* {
    final String primary = model ?? defaultModel;
    bool emitted = false;
    try {
      await for (final String delta in _stream(
        messages: messages,
        conversationId: conversationId,
        model: primary,
        temperature: temperature,
        maxTokens: maxTokens,
      )) {
        emitted = true;
        yield delta;
      }
      return;
    } on DfLlmException catch (e) {
      final bool canRetry = !emitted && model == null && e.retryableWithAnotherModel;
      if (!canRetry) rethrow;
    }
    // 主模型不可用 → 兜底模型再来一次（此时仍未产出任何内容，用户无感）
    yield* _stream(
      messages: messages,
      conversationId: conversationId,
      model: fallbackModel,
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }

  /// 单次请求的 SSE 解析。
  Stream<String> _stream({
    required List<DfLlmMessage> messages,
    required String model,
    required double temperature,
    required int maxTokens,
    String? conversationId,
  }) async* {
    final http.Request req = http.Request(
      'POST',
      Uri.parse('${DfCloudConfig.endpoint}${DfCloudConfig.llmChatPath}'),
    );
    req.headers.addAll(<String, String>{
      'x-wb-webapp-access-key': DfCloudConfig.publishableKey,
      'Accept': 'text/event-stream',
      'Content-Type': 'application/json',
      if (conversationId != null) 'X-Conversation-ID': conversationId,
    });
    req.body = jsonEncode(<String, dynamic>{
      'model': model,
      'messages': <Map<String, String>>[
        for (final DfLlmMessage m in messages)
          <String, String>{'role': m.role, 'content': m.content},
      ],
      'stream': true,
      'temperature': temperature,
      'max_tokens': maxTokens,
    });

    final http.StreamedResponse resp;
    try {
      // 只等响应头；首个 token 由调用方按需计时（推理模型可能很久才吐字）
      resp = await _client.send(req).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw DfLlmException('gateway_timeout', '连接超时，请稍后再试');
    } catch (_) {
      throw DfLlmException('gateway_unreachable', '网络不可用');
    }
    if (resp.statusCode != 200) {
      throw DfLlmException(
        'internal_http_${resp.statusCode}',
        '服务暂时不可用（${resp.statusCode}）',
      );
    }

    await for (final String line in resp.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      final String trimmed = line.trim();
      if (trimmed.isEmpty || !trimmed.startsWith('data:')) continue;
      final String payload = trimmed.substring(5).trim();
      if (payload == '[DONE]') return;
      final dynamic frame;
      try {
        frame = jsonDecode(payload);
      } on FormatException {
        throw DfLlmException('gateway_invalid_response', '响应解析失败');
      }
      if (frame is Map && frame['error'] != null) {
        final dynamic err = frame['error'];
        throw DfLlmException(
          err is Map ? (err['code'] as String? ?? 'internal_error') : 'internal_error',
          err is Map ? (err['message'] as String? ?? '服务错误') : '服务错误',
        );
      }
      final dynamic choices = frame is Map ? frame['choices'] : null;
      if (choices is List && choices.isNotEmpty) {
        final dynamic delta = choices.first['delta'];
        final dynamic content = delta is Map ? delta['content'] : null;
        if (content is String && content.isNotEmpty) {
          yield content;
        }
      }
    }
    // 流结束但没收到 [DONE]：视为中断（保留已产出文本，由调用方提示重试）
    throw DfLlmException('gateway_stream_interrupted', '回复中断了，可以重新生成');
  }

  /// 一次性收集完整回复（结构化任务用；底层仍是流式）。
  Future<String> chatComplete({
    required List<DfLlmMessage> messages,
    String? conversationId,
    int maxTokens = 400,
  }) async {
    final StringBuffer buf = StringBuffer();
    await for (final String delta in chat(
      messages: messages,
      conversationId: conversationId,
      temperature: 0.2,
      maxTokens: maxTokens,
    )) {
      buf.write(delta);
    }
    return buf.toString();
  }

  void close() => _client.close();
}

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

  @override
  String toString() => 'DfLlmException($code): $message';
}

class DfLlmClient {
  DfLlmClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  List<String>? _cachedModels;

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
  Stream<String> chat({
    required List<DfLlmMessage> messages,
    String? conversationId,
    String? model,
    double temperature = 0.8,
  }) async* {
    final List<String> models = await listModels();
    if (models.isEmpty) {
      throw DfLlmException('model_empty', '暂无可用模型');
    }
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
      'model': model ?? models.first,
      'messages': <Map<String, String>>[
        for (final DfLlmMessage m in messages) <String, String>{'role': m.role, 'content': m.content},
      ],
      'stream': true,
      'temperature': temperature,
    });

    final http.StreamedResponse resp;
    try {
      resp = await _client.send(req).timeout(const Duration(seconds: 30));
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

    final StringBuffer sse = StringBuffer();
    await for (final String chunk in resp.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      final String line = chunk.trim();
      if (line.isEmpty || !line.startsWith('data:')) continue;
      final String payload = line.substring(5).trim();
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
          sse.write(content);
          yield content;
        }
      }
    }
    // 流结束但没收到 [DONE]：视为中断（保留已产出文本，由调用方提示重试）
    throw DfLlmException('gateway_stream_interrupted', '回复中断了，可以重新生成');
  }

  /// 一次性收集完整回复（情绪识别等结构化任务用；底层仍是流式）。
  Future<String> chatComplete({
    required List<DfLlmMessage> messages,
    String? conversationId,
  }) async {
    final StringBuffer buf = StringBuffer();
    await for (final String delta in chat(
      messages: messages,
      conversationId: conversationId,
      temperature: 0.2,
    )) {
      buf.write(delta);
    }
    return buf.toString();
  }

  void close() => _client.close();
}

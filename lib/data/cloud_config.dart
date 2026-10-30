import 'dart:convert';

/// WorkBuddy 云服务公开配置（publicConfig）。
///
/// 这两个值是**端用户可见的公开配置**：publishableKey 只标识应用、不带权限
/// （服务端做校验），允许随应用源码分发；真正的模型密钥全部在服务端。
/// 见 assets/ 说明与 cloud-service 模块文档。
///
/// ## M9.2 · 防拆包提取（2026-10-30）
///
/// publishableKey 本身「可以」公开，但**不该被一行命令拿走**——APK 里的明文
/// 字符串用 `strings` 一扫即得，任何人都零成本冒用应用身份刷积分额度。
/// 所以这里把 key 做**运行时拼装**：逐字节 XOR 掩码 → base64 → 切三段乱序
/// 存放，APK 里不存在完整明文。诚实说明威胁模型：
/// - **防得住**：`strings` / `grep` 级别的顺手提取（绝大多数冒用来自这里）；
/// - **防不住**：愿意花功夫 hook 运行时或反编译的定向逆向。对一个 x0.08
///   低价档的 key，这个成本收益比不成立——且服务端还有配额闸兜底
///   （超限返回 quota_ 错误，不会无限刷）。
/// - 真正的天花板在**控制台配额**：SDK 不暴露配额接口，用量异常请到
///   WorkBuddy 控制台查；如确认泄露，在控制台轮换 key 后随新版本分发。
class DfCloudConfig {
  const DfCloudConfig._();

  /// 云服务数据面入口（应用绑定，勿硬编码到其他应用）
  static const String endpoint = 'https://dreamflow-sleep.app.workbuddy.host';

  /// publishableKey 的存放形式：逐字节 XOR 0x37 后 base64，切三段乱序存放。
  /// 恢复顺序见 [_shuffleOrder]（存储第 i 段 = 原始第 [_shuffleOrder[i]] 段）。
  static const String _encPart1 = 'c1BbekdFdk1ibw5OX0VYVFhzdFJ8';
  static const String _encPart2 = 'QFVHXGhHYmJlTWNFTgZYeXJwXG';
  static const String _encPart3 = 'VibnV4ZW4CaFFVZXRBcH5wQHsH';

  static const List<int> _shuffleOrder = <int>[1, 2, 0];

  static const int _mask = 0x37;

  /// 应用公开标识。运行时拼装，结果恒定，首次访问算一次。
  static final String publishableKey = _assemble();

  static String _assemble() {
    final List<String> parts = <String>[_encPart1, _encPart2, _encPart3];
    final List<String> ordered = <String>[
      for (final int i in _shuffleOrder) parts[i],
    ];
    final List<int> bytes = base64Decode(ordered.join());
    return utf8.decode(<int>[for (final int b in bytes) b ^ _mask]);
  }

  /// LLM API 路径（OpenAI 兼容，仅流式）
  static const String llmChatPath = '/.cloud/llm/chat/completions';
  static const String llmModelsPath = '/.cloud/llm/models';
}

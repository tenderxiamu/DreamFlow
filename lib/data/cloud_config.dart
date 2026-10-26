/// WorkBuddy 云服务公开配置（publicConfig）。
///
/// 这两个值是**端用户可见的公开配置**：publishableKey 只标识应用、不带权限
/// （服务端做校验），允许随应用源码分发；真正的模型密钥全部在服务端。
/// 见 assets/ 说明与 cloud-service 模块文档。
class DfCloudConfig {
  const DfCloudConfig._();

  /// 云服务数据面入口（应用绑定，勿硬编码到其他应用）
  static const String endpoint = 'https://dreamflow-sleep.app.workbuddy.host';

  /// 应用公开标识
  static const String publishableKey =
      'wbpk_pUURzTry1oNEGkRUYBORY5_fbRCvGIGwL0DglMprAzUX9yhrocoDCeK';

  /// LLM API 路径（OpenAI 兼容，仅流式）
  static const String llmChatPath = '/.cloud/llm/chat/completions';
  static const String llmModelsPath = '/.cloud/llm/models';
}

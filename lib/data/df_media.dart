import 'package:flutter/services.dart';

/// M9 · 相册选图
///
/// 一条 MethodChannel 通到 `MainActivity`，选图、裁剪、压缩、落盘都在
/// 原生侧做完，这里只拿回一个**应用私有目录里**的 JPEG 路径：
/// - 头像：中心正方裁剪 512×512
/// - 壁纸：长边压到 1600 以内
///
/// 关于权限：用的是系统相册选择器（`ACTION_PICK`），应用全程只拿到一个
/// 带临时读授权的 URI，**不需要申请 `READ_MEDIA_IMAGES`**。
/// 这比弹一个权限框更尊重用户 —— 一次选图只给一张图的访问权，而不是整库。
///
/// 所有失败（取消、没有相册应用、解码失败）都返回 `null`，调用方据此提示。
class DfMedia {
  DfMedia._();

  static const MethodChannel _channel = MethodChannel('dreamflow/media');

  /// 打开系统相册选一张图。
  ///
  /// [forAvatar] = true 走头像处理（中心正方 512），
  /// false 走壁纸处理（长边 1600 保比例）。
  static Future<String?> pickImage({required bool forAvatar}) async {
    try {
      return await _channel.invokeMethod<String>(
        'pickImage',
        <String, dynamic>{'kind': forAvatar ? 'avatar' : 'wallpaper'},
      );
    } on MissingPluginException {
      // 测试环境 / 非 Android 平台
      return null;
    } on PlatformException {
      return null;
    }
  }
}

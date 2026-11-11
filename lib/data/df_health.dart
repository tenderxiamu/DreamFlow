import 'package:flutter/services.dart';

import 'health_sleep.dart';

/// 健康数据通道的当前状态。
enum DfHealthStatus {
  /// 这个平台 / 这台机器不支持（iOS 未接入、或未安装 Health Connect）
  unsupported,

  /// 支持，但数据源不可用（Health Connect 被停用）
  unavailable,

  /// Health Connect 需要更新
  needsUpdate,

  /// 可用，但用户还没授权
  denied,

  /// 已授权，可以直接读
  granted,
}

/// 一次读取的结果（状态 + 夜晚列表）。
class DfHealthSnapshot {
  const DfHealthSnapshot({required this.status, required this.nights});

  const DfHealthSnapshot.unsupported()
      : status = DfHealthStatus.unsupported,
        nights = const <DfMeasuredNight>[];

  final DfHealthStatus status;
  final List<DfMeasuredNight> nights;

  bool get readable => status == DfHealthStatus.granted;
}

/// M13 · 健康数据（只读）
///
/// 数据来源：系统健康库。Android 走 **Health Connect**，手环厂商 App
/// （小米运动健康 / 华为运动健康 / Zepp…）本来就会把睡眠分期写进去，
/// 我们只读、不写、不上传。
///
/// 三条边界（写作约束，别在后续迭代里被打破）：
/// 1. **只读**：不申请任何写入权限，不改用户的健康档案
/// 2. **不碰蓝牙、不开麦克风**：不做「手机自己猜睡眠」，那条路精度差且要吃权限
/// 3. **失败一律降级**：任何异常都退回 [DfHealthStatus.unsupported]，
///    报告继续用本机交互推算，绝不因为读不到健康数据而空转或报错
class DfHealth {
  DfHealth._();

  static const MethodChannel _channel = MethodChannel('dreamflow/health');

  /// 读一次健康库要跨线程、查数据库，报告屏可能在唤醒流程里连续构建，
  /// 这里缓存几分钟，避免同一次浏览重复读
  static const Duration _cacheTtl = Duration(minutes: 5);

  static List<DfMeasuredNight>? _cachedNights;
  static DateTime? _cachedAt;

  /// 当前状态（不做缓存：用户可能刚在系统里授权/撤销）
  static Future<DfHealthStatus> status() async {
    try {
      final Map<Object?, Object?>? raw =
          await _channel.invokeMethod<Map<Object?, Object?>>('status');
      if (raw == null) return DfHealthStatus.unsupported;
      final String state = (raw['state'] as String?) ?? 'unavailable';
      final bool granted = (raw['granted'] as bool?) ?? false;
      if (state != 'available') {
        return state == 'needsUpdate'
            ? DfHealthStatus.needsUpdate
            : DfHealthStatus.unavailable;
      }
      return granted ? DfHealthStatus.granted : DfHealthStatus.denied;
    } on MissingPluginException {
      return DfHealthStatus.unsupported;
    } on PlatformException {
      return DfHealthStatus.unsupported;
    }
  }

  /// 拉起系统的健康数据授权页。返回是否拿到读取权限。
  static Future<bool> requestPermission() async {
    try {
      final bool? ok =
          await _channel.invokeMethod<bool>('requestPermission');
      invalidate();
      return ok ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// 读最近 [days] 天的睡眠记录（已按夜聚合）。
  static Future<List<DfMeasuredNight>> recentNights({int days = 30}) async {
    final List<DfMeasuredNight>? cached = _cachedNights;
    final DateTime? at = _cachedAt;
    if (cached != null &&
        at != null &&
        DateTime.now().difference(at) < _cacheTtl) {
      return cached;
    }

    final DateTime end = DateTime.now();
    final DateTime start = end.subtract(Duration(days: days));
    try {
      final List<Object?>? raw = await _channel.invokeMethod<List<Object?>>(
        'readSleep',
        <String, dynamic>{
          'startMs': start.millisecondsSinceEpoch,
          'endMs': end.millisecondsSinceEpoch,
        },
      );
      final List<DfHealthSession> sessions = <DfHealthSession>[
        for (final Object? item in raw ?? const <Object?>[])
          if (item is Map) _parseSession(item),
      ];
      final List<DfMeasuredNight> nights = buildMeasuredNights(sessions);
      _cachedNights = nights;
      _cachedAt = DateTime.now();
      return nights;
    } on MissingPluginException {
      return const <DfMeasuredNight>[];
    } on PlatformException {
      return const <DfMeasuredNight>[];
    }
  }

  /// 一次拿齐状态与数据（报告聚合用；未授权时 nights 为空）。
  static Future<DfHealthSnapshot> snapshot({int days = 30}) async {
    final DfHealthStatus state = await status();
    if (state != DfHealthStatus.granted) {
      return DfHealthSnapshot(
        status: state,
        nights: const <DfMeasuredNight>[],
      );
    }
    final List<DfMeasuredNight> nights = await recentNights(days: days);
    return DfHealthSnapshot(status: state, nights: nights);
  }

  /// 授权变化 / 下拉刷新后调用
  static void invalidate() {
    _cachedNights = null;
    _cachedAt = null;
  }

  static DfHealthSession _parseSession(Map<Object?, Object?> raw) {
    final int startMs = (raw['start'] as num?)?.toInt() ?? 0;
    final int endMs = (raw['end'] as num?)?.toInt() ?? 0;
    final List<Object?> stageRaw = (raw['stages'] as List<Object?>?) ??
        const <Object?>[];

    final List<DfStageSpan> stages = <DfStageSpan>[];
    for (final Object? item in stageRaw) {
      if (item is! Map) continue;
      final int s = (item['start'] as num?)?.toInt() ?? 0;
      final int e = (item['end'] as num?)?.toInt() ?? 0;
      if (e <= s) continue;
      stages.add(DfStageSpan(
        start: DateTime.fromMillisecondsSinceEpoch(s),
        end: DateTime.fromMillisecondsSinceEpoch(e),
        kind: DfStageKind.fromHealthConnect(
          (item['stage'] as num?)?.toInt() ?? 7,
        ),
      ));
    }

    return DfHealthSession(
      start: DateTime.fromMillisecondsSinceEpoch(startMs),
      end: DateTime.fromMillisecondsSinceEpoch(endMs),
      stages: stages,
    );
  }
}

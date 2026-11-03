/// M12：危机干预配置（词表 + 热线）的远端热更新。
///
/// 为什么必须有这一层（对应评估报告遗留项 ⑤）：
/// `DfMood.crisisWords` 是编译进 APK 的 `const`，发现漏词 / 误报词只能发版，
/// 而危机干预的响应窗口是「小时级」的，不是「发版周期」级的。
///
/// ## 数据通道
///
/// 云服务 `crisis_config` 单行表（**仅 SELECT 授权**给 anon/authenticated，
/// 写只能走管理端 / 控制台）。客户端启动时拉一次，成功后写本地缓存；
/// 顺序为：**远端 → 上次缓存 → 内置底线词表**，任何一层失效都不影响判定。
///
/// ## 安全线（这条优先级高于一切灵活性）
///
/// - **底线词表不可移除**：远端配置只能「增加」词，`DfMood.crisisWords`
///   里的 17 个底线词永远参与判定——就算远端被人写坏甚至清空。
/// - **热线 12356 永远在场**：同理，远端热线列表是追加，不是替换。
/// - 远端 payload **逐字段校验**，任何一项不合法就整包拒绝，保持现状。
///
/// 测试注意：纯解析 / 合并逻辑全部是 static 纯函数，直接 `test()` 打；
/// 涉及 path_provider 的 IO 只在实例方法里，测试用 `cacheDir` 参数注入临时目录。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'cloud_config.dart';
import 'df_mood.dart';

/// 一条求助热线。
@immutable
class DfHotline {
  const DfHotline({required this.name, required this.number, this.note = ''});

  final String name;
  final String number;
  final String note;

  @override
  bool operator ==(Object other) =>
      other is DfHotline &&
      other.name == name &&
      other.number == number &&
      other.note == note;

  @override
  int get hashCode => Object.hash(name, number, note);
}

/// 校验通过的一份远端配置。
@immutable
class DfCrisisPayload {
  const DfCrisisPayload({required this.words, required this.hotlines});

  final List<String> words;
  final List<DfHotline> hotlines;
}

/// 拉取结果状态。
enum DfCrisisStatus {
  /// 尚未尝试（只用内置词表）
  idle,

  /// 拉取并应用成功
  ready,

  /// 用的是本地缓存（远端失败或无缓存）
  fromCache,

  /// 远端失败且无缓存，只用内置词表
  fallback,
}

class DfCrisisConfig extends ChangeNotifier {
  DfCrisisConfig._();

  static final DfCrisisConfig instance = DfCrisisConfig._();

  // ── 内置底线（永不被远端覆盖）───────────────────────────────────────────

  /// 底线词表：即 [DfMood.crisisWords]。
  static List<String> get floorWords => DfMood.crisisWords;

  /// 底线热线：12356 全国心理援助热线。
  static const DfHotline floorHotline = DfHotline(
    name: '全国心理援助热线',
    number: '12356',
    note: '7×24 小时',
  );

  // ── 当前生效状态 ───────────────────────────────────────────────────────

  List<String> _extraWords = const <String>[];
  List<DfHotline> _extraHotlines = const <DfHotline>[];

  DfCrisisStatus status = DfCrisisStatus.idle;
  int? version;
  DateTime? fetchedAt;

  /// 远端追加的词（底线词之外）。判定时与底线词表**取并集**。
  List<String> get extraWords => _extraWords;

  /// 当前完整词表（底线 + 远端追加），调试 / 报告页展示用。
  List<String> get words => <String>[...floorWords, ..._extraWords];

  /// 远端追加的热线（底线热线之外）。
  List<DfHotline> get extraHotlines => _extraHotlines;

  /// 横幅 / 回复里展示的主热线（底线热线恒为第一位）。
  DfHotline get primaryHotline => floorHotline;

  /// 全部热线（底线 + 远端追加）。
  List<DfHotline> get hotlines => mergeHotlines(_extraHotlines);

  /// 缓存文件名（getApplicationSupportDirectory 下）
  static const String _cacheFileName = 'crisis_config.json';

  /// 缓存有效期：超过这个时长还在用缓存，只影响 [status]，不阻断判定
  static const Duration cacheTtl = Duration(days: 3);

  bool get isCacheFresh =>
      fetchedAt != null && DateTime.now().difference(fetchedAt!) <= cacheTtl;

  // ── 纯函数：解析与校验（测试直接打这里）────────────────────────────────

  /// 校验并解析远端 payload。任何字段不合法 → null（整包拒绝，不做部分采纳）。
  static DfCrisisPayload? parseRemote(Object? payload) {
    if (payload is! Map<String, dynamic>) return null;
    return _parseMap(payload);
  }

  static DfCrisisPayload? _parseMap(Map<String, dynamic> m) {
    final Object? rawWords = m['words'];
    if (rawWords is! List) return null;
    if (rawWords.length > 200) return null;

    final Set<String> seen = <String>{};
    final List<String> words = <String>[];
    for (final Object? w in rawWords) {
      if (w is! String) return null;
      final String s = w.trim();
      // 太短会误伤（单字），太长不是「词」；含空白说明是想塞句子
      if (s.length < 2 || s.length > 12) return null;
      if (RegExp(r'[\s\u3000]').hasMatch(s)) return null;
      if (!seen.add(s)) continue;
      words.add(s);
    }
    if (words.isEmpty) return null;

    final Object? rawHotlines = m['hotlines'];
    if (rawHotlines is! List) return null;
    if (rawHotlines.isEmpty || rawHotlines.length > 20) return null;

    final List<DfHotline> hotlines = <DfHotline>[];
    final Set<String> seenNumbers = <String>{};
    for (final Object? h in rawHotlines) {
      if (h is! Map<String, dynamic>) return null;
      final Object? name = h['name'];
      final Object? number = h['number'];
      final Object? note = h['note'];
      if (name is! String || name.trim().isEmpty || name.length > 20) {
        return null;
      }
      // 号码：数字、连字符、空格；3-20 位。不校验真实性（离线做不到），只挡明显写坏
      if (number is! String || !RegExp(r'^[0-9][0-9\- ]{2,19}$').hasMatch(number)) {
        return null;
      }
      if (!seenNumbers.add(number)) continue;
      hotlines.add(DfHotline(
        name: name.trim(),
        number: number.trim(),
        note: note is String && note.length <= 30 ? note : '',
      ));
    }
    if (hotlines.isEmpty) return null;

    return DfCrisisPayload(words: words, hotlines: hotlines);
  }

  /// 底线词表 ∪ 远端词表（去重、底线在前、保序）。
  static List<String> mergeWords(List<String> remote) {
    final List<String> out = <String>[...floorWords];
    for (final String w in remote) {
      if (!out.contains(w)) out.add(w);
    }
    return out;
  }

  /// 底线热线 ∪ 远端热线（按号码去重，底线恒在首位）。
  static List<DfHotline> mergeHotlines(List<DfHotline> remote) {
    final List<DfHotline> out = <DfHotline>[floorHotline];
    for (final DfHotline h in remote) {
      if (!out.any((DfHotline e) => e.number == h.number)) out.add(h);
    }
    return out;
  }

  // ── 实例方法：缓存与拉取 ───────────────────────────────────────────────

  /// 应用启动时调用：把上次缓存读回来（无网络也能用远端词表）。
  ///
  /// [cacheDir] 测试注入；生产走 path_provider。
  Future<void> load({Directory? cacheDir}) async {
    try {
      final File f = await _cacheFile(cacheDir);
      if (!await f.exists()) return;
      final Map<String, dynamic> m =
          jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final DfCrisisPayload? p = parseRemote(m['payload']);
      if (p == null) return; // 缓存坏了就当没有
      _apply(
        payload: p,
        version: m['version'] is int ? m['version'] as int : null,
        fetchedAt:
            m['fetchedAt'] is String ? DateTime.tryParse(m['fetchedAt'] as String) : null,
        status: DfCrisisStatus.fromCache,
      );
    } catch (_) {
      // 缓存读写失败不阻断启动
    }
  }

  /// 拉取远端配置。任何失败都保持现状（status 相应标记），绝不抛出。
  Future<void> refresh({
    http.Client? client,
    Directory? cacheDir,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final http.Client c = client ?? http.Client();
    try {
      final http.Response resp = await c
          .get(
            Uri.parse('${DfCloudConfig.endpoint}${DfCloudConfig.crisisConfigPath}'),
            headers: <String, String>{
              'x-wb-webapp-access-key': DfCloudConfig.publishableKey,
              'Accept': 'application/json',
            },
          )
          .timeout(timeout);

      if (resp.statusCode != 200) {
        status = DfCrisisStatus
            .fromCache; // 有缓存就是 fromCache，没有仍是 fallback
        if (_extraWords.isEmpty) status = DfCrisisStatus.fallback;
        notifyListeners();
        return;
      }

      final Object? body = jsonDecode(utf8.decode(resp.bodyBytes));
      if (body is! List || body.isEmpty) {
        status = _extraWords.isEmpty ? DfCrisisStatus.fallback : status;
        notifyListeners();
        return;
      }

      // 取 version 最大的行
      Map<String, dynamic>? row;
      int best = -1;
      for (final Object? e in body) {
        if (e is Map<String, dynamic> && (e['version'] as int? ?? -1) > best) {
          best = e['version'] as int;
          row = e;
        }
      }
      if (row == null) {
        status = _extraWords.isEmpty ? DfCrisisStatus.fallback : status;
        notifyListeners();
        return;
      }

      final DfCrisisPayload? p = parseRemote(row['payload']);
      if (p == null) {
        // 远端被写坏：保持现状。status 不升级为 ready。
        status = _extraWords.isEmpty ? DfCrisisStatus.fallback : status;
        notifyListeners();
        return;
      }

      final DateTime now = DateTime.now();
      _apply(
        payload: p,
        version: row['version'] as int?,
        fetchedAt: now,
        status: DfCrisisStatus.ready,
      );
      await _writeCache(cacheDir, row, now);
    } catch (_) {
      // 超时 / 无网：保持现状
      if (_extraWords.isEmpty) {
        status = DfCrisisStatus.fallback;
        notifyListeners();
      }
    } finally {
      c.close();
    }
  }

  void _apply({
    required DfCrisisPayload payload,
    required int? version,
    required DateTime? fetchedAt,
    required DfCrisisStatus status,
  }) {
    _extraWords = payload.words;
    _extraHotlines = payload.hotlines;
    this.version = version;
    this.fetchedAt = fetchedAt;
    this.status = status;
    notifyListeners();
  }

  Future<File> _cacheFile(Directory? cacheDir) async {
    if (cacheDir != null) return File('${cacheDir.path}/$_cacheFileName');
    final Directory dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$_cacheFileName');
  }

  Future<void> _writeCache(
    Directory? cacheDir,
    Map<String, dynamic> row,
    DateTime at,
  ) async {
    try {
      final File f = await _cacheFile(cacheDir);
      await f.writeAsString(jsonEncode(<String, dynamic>{
        'version': row['version'],
        'fetchedAt': at.toIso8601String(),
        'payload': row['payload'],
      }));
    } catch (_) {
      // 缓存写失败不影响本次已生效的配置
    }
  }

  /// 测试用：恢复初始状态
  @visibleForTesting
  void resetForTest() {
    _extraWords = const <String>[];
    _extraHotlines = const <DfHotline>[];
    version = null;
    fetchedAt = null;
    status = DfCrisisStatus.idle;
  }
}

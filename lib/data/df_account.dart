import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'db.dart';

/// 本机账号（M7 · 个人中心）
///
/// 先说清楚一件事：**梦洄没有服务器，所以这里没有真正的「认证」**。
/// 账号在这台手机上只是一个身份标记 —— 用户名、加入时间、是否已登录。
/// 数据和账号都在本机，换台手机就什么都没有了。
///
/// 正因为如此，这里**不做密码**：
/// 1. 手机本身已经有锁屏，睡前再输一次密码是纯添堵；
/// 2. 没有服务端就没法校验，加了密码也是「本地假锁」，反而给人虚假的安全感。
/// 与其做一个骗人的登录框，不如把「数据只在本机」这件事直接说清楚。
///
/// 三个动作的语义（这是产品定义，不是实现细节）：
/// - **登录 / 首次建档**：设一个用户名，写入第一天的日期
/// - **退出登录**：只清「已登录」标记，**不动任何数据**；下次输入用户名即可回来
/// - **注销账号**：删账号 + 清空本机全部数据（对话 / 情绪 / 睡眠），不可恢复
///
/// 用 [ChangeNotifier] 而不是 Riverpod：账号是进程级单例，
/// 页面里 `ListenableBuilder` 挂一下就能跟着变，和 [SleepSchedule] 一个套路。
class DfAccount extends ChangeNotifier {
  DfAccount._();

  static final DfAccount instance = DfAccount._();

  /// 用户名上限（按字符数，不是字节）。超过就截断，不弹错 —— 睡前不该被表单教育。
  static const int maxNameLength = 12;

  /// **测试缝隙**：把内存态恢复到「从没登录过」，不碰落盘、不碰数据库。
  ///
  /// 用例之间需要干净的起点，但 [deleteAccount] 会去连数据库（测试环境里跑不通），
  /// [signOut] 又会故意保留用户名 —— 那是给真机用的语义，不该拿来清场。
  @visibleForTesting
  void resetForTest() {
    _username = null;
    _joinedAt = null;
    _signedIn = false;
    _avatarPath = null;
    _ready = true;
    notifyListeners();
  }

  /// **测试缝隙**：置 false 时所有落盘动作直接跳过。
  ///
  /// 为什么需要它：`flutter_test` 里 `path_provider` 的调用不是抛 `MissingPluginException`，
  /// 而是**永远不返回**（binding 在，但插件没注册）。纯单测（没有 binding）反而会立刻抛错。
  /// 与其在测试里跟平台通道较劲，不如把「状态迁移」和「落盘」明确切开：
  /// 测试只验证状态机，落盘由真机验收。
  @visibleForTesting
  static bool persistenceEnabled = true;

  String? _username;
  DateTime? _joinedAt;
  bool _signedIn = false;

  /// 自定义头像（M9）。指向应用私有目录里的 512×512 JPEG，不是相册原图 ——
  /// 相册删了头像不能跟着消失，所以选图时原生侧就拷了一份进来。
  String? _avatarPath;
  bool _ready = false;

  /// 已经读过本地文件（首帧窗口期用它决定是否先别渲染，避免闪一下登录框）
  bool get ready => _ready;

  /// 当前是否处于已登录态。用户名是硬前提 —— 空名字不算登录成功。
  bool get signedIn => _signedIn && (_username?.isNotEmpty ?? false);

  String? get username => _username;

  DateTime? get joinedAt => _joinedAt;

  /// 「加入第 N 天」里的 N，从 1 开始
  int get joinedDay {
    final DateTime? at = _joinedAt;
    if (at == null) return 1;
    final DateTime a = DateTime(at.year, at.month, at.day);
    final DateTime now = DateTime.now();
    final int days = DateTime(now.year, now.month, now.day).difference(a).inDays;
    return days < 0 ? 1 : days + 1;
  }

  /// 自定义头像文件路径；null = 用首字符默认头像
  String? get avatarPath => _avatarPath;

  /// 界面上称呼用的名字（未登录时给一个中性的兜底）
  String get displayName => _username?.isNotEmpty == true ? _username! : '你';

  /// 头像上的那个字：取首字符，包含 emoji / 生僻字都安全
  String get initial {
    final String n = _username?.trim() ?? '';
    if (n.isEmpty) return '梦';
    return String.fromCharCode(n.runes.first);
  }

  // ── 持久化 ───────────────────────────────────────────────────────────

  Future<File> _file() async {
    final Directory dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}account.json');
  }

  /// 启动时读回。**必须在 runApp 之前 await**，否则首帧会闪一下登录弹窗。
  Future<void> load() async {
    if (!persistenceEnabled) {
      _ready = true;
      notifyListeners();
      return;
    }
    try {
      final File f = await _file();
      if (await f.exists()) {
        final Map<String, dynamic> m =
            jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        _username = (m['username'] as String?)?.trim();
        final String? at = m['joinedAt'] as String?;
        _joinedAt = at == null ? null : DateTime.tryParse(at);
        _signedIn = (m['signedIn'] as bool?) ?? _username != null;
        _avatarPath = m['avatarPath'] as String?;
      }
    } catch (_) {
      // 文件坏了就当没登录过，不让启动挂在这
    } finally {
      _ready = true;
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    if (!persistenceEnabled) return;
    try {
      final File f = await _file();
      await f.writeAsString(jsonEncode(<String, dynamic>{
        'username': _username,
        'joinedAt': _joinedAt?.toIso8601String(),
        'signedIn': _signedIn,
        'avatarPath': _avatarPath,
      }));
    } catch (_) {
      // 落盘失败不影响本次使用（内存态仍然正确）
    }
  }

  // ── 登录 / 改名 / 头像 / 退出 / 注销 ─────────────────────────────────

  /// 换自定义头像。[path] 是 `DfMedia.pickImage(forAvatar: true)` 返回的
  /// 私有目录副本。旧头像文件在**落盘成功之后**才删 —— 反过来的话，
  /// 写 account.json 失败就两头都空了。
  Future<void> setAvatar(String path) async {
    final String? old = _avatarPath;
    if (old != null && old == path) return;
    _avatarPath = path;
    await _persist();
    notifyListeners();
    _deleteQuietly(old);
  }

  /// 恢复默认头像（删文件 + 清字段）
  Future<void> clearAvatar() async {
    final String? old = _avatarPath;
    if (old == null) return;
    _avatarPath = null;
    await _persist();
    notifyListeners();
    _deleteQuietly(old);
  }

  void _deleteQuietly(String? path) {
    if (path == null || !persistenceEnabled) return;
    // delete() 的 Future 是 Future<FileSystemEntity>，onError 也得给它一个
    // 同类型的返回值 —— 所以这里不能偷懒写 catchError((_) {})
    File(path)
        .delete()
        .then<void>((FileSystemEntity _) {}, onError: (Object _) {});
  }

  /// 规范化用户输入：去首尾空白、压缩连续空格、按字符截断。
  /// 返回 null 表示「这个名字不能用」。
  static String? normalizeName(String raw) {
    final String s = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (s.isEmpty) return null;
    final List<int> runes = s.runes.toList();
    if (runes.length <= maxNameLength) return s;
    return String.fromCharCodes(runes.take(maxNameLength));
  }

  /// 首次建档 / 再次登录。名字非法返回 false。
  Future<bool> signIn(String raw) async {
    final String? name = normalizeName(raw);
    if (name == null) return false;
    _username = name;
    _joinedAt ??= DateTime.now();
    _signedIn = true;
    await _persist();
    notifyListeners();
    return true;
  }

  /// 改用户名。不重置 join 日期 —— 改名不是重新投胎。
  Future<bool> rename(String raw) async {
    final String? name = normalizeName(raw);
    if (name == null) return false;
    _username = name;
    await _persist();
    notifyListeners();
    return true;
  }

  /// 退出登录：只摘掉登录标记，**数据一条都不动**。
  Future<void> signOut() async {
    _signedIn = false;
    await _persist();
    notifyListeners();
  }

  /// 注销账号：删账号 + 清空本机全部数据。不可恢复。
  ///
  /// 顺序上先清数据再删账号文件：万一中途失败，下次启动至少还是「已登录」的
  /// 半清空状态，用户能看见并重来；反过来会变成「账号没了但数据还在」的孤儿数据。
  Future<void> deleteAccount() async {
    try {
      await DreamFlowDb.instance.wipeAllData();
    } catch (_) {
      // 数据库清空失败不阻断账号注销，但会向上抛给调用方决定要不要提示
      rethrow;
    } finally {
      _username = null;
      _joinedAt = null;
      _signedIn = false;
      final String? avatar = _avatarPath;
      _avatarPath = null;
      if (persistenceEnabled) {
        try {
          final File f = await _file();
          if (await f.exists()) await f.delete();
        } catch (_) {}
        _deleteQuietly(avatar);
      }
      notifyListeners();
    }
  }
}

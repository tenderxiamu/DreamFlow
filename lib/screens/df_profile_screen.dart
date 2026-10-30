import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dreamflow/app/theme_provider.dart';
import 'package:dreamflow/data/df_account.dart';
import 'package:dreamflow/data/df_media.dart';
import 'package:dreamflow/data/df_wallpaper.dart';
import 'package:dreamflow/data/sleep_schedule.dart';
import 'package:dreamflow/design_system/df_tokens.dart';
import 'package:dreamflow/design_system/df_type.dart';
import 'package:dreamflow/design_system/widgets/df_controls.dart';
import 'package:dreamflow/design_system/widgets/df_icons.dart';
import 'package:dreamflow/design_system/widgets/df_screen.dart';
import 'package:dreamflow/design_system/widgets/df_surfaces.dart';
import 'package:dreamflow/screens/df_account_gate.dart';

/// §7 D「我的」页（t-night）· M7 改成真正的个人中心。
///
/// 一屏之内按「我是谁 → 我能调什么 → 我的数据怎么被对待 → 我要不要走」排列：
/// 1. 资料卡：头像 + 用户名 + 加入天数，点「编辑」改名
/// 2. 设置卡：主题（夜墨/宣纸）、起床闹钟（跳助眠页去调）
/// 3. 数据与关于：数据承诺 + 版本 / 邮箱 / 反馈 / 隐私 / 免责
/// 4. 账号操作：退出登录、注销账号
///
/// 文案上有一条要特别小心：以前这里写着「没有账号」，
/// 现在真有了本机账号，那句话必须改掉，否则是自相矛盾。
/// 注意：版本号与 pubspec.yaml 的 `version: 1.0.0+1` 手动同步。
class DfProfileScreen extends ConsumerWidget {
  const DfProfileScreen({super.key, this.onTab});

  final ValueChanged<int>? onTab;

  static const String appVersion = '1.0.0'; // ← pubspec.yaml version 同步处
  static const String contactEmail = 'dreamflow.app@outlook.com';
  static const String repoUrl = 'https://github.com/tenderxiamu/DreamFlow';
  static const String privacyUrl = '$repoUrl/blob/main/docs/privacy-policy.html';
  static const String disclaimerUrl =
      '$repoUrl/blob/main/docs/health-disclaimer.html';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DfPalette p = DfPalette.of(context);
    final DfAccount acc = DfAccount.instance;

    return ListenableBuilder(
      listenable: acc,
      builder: (BuildContext context, Widget? _) {
        return DfScreenScaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('我的', style: DfType.title(context, p.text)),
              const SizedBox(height: 18),
              _identityCard(context, p, acc),
              const SizedBox(height: 14),
              _settingsCard(context, p, ref),
              const SizedBox(height: 14),
              _promiseCard(context, p),
              const SizedBox(height: 14),
              _aboutCard(context, p),
              const SizedBox(height: 18),
              _accountActions(context, p, acc),
              const SizedBox(height: 14),
              Text(
                '© 2026 白日梦 · DreamFlow',
                style: DfType.caption(context, p.text3),
              ),
            ],
          ),
          bottomFullBleed: true,
          bottom: DfTabs(
            currentIndex: 3,
            onTap: onTab,
            items: const <DfTabItem>[
              DfTabItem(DfGlyph.home, '首页'),
              DfTabItem(DfGlyph.chat, '对话'),
              DfTabItem(DfGlyph.moon, '助眠'),
              DfTabItem(DfGlyph.profile, '我的'),
            ],
          ),
        );
      },
    );
  }

  // ── 资料卡 ───────────────────────────────────────────────────────────

  Widget _identityCard(BuildContext context, DfPalette p, DfAccount acc) {
    return DfCard(
      child: Row(
        children: <Widget>[
          // M9：头像可点 —— 有自定义图就显示图，否则显示首字符
          GestureDetector(
            onTap: () => _editAvatar(context, acc),
            child: Semantics(
              button: true,
              label: '更换头像',
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: acc.avatarPath == null
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[Color(0xFF4E6484), Color(0xFF263248)],
                        )
                      : null,
                  border: Border.all(color: p.line),
                ),
                alignment: Alignment.center,
                clipBehavior: Clip.antiAlias,
                child: acc.avatarPath == null
                    ? Text(acc.initial, style: DfType.title(context, p.text))
                    : Image.file(
                        File(acc.avatarPath!),
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        // 私有文件没了（系统清存储）就退回首字符，别让整卡报错
                        errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
                            Text(acc.initial,
                                style: DfType.title(context, p.text)),
                      ),
              ),
            ),
          ),
          const SizedBox(width: DfSpace.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  acc.displayName,
                  style: DfType.titleS(context, p.text),
                  // 用户名最长 12 字，一行放不下就省略 —— 不能让头像卡撑破
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Text(
                  acc.joinedAt == null
                      ? '数据只保存在这台手机里'
                      : '加入第 ${acc.joinedDay} 天 · 数据只在本机',
                  style: DfType.caption(context, p.text2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          DfGhostButton(
            label: '编辑',
            height: 34,
            onPressed: () => _editName(context, acc),
          ),
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext context, DfAccount acc) async {
    final String? name = await showDfNameDialog(
      context,
      title: '改个名字',
      initial: acc.username ?? '',
      hint: '例如：林小满',
      confirmLabel: '保存',
    );
    if (name == null) return;
    await acc.rename(name);
    if (context.mounted) {
      _toast(context, '已改名为 $name');
    }
  }

  /// M9：换头像（底部弹层，两个动作）
  ///
  /// 选图期间原生侧在裁剪压缩（约零点几秒），返回 null 有三种可能：
  /// 用户取消、没有相册应用、解码失败 —— 后两种才值得提示，
  /// 取消是最常见的路径，静默就好。
  Future<void> _editAvatar(BuildContext context, DfAccount acc) async {
    final bool hasCustom = acc.avatarPath != null;
    final String? action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        final DfPalette p = DfPalette.of(ctx);
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(DfRadius.card),
              border: Border.all(color: p.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('头像', style: DfType.bodyS(ctx, p.text)),
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.of(ctx).pop('pick'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text('从相册选择',
                                  style: DfType.body(ctx, p.text)),
                              const SizedBox(height: 3),
                              Text('只取一张，不会访问整个相册',
                                  style: DfType.caption(ctx, p.text2)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (hasCustom)
                  InkWell(
                    onTap: () => Navigator.of(ctx).pop('clear'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text('恢复默认头像',
                                style: DfType.body(ctx, p.text)),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
    if (action == null || !context.mounted) return;

    if (action == 'clear') {
      await acc.clearAvatar();
      if (context.mounted) _toast(context, '已恢复默认头像');
      return;
    }

    final String? path = await DfMedia.pickImage(forAvatar: true);
    if (!context.mounted) return;
    if (path == null) {
      // 取消不提示；只有「真的失败」才说 —— 但现在区分不出来，都轻提示一句
      return;
    }
    await acc.setAvatar(path);
    if (context.mounted) _toast(context, '头像已更新');
  }

  // ── 设置卡 ───────────────────────────────────────────────────────────

  Widget _settingsCard(BuildContext context, DfPalette p, WidgetRef ref) {
    final bool night = ref.watch(themeProvider) == DfAppTheme.night;
    final SleepSchedule s = SleepSchedule.instance;

    return DfCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          _row(
            context,
            p,
            '主题',
            night ? '夜墨 · 适合关灯后' : '宣纸 · 适合白天',
            trailing: DfChip(
              label: night ? '切换到宣纸' : '切换到夜墨',
              onTap: () => ref.read(themeProvider.notifier).toggle(),
            ),
          ),
          _divider(p),
          _row(
            context,
            p,
            '壁纸',
            DfWallpapers.label(DfWallpapers.instance.choice),
            onTap: () => _pickWallpaper(context),
          ),
          _divider(p),
          _row(
            context,
            p,
            '起床闹钟',
            s.alarmEnabled
                ? '${s.alarmLabel}${s.smartWake ? ' · 智能唤醒' : ''}'
                : '已关闭',
            onTap: () => onTab?.call(2),
          ),
          _divider(p),
          _row(
            context,
            p,
            '数据与隐私',
            '全程本机 · 不联网存储',
            onTap: () => _toast(context, '情绪、对话与睡眠记录只写在本机数据库'),
          ),
        ],
      ),
    );
  }

  // ── 数据承诺 ─────────────────────────────────────────────────────────

  Widget _promiseCard(BuildContext context, DfPalette p) {
    return DfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('你的数据属于你', style: DfType.bodyS(context, p.text)),
          const SizedBox(height: 10),
          _bullet(context, p, '情绪记录、对话与睡眠会话只保存在这台手机里'),
          _bullet(context, p, '账号只有用户名，不要手机号，也不接第三方登录'),
          _bullet(context, p, '对话文本仅用于生成回复，不用于训练'),
        ],
      ),
    );
  }

  // ── 关于卡 ───────────────────────────────────────────────────────────

  Widget _aboutCard(BuildContext context, DfPalette p) {
    return DfCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          _row(context, p, '版本', '$appVersion (1) · 开发者 白日梦'),
          _divider(p),
          _row(
            context,
            p,
            '联系邮箱',
            contactEmail,
            onTap: () => _open(context, Uri(scheme: 'mailto', path: contactEmail)),
          ),
          _divider(p),
          _row(
            context,
            p,
            '意见反馈 · GitHub Issues',
            repoUrl.replaceFirst('https://', ''),
            onTap: () => _open(context, Uri.parse('$repoUrl/issues')),
          ),
          _divider(p),
          _row(
            context,
            p,
            '隐私政策',
            '网页版 · 也可在线查看',
            onTap: () => _open(context, Uri.parse(privacyUrl)),
          ),
          _divider(p),
          _row(
            context,
            p,
            '健康免责声明',
            '非医疗器械 · 数据为估算',
            onTap: () => _open(context, Uri.parse(disclaimerUrl)),
          ),
        ],
      ),
    );
  }

  // ── 账号操作 ─────────────────────────────────────────────────────────

  Widget _accountActions(BuildContext context, DfPalette p, DfAccount acc) {
    final bool signedIn = acc.signedIn;
    return Column(
      children: <Widget>[
        SizedBox(
          width: double.infinity,
          child: DfGhostButton(
            label: signedIn ? '退出登录' : '登录',
            onPressed: () => signedIn ? _signOut(context, acc) : _signIn(context, acc),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => _deleteAccount(context, acc),
          child: Text(
            '注销账号',
            style: DfType.caption(context, p.mistPink),
          ),
        ),
      ],
    );
  }

  Future<void> _signIn(BuildContext context, DfAccount acc) async {
    final String? name = await showDfNameDialog(
      context,
      title: '登录梦洄',
      initial: acc.username ?? '',
      hint: '输入你的用户名',
      confirmLabel: '登录',
    );
    if (name == null) return;
    await acc.signIn(name);
  }

  Future<void> _signOut(BuildContext context, DfAccount acc) async {
    final bool ok = await _confirm(
      context,
      title: '退出登录？',
      body: '数据会留在这台手机上，下次输入同样的用户名就能回来。',
      confirmLabel: '退出',
    );
    if (!ok) return;
    await acc.signOut();
  }

  Future<void> _deleteAccount(BuildContext context, DfAccount acc) async {
    final bool ok = await _confirm(
      context,
      title: '注销账号？',
      body: '账号和本机全部数据 —— 情绪记录、对话、睡眠会话 —— 都会被删除，且无法恢复。',
      confirmLabel: '永久删除',
      danger: true,
    );
    if (!ok) return;
    try {
      await acc.deleteAccount();
      // 注销后闸门会自动盖上登录弹窗，这里不用再跳转
    } catch (_) {
      if (context.mounted) _toast(context, '数据清理失败，请重试');
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
    bool danger = false,
  }) async {
    final DfPalette p = DfPalette.of(context);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: DfCard(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: DfType.titleS(context, p.text)),
              const SizedBox(height: 10),
              Text(body, style: DfType.sub(context, p.text2)),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  DfGhostButton(
                    label: '取消',
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  const SizedBox(width: 8),
                  // 危险操作换成带色的文字按钮，视觉上就该比「取消」更重、更警惕
                  danger
                      ? TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(
                            confirmLabel,
                            style: DfType.bodyS(context, p.mistPink),
                          ),
                        )
                      : DfGhostButton(
                          label: confirmLabel,
                          onPressed: () => Navigator.of(context).pop(true),
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return ok ?? false;
  }

  // ── 通用件 ───────────────────────────────────────────────────────────

  void _toast(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)),
    );
  }

  Future<void> _open(BuildContext context, Uri uri) async {
    try {
      final bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw Exception('launch rejected');
    } catch (_) {
      // 打不开（无浏览器/无邮件应用）时退化为复制，保证用户拿到链接
      await Clipboard.setData(ClipboardData(text: uri.toString()));
      if (context.mounted) _toast(context, '链接已复制：${uri.toString()}');
    }
  }

  Widget _bullet(BuildContext context, DfPalette p, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(shape: BoxShape.circle, color: p.mistBlue),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: DfType.caption(context, p.text2))),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    DfPalette p,
    String title,
    String value, {
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: DfType.bodyS(context, p.text)),
                const SizedBox(height: 3),
                Text(value, style: DfType.caption(context, p.text2)),
              ],
            ),
          ),
          if (trailing != null) trailing,
          if (trailing == null && onTap != null)
            Text('›', style: DfType.body(context, p.text3)),
        ],
      ),
    );
    return onTap == null ? content : InkWell(onTap: onTap, child: content);
  }

  /// 壁纸选择（M7.2）
  ///
  /// 用底部弹层而不是二级页面：七个选项、一屏放得下，选完就该消失。
  /// 每一行都带一句人话说明，因为「暮云 / 晨霞 / 一缕」这几个名字
  /// 光看字是猜不出画面的。
  Future<void> _pickWallpaper(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        final DfPalette p = DfPalette.of(ctx);
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(DfRadius.card),
              border: Border.all(color: p.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListenableBuilder(
              listenable: DfWallpapers.instance,
              builder: (BuildContext c, Widget? _) {
                final DfWall cur = DfWallpapers.instance.choice;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text('壁纸',
                                style: DfType.bodyS(c, p.text)),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(ctx).pop(),
                            child: Text('关闭',
                                style: DfType.caption(c, p.text3)),
                          ),
                        ],
                      ),
                    ),
                    for (final DfWall w in DfWallpapers.choices)
                      InkWell(
                        onTap: () => _onWallpaperTap(ctx, w),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 13),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(DfWallpapers.label(w),
                                        style: DfType.body(c, p.text)),
                                    const SizedBox(height: 3),
                                    Text(DfWallpapers.caption(w),
                                        style: DfType.caption(c, p.text2)),
                                  ],
                                ),
                              ),
                              if (w == cur)
                                Text('✓',
                                    style: DfType.body(c, p.text))
                              else
                                const SizedBox(width: 14),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// 壁纸行点击（M9 加相册分支）：
  /// - 普通选项：直接选中、关弹层
  /// - 相册照片、还没选过：关弹层 → 开相册 → 设为壁纸
  /// - 相册照片、已有图：再点一次就是换一张
  Future<void> _onWallpaperTap(BuildContext sheetCtx, DfWall w) async {
    final DfWallpapers wps = DfWallpapers.instance;
    final bool needPick = w == DfWall.custom && wps.customPath == null;
    if (!needPick) {
      wps.select(w);
      Navigator.of(sheetCtx).pop();
      return;
    }
    Navigator.of(sheetCtx).pop();
    final String? path = await DfMedia.pickImage(forAvatar: false);
    if (path == null) return;
    await wps.selectCustom(path);
  }

  Widget _divider(DfPalette p) =>
      Divider(height: 1, thickness: 1, color: p.line);
}

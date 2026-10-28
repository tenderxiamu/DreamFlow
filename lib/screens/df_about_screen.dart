import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dreamflow/design_system/df_tokens.dart';
import 'package:dreamflow/design_system/df_type.dart';
import 'package:dreamflow/design_system/widgets/df_controls.dart';
import 'package:dreamflow/design_system/widgets/df_icons.dart';
import 'package:dreamflow/design_system/widgets/df_screen.dart';
import 'package:dreamflow/design_system/widgets/df_surfaces.dart';

/// §7 D「我的」页（t-night）。
/// 职责单一：版本信息 + 数据承诺 + 联系与合规入口。
/// 注意：版本号与 pubspec.yaml 的 `version: 1.0.0+1` 手动同步。
class DfAboutScreen extends StatelessWidget {
  const DfAboutScreen({super.key, this.onTab});

  final ValueChanged<int>? onTab;

  static const String appVersion = '1.0.0'; // ← pubspec.yaml version 同步处
  static const String contactEmail = 'dreamflow.app@outlook.com';
  static const String repoUrl = 'https://github.com/tenderxiamu/DreamFlow';
  static const String privacyUrl = '$repoUrl/blob/main/docs/privacy-policy.html';
  static const String disclaimerUrl =
      '$repoUrl/blob/main/docs/health-disclaimer.html';

  Future<void> _open(BuildContext context, Uri uri) async {
    try {
      final bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw Exception('launch rejected');
    } catch (_) {
      // 打不开（无浏览器/无邮件应用）时退化为复制，保证用户拿到链接
      await Clipboard.setData(ClipboardData(text: uri.toString()));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('链接已复制：${uri.toString()}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);

    return DfScreenScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('我的', style: DfType.title(context, p.text)),
          const SizedBox(height: 18),
          _identityCard(context, p),
          const SizedBox(height: 14),
          _promiseCard(context, p),
          const SizedBox(height: 14),
          _contactCard(context, p),
          const SizedBox(height: 14),
          Text('© 2026 白日梦 · DreamFlow', style: DfType.caption(context, p.text3)),
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
  }

  /// 应用身份卡：圆形「梦」字标 + 名称 + 版本
  Widget _identityCard(BuildContext context, DfPalette p) {
    return DfCard(
      child: Row(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFF4E6484), Color(0xFF263248)],
              ),
              border: Border.all(color: p.line),
            ),
            alignment: Alignment.center,
            child: Text(
              '梦',
              style: TextStyle(
                fontFamily: 'MaShanZheng',
                fontSize: 30,
                height: 1.1,
                color: p.text,
              ),
            ),
          ),
          const SizedBox(width: DfSpace.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('梦洄 DreamFlow', style: DfType.titleS(context, p.text)),
                const SizedBox(height: 4),
                Text(
                  '版本 $appVersion (1) · 开发者 白日梦',
                  style: DfType.caption(context, p.text2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 数据承诺卡：把隐私卖点说成人话
  Widget _promiseCard(BuildContext context, DfPalette p) {
    return DfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('你的数据属于你', style: DfType.bodyS(context, p.text)),
          const SizedBox(height: 10),
          _bullet(context, p, '情绪记录、对话与睡眠会话只保存在这台手机里'),
          _bullet(context, p, '没有账号，没有广告，没有统计 SDK'),
          _bullet(context, p, '对话文本仅用于生成回复，不用于训练'),
        ],
      ),
    );
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

  /// 联系与合规卡
  Widget _contactCard(BuildContext context, DfPalette p) {
    return DfCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          _row(
            context,
            p,
            '联系邮箱',
            contactEmail,
            () => _open(context, Uri(scheme: 'mailto', path: contactEmail)),
          ),
          _divider(p),
          _row(
            context,
            p,
            '意见反馈 · GitHub Issues',
            repoUrl.replaceFirst('https://', ''),
            () => _open(context, Uri.parse('$repoUrl/issues')),
          ),
          _divider(p),
          _row(
            context,
            p,
            '隐私政策',
            '网页版 · 也可在线查看',
            () => _open(context, Uri.parse(privacyUrl)),
          ),
          _divider(p),
          _row(
            context,
            p,
            '健康免责声明',
            '非医疗器械 · 数据为估算',
            () => _open(context, Uri.parse(disclaimerUrl)),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, DfPalette p, String title, String value,
      VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
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
            Text('›',
                style: DfType.sub(context, p.text3).copyWith(fontSize: 18)),
          ],
        ),
      ),
    );
  }

  Widget _divider(DfPalette p) =>
      Divider(height: 1, thickness: 1, color: p.line);
}

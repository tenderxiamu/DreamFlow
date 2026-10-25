import 'package:flutter/material.dart';

import 'package:dreamflow/design_system/df_theme.dart';
import 'package:dreamflow/design_system/df_tokens.dart';
import 'package:dreamflow/design_system/df_type.dart';
import 'package:dreamflow/design_system/widgets/df_controls.dart';
import 'package:dreamflow/design_system/widgets/df_icons.dart';
import 'package:dreamflow/design_system/widgets/df_screen.dart';
import 'package:dreamflow/design_system/widgets/df_sheep.dart';
import 'package:dreamflow/design_system/widgets/df_states.dart';
import 'package:dreamflow/screens/df_chat_screen.dart';
import 'package:dreamflow/screens/df_home_screen.dart';
import 'package:dreamflow/screens/df_night_flow.dart';
import 'package:dreamflow/screens/df_report_screen.dart';
import 'package:dreamflow/screens/df_sleep_screen.dart';
import 'package:dreamflow/screens/df_state_screen.dart';
import 'package:dreamflow/screens/df_wake_screen.dart';

/// **设计走查专用入口**（不是产品形态，是把五屏横排成一块板供设计比对）。
///
/// 真正的产品入口是 `lib/main.dart`（`DreamFlowApp`）——可导航、可操作的 App。
/// 运行本文件：`flutter run -d windows --target=lib/showcase.dart`
void main() => runApp(const ShowcaseApp());

class ShowcaseApp extends StatefulWidget {
  const ShowcaseApp({super.key});

  @override
  State<ShowcaseApp> createState() => _ShowcaseAppState();
}

class _ShowcaseAppState extends State<ShowcaseApp> {
  bool _night = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DreamFlow 梦洄 · 陈列板',
      debugShowCheckedModeBanner: false,
      // §5.2 切换 = 换 ThemeData，组件零改动
      theme: _night ? DfTheme.nightTheme(context) : DfTheme.paperTheme(context),
      home: DfGalleryBoard(
        night: _night,
        onToggleTheme: () => setState(() => _night = !_night),
      ),
    );
  }
}

/// 交付陈列板：5 屏 × 当前主题 + 一键切换
class DfGalleryBoard extends StatelessWidget {
  const DfGalleryBoard({
    super.key,
    required this.night,
    required this.onToggleTheme,
  });

  final bool night;
  final VoidCallback onToggleTheme;

  static const Color _boardBg = Color(0xFF0A0B0D);
  static const Color _boardFg = Color(0xFFE7E6E2);
  static const Color _boardDim = Color(0xFF7C8794);
  static const Color _boardLine = Color(0xFF23262B);

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);

    return Scaffold(
      backgroundColor: _boardBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Column(
                  children: <Widget>[
                    Text(
                      'DreamFlow 梦洄',
                      style: DfType.title(context, _boardFg).copyWith(fontSize: 34),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'INK × MORANDI',
                      style: DfType.caption(context, _boardDim)
                          .copyWith(letterSpacing: 4),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '设计陈列板 · 非产品形态（产品入口见 lib/main.dart）',
                      style: DfType.caption(context, _boardDim),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              Text(
                night ? '夜墨 t-night' : '宣纸 t-paper',
                style: DfType.bodyS(context, _boardFg),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggleTheme,
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(DfRadius.pill),
                    border: Border.all(color: _boardLine),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const DfIcon(DfGlyph.moon, size: 18, color: _boardDim),
                      const SizedBox(width: 8),
                      Text(
                        '切换主题（组件零改动）',
                        style: DfType.bodyS(context, _boardDim),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _phone(context, 'A · 首页 · 睡前模式', '22:14', const DfHomeScreen()),
                    _phone(context, 'B · 情绪对话', '22:41', const DfChatScreen()),
                    _phone(context, 'C · 沉浸助眠', '23:07', const DfSleepScreen()),
                    _phone(context, 'D · 睡眠报告', '07:36', const DfReportScreen()),
                    _phone(context, 'E · 渐进式唤醒', '06:42', const DfWakeScreen()),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '夜间主链路 · C → E → D（可点击走查）',
                style: DfType.bodyS(context, _boardFg),
              ),
              const SizedBox(height: 4),
              Text(
                '助眠播完 → 渐进式唤醒（我醒了 → 报告 loading → 正文 / 再睡 5 分钟 → 倒计时 → 再唤醒）',
                style: DfType.caption(context, _boardDim),
              ),
              const SizedBox(height: 12),
              DfPhoneFrame(
                time: '23:07',
                child: DfNightFlow(
                  tickInterval: const Duration(milliseconds: 220),
                  step: 0.02,
                  snoozeDuration: const Duration(seconds: 6),
                  loadDuration: const Duration(milliseconds: 900),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '状态页 · 空 / 加载 / 异常（§12 缺口 4）',
                style: DfType.bodyS(context, _boardFg),
              ),
              const SizedBox(height: 4),
              Text(
                '报告屏已接入：DfReportScreen(state: …)',
                style: DfType.caption(context, _boardDim),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _statePhone(context, '加载 · 骨架 + 小羊漂浮', '23:07',
                        const DfStateScreen(kind: DfStateKind.loading)),
                    _statePhone(context, '空 · 还没有可回顾的夜', '07:36',
                        const DfStateScreen(kind: DfStateKind.empty)),
                    _statePhone(context, '异常 · 可重试', '07:36',
                        const DfStateScreen(kind: DfStateKind.error)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('组件状态', style: DfType.bodyS(context, _boardFg)),
              const SizedBox(height: 12),
              _states(context, p),
            ],
          ),
        ),
      ),
    );
  }

  Widget _phone(BuildContext context, String caption, String time, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(right: 22),
      child: Column(
        children: <Widget>[
          Text(caption, style: DfType.caption(context, _boardDim)),
          const SizedBox(height: 9),
          DfPhoneFrame(time: time, child: child),
        ],
      ),
    );
  }

  Widget _statePhone(
    BuildContext context,
    String caption,
    String time,
    Widget child,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 22),
      child: Column(
        children: <Widget>[
          Text(caption, style: DfType.caption(context, _boardDim)),
          const SizedBox(height: 9),
          DfPhoneFrame(time: time, width: 240, height: 520, child: child),
        ],
      ),
    );
  }

  Widget _states(BuildContext context, DfPalette p) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _boardLine),
      ),
      child: Wrap(
        spacing: 22,
        runSpacing: 22,
        children: <Widget>[
          _cell(context, 'btn-cloud 主按钮', <Widget>[
            DfCloudButton(label: '默认', height: 48, onPressed: () {}),
            DfCloudButton(label: '按下', height: 48, onPressed: () {}),
            const DfCloudButton(label: '禁用', height: 48),
          ]),
          _cell(context, 'btn-ghost 次按钮', <Widget>[
            DfGhostButton(label: '默认', height: 44, onPressed: () {}),
            DfGhostButton(label: '悬停', height: 44, onPressed: () {}),
          ]),
          _cell(context, 'icon-btn', <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DfIconButton(
                  glyph: DfGlyph.mic,
                  semanticLabel: '按住说话',
                  onPressed: () {},
                ),
                const SizedBox(width: 14),
                DfIconButton(
                  glyph: DfGlyph.play,
                  semanticLabel: '播放 / 暂停',
                  size: DfTouch.play,
                  onPressed: () {},
                ),
              ],
            ),
          ]),
          _cell(context, 'back 返回键（落地必补）', <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DfIcon(DfGlyph.back, size: 20, color: p.text),
                const SizedBox(width: 14),
                DfIcon(DfGlyph.pause, size: 20, color: p.text),
              ],
            ),
          ]),
          _cell(context, 'chip', <Widget>[
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DfChip(label: '默认'),
                SizedBox(width: 10),
                DfChip(label: '选中', selected: true),
              ],
            ),
          ]),
          _cell(context, 'field', <Widget>[
            const SizedBox(width: 200, child: DfField(hint: '占位文字 16px')),
          ]),
          _cell(context, 'field 错误态（§12 缺口 3）', <Widget>[
            const SizedBox(
              width: 200,
              child: DfField(hint: '占位文字 16px', errorText: '至少说一句话'),
            ),
          ]),
          _cell(context, '小羊（3.6s 漂浮）', <Widget>[
            const DfSheep(height: 58),
          ]),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, String title, List<Widget> children) {
    return SizedBox(
      width: 210,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: DfType.caption(context, _boardDim)),
          const SizedBox(height: 10),
          for (final Widget child in children) ...<Widget>[
            child,
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

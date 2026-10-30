import 'package:flutter/material.dart';

import 'package:dreamflow/data/df_account.dart';
import 'package:dreamflow/design_system/df_tokens.dart';
import 'package:dreamflow/design_system/df_type.dart';
import 'package:dreamflow/design_system/widgets/df_controls.dart';
import 'package:dreamflow/design_system/widgets/df_surfaces.dart';

/// 登录闸门（M7）
///
/// 未登录时在整个 App 之上盖一层**不可关闭**的弹窗：欢迎 → 设置用户名，两步。
///
/// 为什么不用 `showDialog`：这层挂在 `MaterialApp.builder` 里，位置在 Navigator
/// **之上**，拿不到 Navigator 的 context。所以自己用 Stack 画：
/// 底下是被遮住的真实页面（用户能看到 App 长什么样，不是一块白屏），
/// 上面是遮罩 + 卡片。好处是登录态变化时不用管路由栈，[DfAccount] 一 notify 就消失。
class DfAccountGate extends StatelessWidget {
  const DfAccountGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DfAccount.instance,
      builder: (BuildContext context, Widget? _) {
        final DfAccount a = DfAccount.instance;
        // main() 里已经 await load()，正常不会走到这里；留一个兜底避免闪一下遮罩
        if (!a.ready) return child;
        if (a.signedIn) return child;
        return Stack(
          // 必须 expand：否则 Stack 会被「最小的那个非定位子节点」撑成小盒子，
          // 遮罩层跟着一起塌（真机上是整屏的 App，看不出问题；换个宿主就现形）
          fit: StackFit.expand,
          children: <Widget>[
            child,
            const Positioned.fill(child: _LoginOverlay()),
          ],
        );
      },
    );
  }
}

class _LoginOverlay extends StatefulWidget {
  const _LoginOverlay();

  @override
  State<_LoginOverlay> createState() => _LoginOverlayState();
}

class _LoginOverlayState extends State<_LoginOverlay> {
  final TextEditingController _name = TextEditingController();
  final FocusNode _focus = FocusNode();

  /// 0 = 欢迎（提示登录）；1 = 设置用户名
  int _step = 0;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final bool ok = await DfAccount.instance.signIn(_name.text);
    if (!ok && mounted) {
      setState(() => _error = '还没有名字，写一个吧');
    }
    // 成功时不用手动收尾：DfAccount.notifyListeners 会让闸门自己消失
  }

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Stack(
      children: <Widget>[
        // 遮罩：夜墨下用画布底加透明度，宣纸下用墨色，两个主题都不突兀
        Positioned.fill(
          child: ColoredBox(color: p.canvas.withValues(alpha: 0.86)),
        ),
        Positioned.fill(
          child: GestureDetector(
            // 吃掉点击，避免 penetrate 到底下的页面
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusScope.of(context).unfocus(),
            child: Padding(
              padding: EdgeInsets.only(bottom: keyboard),
              // 为什么不用 Center 直接包 SingleChildScrollView：
              // Center 会给子节点**松约束**，卡片里的 `SizedBox(width: infinity)`
              // 在松约束下宽度会塌成 0（真机上就是一条缝，按钮完全点不到）。
              // 标准解法是「视口高度当最小高度 + 内部居中」，宽度始终是紧约束。
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints c) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: ConstrainedBox(
                      // 高度无界时不撑（否则 minHeight 会算成负数直接崩）
                      constraints: BoxConstraints(
                        minHeight:
                            c.maxHeight.isFinite ? (c.maxHeight - 48).clamp(0, double.infinity) : 0,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: DfCard(
                            padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                            child: _step == 0 ? _welcome(p) : _nameStep(p),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── 第一步：提示登录 ────────────────────────────────────────────────

  Widget _welcome(DfPalette p) {
    // 老用户退出后又弹这一层：别再说「欢迎来到」，那是第一次装 App 的话术。
    // 名字直接念出来 —— 这一层的全部意义就是「你回来这件事被记住了」。
    final String? saved = DfAccount.instance.username;
    final bool returning = saved != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          returning ? '欢迎回来，$saved' : '欢迎来到梦洄',
          style: DfType.title(context, p.text),
        ),
        const SizedBox(height: 10),
        Text(
          returning
              ? '你的记录一直留在这台手机上。'
              : '梦洄没有服务器。你的情绪、对话和睡眠记录，只保存在这台手机里。',
          style: DfType.sub(context, p.text2),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: DfCloudButton(
            label: returning ? '继续' : '登录',
            onPressed: () async {
              // 老用户不必再走一遍起名：名字已经在标题里念过了，
              // 再让他确认一次自己叫什么，纯属流程惯性
              if (returning) {
                await DfAccount.instance.signIn(saved);
                return;
              }
              setState(() {
                _step = 1;
                _error = null;
              });
              // 等这一帧渲染完再要焦点，否则节点还没挂上
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _focus.requestFocus();
              });
            },
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            '不需要手机号，也不用密码',
            style: DfType.caption(context, p.text3),
          ),
        ),
      ],
    );
  }

  // ── 第二步：设置用户名 ──────────────────────────────────────────────

  Widget _nameStep(DfPalette p) {
    final bool returning = DfAccount.instance.username != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          returning ? '输入用户名' : '给自己起个名字',
          style: DfType.title(context, p.text),
        ),
        const SizedBox(height: 10),
        Text(
          returning ? '用上次那个名字就行。' : '梦洄会用它来称呼你，之后在「我的」里随时能改。',
          style: DfType.sub(context, p.text2),
        ),
        const SizedBox(height: 18),
        DfField(
          hint: '例如：林小满',
          controller: _name,
          focusNode: _focus,
          errorText: _error,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: DfCloudButton(label: returning ? '继续' : '完成', onPressed: _submit),
        ),
        const SizedBox(height: 8),
        Center(
          child: DfGhostButton(
            label: '返回',
            onPressed: () => setState(() {
              _step = 0;
              _error = null;
            }),
          ),
        ),
      ],
    );
  }
}

/// 「我的」页改用户名用的对话框（这里在 Navigator 之下，可以正常用 showDialog）
Future<String?> showDfNameDialog(
  BuildContext context, {
  required String title,
  required String initial,
  required String hint,
  required String confirmLabel,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) => _DfNameDialog(
      title: title,
      initial: initial,
      hint: hint,
      confirmLabel: confirmLabel,
    ),
  );
}

class _DfNameDialog extends StatefulWidget {
  const _DfNameDialog({
    required this.title,
    required this.initial,
    required this.hint,
    required this.confirmLabel,
  });

  final String title;
  final String initial;
  final String hint;
  final String confirmLabel;

  @override
  State<_DfNameDialog> createState() => _DfNameDialogState();
}

class _DfNameDialogState extends State<_DfNameDialog> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);
  final FocusNode _focus = FocusNode();
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _ok() {
    final String? name = DfAccount.normalizeName(_c.text);
    if (name == null) {
      setState(() => _error = '名字不能为空');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: DfCard(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(widget.title, style: DfType.titleS(context, p.text)),
            const SizedBox(height: 14),
            DfField(
              hint: widget.hint,
              controller: _c,
              focusNode: _focus,
              errorText: _error,
              onSubmitted: (_) => _ok(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                DfGhostButton(
                  label: '取消',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                DfGhostButton(label: widget.confirmLabel, onPressed: _ok),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

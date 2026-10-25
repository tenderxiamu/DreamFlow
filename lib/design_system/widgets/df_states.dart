import 'package:flutter/material.dart';

import '../df_tokens.dart';
import '../df_type.dart';
import 'df_controls.dart';
import 'df_sheep.dart';

/// §12 缺口 4 —— 空状态 / 加载 / 异常的**框架层约定**。
///
/// 设计侧仅约定了原则：小羊出场（§6.14）、一屏一事（§1）、令牌化（§10-1）、
/// 动效降级（§9.4）。本文件据此补齐缺省实现，全部走 [DfPalette]，
/// 出正式稿后只需替换插画，不需要改调用方。
enum DfStateKind { loading, empty, error }

/// 空 / 加载 / 异常三态视图。
///
/// 结构（自上而下）：小羊 → 标题 → 说明 → 可选行动按钮。
/// - 小羊：唯一的插画元素，加载态播放漂浮（其余态静止，避免多动效叠加）
/// - 文案：标题走 `text` / 说明走 `text2`（**不用** `text-3`，避免对比度不足）
/// - 语义：整块 `liveRegion`，读屏在状态变化时自动播报
class DfStateView extends StatelessWidget {
  const DfStateView({
    super.key,
    required this.kind,
    required this.title,
    this.message,
    this.action,
    this.sheepHeight = 72,
  });

  final DfStateKind kind;
  final String title;
  final String? message;

  /// 行动按钮（加载态无；空态「去记录」；异常态「重试」）
  final Widget? action;

  /// 小羊高度：空 / 异常 72（占位主体），加载 48（配合骨架条）
  final double sheepHeight;

  /// 加载态：小羊漂浮 + 骨架条（§12 缺口 4「小羊 + Zzz」）
  factory DfStateView.loading({
    Key? key,
    String title = '正在整理昨夜的梦',
    String? message,
  }) =>
      DfStateView(
        key: key,
        kind: DfStateKind.loading,
        title: title,
        message: message,
        sheepHeight: 48,
      );

  /// 空态：还没有可回顾的数据
  factory DfStateView.empty({
    Key? key,
    String title = '还没有可以回顾的夜',
    String? message = '先睡一晚，梦洄会替你记下它',
    Widget? action,
  }) =>
      DfStateView(
        key: key,
        kind: DfStateKind.empty,
        title: title,
        message: message,
        action: action,
      );

  /// 异常态：网络 / 服务不可用，**必须给出可操作出口**。
  ///
  /// 无论 [onRetry] 是否为空都渲染「重试」按钮（§9 一致性）：
  /// 异常页的唯一用途就是把用户送回正轨，缺了它这屏就是死路。
  /// [onRetry] 为空时按钮仅不可激活（陈列 / 预览场景）。
  factory DfStateView.error({
    Key? key,
    String title = '没能连上你的夜晚',
    String? message = '网络似乎走神了，检查后重试即可',
    VoidCallback? onRetry,
  }) =>
      DfStateView(
        key: key,
        kind: DfStateKind.error,
        title: title,
        message: message,
        action: DfGhostButton(
          label: '重试',
          height: DfTouch.secondaryH,
          onPressed: onRetry,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);

    return Semantics(
      liveRegion: true,
      container: true,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // §6.14 出场点之五：状态页。加载态才漂浮，避免常驻动效多于一个（§8）
              DfSheep(
                height: sheepHeight,
                animate: kind == DfStateKind.loading,
              ),
              SizedBox(
                height: sheepHeight * 0.26 + DfSpace.s4,
              ),
              Text(
                title,
                textAlign: TextAlign.center,
                style: DfType.titleS(context, p.text),
              ),
              if (message != null) ...<Widget>[
                const SizedBox(height: DfSpace.s2),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: DfType.sub(context, p.text2),
                ),
              ],
              if (kind == DfStateKind.loading) ...<Widget>[
                const SizedBox(height: DfSpace.s5),
                const DfSkeletonList(),
              ],
              if (action != null) ...<Widget>[
                const SizedBox(height: DfSpace.s5),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 在「有数据」与「三态」之间切换的便捷封装，页面侧只传 [kind]。
///
/// [kind] 为 `null` 时渲染 [child]（正常内容），否则渲染对应状态视图。
class DfStateSwitch extends StatelessWidget {
  const DfStateSwitch({super.key, this.kind, this.child, this.onRetry});

  /// `null` = 正常内容
  final DfStateKind? kind;
  final Widget? child;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (kind == null) return child ?? const SizedBox.shrink();

    switch (kind!) {
      case DfStateKind.loading:
        // 重定向工厂（DfStateView.loading 等）不可用于 const 上下文
        return DfStateView.loading();
      case DfStateKind.empty:
        return DfStateView.empty();
      case DfStateKind.error:
        return DfStateView.error(onRetry: onRetry);
    }
  }
}

/// §12 缺口 4 —— 加载骨架（替代转圈 spinner，与「水墨留白」一致）。
///
/// 微光扫过动效在 `prefers-reduced-motion` 下自动降级为静态（§9.4 / §11-4）。
class DfSkeletonList extends StatelessWidget {
  const DfSkeletonList({super.key, this.rows = 3, this.height = 14});

  final int rows;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List<Widget>.generate(rows, (int i) {
        final double factor = i == rows - 1 ? 0.62 : 1.0;
        return Padding(
          padding: EdgeInsets.only(bottom: i == rows - 1 ? 0 : DfSpace.s3),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: factor,
              child: DfSkeletonBlock(height: height),
            ),
          ),
        );
      }),
    );
  }
}

/// 单块骨架（圆角 14 = [DfRadius.metric]，与卡片语言一致）
class DfSkeletonBlock extends StatefulWidget {
  const DfSkeletonBlock({super.key, this.height = 14, this.width});

  final double height;
  final double? width;

  @override
  State<DfSkeletonBlock> createState() => _DfSkeletonBlockState();
}

class _DfSkeletonBlockState extends State<DfSkeletonBlock>
    with SingleTickerProviderStateMixin {
  // 与 DfSheep 同理：必须在 initState 立即创建，禁止 late final 懒初始化
  // （animate=false 路径下 dispose 首次访问会抛 "deactivated widget's ancestor"）
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DfRadius.metric),
        child: SizedBox(
          height: widget.height,
          width: widget.width,
          child: DecoratedBox(
            decoration: BoxDecoration(color: p.track),
            child: reduceMotion
                ? null
                : AnimatedBuilder(
                    animation: _controller,
                    builder: (BuildContext context, Widget? child) {
                      // 微光自左向右扫过（进度 −0.2 → 1.2，落到条外时不可见）
                      final double t = _controller.value * 1.4 - 0.2;
                      return CustomPaint(
                        painter: _ShimmerPainter(
                          t: t,
                          color: p.surface.withValues(alpha: 0.55),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  _ShimmerPainter({required this.t, required this.color});

  /// 扫描进度 −0.2 … 1.2（超出即整条透明，形成「扫过」而不是「常亮」）
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // 光带宽度取条长的 45%，中心随 t 从条左外扫到条右外。
    // 用偏移后的 Rect 生成 shader：`LinearGradient` 默认 clamp，
    // 带外自动取端点色（全透明），无需额外裁剪。
    final double band = size.width * 0.45;
    final double center = t * (size.width + band) - band / 2;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          colors: <Color>[
            color.withValues(alpha: 0),
            color,
            color.withValues(alpha: 0),
          ],
        ).createShader(
          Rect.fromLTWH(center - band / 2, 0, band, size.height),
        ),
    );
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.t != t || old.color != color;
}

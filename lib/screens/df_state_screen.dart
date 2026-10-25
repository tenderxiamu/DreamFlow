import 'package:flutter/material.dart';

import 'package:dreamflow/design_system/widgets/df_screen.dart';
import 'package:dreamflow/design_system/widgets/df_states.dart';

/// §12 缺口 4 —— 空 / 加载 / 异常状态屏（设计侧尚未出正式稿，此为框架层缺省实现）
///
/// 与其余五屏共用同一个 [DfScreenScaffold]（画布 + 墨晕 + 纸纹），
/// 因此状态页在双主题下同样成立，且不需要任何额外适配。
class DfStateScreen extends StatelessWidget {
  const DfStateScreen({super.key, required this.kind, this.onRetry});

  final DfStateKind kind;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return DfScreenScaffold(
      centerBody: true,
      body: DfStateSwitch(kind: kind, onRetry: onRetry),
    );
  }
}

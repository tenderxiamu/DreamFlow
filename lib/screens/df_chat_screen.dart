import 'package:flutter/material.dart';

import 'package:dreamflow/design_system/df_tokens.dart';
import 'package:dreamflow/design_system/df_type.dart';
import 'package:dreamflow/design_system/widgets/df_controls.dart';
import 'package:dreamflow/design_system/widgets/df_icons.dart';
import 'package:dreamflow/design_system/widgets/df_screen.dart';
import 'package:dreamflow/design_system/widgets/df_sheep.dart';
import 'package:dreamflow/design_system/widgets/df_surfaces.dart';

/// §7 B 睡前情绪对话（t-night）
class DfChatScreen extends StatelessWidget {
  const DfChatScreen({super.key, this.controller, this.onSend});

  final TextEditingController? controller;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    final DfPalette p = DfPalette.of(context);

    final TextSpan breathing = TextSpan(
      children: <InlineSpan>[
        TextSpan(
          text: '我懂的。那我们先不解决问题——跟着我，',
          style: DfType.bubble(context, p.text),
        ),
        TextSpan(
          text: '吸气四拍，再用更长的六拍呼出去，重复三次。',
          style: DfType.bubble(context, p.mistGreen),
        ),
      ],
    );

    return DfScreenScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 头部行：头像 38（小羊 30）+ 名字 16 + 在线态 ｜ 时间
          Row(
            children: <Widget>[
              const DfAvatar(diameter: 38, sheepHeight: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '梦洄',
                      style: DfType.body(context, p.text),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: p.mistGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '在线 · 陪你入睡',
                          style: DfType.caption(context, p.text2),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text('22:41', style: DfType.caption(context, p.text3)),
            ],
          ),
          const SizedBox(height: 22),
          const DfBubble(text: '看起来今天有些累呢，愿意和我说说，今天发生了什么让你放不下的事吗？'),
          const SizedBox(height: 12),
          const DfBubble(text: '工作上有点急，脑子里停不下来。', mine: true),
          const SizedBox(height: 12),
          DfBubble(text: '', rich: breathing),
          const SizedBox(height: 16),
          DfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '此刻识别到的情绪',
                  style: DfType.bodyS(context, p.text2),
                ),
                const SizedBox(height: 10),
                const Row(
                  children: <Widget>[
                    DfChip(label: '焦虑', selected: true),
                    SizedBox(width: 8),
                    DfChip(label: '疲惫'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: DfField(
                  hint: '说点什么…',
                  controller: controller,
                  onSubmitted: (_) => onSend?.call(),
                ),
              ),
              const SizedBox(width: 10),
              DfIconButton(
                glyph: DfGlyph.mic,
                semanticLabel: '按住说话',
                onPressed: onSend,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // §11 该注脚必须保留
          Text(
            '内容仅用于情绪陪伴，不构成医疗建议',
            textAlign: TextAlign.center,
            style: DfType.caption(context, p.text3),
          ),
        ],
      ),
    );
  }
}

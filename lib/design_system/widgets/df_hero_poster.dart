import 'package:flutter/material.dart';

import 'package:dreamflow/design_system/df_tokens.dart';

/// §6.13 首页 Hero 插画（M7.3）
///
/// 换成画师的整幅插画（月牙 + 睡着的人 + 云上的小生物），替掉原来那张
/// 纯代码画的墨山。三件事值得写下来：
///
/// 1. **按原比例出，不裁**。原图 1440×1079（4:3）。用 cover 塞进原来 214 高的卡片
///    （约 1.7:1）会横着削掉两成、或者上下各切一刀 —— 上面切掉月亮尖，下面切掉肩膀。
///    所以卡片高度跟着宽度走：`AspectRatio` + 1440/1079，高度约 265。
/// 2. **不做压暗**。壁纸要压是因为白字压在上面；这张是独立卡片，图本身就是夜。
///    真机上它比画布亮一些，反而成了首页唯一的"画"，视线落点正好在招呼语下面。
/// 3. **filterQuality 用 medium**。3x 屏上 1440 宽的图正好 1:1，用 high 只是多花
///    GPU 时间；medium 在 1:1 和轻微缩放下的肉眼差别看不出来。
class DfHeroPoster extends StatelessWidget {
  const DfHeroPoster({super.key});

  static const double _w = 1440;
  static const double _h = 1079;

  /// 卡片宽高比 = 原图宽高比
  static const double aspect = _w / _h;

  static const String _asset = 'assets/poster/hero_night.jpg';

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AspectRatio(
        aspectRatio: aspect,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(DfRadius.card),
          child: Image.asset(
            _asset,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// DreamFlow 设计令牌 · §3 色彩 + §3.3 复合令牌
///
/// 双主题：夜墨 [DfPalette.night] / 宣纸 [DfPalette.paper]。
/// 组件**只读取本类字段，禁止硬编码色值**（§10-1）；切换主题 = 换 ThemeData，组件零改动（§5.2）。
@immutable
class DfPalette extends ThemeExtension<DfPalette> {
  const DfPalette({
    required this.canvas,
    required this.canvas2,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.text,
    required this.text2,
    required this.text3,
    required this.mistBlue,
    required this.mistGreen,
    required this.mistPink,
    required this.mistYellow,
    required this.onMist,
    required this.deep,
    required this.sceneA,
    required this.sceneB,
    required this.m1,
    required this.m2,
    required this.m3,
    required this.sheepWool,
    required this.sheepLine,
    required this.blush,
    required this.cardTint,
    required this.wash1,
    required this.wash2,
    required this.flywhite,
    required this.grain,
    required this.track,
    required this.ringBg,
    required this.onDeep,
    required this.ink500,
    required this.ink400,
    required this.glow,
    required this.btnInner,
    required this.brightness,
  });

  // 底 / 面
  final Color canvas; // 屏底
  final Color canvas2; // 点睛层（近山 / 投影）
  final Color surface; // 卡片面
  final Color surface2; // 卡片面 2（洞察卡 / 头像底）
  final Color line; // 描边线

  // 文字
  final Color text; // 正文
  final Color text2; // 次级文字
  final Color text3; // 弱文字

  // 莫兰迪
  final Color mistBlue; // 主色 / CTA
  final Color mistGreen; // 成功 / 良好
  final Color mistPink; // 暖点 / 告警
  final Color mistYellow; // 月亮 / 高光
  final Color onMist; // 莫兰迪面上的字
  final Color deep; // 重墨点睛

  // 场景
  final Color sceneA; // 天空渐变起
  final Color sceneB; // 天空渐变止
  final Color m1; // 远山
  final Color m2; // 中景
  final Color m3; // 近山

  // 吉祥物
  final Color sheepWool;
  final Color sheepLine;
  final Color blush;

  // 效果 / 复合令牌
  final Color cardTint;
  final Color wash1;
  final Color wash2;
  final Color flywhite;
  final double grain;
  final Color track;
  final Color ringBg;
  final Color onDeep;
  final Color ink500;
  final Color ink400;
  final Color glow; // 主按钮彩色光晕
  final Color btnInner; // 主按钮内侧底影

  final Brightness brightness;

  // ───────────────────────── 夜墨 t-night ─────────────────────────
  static const DfPalette night = DfPalette(
    canvas: Color(0xFF14161A),
    canvas2: Color(0xFF0F1114),
    surface: Color(0xFF24282E),
    surface2: Color(0xFF1C1F24),
    line: Color(0xFF333A42),
    text: Color(0xFFF2F0EA),
    text2: Color(0xFF9BA5AF),
    text3: Color(0xFF7C8794),
    mistBlue: Color(0xFFA8B0B8),
    mistGreen: Color(0xFFB0B8A8),
    mistPink: Color(0xFFD4B0AC),
    mistYellow: Color(0xFFD4C8A8),
    onMist: Color(0xFF14161A),
    deep: Color(0xFF0F1114),
    sceneA: Color(0xFF1B2029),
    sceneB: Color(0xFF101317),
    m1: Color(0xFF3A424E),
    m2: Color(0xFF2A313B),
    m3: Color(0xFF1B2028),
    sheepWool: Color(0xFFEDEAE0),
    sheepLine: Color(0x6B14161A), // rgba(20,22,26,.42)
    blush: Color(0xFFD4B0AC),
    cardTint: Color(0x0BF2F0EA), // rgba(242,240,234,.045)
    wash1: Color(0x1AA8B0B8), // rgba(168,176,184,.10)
    wash2: Color(0x12B0B8A8), // rgba(176,184,168,.07)
    flywhite: Color(0x0EF2F0EA), // rgba(242,240,234,.055)
    grain: 0.5,
    track: Color(0x38A8B0B8), // rgba(168,176,184,.22)
    ringBg: Color(0x29A8B0B8), // rgba(168,176,184,.16)
    onDeep: Color(0xFFF2F0EA),
    ink500: Color(0xFF5A6470),
    ink400: Color(0xFF7C8794),
    glow: Color(0x3DA8B0B8), // rgba(168,176,184,.24)
    btnInner: Color(0x1A14161A), // rgba(20,22,26,.10)
    brightness: Brightness.dark,
  );

  // ───────────────────────── 宣纸 t-paper ─────────────────────────
  static const DfPalette paper = DfPalette(
    canvas: Color(0xFFF4F2EC),
    canvas2: Color(0xFFEDEAE1),
    surface: Color(0xFFFBFAF6),
    surface2: Color(0xFFF7F5EF),
    line: Color(0xFFDCD6C8),
    text: Color(0xFF1A1D21),
    text2: Color(0xFF565E66),
    text3: Color(0xFF706A5A),
    mistBlue: Color(0xFF5C6B78),
    mistGreen: Color(0xFF5F6B58),
    mistPink: Color(0xFF8F625D),
    mistYellow: Color(0xFF75683A),
    onMist: Color(0xFFF7F5EF),
    deep: Color(0xFF1A1D21),
    sceneA: Color(0xFFEFEBE1),
    sceneB: Color(0xFFFBFAF6),
    m1: Color(0xFFC9C6BB),
    m2: Color(0xFFB4B2A8),
    m3: Color(0xFF9E9C93),
    sheepWool: Color(0xFFFBFAF6),
    sheepLine: Color(0xFF2A2E33),
    blush: Color(0xFF8F625D),
    cardTint: Color(0x071A1D21), // rgba(26,29,33,.028)
    wash1: Color(0x175C6B78), // rgba(92,107,120,.09)
    wash2: Color(0x125F6B58), // rgba(95,107,88,.07)
    flywhite: Color(0x0B1A1D21), // rgba(26,29,33,.045)
    grain: 0.42,
    track: Color(0x335C6B78), // rgba(92,107,120,.20)
    ringBg: Color(0x245C6B78), // rgba(92,107,120,.14)
    onDeep: Color(0xFF1A1D21),
    ink500: Color(0xFFB2AB9B),
    ink400: Color(0xFF706A5A),
    glow: Color(0x385C6B78), // rgba(92,107,120,.22)
    btnInner: Color(0x1A1A1D21),
    brightness: Brightness.light,
  );

  /// 取当前主题令牌：`DfPalette.of(context).surface`
  static DfPalette of(BuildContext context) =>
      Theme.of(context).extension<DfPalette>() ?? DfPalette.night;

  @override
  DfPalette copyWith() => this;

  @override
  DfPalette lerp(ThemeExtension<DfPalette>? other, double t) {
    if (other is! DfPalette) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    double d(double a, double b) => a + (b - a) * t;
    return DfPalette(
      canvas: c(canvas, other.canvas),
      canvas2: c(canvas2, other.canvas2),
      surface: c(surface, other.surface),
      surface2: c(surface2, other.surface2),
      line: c(line, other.line),
      text: c(text, other.text),
      text2: c(text2, other.text2),
      text3: c(text3, other.text3),
      mistBlue: c(mistBlue, other.mistBlue),
      mistGreen: c(mistGreen, other.mistGreen),
      mistPink: c(mistPink, other.mistPink),
      mistYellow: c(mistYellow, other.mistYellow),
      onMist: c(onMist, other.onMist),
      deep: c(deep, other.deep),
      sceneA: c(sceneA, other.sceneA),
      sceneB: c(sceneB, other.sceneB),
      m1: c(m1, other.m1),
      m2: c(m2, other.m2),
      m3: c(m3, other.m3),
      sheepWool: c(sheepWool, other.sheepWool),
      sheepLine: c(sheepLine, other.sheepLine),
      blush: c(blush, other.blush),
      cardTint: c(cardTint, other.cardTint),
      wash1: c(wash1, other.wash1),
      wash2: c(wash2, other.wash2),
      flywhite: c(flywhite, other.flywhite),
      grain: d(grain, other.grain),
      track: c(track, other.track),
      ringBg: c(ringBg, other.ringBg),
      onDeep: c(onDeep, other.onDeep),
      ink500: c(ink500, other.ink500),
      ink400: c(ink400, other.ink400),
      glow: c(glow, other.glow),
      btnInner: c(btnInner, other.btnInner),
      brightness: t < 0.5 ? brightness : other.brightness,
    );
  }
}

/// §4.1 间距梯度（pt）
class DfSpace {
  const DfSpace._();
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 24;
  static const double s6 = 32;
  static const double s7 = 48;

  /// 屏左右留白（恒定，不随宽度变化）
  static const double padX = 20;

  /// 内容区上边距（§2 内容区 padding: 14px 20px 0）
  static const double contentTop = 14;
}

/// §4.2 字号梯度（8 档，0.5px 已归一）
class DfFontSize {
  const DfFontSize._();
  static const double caption = 11; // 注脚 / Tab / 单位
  static const double small = 12; // 辅助说明 / 徽标
  static const double bodyS = 13; // 正文（气泡 / 说明）
  static const double body = 14; // 次级按钮字
  static const double input = 16; // 输入框（硬性，防 iOS 聚焦缩放）/ 主按钮字
  static const double titleS = 19; // 卡片 / 模块标题
  static const double title = 25; // 页面主标题
  static const double display = 34; // 场景大数字 / 环形睡眠分
}

/// §4.2 行高
class DfLineHeight {
  const DfLineHeight._();
  static const double title = 1.35;
  static const double body = 1.6;
  static const double bubble = 1.62;
  static const double insight = 1.7;
}

/// §4.4 圆角（仅 2 种 + 指标格 14 嵌套件）
class DfRadius {
  const DfRadius._();
  static const double card = 20;
  static const double metric = 14;
  static const double pill = 999;
}

/// §4.4 阴影（仅 2 层）
class DfShadow {
  const DfShadow._();
  static const List<BoxShadow> l1 = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> l2 = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
  ];
}

/// §4.4 触控尺寸
class DfTouch {
  const DfTouch._();
  static const double min = 44; // Tab / 话筒
  static const double play = 66; // 圆形播放键
  static const double primaryH = 56; // 主按钮
  static const double secondaryH = 48; // 唤醒次按钮
}

/// §8 动效
class DfMotion {
  const DfMotion._();
  static const Duration dur = Duration(milliseconds: 200);
  static const Duration max = Duration(milliseconds: 240);
  static const Duration sheepFloat = Duration(milliseconds: 3600);
  static const Curve ease = Cubic(0.4, 0, 0.2, 1);
}

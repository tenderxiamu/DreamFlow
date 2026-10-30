import 'package:flutter_test/flutter_test.dart';

import 'package:dreamflow/data/df_wallpaper.dart';

/// M7.2 壁纸选择：只验逻辑，不验像素。
void main() {
  final DfWallpapers w = DfWallpapers.instance;

  setUp(() async {
    // 测试环境没有 path_provider，关掉落盘
    DfWallpapers.persistenceEnabled = false;
    await w.load();
    await w.select(DfWall.auto);
  });

  test('默认跟随主题：深色配一缕，浅色配晨霞', () {
    expect(w.choice, DfWall.auto);
    expect(w.resolve(dark: true), DfWall.wisp);
    expect(w.resolve(dark: false), DfWall.dawn);
  });

  test('手动选定的壁纸不受主题影响', () async {
    await w.select(DfWall.clear);
    expect(w.resolve(dark: true), DfWall.clear);
    expect(w.resolve(dark: false), DfWall.clear);
  });

  test('选「不用壁纸」时没有任何资源，调用方据此不画图层', () async {
    await w.select(DfWall.none);
    expect(w.resolve(dark: true), DfWall.none);
    expect(w.assetFor(DfWall.none), isNull);
  });

  test('除 none / auto / custom 之外每个选项都有资源，且路径存在声明', () {
    for (final DfWall v in DfWallpapers.choices) {
      if (v == DfWall.none || v == DfWall.auto || v == DfWall.custom) continue;
      final String? a = w.assetFor(v);
      expect(a, isNotNull, reason: '$v 缺资源');
      expect(a, startsWith('assets/wallpaper/'));
      expect(a, endsWith('.jpg'));
    }
  });

  test('每个选项都有名字和说明，不会出现空行', () {
    for (final DfWall v in DfWallpapers.choices) {
      expect(DfWallpapers.label(v), isNotEmpty, reason: '$v 缺名字');
      expect(DfWallpapers.caption(v), isNotEmpty, reason: '$v 缺说明');
    }
  });

  test('重复选同一张不会重复通知', () async {
    await w.select(DfWall.wisp);
    int calls = 0;
    void listener() => calls++;
    w.addListener(listener);
    await w.select(DfWall.wisp);
    w.removeListener(listener);
    expect(calls, 0);
  });

  test('切换会发出通知，界面才能跟着重绘', () async {
    int calls = 0;
    void listener() => calls++;
    w.addListener(listener);
    await w.select(DfWall.dusk);
    w.removeListener(listener);
    expect(calls, 1);
  });

  // ── M9 相册壁纸 ──────────────────────────────────────────────────────

  group('相册壁纸', () {
    const String p1 = '/data/media/wallpaper_1.jpg';
    const String p2 = '/data/media/wallpaper_2.jpg';

    test('selectCustom 选中相册选项并记下文件路径', () async {
      await w.selectCustom(p1);
      expect(w.choice, DfWall.custom);
      expect(w.customPath, p1);
      // 相册壁纸画文件不画资源，两个出口必须一开一关
      expect(w.filePathFor(DfWall.custom), p1);
      expect(w.assetFor(DfWall.custom), isNull);
    });

    test('相册壁纸不受主题影响（它是具体选择，不是规则）', () async {
      await w.selectCustom(p1);
      expect(w.resolve(dark: true), DfWall.custom);
      expect(w.resolve(dark: false), DfWall.custom);
    });

    test('再选一张是替换不是追加：路径更新，选项不变', () async {
      await w.selectCustom(p1);
      await w.selectCustom(p2);
      expect(w.choice, DfWall.custom);
      expect(w.customPath, p2);
    });

    test('切到别的选项路径还在，切回来直接显示', () async {
      await w.selectCustom(p1);
      await w.select(DfWall.dusk);
      expect(w.customPath, p1, reason: '换壁纸不该丢相册照片');
      await w.select(DfWall.custom);
      expect(w.filePathFor(DfWall.custom), p1);
    });

    test('选相册壁纸会通知界面重绘', () async {
      int calls = 0;
      void listener() => calls++;
      w.addListener(listener);
      await w.selectCustom(p1);
      w.removeListener(listener);
      expect(calls, 1);
    });
  });
}

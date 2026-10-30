import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// M7.2：应用壁纸
///
/// 用户给了九张实拍天空，挑出四张做成竖屏壁纸。**处理方式和普通的「换背景图」
/// 不一样**：源图是横拍 4:3，手机是 9:19.5，硬 cover 裁完只剩中间一小条再放大
/// 2.4 倍，云会糊成一团脏斑。所以素材在 `tool/make_wallpaper.py` 里先被竖切、
/// 再重模糊（GaussianBlur 16~22）、加极轻噪点：
/// - **重模糊是必需的**，壁纸是背景不是照片。清晰照片压在文字下面会打架，
///   而且模糊顺带掩盖了低分辨率放大这件事
/// - **噪点用来打散 banding**，模糊后的平滑渐变经 JPEG 压缩很容易拉出色带
///
/// 运行时只做一件事：图 + 一层用画布色糊上去的渐变压暗（见 `DfWallpaper`），
/// 压暗比例由主题决定 —— 夜墨需要压得狠，宣纸本身是奶白，糊上去自然变成水彩。
class DfWallpapers extends ChangeNotifier {
  DfWallpapers._();

  static final DfWallpapers instance = DfWallpapers._();

  /// **测试缝隙**：与 [DfAccount] 同一套路 —— `testWidgets` 里 path_provider
  /// 的调用不会返回，用例会挂死且没有任何异常，所以把落盘和状态切开。
  @visibleForTesting
  static bool persistenceEnabled = true;

  static const Map<DfWall, String> _assets = <DfWall, String>{
    DfWall.dusk: 'assets/wallpaper/w_dusk.jpg',
    DfWall.dawn: 'assets/wallpaper/w_dawn.jpg',
    DfWall.clear: 'assets/wallpaper/w_clear.jpg',
    DfWall.wisp: 'assets/wallpaper/w_wisp.jpg',
  };

  static const Map<DfWall, String> _labels = <DfWall, String>{
    DfWall.auto: '跟随主题',
    DfWall.dusk: '暮云',
    DfWall.dawn: '晨霞',
    DfWall.clear: '晴空',
    DfWall.wisp: '一缕',
    DfWall.custom: '相册照片',
    DfWall.none: '不用壁纸',
  };

  static const Map<DfWall, String> _captions = <DfWall, String>{
    DfWall.auto: '夜墨配暮云，宣纸配晨霞',
    DfWall.dusk: '厚云压着最后一点落日',
    DfWall.dawn: '淡蓝里几朵橘色碎云',
    DfWall.clear: '晴天的积云，光很足',
    DfWall.wisp: '一整片灰蓝，只有一丝白',
    DfWall.custom: '从你的相册挑一张',
    DfWall.none: '回到纯色画布',
  };

  static String label(DfWall w) => _labels[w] ?? '';
  static String caption(DfWall w) => _captions[w] ?? '';

  /// 壁纸在选项列表里的展示顺序（auto 在最前，none 在最后）
  static const List<DfWall> choices = <DfWall>[
    DfWall.auto,
    DfWall.dusk,
    DfWall.dawn,
    DfWall.clear,
    DfWall.wisp,
    DfWall.custom,
    DfWall.none,
  ];

  DfWall _choice = DfWall.auto;

  /// 相册壁纸（M9）。指向应用私有目录的压缩副本（长边 1600），
  /// 不是相册原图 —— 原图删了壁纸不能跟着消失。
  String? _customPath;
  bool _ready = false;

  DfWall get choice => _choice;

  /// 当前相册壁纸路径（还没选过相册照片时为 null）
  String? get customPath => _customPath;

  bool get ready => _ready;

  /// 实际要画哪张图。返回 null 表示不画（纯色画布）。
  ///
  /// `auto` 不是一张图，是一条规则：深色配「一缕」，浅色配「晨霞」。
  /// 放在这里而不是 widget 里，是为了让调用方只问一次「我该显示什么」。
  String? assetFor(DfWall resolved) => _assets[resolved];

  /// 相册壁纸要画**文件**而不是资源，所以单独一个出口。
  /// widget 先问这个，再问 [assetFor]。
  String? filePathFor(DfWall resolved) =>
      resolved == DfWall.custom ? _customPath : null;

  /// 深色默认不是「暮云」而是「一缕」—— 这是真机试出来的。
  ///
  /// 暮云是大面积暖棕，压在近黑的画布上会变成一块发闷的褐色雾；
  /// 一缕的灰蓝和夜墨是同一个色系，压暗之后像「夜里隔着窗看天」，
  /// 而且它本来就没什么细节，模糊之后不会出现假的云块。
  /// 暮云留着给喜欢暖调的人自己选。
  DfWall resolve({required bool dark}) {
    if (_choice != DfWall.auto) return _choice;
    return dark ? DfWall.wisp : DfWall.dawn;
  }

  Future<File> _file() async {
    final Directory dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}wallpaper.json');
  }

  Future<void> load() async {
    if (!persistenceEnabled) {
      _ready = true;
      notifyListeners();
      return;
    }
    try {
      final File f = await _file();
      if (await f.exists()) {
        final Map<String, dynamic> m =
            jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        final String? name = m['choice'] as String?;
        _choice = DfWall.values.firstWhere(
          (DfWall w) => w.name == name,
          orElse: () => DfWall.auto,
        );
        _customPath = m['customPath'] as String?;
      }
    } catch (_) {
      // 文件坏了就当没设过，不让启动挂在这
    } finally {
      _ready = true;
      notifyListeners();
    }
  }

  Future<void> select(DfWall w) async {
    if (_choice == w) return;
    _choice = w;
    notifyListeners();
    if (!persistenceEnabled) return;
    try {
      final File f = await _file();
      await f.writeAsString(jsonEncode(<String, dynamic>{
        'choice': w.name,
        'customPath': _customPath,
      }));
    } catch (_) {
      // 落盘失败不影响本次使用
    }
  }

  /// 设为相册壁纸（M9）。[path] 是 `DfMedia.pickImage(forAvatar: false)`
  /// 返回的私有目录副本。
  ///
  /// 旧文件在落盘成功后才删（和 [DfAccount.setAvatar] 同一套顺序）。
  /// 已经有相册壁纸再选一张 = 替换，不是追加 —— 应用目录里最多留一张。
  Future<void> selectCustom(String path) async {
    final String? old = _customPath;
    if (old != null && old == path && _choice == DfWall.custom) return;
    _customPath = path;
    _choice = DfWall.custom;
    notifyListeners();
    if (!persistenceEnabled) return;
    try {
      final File f = await _file();
      await f.writeAsString(jsonEncode(<String, dynamic>{
        'choice': DfWall.custom.name,
        'customPath': path,
      }));
    } catch (_) {}
    if (old != null && old != path) {
      File(old).delete().then<void>(
            (FileSystemEntity _) {},
            onError: (Object _) {},
          );
    }
  }
}

enum DfWall { auto, dusk, dawn, clear, wisp, custom, none }

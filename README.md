# DreamFlow 梦洄

私人定制音频助眠应用 · 水墨 × 莫兰迪设计体系（Ink-Morandi）。

## 技术栈

- **Flutter 3.19**（单代码库，iOS / Android）
- go_router（三 Tab 导航壳）· flutter_riverpod（状态管理 · 日/夜双主题）
- Drift（SQLite 本地库：情绪记录 / 睡眠会话）
- just_audio + audio_service（后台播放 / 锁屏控制中心）
- 三字体 OFL 子集化（Ma Shan Zheng / LXGW WenKai / Cormorant Garamond）

## 音景资产

`assets/audio/` 内音景来自 Pixabay（Pixabay Content License，可免费商用、无需署名），
逐条授权登记见 [assets/AUDIO_LICENSES.md](assets/AUDIO_LICENSES.md)。

## 产物

`build/app/outputs/flutter-apk/`

| 文件 | 说明 | 体积 |
|---|---|---|
| `app-release.apk` | 全 ABI 内测包（arm64-v8a / armeabi-v7a / x86_64） | 约 81 MB |
| `app-arm64-v8a-release.apk` | 主流真机包（推荐分发） | 约 43 MB |
| `app-armeabi-v7a-release.apk` | 32 位老机型 | 约 41 MB |
| `app-x86_64-release.apk` | 模拟器 | 约 45 MB |

> release 包当前使用 debug 签名（Flutter 模板默认），仅供内测安装；上架前需配置正式 keystore。

## 图标与启动屏

- 图标母稿：手绘蜡笔画 `tool/icon_source.png`（小虫趴在云上做梦，右上飘 Z）。
- 生成脚本 `tool/make_icons.py`：色度抠图把笔触从原蓝底分离 → alpha 拉伸去雾斑 →
  重新压在「深夜蓝」径向渐变底上 → 分平台导出（Android 传统/圆形/自适应前景+背景、
  iOS 19 尺寸、Web）。改图只需替换 `icon_source.png` 后重跑脚本。
- 自适应图标为分层结构：`@mipmap/ic_launcher_bg`（渐变）+ `ic_launcher_fg`（笔触，
  图形占 108dp 画布 59%，确保圆形遮罩下不被切）
- 启动屏：夜墨 `#14161A`（与首屏睡前模式无缝衔接），见 `res/drawable*/launch_background.xml`

## 签名

- 正式签名：`android/key.jks` + `android/key.properties`（两者不入版本库），
  keystore 备份在仓库外 `keystore-backup/`。换机器时把两者放回原位即可重签。
- `build.gradle.kts`：有 `key.properties` 走正式签名，没有则回退 debug 签名。

## 构建（国内网络环境）

```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://mirrors.cloud.tencent.com/flutter
flutter pub get
flutter build apk --debug
```

说明：
- sqlite3 的 native assets 默认从 GitHub 下载预编译库；本仓库已预下载至
  `tool/sqlite3_native/`（pubspec 中 `hooks.user_defines` 指向该目录），无需联网。
- 运行 `flutter test` 时建议临时移除 `HTTP_PROXY/HTTPS_PROXY` 环境变量，
  否则代理会劫持 flutter_tester 的本地 WebSocket 连接。

## 里程碑

| 阶段 | 内容 | 状态 |
|---|---|---|
| M1 | App 壳 + 设计系统迁移 + 字体子集化 | ✅ |
| M2 | 导航骨架 + Riverpod 主题 + Drift 数据层 | ✅ |
| M3 | 音景播放 + 后台播放 + 锁屏控制 | ✅ |
| M4 | LLM 对话（情绪识别卡 + 免责注脚合规） | ✅ |
| M5 | 渐进式唤醒（浅睡窗口 + 唤醒通知）+ 本地睡眠报告 | ✅ |
| M6 | 图标/启动屏/双端打包分发 | ✅ |

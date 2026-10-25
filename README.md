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
| M4 | LLM 对话（情绪识别卡 + 免责注脚合规） | 🚧 |
| M5 | 渐进式唤醒 + 本地睡眠报告 | ⬜ |
| M6 | 图标/启动屏/双端打包分发 | ⬜ |

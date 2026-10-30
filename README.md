# DreamFlow 梦洄

私人定制音频助眠应用 · 水墨 × 莫兰迪设计体系（Ink-Morandi）。

睡前对话 / 情绪落笔 / 音景助眠 / 渐进式唤醒 / 本地睡眠报告。数据全部在本机，
无账号体系、无广告、无第三方统计 SDK。

## 功能一览

- **睡前对话**：LLM 驱动的共情陪伴（WorkBuddy 云服务免密钥代理，模型密钥不出服务端），
  本地情绪判定引擎——否定词识别、危机干预词表（窄表设计：误报一次用户就不再说实话）、
  12356 心理援助热线卡
- **音景**：后台播放 + 锁屏控制中心，动态场景视频
- **渐进式唤醒**：浅睡窗口精准闹钟 + 唤醒通知 + 本地睡眠报告
- **个性化**：自定义头像与壁纸（**零权限**——系统 `ACTION_PICK` 临时授权，
  原生侧完成 EXIF 旋转 / 裁剪 / 压缩后拷入应用私有目录，全程不申请媒体权限）

## 技术栈

- **Flutter 3.19**（单代码库，iOS / Android）
- go_router（三 Tab 导航壳）· flutter_riverpod（状态管理 · 日/夜双主题）
- Drift（SQLite 本地库：情绪记录 / 睡眠会话，全参数化查询）
- just_audio + audio_service（后台播放 / 锁屏控制中心）
- http（唯一出网通道：应用绑定的 WorkBuddy 云服务域名，全程 HTTPS）
- 三字体 OFL 子集化（Ma Shan Zheng / LXGW WenKai / Cormorant Garamond）

## 密钥与配置（重要）

本仓库**不包含任何明文密钥**。需要区分两类「key」：

### 1. publishableKey（云服务应用标识）

- 位置：`lib/data/cloud_config.dart`，**运行时拼装**——逐字节 XOR → base64 →
  切三段乱序存放（`_encPart1/2/3`），仓库与 APK 内均无完整明文
- 它只标识应用、不带权限，真正的模型密钥在服务端；但为防拆包顺手提取，
  请**不要**把明文 key 提交进任何文件
- **轮换流程**（在 WorkBuddy 控制台重置 key 后）：
  ```bash
  DF_WB_KEY=<你的新key> python tool/encode_publishable_key.py
  # 这里输入你的 key：脚本输出三段新分片 + 一致性自检，
  # 覆盖 cloud_config.dart 中对应三个常量，然后 flutter test 确认
  ```
- 临时脚本（如 `tool/llm_bench.py`）从环境变量读取，**这里输入你的 key**：
  ```bash
  DF_WB_KEY=<你的key> python tool/llm_bench.py [模型ID...]
  ```

### 2. 签名 keystore（上架用，与上面无关）

```bash
# 复制 android/key.properties.example 为 android/key.properties，
# 这里输入你的 keystore 密码等信息；key.jks 不入版本库，备份在仓库外
cp android/key.properties.example android/key.properties
```

`build.gradle.kts`：有 `key.properties` 走正式签名，没有则回退 debug 签名。

## 构建（国内网络环境）

```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://mirrors.cloud.tencent.com/flutter
flutter pub get
flutter build apk --release --split-per-abi
```

说明：
- sqlite3 的 native assets 默认从 GitHub 下载预编译库；本仓库已预下载至
  `tool/sqlite3_native/`（pubspec 中 `hooks.user_defines` 指向该目录），无需联网。
- 运行 `flutter test` 时建议临时移除 `HTTP_PROXY/HTTPS_PROXY` 环境变量，
  否则代理会劫持 flutter_tester 的本地 WebSocket 连接。
- `tool/struct_check.py`：结构自检（括号/注释状态机/import/export 配平）。

## 产物

`build/app/outputs/flutter-apk/`

| 文件 | 说明 | 体积 |
|---|---|---|
| `app-arm64-v8a-release.apk` | 主流真机包（推荐分发） | 约 48 MB |
| `app-armeabi-v7a-release.apk` | 32 位老机型 | 约 46 MB |
| `app-x86_64-release.apk` | 模拟器 | 约 50 MB |

release 包使用正式签名（见上文「签名 keystore」）。

## 安全说明

- 权限最小化：仅 `INTERNET` / `WAKE_LOCK` / 前台服务 / 通知 / 精确闹钟，
  无存储、相册、相机、定位、联系人权限
- 数据本机化：对话 / 情绪 / 睡眠记录在应用私有目录（SQLite + JSON），
  云端只上行对话文本（经云服务代理，模型密钥不出服务端）
- 防注入：Drift 参数化查询、无 WebView、LLM 输出仅进纯文本组件、无动态代码加载
- 完整评估见仓库外《梦洄-安全评估报告》（2026-10-30，总体低风险）

## 音景资产

`assets/audio/` 内音景来自 Pixabay（Pixabay Content License，可免费商用、无需署名），
逐条授权登记见 [assets/AUDIO_LICENSES.md](assets/AUDIO_LICENSES.md)。

## 图标与启动屏

- 图标母稿：手绘蜡笔画 `tool/icon_source.png`（小虫趴在云上做梦，右上飘 Z）。
- 生成脚本 `tool/make_icons.py`：色度抠图 → alpha 去雾斑 → 重压「深夜蓝」径向渐变底 →
  分平台导出（Android 传统/圆形/自适应前景+背景、iOS 19 尺寸、Web）。
- 启动屏：夜墨 `#14161A`（与首屏睡前模式无缝衔接）。

## 里程碑

| 阶段 | 内容 | 状态 |
|---|---|---|
| M1 | App 壳 + 设计系统迁移 + 字体子集化 | ✅ |
| M2 | 导航骨架 + Riverpod 主题 + Drift 数据层 | ✅ |
| M3 | 音景播放 + 后台播放 + 锁屏控制 | ✅ |
| M4 | LLM 对话（WorkBuddy 云服务免密钥代理） | ✅ |
| M5 | 渐进式唤醒 + 本地睡眠报告 | ✅ |
| M6 | 图标/启动屏/双端打包分发 | ✅ |
| M6.5 | 正式签名、商店素材、合规页、「我的」页 | ✅ |
| M6.7 | 对话提速（固定快模型 + 降级链路） | ✅ |
| M6.8 | 字体缺字根治 + 播放页重做 + 起床闹钟 | ✅ |
| M6.9 | 助眠页去噪 + 音景动态场景 | ✅ |
| M7 | 个人中心 + 本机账号（无密码设计）+ 每日问候 | ✅ |
| M7.3 | 首页插画替换（程序修字管线 `tool/make_poster.py`） | ✅ |
| M8 | 测试报告 9 项修复（回归 62→80） | ✅ |
| M9 | 自定义头像 + 相册壁纸（零权限 ACTION_PICK） | ✅ |
| M9.1 | 兜底模型修复（minimax-m3 下线 → m3.1-flash） | ✅ |
| M9.2 | publishableKey 防拆包提取（运行时拼装）+ 密钥出库 | ✅ |

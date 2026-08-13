# Talk With Anyone App

手机客户端，用于替代"手机浏览器访问"的方式连接电脑上的 [talk-with-anyone](https://github.com/wangguanghua2099/talk-with-anyone) 服务器。服务器是唯一"大脑"（LLM / TTS / ASR / 角色 / 会话），App 通过 HTTP/WebSocket 接口访问它。

## 平台

- 目前提供 **Android** 包
- iOS 未打包：代码 ~95% 共用，需 macOS + Xcode + Apple 开发者账号后在 Mac 上执行 `flutter build ios`

## 构建

```bash
flutter create --org com.talkwithanyone --project-name talk_with_anyone_app .
flutter pub get
flutter build apk --release
```

APK 输出在 `build/app/outputs/flutter-apk/app-release.apk`。

## 功能进度

| 里程碑 | 内容 | 状态 |
| --- | --- | --- |
| M1 | 环境 + 连接页（地址/口令/测试连接/自签名证书信任） | ✅ |
| M2 | 聊天页 + 流式 TTS 朗读 | ✅ |
| M3 | 电话模式全双工语音 | ✅ |
| M4 | 会话/角色管理 | ✅ |
| M5 | 打磨 + APK v0.1 | ✅（app-release.apk 49.4MB，已签名） |

## 目录结构

```
lib/
  main.dart          入口
  app.dart           App 根组件（已连接→主页，未连接→连接页）
  theme.dart         主题（主色 #007AFF，与网页一致）
  models/            数据模型（ServerInfo/Character/Conversation/Message/ChatResult）
  services/
    api_client.dart  HTTP/WS 客户端（口令注入 + 自签名证书信任 + WS 地址拼接）
    server_service.dart  服务器 HTTP 接口封装
    tts_service.dart  /ws/tts-stream 流式朗读（PCM16 打包成 WAV 播放）
    voice_service.dart    /ws/voice 全双工语音（录音 → 识别 → 回复朗读 + 自动打断）
    prefs.dart       本地持久化（服务器地址/口令）
  state/
    app_state.dart   全局状态（含 convVersion，会话切换后聊天页自动刷新）
  screens/           连接页 / 主页外壳 / 聊天 / 电话 / 会话与角色 / 设置
```

## 说明

- 服务器 `access_token` 为可选：为空则直接连接；非空需在连接页输入口令
- 自签名 HTTPS 证书由 App 直接信任（局域网自用场景；若暴露公网请改为证书锁定）
- 对话与 TTS 的 WebSocket 同样使用忽略证书校验的连接（`IOWebSocketChannel.connect(customClient: ...)`）

## 已完成的工程配置

- `AndroidManifest.xml`：已加 `INTERNET` + `RECORD_AUDIO` 权限，应用名 `Talk With Anyone`
- `minSdkVersion`：Flutter 默认 24，满足 record 插件要求（≥23）
- 国内网络：
  - `FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`、`PUB_HOSTED_URL=https://pub.flutter-io.cn`（Flutter 引擎 / Dart 包）
  - Gradle 发行包走腾讯镜像、Maven 依赖走阿里云镜像（见 `android/gradle/wrapper/gradle-wrapper.properties` 与 `android/settings.gradle.kts`）
  - `kotlin.incremental=false`：插件源码在 C:（pub cache）、项目在 D:，跨盘增量缓存报错
- `JAVA_HOME=D:\program\Android\Android Studio\jbr`（Android Studio 自带 JDK）

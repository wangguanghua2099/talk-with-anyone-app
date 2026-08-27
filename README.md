# Talk With Anyone · 手机客户端

本地优先的语音聊天智能体的 **Flutter 手机客户端**。配合 [Talk With Anyone](https://github.com/wangguanghua/talk-with-anyone)（FastAPI 服务端）使用，可在 Android / iOS / Web 上体验实时语音对话、文字聊天、角色切换等功能。

[English](./README_EN.md) | **简体中文**

---

## ✨ 功能特性

- 📞 **电话模式（全双工实时语音）**：基于两条 WebSocket 链路（`/ws/voice` 上行音频、`/ws/tts-stream` 下行 AI 回复），低延迟连续对话；支持回声消除、语音打断（VAD 检测说话即中断 AI）。
- 💬 **文字聊天**：多会话管理，消息流式展示，可随时停止朗读。
- 🗣️ **多 TTS 引擎**：`edge`（在线免费）、`moss`、`qwen3`、`qwen3-clone`（声音克隆）；进度条显示 + 音频/文本可保存到公共 Downloads。
- 🎭 **角色系统**：切换、新增、删除自定义 AI 角色（人设、头像、专属声音）。
- 📚 **知识库管理**：嵌入服务状态一览；多库管理——txt 上传/粘贴创建、增量追加、设为聊天用、删除，构建进度实时轮询；支持检索测试；聊天页一键开关知识库增强（开启后 AI 回答自动引用库内内容）。
- 🌐 **双语界面**：中文 / English 一键切换。
- 📡 **离线只读缓存**：以服务端为准，手机本地保存元数据快照与会话消息文件；离线时可浏览历史会话、角色与消息，**写操作被拦截并提示「需要联网」**。
- 🔒 **本地优先**：服务器地址与访问口令仅保存在本机 `SharedPreferences`，不上传、不随仓库分发。

## 🛠 技术栈

| 层 | 技术 |
| --- | --- |
| 框架 | Flutter 3.x（Dart ≥ 3.3） |
| 状态管理 | `provider` |
| 网络 | `dio` + `web_socket_channel` |
| 音频 | `record`（录音）、`just_audio`（播放）、`audio_session` |
| 存储 | `shared_preferences`、`path_provider`、`file_picker` |
| 图标 | `flutter_launcher_icons`（源图 `assets/icon/app_icon.png`，白底蓝燕子） |

## 🚀 快速开始

### 1. 环境要求

- Flutter SDK ≥ 3.3（建议最新稳定版），参见 [Flutter 安装](https://docs.flutter.dev/get-started/install)。
- 一台已运行 **Talk With Anyone** 服务端的机器（见下文「服务端准备」）。

### 2. 获取代码

```bash
git clone <本仓库地址> talk-with-anyone-app
cd talk-with-anyone-app
flutter pub get
```

### 3. 运行 / 构建

```bash
# 调试运行（默认会显示调试诊断条）
flutter run

# 发布构建 Android APK（release 下隐藏调试条）
flutter build apk --release

# iOS（需 macOS + Xcode）
flutter build ios --release

# Web
flutter build web
```

### 4. 连接服务端

首次打开 App 进入「连接」页，填写：

- **服务器地址**：如 `https://192.168.1.100:7862`（手机与服务端需在同一局域网；HTTPS 为麦克风/电话模式所必需，详见服务端说明）。
- **访问口令（可选）**：与服务端 `config.json` 中的 `access_token` 一致；留空表示服务端未启用鉴权。

该信息仅保存在本机，不会上传到任何第三方。

## 🖥 服务端准备

本客户端**不包含**语音识别 / 大模型 / TTS 推理，需自行部署服务端：

1. 克隆并启动 [Talk With Anyone](https://github.com/wangguanghua/talk-with-anyone)：
   ```bash
   git clone https://github.com/wangguanghua/talk-with-anyone
   cd talk-with-anyone
   pip install -r requirements.txt
   cp config.example.json config.json
   python main.py
   ```
2. 手机通过局域网 HTTPS 访问时，按服务端 README 生成自签证书（`python generate_cert.py`），并在手机端信任证书后授权麦克风。

> 服务端为本地优先设计：默认 Edge-TTS + 本地 LLM 即可无 GPU 运行；使用本地 MOSS-TTS / Qwen3-TTS / SenseVoice 建议配备 NVIDIA GPU。

## 🔒 隐私说明

- 服务器地址与**访问口令是用户自己填写的服务器凭证**，仅存储于本机 `SharedPreferences`，**不会被上传或随源码分发**。
- 仓库中**不包含任何密钥、证书或真实配置**：服务端自签证书（`*.pem`）、`config.json`、签名 keystore 等均已通过 `.gitignore` 排除。
- 离线缓存仅保存在本机沙盒目录（`path_provider` 的 `conv_cache/`），不会外发。

## 📁 目录结构

```
talk-with-anyone-app/
├── lib/
│   ├── i18n/            # 中英双语文案（app_strings.dart）
│   ├── models/          # 数据模型
│   ├── screens/         # 页面（chat / phone / connect / llm_settings …）
│   ├── services/        # 网络、TTS、离线缓存、偏好设置
│   ├── state/           # 全局状态（AppState）
│   └── widgets/         # 抽屉、对话列表等组件
├── assets/icon/         # 应用图标源图
├── pubspec.yaml
├── LICENSE
└── README.md / README_EN.md
```

## 📄 License

[MIT](./LICENSE) © wangguanghua

---

> 本项目为个人学习项目，模型与数据请遵守各自原始 License。

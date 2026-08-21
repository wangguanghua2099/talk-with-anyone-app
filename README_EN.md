# Talk With Anyone · Mobile Client

The **Flutter mobile client** for Talk With Anyone, a local-first voice chat agent. Use it together with the [Talk With Anyone](https://github.com/wangguanghua/talk-with-anyone) (FastAPI) server to enjoy real-time voice conversation, text chat, and character switching on Android / iOS / Web.

[简体中文](./README.md) | **English**

---

## ✨ Features

- 📞 **Phone mode (full-duplex real-time voice)**: two WebSocket links (`/ws/voice` for uplink audio, `/ws/tts-stream` for downlink AI replies) for low-latency continuous conversation; echo cancellation and voice interruption (VAD detects speech to cut off the AI).
- 💬 **Text chat**: multi-conversation management, streamed message rendering, stop-reading anytime.
- 🗣️ **Multiple TTS engines**: `edge` (free online), `moss`, `qwen3`, `qwen3-clone` (voice cloning); progress bar plus audio/text export to public Downloads.
- 🎭 **Character system**: switch, add, and delete custom AI characters (persona, avatar, dedicated voice).
- 🌐 **Bilingual UI**: Chinese / English toggle.
- 📡 **Offline read-only cache**: server is the source of truth; the phone keeps a metadata snapshot and per-conversation message files. Offline you can browse history, characters, and messages; **write operations are blocked with a "requires network" notice**.
- 🔒 **Local-first**: server URL and access token are stored only in the device's `SharedPreferences` — never uploaded, never shipped with the repo.

## 🛠 Tech Stack

| Layer | Tech |
| --- | --- |
| Framework | Flutter 3.x (Dart ≥ 3.3) |
| State | `provider` |
| Networking | `dio` + `web_socket_channel` |
| Audio | `record` (recording), `just_audio` (playback), `audio_session` |
| Storage | `shared_preferences`, `path_provider`, `file_picker` |
| Icon | `flutter_launcher_icons` (source `assets/icon/app_icon.png`, white background with a blue swallow) |

## 🚀 Quick Start

### 1. Requirements

- Flutter SDK ≥ 3.3 (any recent stable build), see [Flutter install](https://docs.flutter.dev/get-started/install).
- A machine running the **Talk With Anyone** server (see "Server setup" below).

### 2. Get the code

```bash
git clone <this repo url> talk-with-anyone-app
cd talk-with-anyone-app
flutter pub get
```

### 3. Run / Build

```bash
# Debug run (shows a debug diagnostics bar by default)
flutter run

# Release Android APK (debug bar hidden in release)
flutter build apk --release

# iOS (requires macOS + Xcode)
flutter build ios --release

# Web
flutter build web
```

### 4. Connect to the server

On first launch you land on the "Connect" screen. Fill in:

- **Server URL**: e.g. `https://192.168.1.100:7862` (phone and server must be on the same LAN; HTTPS is required for microphone / phone mode — see the server docs).
- **Access token (optional)**: must match `access_token` in the server's `config.json`; leave empty if the server has no auth enabled.

This information is stored only on the device and is never uploaded to any third party.

## 🖥 Server Setup

This client does **not** include ASR / LLM / TTS inference — you must self-host the server:

1. Clone and start [Talk With Anyone](https://github.com/wangguanghua/talk-with-anyone):
   ```bash
   git clone https://github.com/wangguanghua/talk-with-anyone
   cd talk-with-anyone
   pip install -r requirements.txt
   cp config.example.json config.json
   python main.py
   ```
2. For LAN HTTPS access from a phone, generate a self-signed cert per the server README (`python generate_cert.py`), trust it on the phone, then grant microphone permission.

> The server is local-first: default Edge-TTS + a local LLM runs without a GPU; local MOSS-TTS / Qwen3-TTS / SenseVoice benefit from an NVIDIA GPU.

## 🔒 Privacy

- The server URL and **access token are credentials you enter yourself**; they live only in the device's `SharedPreferences` and are **never uploaded or distributed with the source**.
- The repository contains **no keys, certificates, or real config**: server self-signed certs (`*.pem`), `config.json`, and signing keystores are excluded via `.gitignore`.
- The offline cache stays in the device sandbox (`conv_cache/` from `path_provider`) and is never sent out.

## 📁 Project Structure

```
talk-with-anyone-app/
├── lib/
│   ├── i18n/            # zh/en strings (app_strings.dart)
│   ├── models/          # data models
│   ├── screens/         # pages (chat / phone / connect / llm_settings …)
│   ├── services/        # networking, TTS, offline cache, prefs
│   ├── state/           # global state (AppState)
│   └── widgets/         # drawer, conversation list, etc.
├── assets/icon/         # app icon source
├── pubspec.yaml
├── LICENSE
└── README.md / README_EN.md
```

## 📄 License

[MIT](./LICENSE) © wangguanghua

---

> This is a personal learning project. Models and data must comply with their respective original licenses.

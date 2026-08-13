// 全双工语音电话模式：录音 PCM16 → /ws/voice → 服务器识别并回复 → 手机本地 TTS 播放
//
// 协议（见服务器 routes/voice.py）：
//   连接后服务器发 {"type":"server.ready","session_id":...,"asr_engine":...}
//   客户端发    {"type":"session.start","mode":"chat"}          → 收到 {"type":"session.ready",...}
//   客户端持续发送二进制 PCM16（16k/单声道）
//   服务器按 VAD 识别：{"type":"vad.speaking","speaking":bool}
//                     {"type":"asr.result","text":"...","is_final":true}
//                     {"type":"assistant.completed","text":"..."}
//   客户端发    {"type":"interrupt"} 打断；{"type":"session.stop"} 结束
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_client.dart';
import 'tts_service.dart';

/// 会话中产生的展示事件
sealed class VoiceEvent {
  const VoiceEvent();
}

class VoiceUserText extends VoiceEvent {
  const VoiceUserText(this.text);
  final String text;
}

class VoiceAssistantText extends VoiceEvent {
  const VoiceAssistantText(this.text);
  final String text;
}

class VoiceError extends VoiceEvent {
  const VoiceError(this.message);
  final String message;
}

class VoiceService {
  VoiceService({required this.baseUrl, required this.token});

  final String baseUrl;
  final String token;

  final AudioRecorder _recorder = AudioRecorder();
  TtsService? _tts;
  WebSocketChannel? _channel;
  StreamSubscription<Uint8List>? _micSub;
  bool _active = false;
  bool _micMuted = false;

  final _events = StreamController<VoiceEvent>.broadcast();
  final ValueNotifier<bool> speaking = ValueNotifier(false);
  final ValueNotifier<bool> ttsPlaying = ValueNotifier(false);
  final ValueNotifier<bool> active = ValueNotifier(false);

  /// 是否已收到 session.ready（用于界面显示"请说话"）
  final ValueNotifier<bool> connected = ValueNotifier(false);

  /// 用户是否已开口说过话（用于隐藏"请说话"提示）
  final ValueNotifier<bool> heardUser = ValueNotifier(false);

  /// 麦克风是否已静音（静音时不发送音频）
  final ValueNotifier<bool> micMuted = ValueNotifier(false);

  /// 已发送的音频字节数（诊断用：看"通话死了"时麦克风是否还在发）
  final ValueNotifier<int> micBytesSent = ValueNotifier(0);

  /// 全双工录音配置（豆包式）：通话音源 + 硬件回声消除 + 强制外放。
  /// 让麦克风在 AI 播放时仍能收到并滤掉扬声器回声，从而支持说话打断。
  ///
  /// audioInterruption 必须是 none：录音端一旦参与音频焦点（默认 pause），
  /// TTS 播放请求瞬时焦点时录音会被“焦点丢失”事件暂停，且朗读结束后不会
  /// 自动恢复 —— 表现为朗读中无法打断、朗读完无法继续说话。
  /// 全双工模式下麦克风必须始终录音，不理会任何焦点事件。
  static const RecordConfig _voiceRecordConfig = RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: 16000,
    numChannels: 1,
    echoCancel: true,
    noiseSuppress: true,
    audioInterruption: AudioInterruptionMode.none,
    androidConfig: AndroidRecordConfig(
      audioSource: AndroidAudioSource.voiceCommunication,
      speakerphone: true,
      audioManagerMode: AudioManagerMode.modeInCommunication,
    ),
  );

  /// 展示事件流（user 文本 / assistant 文本 / 错误）
  Stream<VoiceEvent> get events => _events.stream;

  bool get isMicMuted => _micMuted;

  /// 切换麦克风静音
  void toggleMicMuted() {
    _micMuted = !_micMuted;
    micMuted.value = _micMuted;
  }

  /// 开始通话：建立连接 + 启动录音
  Future<void> start() async {
    if (_active) return;
    if (!await _recorder.hasPermission()) {
      _events.add(const VoiceError('未获得麦克风权限'));
      return;
    }
    _tts = TtsService(baseUrl: baseUrl, token: token, inCallMode: true);

    final uri = ApiClient.webSocketUri(baseUrl, '/ws/voice', token: token);
    final channel = ApiClient.connectWs(uri);
    _channel = channel;
    _active = true;
    active.value = true;
    connected.value = false;
    heardUser.value = false;

    channel.stream.listen(
      (data) => _handleServerMessage(data),
      onError: (Object e) {
        _events.add(VoiceError('连接错误：$e'));
      },
      onDone: () => _onConnectionClosed(),
    );

    try {
      await channel.ready.timeout(const Duration(seconds: 8));
      channel.sink.add(jsonEncode({'type': 'session.start', 'mode': 'chat'}));
    } catch (e) {
      await stop();
      _events.add(VoiceError('连接服务器失败：$e'));
      return;
    }

    final stream = await _recorder.startStream(_voiceRecordConfig);
    _micSub = stream.listen(_onMicChunk, onError: (Object e) {
      _events.add(VoiceError('录音异常：$e'));
    });
  }

  /// 停止通话（结束录音 + 关闭连接 + 停止播放）
  Future<void> stop() async {
    if (!_active) return;
    _active = false;
    active.value = false;
    connected.value = false;
    await _micSub?.cancel();
    _micSub = null;
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    if (_channel != null) {
      try {
        _channel!.sink.add(jsonEncode({'type': 'session.stop'}));
      } catch (_) {}
      await _channel!.sink.close();
    }
    _channel = null;
    await _tts?.stop();
    _onConnectionClosed();
  }

  void _handleServerMessage(dynamic data) {
    if (data is! String) return;
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(data) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (msg['type']) {
      case 'session.ready':
        connected.value = true;
      case 'vad.speaking':
        final sp = msg['speaking'] == true;
        speaking.value = sp;
        if (sp) {
          heardUser.value = true;
          // barge-in（豆包式打断）：用户一开口，既停本地 TTS 播放，
          // 也通知服务器取消上一轮未完成的回复（停止 LLM/合成），
          // 保证接下来只合成和播放新回复。依赖全双工音源的回声消除。
          unawaited(interrupt());
        }
      case 'asr.result':
        final text = (msg['text'] ?? '').toString();
        if (text.trim().isNotEmpty) {
          heardUser.value = true;
          _events.add(VoiceUserText(text));
        }
      case 'assistant.completed':
        final text = (msg['text'] ?? '').toString();
        if (text.trim().isNotEmpty) {
          _events.add(VoiceAssistantText(text));
          _speak(text);
        }
      case 'assistant.error':
        _events.add(VoiceError((msg['message'] ?? '回复失败').toString()));
      case 'error':
        _events.add(VoiceError((msg['message'] ?? '服务器错误').toString()));
    }
  }

  /// _speak 轮次序号：被打断的旧 _speak 结束时不能把新回复的
  /// ttsPlaying 状态误清为 false
  int _speakSeq = 0;

  Future<void> _speak(String text) async {
    final seq = ++_speakSeq;
    ttsPlaying.value = true;
    try {
      await _tts?.speak(text);
    } catch (e) {
      _events.add(VoiceError('语音播放出错：$e'));
    } finally {
      // 兜底：无论何种原因（外部焦点事件等）导致录音被暂停，朗读结束后立即
      // 恢复，保证全双工通话不会“死掉”。
      try {
        if (_active && await _recorder.isPaused()) {
          debugPrint('[Voice] 检测到录音被暂停，自动恢复');
          await _recorder.resume();
        }
      } catch (_) {}
      if (_speakSeq == seq) {
        final status = _tts?.lastStatus ?? '';
        if (status.contains('失败')) {
          _events.add(VoiceError('语音诊断：$status'));
        }
        ttsPlaying.value = false;
      }
    }
  }

  /// 用户说话打断：发 interrupt + 停掉当前播放
  Future<void> interrupt() async {
    if (_channel == null) return;
    try {
      _channel!.sink.add(jsonEncode({'type': 'interrupt'}));
    } catch (_) {}
    try {
      await _tts?.stop();
    } catch (_) {}
  }

  void _onMicChunk(Uint8List chunk) {
    if (!_active || _channel == null || _micMuted) return;
    try {
      _channel!.sink.add(chunk);
      micBytesSent.value += chunk.length;
    } catch (_) {}
  }

  void _onConnectionClosed() {
    speaking.value = false;
    ttsPlaying.value = false;
    connected.value = false;
  }

  Future<void> dispose() async {
    await stop();
    await _events.close();
    await _recorder.dispose();
  }
}

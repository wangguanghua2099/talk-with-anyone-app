// 语音转文本（STT Studio）流式听写服务：
// 打开麦克风后持续把 PCM16 发给 /ws/voice（mode=transcribe），
// 服务器 VAD 说一句识别一句，逐句抛回文本。纯转写不触发 LLM/TTS。
//
// 对应网页版 stt-studio.js / routes/voice.py 中 mode == "transcribe" 的逻辑。
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_client.dart';

class SttListenService {
  SttListenService({required this.baseUrl, required this.token});

  final String baseUrl;
  final String token;

  final AudioRecorder _recorder = AudioRecorder();
  WebSocketChannel? _channel;
  StreamSubscription<Uint8List>? _micSub;
  bool _active = false;

  final _text = StreamController<String>.broadcast();
  final _status = StreamController<String>.broadcast();

  Stream<String> get onText => _text.stream;
  Stream<String> get onStatus => _status.stream;

  final ValueNotifier<bool> active = ValueNotifier(false);

  static const _config = RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: 16000,
    numChannels: 1,
    echoCancel: true,
    noiseSuppress: true,
  );

  bool get isActive => _active;

  /// 开始听写：建立 WS + mode=transcribe，然后打开麦克风持续发送 PCM16
  Future<void> start() async {
    if (_active) return;
    if (!await _recorder.hasPermission()) {
      throw Exception('未获得麦克风权限');
    }
    _status.add('正在连接识别服务…');

    final uri = ApiClient.webSocketUri(baseUrl, '/ws/voice', token: token);
    final channel = ApiClient.connectWs(uri);
    _channel = channel;
    _active = true;
    active.value = true;

    channel.stream.listen(
      _handleServerMessage,
      onError: (Object e) {
        _status.add('连接错误：$e');
      },
      onDone: () => _onClosed(),
    );

    try {
      await channel.ready.timeout(const Duration(seconds: 8));
      channel.sink
          .add(jsonEncode({'type': 'session.start', 'mode': 'transcribe'}));
    } catch (e) {
      await stop();
      throw Exception('连接服务器失败：$e');
    }

    final stream = await _recorder.startStream(_config);
    _micSub = stream.listen(
      (Uint8List chunk) {
        if (_active && _channel != null) {
          try {
            _channel!.sink.add(chunk);
          } catch (_) {}
        }
      },
      onError: (Object e) {
        _status.add('录音异常：$e');
        unawaited(stop());
      },
    );
    _status.add('请开始说话，说一句自动识别一句');
  }

  /// 停止听写：关麦克风 + 发 session.stop + 关 WS
  Future<void> stop() async {
    if (!_active) return;
    _active = false;
    active.value = false;
    await _micSub?.cancel();
    _micSub = null;
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    final ch = _channel;
    _channel = null;
    if (ch != null) {
      try {
        ch.sink.add(jsonEncode({'type': 'session.stop'}));
      } catch (_) {}
      try {
        await ch.sink.close();
      } catch (_) {}
    }
    _status.add('麦克风已关闭');
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
        _status.add('请开始说话');
      case 'vad.speaking':
        _status.add((msg['speaking'] == true)
            ? '正在聆听…'
            : '说一句自动识别一句');
      case 'asr.result':
        final text = (msg['text'] ?? '').toString().trim();
        if (text.isNotEmpty) {
          _text.add(text);
        }
      case 'asr.error':
        _status.add('识别失败：${msg['message']}');
      case 'error':
        _status.add('服务器错误：${msg['message']}');
    }
  }

  void _onClosed() {
    active.value = false;
    if (_active) {
      _active = false;
      unawaited(stopMicOnly());
      _status.add('连接已断开');
    }
  }

  Future<void> stopMicOnly() async {
    await _micSub?.cancel();
    _micSub = null;
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
  }

  Future<void> dispose() async {
    _active = false;
    active.value = false;
    await _micSub?.cancel();
    _micSub = null;
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    await _recorder.dispose();
    await _text.close();
    await _status.close();
  }
}
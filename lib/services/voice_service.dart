// 全双工语音电话模式：录音 PCM16 → /ws/voice → 服务器识别并流式回复
//
// 协议（见服务器 routes/voice.py，新版流式）：
//   连接后服务器发 {"type":"server.ready","session_id":...,"asr_engine":...}
//   客户端发    {"type":"session.start","mode":"chat"}          → 收到 {"type":"session.ready",...}
//   客户端持续发送二进制 PCM16（16k/单声道）
//   服务器按 VAD 识别：{"type":"vad.speaking","speaking":bool}
//                     {"type":"asr.result","text":"...","is_final":true}
//   回复流式下发（边生成边发）：
//                     {"type":"assistant.delta","text":"增量"}     文字 token 级直推
//                     {"type":"audio.start","sample_rate":24000}   流式音频开始
//                     {"type":"audio.chunk","data":"base64 PCM16"} 音频块（边合成边推）
//                     {"type":"audio.done"}                        本轮音频发送完毕
//                     {"type":"audio.file","path":"/static/..."}   无流式引擎的逐句文件
//                     {"type":"assistant.completed","text":"全文"}
//   客户端发    {"type":"interrupt"} 打断；{"type":"session.stop"} 结束
//               {"type":"client_stats","llm_first_token_to_audio_ms":...} 延迟上报
//
// 文字与语音解耦：delta 立刻上抛给界面打字显示，不等 TTS；音频块由
// VoiceStreamPlayer 边收边播（首包到达即出声）。只有整轮没收到过任何
// 音频（服务器关了朗读/合成失败/旧后端）时，才回退到拿到全文后再
// 请求 TTS 合成播放（旧行为）。
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_client.dart';
import 'tts_service.dart';
import 'voice_stream_player.dart';

/// 会话中产生的展示事件
sealed class VoiceEvent {
  const VoiceEvent();
}

class VoiceUserText extends VoiceEvent {
  const VoiceUserText(this.text);
  final String text;
}

/// 回复文字增量（流式打字显示用，逐条上抛）
class VoiceAssistantDelta extends VoiceEvent {
  const VoiceAssistantDelta(this.text);
  final String text;
}

/// 回复正常完成：全文（替换掉正在打字的气泡内容）
class VoiceAssistantText extends VoiceEvent {
  const VoiceAssistantText(this.text);
  final String text;
}

/// 回复被打断/出错：已收到的部分文字（立即收尾显示）
class VoiceAssistantPartial extends VoiceEvent {
  const VoiceAssistantPartial(this.text);
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
  VoiceStreamPlayer? _streamPlayer;
  WebSocketChannel? _channel;
  StreamSubscription<Uint8List>? _micSub;
  bool _active = false;
  bool _micMuted = false;

  /// 服务器朗读开关（config.tts_read_ai）：决定 completed 后要不要兜底朗读
  bool _ttsReadAi = true;

  /// 当前回复轮状态：是否进行中 / 已收文字 / 已收音频 / 是否已收尾
  bool _roundActive = false;
  bool _roundFinalized = false;
  bool _receivedAudio = false;
  String _assistantBuf = '';

  /// LLM 首个文字增量时刻（出声延迟统计用，每轮一次）
  DateTime? _llmFirstTokenAt;

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

  /// 展示事件流（user 文本 / assistant 流式与最终文本 / 错误）
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
    _streamPlayer = VoiceStreamPlayer(baseUrl: baseUrl, token: token)
      ..onFirstAudio = _onFirstAudio;
    _streamPlayer!.playing.addListener(() {
      // 流式音频路径的"AI 正在说话"提示；兜底 _speak 路径自行维护该状态
      if (!_speakBusy) ttsPlaying.value = _streamPlayer!.playing.value;
    });
    unawaited(_loadTtsEnabled());

    final uri = ApiClient.webSocketUri(baseUrl, '/ws/voice', token: token);
    final channel = ApiClient.connectWs(uri);
    _channel = channel;
    _active = true;
    active.value = true;
    connected.value = false;
    heardUser.value = false;
    _resetRound();

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

  /// 读取服务器朗读开关（失败按开启处理，保持旧的"总是朗读"行为）
  Future<void> _loadTtsEnabled() async {
    try {
      final dio = ApiClient.create(baseUrl: baseUrl, token: token);
      final resp = await dio.get<Map<String, dynamic>>('/api/config');
      final v = resp.data?['tts_read_ai'];
      if (v is bool) _ttsReadAi = v;
    } catch (_) {}
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
          // barge-in（豆包式打断）：用户一开口，先收尾正在打字的回复，
          // 停掉本地播放，再通知服务器取消上一轮未完成的生成，
          // 保证接下来只合成和播放新回复。依赖全双工音源的回声消除。
          _finalizePartialRound();
          unawaited(interrupt());
        }
      case 'asr.result':
        final text = (msg['text'] ?? '').toString();
        if (text.trim().isNotEmpty) {
          heardUser.value = true;
          // 新一轮回复开始（防御：上一轮没收尾的先收尾）
          _finalizePartialRound();
          _resetRound();
          _events.add(VoiceUserText(text));
        }
      case 'assistant.delta':
        if (_roundFinalized) return; // 已被打断收尾，丢弃迟到内容
        final text = (msg['text'] ?? '').toString();
        if (text.isEmpty) return;
        _roundActive = true;
        _assistantBuf += text;
        _llmFirstTokenAt ??= DateTime.now();
        _events.add(VoiceAssistantDelta(text));
      case 'audio.start':
        _receivedAudio = true;
        final sr = (msg['sample_rate'] as num?)?.toInt() ?? 24000;
        _streamPlayer?.start(sr);
      case 'audio.chunk':
        final b64 = msg['data'] as String?;
        if (b64 != null) _streamPlayer?.pushChunk(b64);
      case 'audio.done':
        _streamPlayer?.markDone();
      case 'audio.file':
        _receivedAudio = true;
        final path = (msg['path'] ?? '').toString();
        if (path.isNotEmpty) unawaited(_streamPlayer?.playFile(path));
      case 'assistant.completed':
        if (_roundFinalized) return; // 本轮已被打断，丢弃迟到结果
        final text = (msg['text'] ?? '').toString();
        _roundFinalized = true;
        _roundActive = false;
        if (text.trim().isNotEmpty) {
          _events.add(VoiceAssistantText(text));
          // 新后端音频已随句子推送播放；整轮没收到过音频才走
          // "全文→TTS 合成"的兜底（旧后端/服务器朗读关闭/合成失败）
          if (!_receivedAudio && _ttsReadAi) {
            unawaited(_speak(text));
          }
        }
      case 'assistant.error':
        _finalizePartialRound();
        _events.add(VoiceError((msg['message'] ?? '回复失败').toString()));
      case 'interrupt.ack':
        // 后端已确认取消生成；播放已停，部分文字由 vad 触发时收尾
        unawaited(_streamPlayer?.stop());
      case 'error':
        _events.add(VoiceError((msg['message'] ?? '服务器错误').toString()));
    }
  }

  /// 收尾当前轮（打断/出错）：已缓冲的文字作为部分内容上抛，不再等 completed
  void _finalizePartialRound() {
    if (!_roundActive || _roundFinalized) return;
    _roundFinalized = true;
    _roundActive = false;
    unawaited(_streamPlayer?.stop());
    final partial = _assistantBuf.trim();
    if (partial.isNotEmpty) {
      _events.add(VoiceAssistantPartial(partial));
    }
  }

  void _resetRound() {
    _roundActive = false;
    _roundFinalized = false;
    _receivedAudio = false;
    _assistantBuf = '';
    _llmFirstTokenAt = null;
  }

  /// 出声计时：AI 语音第一个音频块实际开始播放时，
  /// 把"LLM 首个文字增量 → 出声"的间隔回传服务器（后台日志展示）
  void _onFirstAudio() {
    final t0 = _llmFirstTokenAt;
    _llmFirstTokenAt = null;
    if (t0 == null) return;
    final lat = DateTime.now().difference(t0).inMilliseconds;
    debugPrint('[Voice] LLM首token→出声: $lat ms');
    try {
      _channel?.sink
          .add(jsonEncode({'type': 'client_stats', 'llm_first_token_to_audio_ms': lat}));
    } catch (_) {}
  }

  /// _speak 轮次序号：被打断的旧 _speak 结束时不能把新回复的
  /// ttsPlaying 状态误清为 false
  int _speakSeq = 0;
  bool _speakBusy = false;

  Future<void> _speak(String text) async {
    final seq = ++_speakSeq;
    _speakBusy = true;
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
        _speakBusy = false;
        final status = _tts?.lastStatus ?? '';
        if (status.contains('失败')) {
          _events.add(VoiceError('语音诊断：$status'));
        }
        ttsPlaying.value = _streamPlayer?.playing.value ?? false;
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
      await _streamPlayer?.stop();
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

  /// 停止通话（结束录音 + 关闭连接 + 停止播放）
  Future<void> stop() async {
    if (!_active) return;
    _active = false;
    active.value = false;
    connected.value = false;
    _finalizePartialRound();
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
    await _streamPlayer?.stop();
    await _tts?.stop();
    _onConnectionClosed();
  }

  Future<void> dispose() async {
    await stop();
    await _streamPlayer?.dispose();
    await _events.close();
    await _recorder.dispose();
  }
}

// 电话模式流式音频播放器（对应 web 端 phone.js 的 StreamPlayer）。
//
// 后端 /ws/voice 现在边生成边推送音频：
//   audio.start {sample_rate} → audio.chunk {data: base64 int16 PCM} * n → audio.done
//   （不支持流式的引擎如 edge 则逐批发 audio.file {path}）
//
// 播放策略与 TtsService._tryWsStream 相同（复用其 BytesAudioSource/pcm16ToWav）：
//   每个 PCM 分块打包成完整短 WAV，第一块立即开播，后续块用 addAudioSource
//   追加到播放列表尾部无缝衔接 —— 即"边收边播"，首包音频到达后约 1 秒内出声，
//   不再等整段回复合成完。
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'api_client.dart';
import 'tts_service.dart';

class VoiceStreamPlayer {
  VoiceStreamPlayer({required this.baseUrl, required this.token});

  final String baseUrl;
  final String token;

  late final AudioPlayer _player = AudioPlayer(
    // 全双工通话（麦克风持续录音）下绝不激活音频会话/请求焦点，
    // 否则录音端会被"焦点丢失"暂停（与 TtsService inCallMode 同理）
    handleAudioSessionActivation:
        !(defaultTargetPlatform == TargetPlatform.android),
    audioLoadConfiguration: const AudioLoadConfiguration(
      androidLoadControl: AndroidLoadControl(
        bufferForPlaybackDuration: Duration(milliseconds: 500),
        bufferForPlaybackAfterRebufferDuration: Duration(seconds: 2),
      ),
    ),
  );

  int _sampleRate = 24000;
  bool _active = false;
  bool _playStarted = false;
  bool _serverDone = false;

  /// 分块到达按序串行处理（addAudioSource 是异步的，乱序会接反）
  Future<void> _chain = Future<void>.value();

  /// audio.file（edge 引擎）逐句播放队列
  final List<String> _fileQueue = [];
  bool _fileLoading = false;
  bool _fileMode = false;

  /// "AI 正在说话"提示（界面用）：开播后为 true，全部播完/被打断为 false
  final ValueNotifier<bool> playing = ValueNotifier(false);

  /// 第一个音频块真正开始播放的时刻回调（端到端延迟统计用）
  void Function()? onFirstAudio;
  bool _firstAudioFired = false;

  StreamSubscription<PlayerState>? _stateSub;

  /// 开始接收新一轮音频流（复用播放器时先在任务链里清掉上一轮的播放列表）
  void start(int sampleRate) {
    _sampleRate = sampleRate > 0 ? sampleRate : 24000;
    _active = true;
    _serverDone = false;
    _firstAudioFired = false;
    _fileMode = false;
    _stateSub ??= _player.playerStateStream.listen(_onPlayerState);
    if (_playStarted) {
      _playStarted = false;
      // 与分块任务共用同一条串行链，保证清空先于新块追加执行
      _chain = _chain.then((_) async {
        try {
          await _player.stop();
        } catch (_) {}
      });
    }
  }

  /// 追加一个 base64 int16 PCM 分块（被打断/未 start 时静默丢弃）
  void pushChunk(String b64) {
    if (!_active || _fileMode) return;
    Future<void> task() async {
      if (!_active) return;
      Uint8List pcm;
      try {
        pcm = base64Decode(b64);
      } catch (_) {
        return;
      }
      if (pcm.isEmpty) return;
      final wav = TtsService.pcm16ToWav(pcm, _sampleRate);
      try {
        if (!_playStarted) {
          _playStarted = true;
          await _player.setAudioSources([BytesAudioSource(wav)]);
          if (!_active) return;
          unawaited(_player.play());
          playing.value = true;
          if (!_firstAudioFired) {
            _firstAudioFired = true;
            onFirstAudio?.call();
          }
        } else {
          await _player.addAudioSource(BytesAudioSource(wav));
          if (!_active) return;
          // 欠载自愈：播放追上了进度，新块到达则续播
          if (_player.processingState == ProcessingState.completed) {
            unawaited(_player.play());
          }
        }
      } catch (e) {
        debugPrint('[VoicePlayer] 播放器错误: $e');
      }
    }

    _chain = _chain.then((_) => task());
  }

  /// 服务器本轮流式音频发送完毕（audio.done）
  void markDone() {
    _serverDone = true;
  }

  /// 播放服务器已合成的音频文件（audio.file，edge 引擎逐句一批）。
  /// 多批按到达顺序排队，等上一句播完再播下一句。
  Future<void> playFile(String path) async {
    if (!_active) return;
    if (!_fileMode) {
      // 与分块模式互斥：一轮回复只会走其中一种
      if (_playStarted) return;
      _fileMode = true;
    }
    _fileQueue.add(path);
    await _pumpFileQueue();
  }

  Future<void> _pumpFileQueue() async {
    if (_fileLoading || !_active) return;
    final path = _fileQueue.isEmpty ? null : _fileQueue.first;
    if (path == null) return;
    _fileLoading = true;
    try {
      final isMp3 = path.toLowerCase().endsWith('.mp3');
      final bytes = await _download(path);
      if (!_active) return;
      if (bytes == null || bytes.isEmpty) return;
      await _player.setAudioSource(
        BytesAudioSource(
          bytes,
          contentType: isMp3 ? 'audio/mpeg' : 'audio/wav',
        ),
      );
      if (!_active) return;
      unawaited(_player.play());
      playing.value = true;
      if (!_firstAudioFired) {
        _firstAudioFired = true;
        onFirstAudio?.call();
      }
      // 等这一句播完再取下一句（队列头部留在原地，播完移除）
      final done = Completer<void>();
      late final StreamSubscription<PlayerState> sub;
      sub = _player.playerStateStream.listen((state) {
        if (done.isCompleted) return;
        if (state.processingState == ProcessingState.completed ||
            state.processingState == ProcessingState.idle) {
          done.complete();
        }
      });
      await done.future.timeout(const Duration(minutes: 5), onTimeout: () {});
      await sub.cancel();
    } catch (e) {
      debugPrint('[VoicePlayer] 文件播放失败: $e');
    } finally {
      if (_fileQueue.isNotEmpty) _fileQueue.removeAt(0);
      _fileLoading = false;
      if (_fileQueue.isNotEmpty && _active) {
        unawaited(_pumpFileQueue());
      } else if (_fileQueue.isEmpty) {
        playing.value = false;
      }
    }
  }

  Future<Uint8List?> _download(String path) async {
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        final dio = ApiClient.create(baseUrl: baseUrl, token: token)
          ..options.receiveTimeout = const Duration(minutes: 3);
        final resp = await dio.get<List<int>>(
          '/api/tts/download?filename=${Uri.encodeQueryComponent(path)}',
          options: Options(responseType: ResponseType.bytes),
        );
        final data = resp.data;
        if (data != null && data.isNotEmpty) return Uint8List.fromList(data);
      } catch (e) {
        debugPrint('[VoicePlayer] 下载失败(第$attempt次): $e');
      }
      if (attempt < 2 && _active) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    }
    return null;
  }

  void _onPlayerState(PlayerState state) {
    if (!_active) return;
    if (state.processingState == ProcessingState.completed) {
      if (_fileMode) return; // 文件模式由 _pumpFileQueue 管理状态
      // 全部排程的音频播完。若服务器还没发完（欠载），保持"在说话"，
      // 后续块到达会自动续播；发完了就结束
      if (_serverDone) playing.value = false;
    }
  }

  /// 停止并释放（打断/挂断时调用）；之后可重新 start 复用
  Future<void> stop() async {
    _active = false;
    _serverDone = false;
    _playStarted = false;
    _fileMode = false;
    _fileQueue.clear();
    _fileLoading = false;
    playing.value = false;
    await _stateSub?.cancel();
    _stateSub = null;
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}

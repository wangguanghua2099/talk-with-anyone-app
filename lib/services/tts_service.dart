// 流式 TTS（WebSocket 分块边收边播，与 Web 端 tts.js 相同的模型）。
//
// 播放链路：
//   1) WebSocket /ws/tts-stream：服务器边合成边发 base64 PCM 分块；
//      每个分块打包成一段完整的短 WAV，作为播放列表项追加到
//      ConcatenatingAudioSource，播放器在收到第一块后立即开始播放，
//      后续分块无缝衔接 —— 即“边生成边播”，首包后约 1 秒出声。
//   2) 兜底：POST /api/tts/speak 拿文件路径 → 下载完整 WAV 播放。
//
// 为什么不继续用旧的 HTTP 渐进流（_PullByteSource）：
//   长度未知的渐进流在 just_audio/ExoPlayer 里有两处坑（Range 请求空指针、
//   单订阅 Stream 被二次监听直接抛异常导致 “source error”），改用
//   “已知长度的完整 WAV 分块 + 播放列表动态追加” 可完全绕开。
//
// 音频路由：Android 使用 usage=media，从扬声器（外放）出声；
//   旧的 voiceCommunication 会被系统路由到听筒。
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_client.dart';

// ignore_for_file: experimental_member_use

class TtsService {
  TtsService({
    required this.baseUrl,
    required this.token,
    this.voice,
    this.inCallMode = false,
  }) {
    // 通话模式（全双工：麦克风正在持续录音）下，播放器绝不能激活音频会话/
    // 请求音频焦点：否则录音端会收到“焦点丢失”事件而被暂停，表现为 AI 朗读时
    // 麦克风失灵、朗读结束后也无法继续说话。
    _player = AudioPlayer(
      handleAudioSessionActivation:
          !(inCallMode && defaultTargetPlatform == TargetPlatform.android),
      // Android 上把“开始播放前所需缓冲”从默认 2.5s 压到 0.5s，降低首块延迟。
      audioLoadConfiguration: const AudioLoadConfiguration(
        androidLoadControl: AndroidLoadControl(
          bufferForPlaybackDuration: Duration(milliseconds: 500),
          bufferForPlaybackAfterRebufferDuration: Duration(seconds: 2),
        ),
      ),
    );
    unawaited(_configureAudioSession());
  }

  final String baseUrl;
  final String token;
  final String? voice;

  /// 是否处于全双工通话模式（播放与录音同时进行）
  final bool inCallMode;

  late final AudioPlayer _player;

  WebSocketChannel? _channel;

  /// 轮次代号：每次 [speak] 领取最新代号，[stop] 立即使代号失效。
  /// 被打断的朗读在任何 await 返回后发现代号已旧，会立刻退出、
  /// 绝不再走兜底路径，防止旧内容被重新合成并与新回复叠播。
  int _gen = 0;

  /// 结束当前流式播放等待的钩子（由 _tryWsStream 设置，stop 时调用）
  Future<void> Function()? _abort;
  bool _busy = false;

  /// 最近一次朗读的结果/错误描述（界面诊断用）
  String lastStatus = '';

  /// 当前是否正在朗读（含播放阶段）
  bool get busy => _busy;

  /// 配置音频会话：媒体播放属性（走扬声器），播放时只瞬时窥探焦点、不抢占，
  /// 避免影响电话模式下正在进行的全双工录音（VOICE_COMMUNICATION + AEC）。
  Future<void> _configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
      ));
    } catch (_) {
      // 音频会话配置失败不致命
    }
  }

  /// 朗读一段文本；阻塞直到播放结束、被打断或所有方式都失败。
  Future<void> speak(String text, {String? voice}) async {
    await stop();
    // 领取本轮代号；之后若被 stop()，_gen 变化，下面每一步都会立即跳过
    final gen = ++_gen;
    final v = voice ?? this.voice;
    _busy = true;
    lastStatus = '';

    var played = false;

    // 1) WebSocket 分块流式播放（主路径，低延迟）
    if (_gen == gen) {
      played = await _tryWsStream(text, v, gen);
    }

    // 2) HTTP 下载播放（最稳兜底；被打断时绝不再走兜底）
    if (!played && _gen == gen) {
      played = await _tryDownloadPlay(text, v, gen);
    }

    if (!played && _gen == gen) {
      lastStatus =
          lastStatus.isEmpty ? '所有朗读方式均失败' : '$lastStatus（均失败）';
    }
    debugPrint('[TTS] 朗读结束 played=$played status=$lastStatus');
    if (_gen == gen) _busy = false;
  }

  /// 1) WebSocket 分块流式播放。
  ///
  /// 每个 PCM 分块包装成独立的完整 WAV：第一块直接设为播放列表并立即播放，
  /// 之后的块用 addAudioSource 依次追加到列表尾部无缝衔接，实现边生成边播；
  /// 服务器发完 audio.done 且播放器走到 completed 才算整体结束。
  /// 播放追上数据（欠载）时，新块到达会自动续播。
  Future<bool> _tryWsStream(String text, String? v, int gen) async {
    final uri = ApiClient.webSocketUri(baseUrl, '/ws/tts-stream', token: token);
    final channel = ApiClient.connectWs(uri);
    _channel = channel;

    var sampleRate = 24000;
    var chunkCount = 0;
    var serverDone = false;
    var playStarted = false;
    var finished = false;
    var chain = Future<void>.value();
    final result = Completer<bool>();
    Timer? timer;
    StreamSubscription<PlayerState>? sub;

    Future<void> finish(bool ok, String status) async {
      if (finished) return;
      finished = true;
      _abort = null;
      lastStatus = status;
      timer?.cancel();
      await sub?.cancel();
      await channel.sink.close();
      if (identical(_channel, channel)) _channel = null;
      if (!ok) {
        // 失败/打断：立即停掉播放器，让兜底方式或下一次朗读干净接管
        try {
          await _player.stop();
        } catch (_) {}
      }
      if (!result.isCompleted) result.complete(ok);
    }

    // stop() 通过这个钩子立即结束本轮等待
    _abort = () => finish(false, '已打断');

    Future<void> onChunk(String b64) async {
      if (finished) return;
      final pcm = base64Decode(b64);
      if (pcm.isEmpty) return;
      final wav = _wavFromPcm16(pcm, sampleRate);
      chunkCount++;
      try {
        if (!playStarted) {
          playStarted = true;
          debugPrint('[TTS] 首个分块到达，开始流式播放');
          await _player.setAudioSources([_BytesAudioSource(wav)]);
          if (finished) return;
          unawaited(_player.play());
        } else {
          await _player.addAudioSource(_BytesAudioSource(wav));
          if (finished) return;
          // 欠载自愈：播放已追上进度（completed），新块到达则续播
          if (_player.processingState == ProcessingState.completed) {
            unawaited(_player.play());
          }
        }
      } catch (e) {
        await finish(false, '播放器错误：$e');
      }
    }

    // 消息按到达顺序串行处理，保证分块顺序
    void enqueue(Future<void> Function() task) {
      chain = chain.then<void>((_) async {
        if (finished) return;
        await task();
      });
    }

    // 完成判定：服务器已发完 + 播放器播完。
    // 欠载（serverDone 之前的 completed）不会误判，因为要求 serverDone 为真，
    // 而 done 消息在链中排在所有分块之后。
    sub = _player.playerStateStream.listen((state) async {
      if (finished) return;
      if (state.processingState != ProcessingState.completed) return;
      if (!serverDone || !playStarted) return;
      await finish(true, '流式播放完成（$chunkCount 块）');
    });

    // 总超时兜底（服务器/引擎异常导致流不结束）
    final timeoutMs = (text.length * 300).clamp(30000, 300000);
    timer = Timer(Duration(milliseconds: timeoutMs), () {
      if (finished) return;
      unawaited(finish(false, '流式播放超时'));
    });

    try {
      await channel.ready.timeout(const Duration(seconds: 8));
      channel.sink.add(jsonEncode({'text': text, if (v != null) 'voice': v}));
    } catch (e) {
      unawaited(finish(false, 'WS连接失败：$e'));
      return result.future;
    }

    channel.stream.listen(
      (data) {
        if (data is! String) return;
        Map<String, dynamic> msg;
        try {
          msg = jsonDecode(data) as Map<String, dynamic>;
        } catch (_) {
          return;
        }
        switch (msg['type']) {
          case 'audio.start':
            sampleRate = (msg['sample_rate'] as num?)?.toInt() ?? 24000;
          case 'audio.chunk':
            final b64 = msg['data'] as String?;
            if (b64 != null) enqueue(() => onChunk(b64));
          case 'audio.done':
            final path = msg['path'] as String?;
            if (path != null && path.isNotEmpty) {
              // 引擎不支持流式（如 edge）：服务器只返回文件路径 → 下载后播放。
              // 必须等到真的播完才算本轮成功，否则 speak() 提前返回，
              // 连续朗读下一句会立刻 stop() 把还没播出来的声音掐掉。
              enqueue(() async {
                serverDone = true;
                if (chunkCount > 0) {
                  // 已经流式播了一部分，等播完即可（playerStateStream 收尾）
                  return;
                }
                timer?.cancel();
                final ok = await _playDownloadedPath(path, gen);
                await finish(ok, ok ? '下载服务器音频播放' : '下载服务器音频播放失败');
              });
            } else {
              enqueue(() async {
                serverDone = true;
                if (chunkCount == 0 && !finished) {
                  await finish(false, '服务器未返回音频');
                }
              });
            }
          case 'error':
            final message = (msg['message'] ?? 'TTS 错误').toString();
            enqueue(() => finish(false, '服务器错误：$message'));
        }
      },
      onError: (Object e) {
        if (!finished) unawaited(finish(false, 'WS连接错误：$e'));
      },
      onDone: () {
        // 服务器侧关闭：音频已发全且已在播则等播放完成事件，否则视为中断
        enqueue(() async {
          if (finished) return;
          if (!serverDone || !playStarted) {
            await finish(false, 'WS提前关闭');
          }
        });
      },
    );

    final ok = await result.future;
    if (!ok) {
      debugPrint('[TTS] WS流式播放失败: $lastStatus');
    }
    return ok;
  }

  /// 把 dio 异常翻译成可读信息：带 HTTP 状态码和服务器返回的真实原因。
  /// （默认 toString 只有 "DioException [unknown]: null"，无法定位问题）
  static String _dioErrText(Object e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      final data = e.response?.data;
      var detail = '';
      if (data is Map) {
        detail = (data['message'] ?? data['error'] ?? '').toString();
      } else if (data is String && data.isNotEmpty && data.length < 200) {
        detail = data;
      }
      final prefix = code != null ? 'HTTP $code' : e.type.name;
      if (detail.isEmpty && e.message != null) detail = e.message!;
      // 底层异常（如 URL 拼接错误的 FormatException）往往才是真正原因
      if (detail.isEmpty && e.error != null) detail = e.error.toString();
      return detail.isEmpty ? prefix : '$prefix: $detail';
    }
    return e.toString();
  }

  /// 独立连接下载音频：每次新建 Dio（不复用可能已断的 keep-alive 连接，
  /// WiFi/热点切换、高抖动网络下旧连接极易失效），失败自动重试。
  /// 返回 null 表示失败或已被打断（lastStatus 里给出原因）。
  Future<Uint8List?> _downloadBytes(String url, int gen) async {
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final dio = ApiClient.create(baseUrl: baseUrl, token: token)
          ..options.receiveTimeout = const Duration(minutes: 3);
        final resp = await dio.get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
        if (_gen != gen) return null; // 已被打断
        final data = resp.data;
        if (data != null && data.isNotEmpty) return Uint8List.fromList(data);
        lastStatus = 'HTTP下载：音频为空';
      } catch (e) {
        lastStatus = 'HTTP下载失败(第$attempt次)：${_dioErrText(e)}';
      }
      if (attempt < 3) {
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
        if (_gen != gen) return null;
      }
    }
    return null;
  }

  /// 播放服务器合成好的文件（引擎不支持流式时的 audio.done 带 path 场景，
  /// 如 edge 引擎返回 /static/current_audio.mp3）。
  ///
  /// [gen] 为本轮朗读代号：下载/播放途中若被 stop()（_gen 变化或播放器被
  /// stop 归为 idle）立即中止并返回 false；且必须等到真正播完才返回 true，
  /// 否则 speak() 提前返回，连续朗读的下一句会立刻 stop() 把声音掐掉。
  Future<bool> _playDownloadedPath(String path, int gen) async {
    try {
      // 相对路径交给 dio 按 baseUrl 解析（baseUrl 已规范化）；
      // 不要用原始 baseUrl 手工拼绝对 URL —— 用户没填协议头时会拼出
      // "IP:端口/api/..." 畸形地址，本地抛 FormatException 且请求发不出去。
      final url =
          '/api/tts/download?filename=${Uri.encodeQueryComponent(path)}';
      final bytes = await _downloadBytes(url, gen);
      if (bytes == null || _gen != gen) return false;
      // edge 输出 MP3、其他引擎输出 WAV —— 按扩展名给对类型，否则解码失败
      final isMp3 = path.toLowerCase().endsWith('.mp3');
      await _player.setAudioSource(
        _BytesAudioSource(bytes, contentType: isMp3 ? 'audio/mpeg' : 'audio/wav'),
      );
      if (_gen != gen) return false;
      await _player.play();
      final done = Completer<bool>();
      final sub = _player.playerStateStream.listen((state) {
        if (done.isCompleted) return;
        if (state.processingState == ProcessingState.completed) {
          done.complete(true);
        } else if (state.processingState == ProcessingState.idle) {
          // 被 stop()/新朗读打断回到 idle，视为未播完
          done.complete(false);
        }
      });
      try {
        final ok = await done.future
            .timeout(const Duration(minutes: 5), onTimeout: () => false);
        return _gen == gen && ok;
      } finally {
        await sub.cancel();
      }
    } catch (e) {
      debugPrint('[TTS] 下载路径播放失败: $e');
      lastStatus = '下载服务器音频播放异常：${_dioErrText(e)}';
      return false;
    }
  }

  /// 2) HTTP 下载播放：POST /api/tts/speak 拿路径 → 下载 → 播放（兜底）。
  /// [gen] 为本轮朗读代号：下载途中若被打断（代号变旧），立即放弃，
  /// 绝不把已被打断的旧内容重新合成播放出来。
  Future<bool> _tryDownloadPlay(String text, String? v, int gen) async {
    try {
      final req = await ApiClient.create(baseUrl: baseUrl, token: token)
          .post(
        '/api/tts/speak',
        data: {'text': text, if (v != null) 'voice': v},
      ).timeout(const Duration(minutes: 3));
      if (_gen != gen) return false; // 已被打断：放弃旧内容
      final audio = (req.data as Map<String, dynamic>?)?['audio'] as String?;
      if (audio == null || audio.isEmpty) {
        lastStatus = 'HTTP下载：未拿到音频路径';
        return false;
      }
      final url =
          '/api/tts/download?filename=${Uri.encodeQueryComponent(audio)}';
      final bytes = await _downloadBytes(url, gen);
      if (bytes == null || _gen != gen) return false;
      // edge 输出 MP3、其他引擎输出 WAV —— 按扩展名给对类型，否则解码失败
      final isMp3 = audio.toLowerCase().endsWith('.mp3');
      await _player.setAudioSource(
        _BytesAudioSource(bytes, contentType: isMp3 ? 'audio/mpeg' : 'audio/wav'),
      );
      if (_gen != gen) return false;
      await _player.play();
      final done = Completer<bool>();
      final sub = _player.playerStateStream.listen((state) {
        if (done.isCompleted) return;
        if (state.processingState == ProcessingState.completed) {
          done.complete(true);
        } else if (state.processingState == ProcessingState.idle) {
          done.complete(false);
        }
      });
      try {
        final ok = await done.future
            .timeout(const Duration(minutes: 5), onTimeout: () => false);
        final realOk = _gen == gen && ok;
        lastStatus = realOk ? 'HTTP下载播放完成' : 'HTTP下载播放被打断';
        return realOk;
      } finally {
        await sub.cancel();
      }
    } catch (e) {
      lastStatus = 'HTTP下载播放失败：${_dioErrText(e)}';
      debugPrint('[TTS] HTTP下载失败: $e');
      return false;
    }
  }

  /// 打断当前朗读（关闭 WS、停止播放、使等待中的 speak 立即作废）。
  ///
  /// 关键：所有状态失效都在第一个 await 之前同步完成 —— 若先 await 清理
  /// 再失效，被打断的 speak() 可能趁窗口期滑进下载兜底，把旧内容重新
  /// 合成播放，与新回复叠在一起（“两个声音同时说、卡住”）。
  Future<void> stop() async {
    _gen++; // 正在进行的朗读立即作废
    _busy = false;
    final abort = _abort;
    _abort = null;
    final ch = _channel;
    _channel = null;
    if (abort != null) {
      try {
        await abort();
      } catch (_) {}
    }
    if (ch != null) {
      try {
        await ch.sink.close();
      } catch (_) {}
    }
    try {
      await _player.stop();
    } catch (_) {}
  }

  /// 释放资源（页面销毁时调用）
  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }

  /// PCM16（单声道）打包成 WAV
  static Uint8List _wavFromPcm16(Uint8List pcm, int sampleRate) {
    final dataSize = pcm.length;
    final buffer = BytesBuilder();
    void writeStr(String s) => buffer.add(utf8.encode(s));
    void writeU32(int v) =>
        buffer.add([v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff]);
    void writeU16(int v) => buffer.add([v & 0xff, (v >> 8) & 0xff]);

    writeStr('RIFF');
    writeU32(36 + dataSize);
    writeStr('WAVE');
    writeStr('fmt ');
    writeU32(16);
    writeU16(1); // PCM
    writeU16(1); // 单声道
    writeU32(sampleRate);
    writeU32(sampleRate * 2); // 字节率
    writeU16(2); // 块对齐
    writeU16(16); // 位深
    writeStr('data');
    writeU32(dataSize);
    buffer.add(pcm);
    return buffer.toBytes();
  }
}

/// 已知长度的完整音频源（支持 Range 请求），喂给 just_audio/ExoPlayer。
///
/// [contentType] 默认 `audio/wav`（流式 PCM 分块打包的 WAV）；
/// 下载服务器已合成文件时按扩展名传 `audio/mpeg`（edge 输出 MP3）等。
class _BytesAudioSource extends StreamAudioSource {
  _BytesAudioSource(this._bytes, {this.contentType = 'audio/wav'})
      : super(tag: 'tts-chunk');

  final Uint8List _bytes;
  final String contentType;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final s = start ?? 0;
    final e = end ?? _bytes.length;
    return StreamAudioResponse(
      rangeRequestsSupported: true,
      sourceLength: _bytes.length,
      contentLength: e - s,
      offset: s,
      contentType: contentType,
      stream: Stream.value(_bytes.sublist(s, e)),
    );
  }
}

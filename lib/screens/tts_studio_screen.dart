// 语音合成页：参考网页版 tts-studio.js 的操作逻辑
// 引擎/音色下拉 → 输入文本 → 合成 → 播放预览 → 保存到手机本地
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../i18n/app_strings.dart';
import '../services/api_client.dart';
import '../services/save_audio_io.dart'
    if (dart.library.js_interop) '../services/save_audio_web.dart' as saver;
import '../state/app_state.dart';
import '../theme.dart';

// ignore_for_file: experimental_member_use

class TtsStudioScreen extends StatefulWidget {
  const TtsStudioScreen({super.key});

  @override
  State<TtsStudioScreen> createState() => _TtsStudioScreenState();
}

class _TtsStudioScreenState extends State<TtsStudioScreen> {
  final _textController = TextEditingController();
  final _voiceController = TextEditingController();

  final List<String> _engines = [];
  String _currentEngine = '';
  List<String> _voices = [];
  String? _voice;

  bool _loading = true;
  bool _synthLoading = false;
  bool _playing = false;
  bool _saving = false;
  String? _error;
  String? _savedPath;
  String? _lastPath;

  double _playProgress = 0;
  Duration _playDuration = Duration.zero;

  late final AudioPlayer _player;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _playing = state.processingState != ProcessingState.idle &&
              (state.playing || state.processingState == ProcessingState.loading);
        });
      }
    });
    _player.positionStream.listen((position) {
      if (!mounted) return;
      setState(() {
        _playProgress = _playDuration > Duration.zero
            ? (position.inMilliseconds / _playDuration.inMilliseconds)
                .clamp(0.0, 1.0)
            : 0;
      });
    });
    _loadAll();
  }

  @override
  void dispose() {
    _textController.dispose();
    _voiceController.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final service = context.read<AppState>().service;
    if (service == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await service.getTtsEngines();
      if (!mounted) return;
      setState(() {
        _engines
          ..clear()
          ..addAll(result.engines);
        _currentEngine = result.current;
      });
      await _loadVoices();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '${context.strs.loadFailed}${context.strs.colon}$e';
      });
    }
  }

  /// 切换引擎并加载其音色（参考 tts-studio.js onEngineChange / loadVoices）
  Future<void> _switchEngine(String engine) async {
    if (engine == _currentEngine) return;
    final service = context.read<AppState>().service;
    if (service == null) return;
    setState(() {
      _currentEngine = engine;
      _voices = [];
      _voice = null;
    });
    try {
      await service.switchTtsEngine(engine);
      await _loadVoices();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.strs.switchEngineFailed}$e')),
      );
    }
  }

  Future<void> _loadVoices() async {
    final service = context.read<AppState>().service;
    if (service == null) return;
    try {
      final voices = await service.getTtsVoices();
      if (!mounted) return;
      setState(() {
        _voices = voices;
        _voice = voices.isEmpty ? null : voices.first;
        _voiceController.text = voices.isEmpty ? '' : voices.first;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '${context.strs.voiceLoadFailed}$e';
      });
    }
  }

  /// 合成：POST /api/tts/synthesize → 拿 audio 路径 → 下载 → 播放/保存
  Future<void> _synthesize() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strs.enterSynthText)),
      );
      return;
    }
    final service = context.read<AppState>().service;
    if (service == null) return;
    setState(() {
      _synthLoading = true;
      _error = null;
      _savedPath = null;
    });
    try {
      final path = await service.synthesize(text, _voice ?? '');
      if (!mounted) return;
      setState(() {
        _lastPath = path;
        _savedPath = null;
      });
      final wav = await _download(path);
      if (!mounted) return;
      _playDuration = _wavDuration(wav);
      setState(() => _playProgress = 0);
      await _player.setAudioSource(_BytesAudioSource(wav));
      await _player.play();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '${context.strs.synthFailed}$e');
    } finally {
      if (mounted) setState(() => _synthLoading = false);
    }
  }

  /// 下载合成好的音频（GET /api/tts/download）
  Future<Uint8List> _download(String path) async {
    final app = context.read<AppState>();
    return ApiClient.downloadBytes(
      baseUrl: app.baseUrl,
      token: app.token,
      url:
          '/api/tts/download?filename=${Uri.encodeQueryComponent(path)}',
    );
  }

  /// 从 WAV 头（44 字节标准头）解析音频时长。
  /// 采样率在偏移 24，byteRate（每秒字节数）在偏移 28，
  /// data 块大小在偏移 40。duration = dataSize / byteRate。
  Duration _wavDuration(Uint8List wav) {
    try {
      if (wav.length < 44) return Duration.zero;
      final view = ByteData.sublistView(wav);
      final byteRate = view.getUint32(28, Endian.little);
      final dataSize = view.getUint32(40, Endian.little);
      if (byteRate <= 0 || dataSize <= 0) return Duration.zero;
      return Duration(
        milliseconds: (dataSize * 1000 / byteRate).round(),
      );
    } catch (_) {
      return Duration.zero;
    }
  }

  /// 停止播放
  Future<void> _stop() async {
    await _player.stop();
  }

  /// 保存到手机本地（path_provider 写入应用文档目录）。
  /// Web 调试版不支持保存本地文件，提示即可。
  Future<void> _save(String path) async {
    final app = context.read<AppState>();
    setState(() => _saving = true);
    try {
      final wav = await ApiClient.downloadBytes(
        baseUrl: app.baseUrl,
        token: app.token,
        url: '/api/tts/download?filename=${Uri.encodeQueryComponent(path)}',
      );
      final saved = await saver.saveAudioBytes(wav, baseName: 'tts');
      if (!mounted) return;
      setState(() => _savedPath = saved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strs.audioSaved)),
      );
    } on UnsupportedError {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strs.webSaveUnsupported)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.strs.saveFailed}$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strs = context.strs;
    return Scaffold(
      appBar: AppBar(title: Text(strs.ttsStudio)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _engines.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _loadAll, child: Text(strs.retry)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    // 引擎选择
                    DropdownButtonFormField<String>(
                      initialValue: _currentEngine,
                      decoration: InputDecoration(
                        labelText: strs.ttsEngine,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _engines
                          .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(e),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) _switchEngine(v);
                      },
                    ),
                    const SizedBox(height: 12),
                    // 音色选择
                    DropdownButtonFormField<String>(
                      key: ValueKey(_voices.join(',')),
                      initialValue: _voice,
                      decoration: InputDecoration(
                        labelText: strs.voiceLabel,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _voices
                          .map((v) => DropdownMenuItem(
                                value: v,
                                child: Text(v),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _voice = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    // 文本输入
                    TextField(
                      controller: _textController,
                      maxLines: 6,
                      maxLength: 2000,
                      decoration: InputDecoration(
                        hintText: strs.synthTextHint,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 操作按钮
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _synthLoading ? null : _synthesize,
                            icon: _synthLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.graphic_eq),
                            label: Text(strs.synthesize),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _playing ? _stop : null,
                            icon: const Icon(Icons.stop),
                            label: Text(strs.stop),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 播放 + 保存
                    if (_playing) ...[
                      LinearProgressIndicator(
                        value: _playDuration > Duration.zero
                            ? _playProgress
                            : null,
                        minHeight: 4,
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    if (_savedPath != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '${strs.savedPathPrefix}$_savedPath',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : () => _save(_lastPath ?? ''),
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.download),
                        label: Text(strs.saveAudio),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }
}

/// 已知长度的完整音频源（同 tts_service 中的实现，喂给 just_audio）
class _BytesAudioSource extends StreamAudioSource {
  _BytesAudioSource(this._bytes) : super(tag: 'tts-studio');

  final Uint8List _bytes;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final s = start ?? 0;
    final e = end ?? _bytes.length;
    return StreamAudioResponse(
      rangeRequestsSupported: true,
      sourceLength: _bytes.length,
      contentLength: e - s,
      offset: s,
      contentType: 'audio/wav',
      stream: Stream.value(_bytes.sublist(s, e)),
    );
  }
}
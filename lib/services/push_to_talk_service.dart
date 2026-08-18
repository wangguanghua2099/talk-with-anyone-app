// 按住说话输入：录音 PCM16 → 打包 WAV → 上传转写 → 得到文字
//
// 后端接口：POST /api/stt/transcribe（multipart 上传音频文件，返回 {text}）
// 参考 routes/stt.py：decode_audio 支持 wav/mp3/flac/ogg/m4a，识别后返回文本。
//
// 录音用 record 包的 startStream（PCM16/16k/单声道），跨平台可用：
//   - Android/iOS：record 平台实现输出 PCM16 流
//   - Web（Edge 调试用）：record_web 同样输出 PCM16 流（mic_recorder_delegate）
// 收集完毕后自己写 WAV 头打包，避免依赖本地方便路径，方便 Web 端上传。
import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

class PushToTalkService {
  PushToTalkService({required this.baseUrl, required this.token});

  final String baseUrl;
  final String token;

  final AudioRecorder _recorder = AudioRecorder();
  final BytesBuilder _buf = BytesBuilder();
  StreamSubscription<Uint8List>? _sub;
  bool _recording = false;

  /// 是否正在录音
  bool get isRecording => _recording;

  static const _config = RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: 16000,
    numChannels: 1,
    echoCancel: true,
    noiseSuppress: true,
  );

  /// 检查/请求麦克风权限
  Future<bool> hasPermission() => _recorder.hasPermission();

  /// 开始按住说话：开启录音并把 PCM16 分块收进缓冲区
  Future<void> start() async {
    if (_recording) return;
    _buf.clear();
    final stream = await _recorder.startStream(_config);
    _recording = true;
    _sub = stream.listen(
      _buf.add,
      onError: (Object e) {
        _recording = false;
      },
    );
  }

  /// 停止按住说话：停止录音，把缓冲的 PCM16 打包成 16k/单声道 WAV 返回
  Future<Uint8List> stop() async {
    _recording = false;
    await _sub?.cancel();
    _sub = null;
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    final pcm = _buf.takeBytes();
    return _wavFromPcm16(pcm, 16000);
  }

  Future<void> dispose() async {
    _recording = false;
    await _sub?.cancel();
    _sub = null;
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    await _recorder.dispose();
  }

  /// PCM16（单声道）打包成 WAV（与 tts_service 中相同的实现）
  static Uint8List _wavFromPcm16(Uint8List pcm, int sampleRate) {
    final dataSize = pcm.length;
    final buffer = BytesBuilder();
    void writeStr(String s) => buffer.add(s.codeUnits);
    void writeU32(int v) => buffer.add([
          v & 0xff,
          (v >> 8) & 0xff,
          (v >> 16) & 0xff,
          (v >> 24) & 0xff,
        ]);
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
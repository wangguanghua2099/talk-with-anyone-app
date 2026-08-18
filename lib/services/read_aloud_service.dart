// 连续朗读服务：从指定消息开始逐条朗读到对话末尾（参考 web read-aloud.js）
// 用户消息用 user_voice，AI 用 ai_voice；stop() 立即中断并清空高亮。
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'tts_service.dart';

class ReadAloudService {
  ReadAloudService({required this.baseUrl, required this.token});

  final String baseUrl;
  final String token;

  TtsService? _tts;
  bool _reading = false;

  /// 正在朗读的消息下标（供界面高亮）
  int? readingIndex;

  /// 是否正在朗读
  bool get reading => _reading;

  /// 朗读进度回调：切换到第 index 条时的通知
  void Function(int index)? onIndexChanged;

  /// 整轮朗读结束回调（读完或被打断）
  VoidCallback? onFinished;

  /// 错误回调（界面用 SnackBar 提示）
  void Function(String message)? onError;

  TtsService get _ttsInstance =>
      _tts ??= TtsService(baseUrl: baseUrl, token: token);

  /// 从 [startIndex] 开始连续朗读到 [messages] 末尾。
  /// [userVoice]/[aiVoice] 由调用方从 config 读取后传入。
  Future<void> start(
    List<ChatMessage> messages,
    int startIndex, {
    String? userVoice,
    String? aiVoice,
  }) async {
    stop();
    if (startIndex < 0 || startIndex >= messages.length) return;
    _reading = true;
    for (var i = startIndex; i < messages.length; i++) {
      if (!_reading) break;
      final m = messages[i];
      if (m.content.trim().isEmpty) continue;
      readingIndex = i;
      onIndexChanged?.call(i);
      final voice = m.role == 'user' ? userVoice : aiVoice;
      try {
        await _ttsInstance.speak(m.content, voice: voice);
      } catch (e) {
        if (!_reading) break;
        _reading = false;
        onError?.call(e.toString());
        break;
      }
    }
    _finish();
  }

  /// 立即中断朗读（服务端停止 + 本地停止 + 清高亮）
  Future<void> stop() async {
    _reading = false;
    await _tts?.stop();
    _finish();
  }

  void _finish() {
    readingIndex = null;
    onFinished?.call();
  }
}
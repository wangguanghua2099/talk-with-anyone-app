// 聊天输入栏：文本输入 + 发送 + 按住说话麦克风（语音识别输入文字）
import 'package:flutter/material.dart';

import '../i18n/app_strings.dart';
import '../theme.dart';

enum PttStatus { none, recording, transcribing }

class ChatInputBar extends StatelessWidget {
  const ChatInputBar({
    super.key,
    required this.controller,
    required this.sending,
    required this.pttStatus,
    required this.onSend,
    required this.onPttStart,
    required this.onPttEnd,
    required this.onPttCancel,
  });

  final TextEditingController controller;
  final bool sending;
  final PttStatus pttStatus;
  final VoidCallback onSend;
  final VoidCallback onPttStart;
  final VoidCallback onPttEnd;
  final VoidCallback onPttCancel;

  @override
  Widget build(BuildContext context) {
    final strs = context.strs;
    final recording = pttStatus == PttStatus.recording;
    final transcribing = pttStatus == PttStatus.transcribing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (recording || transcribing)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    transcribing ? Icons.graphic_eq : Icons.mic,
                    size: 16,
                    color: transcribing ? AppTheme.primary : Colors.redAccent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    transcribing ? strs.recognizingVoice : strs.speechHint,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: strs.inputHint,
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: sending ? null : onSend,
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send),
              ),
              const SizedBox(width: 8),
              // 按住说话：语音识别输入文字
              GestureDetector(
                onLongPressStart: (_) => onPttStart(),
                onLongPressEnd: (_) => onPttEnd(),
                onLongPressCancel: () => onPttCancel(),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: recording
                        ? Colors.redAccent
                        : transcribing
                            ? AppTheme.primary
                            : AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    recording
                        ? Icons.mic
                        : transcribing
                            ? Icons.hourglass_top
                            : Icons.mic_none,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
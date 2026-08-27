// 聊天上方工具栏：电话 + 喇叭开关（开启/关闭 TTS 朗读） + 停止朗读 + 知识库开关
import 'package:flutter/material.dart';

import '../i18n/app_strings.dart';
import '../theme.dart';

class ChatPhoneBar extends StatelessWidget {
  const ChatPhoneBar({
    super.key,
    required this.phoneLabel,
    required this.ttsEnabled,
    required this.stopEnabled,
    required this.ragEnabled,
    required this.onPhoneTap,
    required this.onToggleTts,
    required this.onStopTap,
    required this.onToggleRag,
  });

  final String phoneLabel;

  /// TTS 朗读开关状态：false 时喇叭为静音（禁用）样式
  final bool ttsEnabled;

  final bool stopEnabled;

  /// 知识库开关状态：true 时图标高亮主色
  final bool ragEnabled;
  final VoidCallback onPhoneTap;
  final VoidCallback onToggleTts;
  final VoidCallback onStopTap;
  final VoidCallback onToggleRag;

  @override
  Widget build(BuildContext context) {
    final strs = context.strs;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: onPhoneTap,
            icon: const Icon(Icons.phone_outlined, size: 18),
            label: Text(phoneLabel),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primary,
              visualDensity: VisualDensity.compact,
            ),
          ),
          // 喇叭开关：开启 = 有声（主色），关闭 = 静音（灰色，禁用观感）
          IconButton(
            tooltip: ttsEnabled ? strs.toggleTtsOff : strs.toggleTtsOn,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              ttsEnabled
                  ? Icons.volume_up_outlined
                  : Icons.volume_off_outlined,
              size: 20,
              color: ttsEnabled ? AppTheme.primary : AppTheme.textSecondary,
            ),
            onPressed: onToggleTts,
          ),
          TextButton.icon(
            onPressed: stopEnabled ? onStopTap : null,
            icon: const Icon(Icons.stop_circle_outlined, size: 18),
            label: Text(strs.stopReading),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primary,
              visualDensity: VisualDensity.compact,
              disabledForegroundColor: AppTheme.textSecondary,
            ),
          ),
          // 知识库开关：开启 = 书本高亮主色 + "知识库"文字，关闭 = 灰色
          TextButton.icon(
            onPressed: onToggleRag,
            icon: Icon(
              ragEnabled
                  ? Icons.auto_stories
                  : Icons.auto_stories_outlined,
              size: 18,
              color: ragEnabled ? AppTheme.primary : AppTheme.textSecondary,
            ),
            label: Text(strs.knowledgeBase),
            style: TextButton.styleFrom(
              foregroundColor:
                  ragEnabled ? AppTheme.primary : AppTheme.textSecondary,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}
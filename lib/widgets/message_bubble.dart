// 聊天消息气泡：头像 + 名称 + 气泡；朗读高亮、点击回调。
// 布局参考网页版（chat.js + style.css）：
//   AI   消息：头像在左、名称左对齐、白底气泡
//   用户消息：头像在右、名称右对齐、蓝底气泡
// 头像缺省用首字符占位：用户绿色 #4CD964，AI 蓝 #007AFF。
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';
import 'avatar.dart';
import 'typewriter_text.dart';

/// 消息之间的时间分隔条（微信风格：间隔>1分钟才显示，居中灰底小标签）
class TimeHeader extends StatelessWidget {
  const TimeHeader({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFE8E8E8),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
          ),
        ),
      ),
    );
  }
}

/// 时间格式化（与网页版 formatTime 一致）：
///   今天 → 「今天 HH:mm」；昨天 → 「昨天 HH:mm」；更早 → 「M月D日 HH:mm」
///   isEn 时 → Today/Yesterday/M/D HH:mm
String formatChatTime(DateTime date, {required bool isEn}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final msgDay = DateTime(date.year, date.month, date.day);
  final hh = date.hour.toString().padLeft(2, '0');
  final mm = date.minute.toString().padLeft(2, '0');
  if (msgDay == today) return isEn ? 'Today $hh:$mm' : '今天 $hh:$mm';
  final yesterday = today.subtract(const Duration(days: 1));
  if (msgDay == yesterday) {
    return isEn ? 'Yesterday $hh:$mm' : '昨天 $hh:$mm';
  }
  return isEn
      ? '${date.month}/${date.day} $hh:$mm'
      : '${date.month}月${date.day}日 $hh:$mm';
}

/// 是否应显示时间头（网页版 shouldShowTimeHeader）：
///   与上一个时间头间隔超过 1 分钟才显示，避免每条都出现
bool shouldShowTimeHeader(DateTime current, DateTime reference) {
  return current.difference(reference) >
      const Duration(minutes: 1);
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.userName,
    this.userAvatar,
    required this.aiName,
    this.aiAvatar,
    this.isReading = false,
    this.isFlash = false,
    this.onTap,
    this.streamText,
    this.streamDone = false,
    this.onStreamFinished,
    this.onStreamProgress,
  });

  final ChatMessage message;

  /// 当前的用户昵称/头像（来自服务器全局配置）
  final String userName;
  final String? userAvatar;

  /// 该条 AI 消息的显示名称/头像（按消息角色匹配）
  final String aiName;
  final String? aiAvatar;

  final bool isReading;

  /// 搜索跳转定位后的短暂高亮（对应网页版 message-flash）
  final bool isFlash;
  final VoidCallback? onTap;

  /// 流式打字显示：非空时气泡正文用 TypewriterText 渲染（忽略 message.content），
  /// 全部显示完后回调 onStreamFinished（父级再换成最终静态文本）
  final ValueListenable<String>? streamText;
  final bool streamDone;
  final VoidCallback? onStreamFinished;
  final VoidCallback? onStreamProgress;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final name = isUser ? userName : aiName;
    final avatar = AppAvatar(
      dataUri: isUser ? userAvatar : aiAvatar,
      name: name,
      radius: 20,
      backgroundColor:
          isUser ? const Color(0xFF4CD964) : AppTheme.primary,
    );

    final bubble = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isReading || isFlash
            ? (isUser
                ? AppTheme.primary.withValues(alpha: 0.7)
                : const Color(0xFFE8F4FF))
            : (isUser ? AppTheme.primary : Colors.white),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isUser ? 16 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 16),
        ),
        border: isReading || isFlash
            ? Border.all(color: AppTheme.primary, width: 2)
            : (isUser ? null : Border.all(color: AppTheme.border)),
      ),
      child: streamText != null
          ? TypewriterText(
              buffer: streamText!,
              done: streamDone,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: isUser ? Colors.white : AppTheme.textPrimary,
              ),
              onFinished: onStreamFinished,
              onProgress: onStreamProgress,
            )
          : Text(
              message.content,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: isUser ? Colors.white : AppTheme.textPrimary,
              ),
            ),
    );

    final content = Column(
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF888888),
          ),
        ),
        bubble,
      ],
    );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: isUser
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(child: content),
                      const SizedBox(width: 8),
                      avatar,
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      avatar,
                      const SizedBox(width: 8),
                      Flexible(child: content),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
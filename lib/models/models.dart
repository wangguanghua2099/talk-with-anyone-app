// 数据模型：与服务器 API 返回结构对应
class ServerInfo {
  final String name;
  final String version;
  final bool authRequired;

  ServerInfo({required this.name, required this.version, required this.authRequired});

  factory ServerInfo.fromJson(Map<String, dynamic> json) => ServerInfo(
        name: json['name'] ?? 'Talk With Anyone',
        version: json['version'] ?? 'unknown',
        authRequired: json['auth_required'] == true,
      );
}

class Character {
  final String id;
  final String name;
  final String displayName;
  final String aiPrompt;
  final String aiVoice;
  final String aiAvatar;
  final Map<String, dynamic> engineVoices;

  Character({
    required this.id,
    required this.name,
    required this.displayName,
    required this.aiPrompt,
    required this.aiVoice,
    required this.aiAvatar,
    required this.engineVoices,
  });

  factory Character.fromJson(Map<String, dynamic> json) => Character(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        displayName: json['display_name'] ?? json['name'] ?? '',
        aiPrompt: json['ai_prompt'] ?? '',
        aiVoice: json['ai_voice'] ?? '',
        aiAvatar: json['ai_avatar'] ?? '',
        engineVoices: (json['engine_voices'] as Map?)?.cast<String, dynamic>() ?? {},
      );
}

class Conversation {
  final String id;
  final String title;
  final String createdAt;
  final String updatedAt;
  final int messageCount;

  Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messageCount,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        createdAt: json['created_at'] ?? '',
        updatedAt: json['updated_at'] ?? '',
        messageCount: json['message_count'] ?? 0,
      );
}

class ChatMessage {
  final String role; // user / assistant
  final String content;
  final String? displayName;
  final String timestamp;
  final String? characterId;

  ChatMessage({
    required this.role,
    required this.content,
    this.displayName,
    required this.timestamp,
    this.characterId,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: json['role'] ?? '',
        content: json['content'] ?? '',
        displayName: json['display_name'],
        timestamp: json['timestamp'] ?? '',
        characterId: json['character_id'],
      );

  /// /api/chat 返回的 assistant 消息：timestamp 本地生成
  factory ChatMessage.assistant(String reply, String displayName, {DateTime? now}) {
    final t = (now ?? DateTime.now()).toIso8601String();
    return ChatMessage(
      role: 'assistant',
      content: reply,
      displayName: displayName,
      timestamp: t,
    );
  }
}

/// /api/chat 响应：{reply, display_name, history}
class ChatResult {
  final String reply;
  final String displayName;
  final List<ChatMessage> history;

  ChatResult({required this.reply, required this.displayName, required this.history});

  factory ChatResult.fromJson(Map<String, dynamic> json) => ChatResult(
        reply: json['reply'] ?? '',
        displayName: json['display_name'] ?? 'AI',
        history: (json['history'] as List? ?? [])
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

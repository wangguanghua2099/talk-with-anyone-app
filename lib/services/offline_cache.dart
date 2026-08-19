// 离线只读缓存：以电脑服务器数据为准，断连时手机可回看最近一次同步的内容。
//
// 写：每次从服务器成功拉取后由 ServerService 自动落盘（fire-and-forget）；
// 读：断连时各界面从这里取数据，绝不反向改服务器。
//
// 存两类：
//   1) 元数据快照（会话列表/角色/配置/服务器信息） → SharedPreferences 单条 JSON
//   2) 每个会话的消息（可能很大） → 应用支持目录下 conv_cache/<id>.json
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// 元数据快照：断连时从它恢复会话列表、角色、配置、服务器信息。
class OfflineSnapshot {
  const OfflineSnapshot({
    required this.savedAt,
    this.serverInfo,
    required this.conversations,
    required this.currentConversationId,
    required this.characters,
    required this.currentCharacterId,
    this.config,
  });

  final DateTime savedAt;
  final ServerInfo? serverInfo;
  final List<Conversation> conversations;
  final String currentConversationId;
  final List<Character> characters;
  final String currentCharacterId;
  final Map<String, dynamic>? config;

  Character? get currentCharacter {
    for (final c in characters) {
      if (c.id == currentCharacterId) return c;
    }
    return null;
  }

  factory OfflineSnapshot.fromJson(Map<String, dynamic> json) =>
      OfflineSnapshot(
        savedAt:
            DateTime.tryParse(json['saved_at'] ?? '') ?? DateTime.now(),
        serverInfo: json['server_info'] == null
            ? null
            : ServerInfo.fromJson(json['server_info'] as Map<String, dynamic>),
        conversations: (json['conversations'] as List? ?? [])
            .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
            .toList(),
        currentConversationId: json['current_conversation_id'] ?? '',
        characters: (json['characters'] as List? ?? [])
            .map((e) => Character.fromJson(e as Map<String, dynamic>))
            .toList(),
        currentCharacterId: json['current_character_id'] ?? '',
        config: (json['config'] as Map?)?.cast<String, dynamic>(),
      );

  Map<String, dynamic> toJson() => {
        'saved_at': savedAt.toIso8601String(),
        'server_info': serverInfo?.toJson(),
        'conversations': conversations.map((e) => e.toJson()).toList(),
        'current_conversation_id': currentConversationId,
        'characters': characters.map((e) => e.toJson()).toList(),
        'current_character_id': currentCharacterId,
        'config': config,
      };

  OfflineSnapshot copyWith({
    DateTime? savedAt,
    ServerInfo? serverInfo,
    List<Conversation>? conversations,
    String? currentConversationId,
    List<Character>? characters,
    String? currentCharacterId,
    Map<String, dynamic>? config,
  }) =>
      OfflineSnapshot(
        savedAt: savedAt ?? this.savedAt,
        serverInfo: serverInfo ?? this.serverInfo,
        conversations: conversations ?? this.conversations,
        currentConversationId:
            currentConversationId ?? this.currentConversationId,
        characters: characters ?? this.characters,
        currentCharacterId: currentCharacterId ?? this.currentCharacterId,
        config: config ?? this.config,
      );
}

class OfflineCache {
  static const _metaKey = 'offline_snapshot_v1';

  // ---- 元数据快照 ----

  static Future<OfflineSnapshot?> _readMeta() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_metaKey);
      if (raw == null || raw.isEmpty) return null;
      return OfflineSnapshot.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeMeta(OfflineSnapshot snap) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_metaKey, jsonEncode(snap.toJson()));
    } catch (_) {
      // 缓存写失败不致命
    }
  }

  /// 更新快照里的指定字段（先读后合写，避免并发覆盖丢失字段）
  static Future<void> updateMeta({
    ServerInfo? serverInfo,
    List<Conversation>? conversations,
    String? currentConversationId,
    List<Character>? characters,
    String? currentCharacterId,
    Map<String, dynamic>? config,
  }) async {
    final old = await _readMeta();
    final base = old ??
        OfflineSnapshot(
          savedAt: DateTime.now(),
          conversations: const [],
          currentConversationId: '',
          characters: const [],
          currentCharacterId: '',
        );
    await _writeMeta(
      base.copyWith(
        savedAt: DateTime.now(),
        serverInfo: serverInfo,
        conversations: conversations,
        currentConversationId: currentConversationId,
        characters: characters,
        currentCharacterId: currentCharacterId,
        config: config,
      ),
    );
  }

  static Future<OfflineSnapshot?> loadSnapshot() => _readMeta();

  static Future<List<Conversation>> loadConversations() async {
    final snap = await _readMeta();
    return snap?.conversations ?? const [];
  }

  static Future<({List<Character> characters, String currentId})>
      loadCharacters() async {
    final snap = await _readMeta();
    return (
      characters: snap?.characters ?? const [],
      currentId: snap?.currentCharacterId ?? '',
    );
  }

  static Future<Map<String, dynamic>?> loadConfig() async {
    final snap = await _readMeta();
    return snap?.config;
  }

  static Future<String> loadCurrentConversationId() async {
    final snap = await _readMeta();
    return snap?.currentConversationId ?? '';
  }

  // ---- 会话消息（按会话文件存储） ----

  static Future<Directory> _convCacheDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}conv_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static String _convCacheFile(String convId) =>
      '${convId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.json';

  static Future<void> saveConversation({
    required Conversation conversation,
    required List<ChatMessage> messages,
  }) async {
    try {
      final dir = await _convCacheDir();
      final file = File('${dir.path}${Platform.pathSeparator}'
          '${_convCacheFile(conversation.id)}');
      await file.writeAsString(jsonEncode({
        'saved_at': DateTime.now().toIso8601String(),
        'conversation': conversation.toJson(),
        'messages': messages.map((m) => m.toJson()).toList(),
      }));
    } catch (_) {
      // 缓存写失败不致命
    }
  }

  /// 返回缓存的会话消息；没有则 null。
  static Future<({Conversation conversation, List<ChatMessage> messages})?>
      loadConversation(String convId) async {
    if (convId.isEmpty) return null;
    try {
      final dir = await _convCacheDir();
      final file = File('${dir.path}${Platform.pathSeparator}'
          '${_convCacheFile(convId)}');
      if (!await file.exists()) return null;
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return (
        conversation:
            Conversation.fromJson(json['conversation'] as Map<String, dynamic>),
        messages: (json['messages'] as List? ?? [])
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> deleteConversationCache(String convId) async {
    try {
      final dir = await _convCacheDir();
      final file = File('${dir.path}${Platform.pathSeparator}'
          '${_convCacheFile(convId)}');
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// 登录信息被清空（退出登录）时一并清掉缓存
  static Future<void> clear() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_metaKey);
      final dir = await _convCacheDir();
      if (await dir.exists()) {
        await for (final e in dir.list()) {
          await e.delete(recursive: true);
        }
      }
    } catch (_) {}
  }
}
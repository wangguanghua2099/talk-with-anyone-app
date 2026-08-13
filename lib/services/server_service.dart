// 服务器接口封装：连接测试、角色、会话、聊天
import 'package:dio/dio.dart';

import '../models/models.dart';
import 'api_client.dart';

class ServerService {
  ServerService({required this.baseUrl, required this.token}) {
    _dio = ApiClient.create(baseUrl: baseUrl, token: token);
  }

  final String baseUrl;
  final String token;
  late final Dio _dio;

  /// 测试连接：GET /api/info（该接口豁免口令校验，可用于探测服务器是否存在）
  Future<ServerInfo> testConnection() async {
    final resp = await _dio.get('/api/info');
    return ServerInfo.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<List<Character>> getCharacters() async {
    final resp = await _dio.get('/api/characters');
    final list = (resp.data as Map<String, dynamic>)['characters'] as List;
    return list.map((e) => Character.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 服务器全局配置（含 current_character_id、用户名、头像等）
  Future<Map<String, dynamic>> getConfig() async {
    final resp = await _dio.get('/api/config');
    return resp.data as Map<String, dynamic>;
  }

  Future<List<Conversation>> searchConversations(String query) async {
    final resp = await _dio.get(
      '/api/conversations/search',
      queryParameters: {'q': query},
    );
    final list = ((resp.data as Map<String, dynamic>)['conversations'] as List? ??
            [])
        .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<({List<Conversation> conversations, String currentId})> getConversations() async {
    final resp = await _dio.get('/api/conversations');
    final data = resp.data as Map<String, dynamic>;
    final list = (data['conversations'] as List? ?? [])
        .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
        .toList();
    return (conversations: list, currentId: (data['current_id'] as String?) ?? '');
  }

  /// 获取指定会话（含消息列表）。返回当前会话对象。
  Future<({Conversation conversation, List<ChatMessage> messages})> getConversation(
    String convId,
  ) async {
    final resp = await _dio.get('/api/conversations/$convId');
    final data = (resp.data as Map<String, dynamic>)['conversation'] as Map<String, dynamic>;
    final messages = (data['messages'] as List? ?? [])
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
    return (
      conversation: Conversation.fromJson(data),
      messages: messages,
    );
  }

  /// 切换当前会话（服务器端保存，之后 /api/chat 都会基于它）
  Future<void> switchConversation(String convId) async {
    await _dio.post('/api/conversations/switch', data: {'conv_id': convId});
  }

  Future<void> createConversation() async {
    await _dio.post('/api/conversations');
  }

  Future<void> deleteConversation(String convId) async {
    await _dio.delete('/api/conversations/$convId');
  }

  Future<void> renameConversation(String convId, String title) async {
    await _dio.post('/api/conversations/$convId/rename', data: {'title': title});
  }

  Future<ChatResult> sendMessage(String message) async {
    final resp = await _dio.post('/api/chat', data: {'message': message});
    return ChatResult.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> selectCharacter(String id) async {
    await _dio.post('/api/characters/select', data: {'id': id});
  }
}

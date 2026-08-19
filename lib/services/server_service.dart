// 服务器接口封装：连接测试、角色、会话、聊天
import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/models.dart';
import 'api_client.dart';
import 'offline_cache.dart';

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
    final info = ServerInfo.fromJson(resp.data as Map<String, dynamic>);
    unawaited(OfflineCache.updateMeta(serverInfo: info));
    return info;
  }

  Future<List<Character>> getCharacters() async {
    final resp = await _dio.get('/api/characters');
    final list = (resp.data as Map<String, dynamic>)['characters'] as List;
    final chars = list
        .map((e) => Character.fromJson(e as Map<String, dynamic>))
        .toList();
    unawaited(OfflineCache.updateMeta(characters: chars));
    return chars;
  }

  /// 服务器全局配置（含 current_character_id、用户名、头像等）
  Future<Map<String, dynamic>> getConfig() async {
    final resp = await _dio.get('/api/config');
    final data = resp.data as Map<String, dynamic>;
    unawaited(OfflineCache.updateMeta(config: data));
    return data;
  }

  /// 更新服务器全局配置（POST /api/config，未传字段保持不变）
  Future<void> updateConfig(Map<String, dynamic> data) async {
    await _dio.post('/api/config', data: data);
  }

  /// 上传用户头像（POST /api/avatar/upload，avatar 为 base64 data URI，target=user）
  Future<void> uploadUserAvatar(String dataUri) async {
    await _dio.post('/api/avatar/upload', data: {
      'avatar': dataUri,
      'target': 'user',
    });
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
    final currentId = (data['current_id'] as String?) ?? '';
    unawaited(OfflineCache.updateMeta(
      conversations: list,
      currentConversationId: currentId,
    ));
    return (conversations: list, currentId: currentId);
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
    final conversation = Conversation.fromJson(data);
    unawaited(OfflineCache.saveConversation(
      conversation: conversation,
      messages: messages,
    ));
    return (conversation: conversation, messages: messages);
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
    unawaited(OfflineCache.deleteConversationCache(convId));
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

  /// 新增角色（POST /api/characters），返回创建后的角色
  Future<Character> addCharacter(Map<String, dynamic> data) async {
    final resp = await _dio.post('/api/characters', data: data);
    final char = (resp.data as Map<String, dynamic>)['character'] as Map<String, dynamic>;
    return Character.fromJson(char);
  }

  /// 更新角色（PUT /api/characters/{id}，未传字段保持不变）
  Future<Character> updateCharacter(String id, Map<String, dynamic> data) async {
    final resp = await _dio.put('/api/characters/$id', data: data);
    final char = (resp.data as Map<String, dynamic>)['character'] as Map<String, dynamic>;
    return Character.fromJson(char);
  }

  /// 删除角色（DELETE /api/characters/{id}）
  Future<void> deleteCharacter(String id) async {
    await _dio.delete('/api/characters/$id');
  }

  /// 上传 AI（角色）头像（POST /api/avatar/upload，保存到当前角色 ai_avatar）
  Future<void> uploadAiAvatar(String dataUri) async {
    await _dio.post('/api/avatar/upload', data: {
      'avatar': dataUri,
      'target': 'ai',
    });
  }

  /// TTS 引擎列表 + 当前引擎（GET /api/tts/engines）
  Future<({List<String> engines, String current})> getTtsEngines() async {
    final resp = await _dio.get('/api/tts/engines');
    final data = resp.data as Map<String, dynamic>;
    return (
      engines: (data['engines'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      current: (data['current'] as String?) ?? '',
    );
  }

  /// 切换 TTS 引擎（POST /api/tts/engine）
  Future<void> switchTtsEngine(String engine) async {
    await _dio.post('/api/tts/engine', data: {'engine': engine});
  }

  /// 当前引擎的音色列表（GET /api/tts/voices）
  Future<List<String>> getTtsVoices() async {
    final resp = await _dio.get('/api/tts/voices');
    final data = resp.data as Map<String, dynamic>;
    return (data['voices'] as List? ?? []).map((e) => e.toString()).toList();
  }

  /// 合成音频并保存到服务器，返回文件路径（POST /api/tts/synthesize）
  Future<String> synthesize(String text, String voice) async {
    final resp = await _dio.post(
      '/api/tts/synthesize',
      data: {'text': text, 'voice': voice},
    );
    final data = resp.data as Map<String, dynamic>;
    return (data['audio'] as String?) ?? '';
  }

  /// 自定义音色列表（GET /api/tts/custom-voices）
  Future<List<Map<String, dynamic>>> getCustomVoices() async {
    final resp = await _dio.get('/api/tts/custom-voices');
    final data = resp.data as Map<String, dynamic>;
    return (data['voices'] as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// 添加自定义音色（POST /api/tts/custom-voices，multipart）
  Future<void> addCustomVoice({
    required String name,
    required String refText,
    required String fileName,
    required List<int> fileBytes,
  }) async {
    final file = MultipartFile.fromBytes(
      fileBytes,
      filename: fileName,
    );
    final formData = FormData.fromMap({
      'name': name,
      'ref_text': refText,
      'file': file,
    });
    await _dio.post(
      '/api/tts/custom-voices',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  /// 删除自定义音色（DELETE /api/tts/custom-voices/{id}）
  Future<void> deleteCustomVoice(String voiceId) async {
    await _dio.delete('/api/tts/custom-voices/$voiceId');
  }

  /// 上传音频转写为文字（POST /api/stt/transcribe）
  Future<String> transcribeAudio(Uint8List wavBytes) async {
    final file = MultipartFile.fromBytes(wavBytes, filename: 'speech.wav');
    final formData = FormData.fromMap({'file': file});
    final resp = await _dio.post(
      '/api/stt/transcribe',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return (resp.data as Map<String, dynamic>)['text']?.toString() ?? '';
  }

  /// 抓取网页正文文本（POST /api/web/fetch）
  Future<String> fetchWebContent(String url) async {
    final resp = await _dio.post('/api/web/fetch', data: {'url': url});
    return (resp.data as Map<String, dynamic>)['content']?.toString() ?? '';
  }

  /// 拉取 LLM 服务商可用模型列表（POST /api/llm/models）
  Future<List<String>> getLlmModels({
    required String backend,
    required String url,
    required String apiKey,
  }) async {
    final resp = await _dio.post(
      '/api/llm/models',
      data: {
        'llm_backend': backend,
        'llm_url': url,
        'llm_api_key': apiKey,
      },
    );
    final data = resp.data as Map<String, dynamic>;
    final models = (data['models'] as List? ?? [])
        .whereType<String>()
        .toList();
    return models;
  }
}

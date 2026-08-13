// 全局应用状态
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/prefs.dart';
import '../services/server_service.dart';

class AppState extends ChangeNotifier {
  String baseUrl = '';
  String token = '';
  ServerInfo? serverInfo;
  ServerService? service;
  bool connected = false;

  /// 角色列表缓存 + 当前角色
  List<Character> characters = const [];
  Character? currentCharacter;
  int characterVersion = 0;

  /// 界面语言：true = English
  bool _isEn = false;
  bool get isEn => _isEn;

  /// 会话列表版本号：新建/切换/删除会话后 +1，聊天页据此刷新
  int convVersion = 0;
  void bumpConv() {
    convVersion++;
    notifyListeners();
  }

  Future<void> initFromPrefs() async {
    final p = await Prefs.load();
    baseUrl = p.baseUrl;
    token = p.token;
    _isEn = p.isEn;
    connected = baseUrl.isNotEmpty;
    if (connected) {
      service = ServerService(baseUrl: baseUrl, token: token);
    }
    notifyListeners();
  }

  void setLocale({required bool isEn}) {
    if (_isEn == isEn) return;
    _isEn = isEn;
    Prefs.saveLocale(isEn: isEn);
    notifyListeners();
  }

  /// 拉取角色列表并从配置读取当前角色
  Future<void> loadCharacters() async {
    final svc = service;
    if (svc == null) return;
    try {
      final chars = await svc.getCharacters();
      Character? cur;
      try {
        final config = await svc.getConfig();
        final currentId = config['current_character_id'] as String?;
        if (currentId != null && currentId.isNotEmpty) {
          for (final c in chars) {
            if (c.id == currentId) {
              cur = c;
              break;
            }
          }
        }
      } catch (_) {}
      characters = chars;
      currentCharacter = cur;
      characterVersion++;
      notifyListeners();
    } catch (_) {
      // 加载失败不阻塞聊天
    }
  }

  Future<void> selectCharacter(String id) async {
    final svc = service;
    if (svc == null) return;
    await svc.selectCharacter(id);
    await loadCharacters();
  }

  Future<void> connect({
    required String baseUrl,
    required String token,
  }) async {
    final service = ServerService(baseUrl: baseUrl, token: token);
    final info = await service.testConnection(); // 失败则抛异常
    if (info.authRequired) {
      // /api/info 豁免口令，需再调一个鉴权接口验证口令
      try {
        await service.getCharacters();
      } catch (_) {
        throw Exception('访问口令错误或无权访问');
      }
    }
    this.baseUrl = baseUrl.trim();
    this.token = token.trim();
    this.service = service;
    serverInfo = info;
    connected = true;
    await Prefs.save(baseUrl: this.baseUrl, token: this.token);
    notifyListeners();
  }

  Future<void> disconnect() async {
    await Prefs.clear();
    baseUrl = '';
    token = '';
    service = null;
    serverInfo = null;
    connected = false;
    notifyListeners();
  }
}

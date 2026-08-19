// 全局应用状态
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/offline_cache.dart';
import '../services/prefs.dart';
import '../services/server_service.dart';

/// 访问口令错误或无权访问（界面按语言提示）
class AuthException implements Exception {
  const AuthException();

  @override
  String toString() => 'AuthException';
}

class AppState extends ChangeNotifier {
  String baseUrl = '';
  String token = '';
  ServerInfo? serverInfo;
  ServerService? service;
  bool connected = false;

  /// 是否处于离线模式（连不上服务器、正在展示上次同步的缓存）。
  /// 离线时禁止一切写操作（增删改都在服务器上以服务器数据为准）。
  bool offline = false;
  bool get needsNetwork => offline;

  /// 离线时用户正在浏览的会话 id（可为空，表示浏览缓存里记录的当前会话）
  String offlineConvId = '';

  /// 离线浏览某个会话：只切换本地浏览目标，不动服务器
  Future<void> setOfflineConv(String id) async {
    offlineConvId = id;
    bumpConv();
  }

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
      setOnline();
      notifyListeners();
    } catch (_) {
      // 连不上服务器：回退到上次同步的缓存，进入离线模式
      final cached = await OfflineCache.loadCharacters();
      characters = cached.characters;
      for (final c in characters) {
        if (c.id == cached.currentId) {
          currentCharacter = c;
          break;
        }
      }
      characterVersion++;
      setOffline();
      notifyListeners();
    }
  }

  /// 标记在线/离线并通知界面（值未变化时不重复通知）
  void setOnline() {
    if (!offline) return;
    offline = false;
    notifyListeners();
  }

  void setOffline() {
    if (offline) return;
    offline = true;
    notifyListeners();
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
        throw const AuthException();
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
    await OfflineCache.clear();
    baseUrl = '';
    token = '';
    service = null;
    serverInfo = null;
    connected = false;
    offline = false;
    offlineConvId = '';
    characters = const [];
    currentCharacter = null;
    notifyListeners();
  }
}

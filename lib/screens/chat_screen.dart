// 聊天页：主界面。文字对话 + AI 回复自动流式朗读 + 汉堡抽屉
// 消息气泡/输入栏/朗读服务均已拆出到 widgets/ 与 services/
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/app_strings.dart';
import '../models/models.dart';
import '../services/offline_cache.dart';
import '../services/push_to_talk_service.dart';
import '../services/read_aloud_service.dart';
import '../services/server_service.dart';
import '../services/tts_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/avatar.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/chat_phone_bar.dart';
import '../widgets/message_bubble.dart';
import 'characters_screen.dart';
import 'phone_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _sending = false;
  TtsService? _tts;
  PushToTalkService? _ptt;
  ReadAloudService? _reader;
  int _loadedVersion = -1;
  bool _charsRequested = false;
  String _convTitle = '';

  /// 当前用户昵称/头像（来自服务器全局配置，用于气泡头部显示）
  String _userName = '';
  String _userAvatar = '';

  /// TTS 朗读开关（服务器 config.tts_read_ai）：关时 AI 回复不自动朗读
  bool _ttsEnabled = true;

  /// 知识库开关（服务器 config.rag_enabled）：开时 AI 回答参考本地知识库
  bool _ragEnabled = false;

  /// 每条消息的滚动定位键（朗读高亮自动滚动用）
  final List<GlobalKey> _msgKeys = [];

  /// 按住说话状态
  PttStatus _pttStatus = PttStatus.none;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = context.watch<AppState>();
    if (!_charsRequested && app.connected && app.service != null) {
      _charsRequested = true;
      app.loadCharacters();
      _loadConfig();
    }
    final version = app.convVersion;
    if (version != _loadedVersion) {
      _loadedVersion = version;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _tts?.dispose();
    _ptt?.dispose();
    _reader?.stop();
    super.dispose();
  }

  ServerService? get _service => context.read<AppState>().service;

  Future<void> _loadConfig() async {
    final service = _service;
    if (service == null) return;
    try {
      final config = await service.getConfig();
      if (!mounted) return;
      setState(() {
        final name = config['user_name'] as String?;
        _userName =
            (name == null || name.isEmpty) ? context.strs.userBubble : name;
        _userAvatar = (config['user_avatar'] as String?) ?? '';
        _ttsEnabled = (config['tts_read_ai'] as bool?) ?? true;
        _ragEnabled = (config['rag_enabled'] as bool?) ?? false;
      });
    } catch (_) {
      // 网络不可用：回退到缓存配置（用户名/头像/朗读开关）
      final cached = await OfflineCache.loadConfig();
      if (!mounted || cached == null) return;
      setState(() {
        final name = cached['user_name'] as String?;
        _userName =
            (name == null || name.isEmpty) ? context.strs.userBubble : name;
        _userAvatar = (cached['user_avatar'] as String?) ?? '';
        _ttsEnabled = (cached['tts_read_ai'] as bool?) ?? true;
        _ragEnabled = (cached['rag_enabled'] as bool?) ?? false;
      });
    }
  }

  Future<void> _loadHistory() async {
    final app = context.read<AppState>();
    final service = _service;
    if (service == null) return;
    String convId = '';
    if (app.offline && app.offlineConvId.isNotEmpty) {
      // 离线浏览场景：直接看缓存的指定会话
      convId = app.offlineConvId;
    } else {
      try {
        final convs = await service.getConversations();
        app.setOnline();
        convId = convs.currentId;
        if (convId.isEmpty) {
          if (mounted) {
            setState(() {
              _messages.clear();
              _convTitle = '';
              _syncMessageKeys();
            });
          }
          return;
        }
        final data = await service.getConversation(convId);
        if (!mounted) return;
        setState(() {
          _messages
            ..clear()
            ..addAll(data.messages);
          _convTitle = data.conversation.title;
          _syncMessageKeys();
        });
        _scrollToBottom();
        return;
      } catch (_) {
        // 网络不可用：标记离线，回退到缓存的当前会话消息
        app.setOffline();
        if (convId.isEmpty) {
          convId = await OfflineCache.loadCurrentConversationId();
        }
      }
    }
    final cached = await OfflineCache.loadConversation(convId);
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(cached?.messages ?? const <ChatMessage>[]);
      _convTitle = cached?.conversation.title ?? '';
      _syncMessageKeys();
    });
    if (cached != null) _scrollToBottom();
  }

  /// 按消息列表重建定位键（每次 setState 改消息内容后调用）
  void _syncMessageKeys() {
    _msgKeys
      ..clear()
      ..addAll(List.generate(_messages.length, (_) => GlobalKey()));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _scrollToMessage(int index) {
    final ctx = index < _msgKeys.length ? _msgKeys[index].currentContext : null;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      alignment: 0.15,
    );
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    final app = context.read<AppState>();
    final service = app.service;
    if (service == null) return;
    if (app.offline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strs.networkRequired)),
      );
      return;
    }
    setState(() {
      _sending = true;
      _messages.add(ChatMessage(
        role: 'user',
        content: text,
        timestamp: DateTime.now().toIso8601String(),
      ));
      _syncMessageKeys();
    });
    _input.clear();
    _scrollToBottom();
    try {
      final result = await service.sendMessage(text);
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage.assistant(result.reply, result.displayName));
        _sending = false;
        _syncMessageKeys();
      });
      _scrollToBottom();
      _speak(result.reply);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.strs.sendFailed}$e')),
      );
    }
  }

  Future<void> _speak(String text) async {
    if (!_ttsEnabled) return;
    final app = context.read<AppState>();
    if (app.service == null) return;
    _tts ??= TtsService(baseUrl: app.baseUrl, token: app.token);
    try {
      await _tts!.speak(text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.strs.readFailed}$e')),
      );
      return;
    }
    final status = _tts?.lastStatus ?? '';
    if (!mounted || status.isEmpty || !status.contains('失败')) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${context.strs.voiceDiagPrefix}$status')),
    );
  }

  Future<void> _stopSpeaking() async {
    final reader = _reader;
    if (reader != null && reader.reading) {
      await reader.stop();
      return;
    }
    await _tts?.stop();
  }

  /// 喇叭开关：切换 TTS 朗读功能（持久化到服务器 config.tts_read_ai）
  Future<void> _toggleTts() async {
    final next = !_ttsEnabled;
    setState(() => _ttsEnabled = next);
    if (!next) {
      // 关闭时立即停止正在进行的朗读
      final reader = _reader;
      if (reader != null && reader.reading) {
        await reader.stop();
      } else {
        await _tts?.stop();
      }
    }
    final service = _service;
    if (service == null) return;
    try {
      await service.updateConfig({'tts_read_ai': next});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.strs.saveReadToggleFailed}$e')),
      );
    }
  }

  /// 知识库开关：切换 config.rag_enabled（服务器端保存）
  Future<void> _toggleRag() async {
    final next = !_ragEnabled;
    setState(() => _ragEnabled = next);
    final service = _service;
    if (service == null) return;
    try {
      await service.updateConfig({'rag_enabled': next});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.strs.saveReadToggleFailed}$e')),
      );
    }
  }

  /// 从指定消息开始连续朗读到对话末尾（参考 web read-aloud.js）
  Future<void> _speakFrom(int index) async {
    final app = context.read<AppState>();
    final service = app.service;
    if (service == null) return;
    String? userVoice;
    String? aiVoice;
    try {
      final config = await service.getConfig();
      userVoice = (config['user_voice'] as String?) ?? '云扬';
      aiVoice = (config['ai_voice'] as String?) ?? '晓晓';
    } catch (_) {}
    final reader = _reader ??= ReadAloudService(
      baseUrl: app.baseUrl,
      token: app.token,
    );
    reader
      ..onIndexChanged = (i) {
        if (!mounted) return;
        setState(() {});
        _scrollToMessage(i);
      }
      ..onFinished = () {
        if (mounted) setState(() {});
      }
      ..onError = (msg) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.strs.readFailed}$msg'),
          ),
        );
      };
    // 用展开的消息列表快照参与朗读，避免朗读中被 setState 替换
    final snapshot = List<ChatMessage>.from(_messages);
    await reader.start(snapshot, index, userVoice: userVoice, aiVoice: aiVoice);
  }

  /// 组装聊天列表行：在消息之间插入时间头（网页版 shouldShowTimeHeader：
  /// 第一条显示，之后与上一条时间头间隔超过 1 分钟才显示）
  List<Object> get _rows {
    final rows = <Object>[];
    DateTime? lastHeaderTs;
    for (var i = 0; i < _messages.length; i++) {
      final ts = DateTime.tryParse(_messages[i].timestamp);
      final isEn = context.read<AppState>().isEn;
      if (ts != null &&
          (lastHeaderTs == null ||
              shouldShowTimeHeader(ts, lastHeaderTs))) {
        rows.add(TimeHeader(text: formatChatTime(ts, isEn: isEn)));
        lastHeaderTs = ts;
      }
      rows.add(i);
    }
    return rows;
  }

  /// 解析该条消息对应的 AI 角色（网页版 getAvatarHtml：按 character_id，
  /// 其次按 displayName 匹配角色名，最后回退当前选中角色）
  Character? _charForMessage(ChatMessage m) {
    final app = context.read<AppState>();
    if (m.characterId != null && m.characterId!.isNotEmpty) {
      for (final c in app.characters) {
        if (c.id == m.characterId) return c;
      }
    }
    final dn = m.displayName;
    if (dn != null && dn.isNotEmpty) {
      for (final c in app.characters) {
        if (c.name == dn || c.displayName == dn) return c;
      }
    }
    return app.currentCharacter;
  }

  String _aiNameFor(ChatMessage m) {
    if (m.role != 'assistant') return _userName;
    final c = _charForMessage(m);
    final name = c?.displayName;
    if (name != null && name.isNotEmpty) return name;
    return m.displayName ?? 'AI';
  }

  String _aiAvatarFor(ChatMessage m) {
    if (m.role != 'assistant') return '';
    return _charForMessage(m)?.aiAvatar ?? '';
  }

  /// 点击一条消息：弹出操作菜单（含「朗读」），参考 web 右键菜单
  void _onMessageTap(int index) {
    if (index < 0 || index >= _messages.length) return;
    final m = _messages[index];
    if (m.content.trim().isEmpty) return;
    final strs = context.strs;
    final reading = _reader?.reading ?? false;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(strs.readMessage),
              leading: reading
                  ? const Icon(Icons.stop_circle_outlined)
                  : const Icon(Icons.volume_up_outlined),
              onTap: () {
                Navigator.pop(sheetContext);
                _speakFrom(index);
              },
            ),
            if (reading) ...[
              const Divider(height: 1),
              ListTile(
                title: Text(strs.stopReading),
                leading: const Icon(Icons.stop),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _stopSpeaking();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 按住开始录音（麦克风按钮按下）
  Future<void> _pttStart() async {
    if (_sending) return;
    final app = context.read<AppState>();
    if (app.service == null) return;
    _ptt ??= PushToTalkService(baseUrl: app.baseUrl, token: app.token);
    try {
      if (!await _ptt!.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.strs.noMicPermission)),
          );
        }
        return;
      }
      await _ptt!.start();
      if (mounted) setState(() => _pttStatus = PttStatus.recording);
    } catch (e) {
      if (mounted) {
        setState(() => _pttStatus = PttStatus.none);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.strs.startRecordFailed}$e')),
        );
      }
    }
  }

  /// 松开结束录音并转写（麦克风按钮抬起）
  Future<void> _pttEnd() async {
    if (_pttStatus == PttStatus.none || _pttStatus == PttStatus.transcribing) {
      return;
    }
    if (mounted) setState(() => _pttStatus = PttStatus.transcribing);
    final service = _service;
    Uint8List wav;
    try {
      wav = await _ptt!.stop();
    } catch (e) {
      if (mounted) {
        setState(() => _pttStatus = PttStatus.none);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.strs.stopRecordFailed}$e')),
        );
      }
      return;
    }
    if (service == null) {
      if (mounted) setState(() => _pttStatus = PttStatus.none);
      return;
    }
    try {
      final text = await service.transcribeAudio(wav);
      if (!mounted) return;
      setState(() => _pttStatus = PttStatus.none);
      final t = text.trim();
      if (t.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strs.noSpeechDetected)),
        );
        return;
      }
      final cur = _input.text;
      _input.text = cur.isEmpty ? t : '$cur $t';
      _input.selection = TextSelection.collapsed(offset: _input.text.length);
    } catch (e) {
      if (!mounted) return;
      setState(() => _pttStatus = PttStatus.none);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.strs.voiceRecFailed}$e')),
      );
    }
  }

  /// 手指移开/手势取消：放弃本次录音
  Future<void> _pttCancel() async {
    if (_pttStatus != PttStatus.recording) return;
    try {
      await _ptt?.stop();
    } catch (_) {}
    if (mounted) setState(() => _pttStatus = PttStatus.none);
  }

  void _openCharacters() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CharactersScreen()),
    );
  }

  void _openPhone() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PhoneScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strs = context.strs;
    final app = context.watch<AppState>();
    final ttsBusy = _tts?.busy ?? false;
    final reading = _reader?.reading ?? false;
    final currentChar = app.currentCharacter;
    final title = _convTitle.isNotEmpty ? _convTitle : strs.newConversation;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _openCharacters,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: AppAvatar(
                  dataUri: currentChar?.aiAvatar,
                  name: currentChar?.displayName ?? 'AI',
                  radius: 16,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (app.offline)
            Container(
              width: double.infinity,
              color: const Color(0xFFFFF3CD),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                strs.offlineModeBanner,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
              ),
            ),
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      strs.greeting,
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    itemCount: _rows.length,
                    itemBuilder: (context, r) {
                      final row = _rows[r];
                      if (row is TimeHeader) return row;
                      final i = row as int;
                      final m = _messages[i];
                      return KeyedSubtree(
                        key: _msgKeys[i],
                        child: MessageBubble(
                          message: m,
                          userName: _userName,
                          userAvatar: _userAvatar.isEmpty ? null : _userAvatar,
                          aiName: _aiNameFor(m),
                          aiAvatar: _aiAvatarFor(m),
                          isReading: reading && i == _reader?.readingIndex,
                          onTap: () => _onMessageTap(i),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: ChatPhoneBar(
              phoneLabel: strs.phone,
              ttsEnabled: _ttsEnabled,
              stopEnabled: reading || ttsBusy,
              ragEnabled: _ragEnabled,
              onPhoneTap: _openPhone,
              onToggleTts: _toggleTts,
              onStopTap: _stopSpeaking,
              onToggleRag: _toggleRag,
            ),
          ),
          SafeArea(
            top: false,
            child: ChatInputBar(
              controller: _input,
              sending: _sending,
              pttStatus: _pttStatus,
              onSend: _send,
              onPttStart: _pttStart,
              onPttEnd: _pttEnd,
              onPttCancel: _pttCancel,
            ),
          ),
        ],
      ),
    );
  }
}
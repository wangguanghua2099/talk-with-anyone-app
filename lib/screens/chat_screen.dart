// 聊天页：主界面。文字对话 + AI 回复自动流式朗读 + 汉堡抽屉
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/app_strings.dart';
import '../models/models.dart';
import '../services/server_service.dart';
import '../services/tts_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/avatar.dart';
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
  int _loadedVersion = -1;
  bool _charsRequested = false;
  String _convTitle = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = context.watch<AppState>();
    if (!_charsRequested && app.connected && app.service != null) {
      _charsRequested = true;
      app.loadCharacters();
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
    super.dispose();
  }

  ServerService? get _service => context.read<AppState>().service;

  Future<void> _loadHistory() async {
    final service = _service;
    if (service == null) return;
    try {
      final convs = await service.getConversations();
      if (convs.currentId.isEmpty) {
        if (mounted) {
          setState(() {
            _messages.clear();
            _convTitle = '';
          });
        }
        return;
      }
      final data = await service.getConversation(convs.currentId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(data.messages);
        _convTitle = data.conversation.title;
      });
      _scrollToBottom();
    } catch (_) {
      // 加载失败不阻塞聊天
    }
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

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    final service = _service;
    if (service == null) return;
    setState(() {
      _sending = true;
      _messages.add(ChatMessage(
        role: 'user',
        content: text,
        timestamp: DateTime.now().toIso8601String(),
      ));
    });
    _input.clear();
    _scrollToBottom();
    try {
      final result = await service.sendMessage(text);
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage.assistant(result.reply, result.displayName));
        _sending = false;
      });
      _scrollToBottom();
      _speak(result.reply);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送失败：$e')),
      );
    }
  }

  Future<void> _speak(String text) async {
    final app = context.read<AppState>();
    if (app.service == null) return;
    _tts ??= TtsService(baseUrl: app.baseUrl, token: app.token);
    try {
      await _tts!.speak(text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('朗读失败：$e')),
      );
      return;
    }
    final status = _tts?.lastStatus ?? '';
    if (!mounted || status.isEmpty || !status.contains('失败')) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('语音诊断：$status')),
    );
  }

  Future<void> _stopSpeaking() async {
    await _tts?.stop();
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
          IconButton(
            tooltip: '停止朗读',
            icon: const Icon(Icons.stop_circle_outlined),
            onPressed: ttsBusy ? _stopSpeaking : null,
          ),
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
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      '和 AI 打个招呼吧',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) =>
                        _MessageBubble(message: _messages[i]),
                  ),
          ),
          SafeArea(
            top: false,
            child: _phoneBar(context, strs.phone),
          ),
          SafeArea(
            top: false,
            child: _inputBar(),
          ),
        ],
      ),
    );
  }

  Widget _phoneBar(BuildContext context, String phone) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Center(
        child: TextButton.icon(
          onPressed: _openPhone,
          icon: const Icon(Icons.phone_outlined, size: 18),
          label: Text(phone),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.primary,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }

  Widget _inputBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: '输入消息…',
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _sending ? null : _send,
            icon: _sending
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
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final name = isUser ? '我' : (message.displayName ?? 'AI');
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser ? null : Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Text(
              message.content,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: isUser ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

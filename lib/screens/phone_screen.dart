// 电话页：全双工语音通话，进入即自动连接
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/app_strings.dart';
import '../services/voice_service.dart';
import '../state/app_state.dart';
import '../theme.dart';

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  VoiceService? _voice;
  StreamSubscription<VoiceEvent>? _sub;
  final List<VoiceEvent> _log = [];
  final ScrollController _logScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _voice?.dispose();
    _logScroll.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final app = context.read<AppState>();
    if (app.service == null) return;
    _voice ??= VoiceService(baseUrl: app.baseUrl, token: app.token);
    _sub ??= _voice!.events.listen(_onEvent);
    try {
      await _voice!.start();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.strs.callStartFailed}$e')),
        );
      }
    }
  }

  void _onEvent(VoiceEvent event) {
    if (!mounted) return;
    setState(() => _log.add(event));
    // 新字幕出现后自动滚到底部，满屏时不用手动翻
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_logScroll.hasClients) return;
      _logScroll.animateTo(
        _logScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _hangUp() {
    _voice?.stop();
    Navigator.of(context).pop();
  }

  String _statusLabel(
    AppStrings strs, {
    required bool active,
    required bool connected,
    required bool heard,
  }) {
    if (!active) return '';
    if (!connected) return strs.callConnected;
    return heard ? '' : strs.pleaseSpeak;
  }

  @override
  Widget build(BuildContext context) {
    final strs = context.strs;
    final app = context.watch<AppState>();
    final charName = (app.currentCharacter?.displayName.isNotEmpty ?? false)
        ? app.currentCharacter!.displayName
        : 'AI';
    final voice = _voice;
    final statusListenable = Listenable.merge([
      if (voice != null) ...[
        voice.active,
        voice.connected,
        voice.heardUser,
        voice.speaking,
        voice.ttsPlaying,
      ],
    ]);

    return Scaffold(
      appBar: AppBar(title: Text(charName)),
      body: AnimatedBuilder(
        animation: statusListenable,
        builder: (context, _) {
          final active = voice?.active.value ?? false;
          final conn = voice?.connected.value ?? false;
          final heard = voice?.heardUser.value ?? false;
          final speaking = voice?.speaking.value ?? false;
          final ttsBusy = voice?.ttsPlaying.value ?? false;

          final Widget center;
          if (_log.isNotEmpty) {
            center = ListView.builder(
              controller: _logScroll,
              padding: const EdgeInsets.all(12),
              itemCount: _log.length,
              itemBuilder: (context, i) => _eventTile(_log[i]),
            );
          } else if (!active || !conn) {
            center = Center(
              child: Text(
                strs.callConnected,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            );
          } else {
            center = const Center(
              child: Icon(Icons.mic, size: 36, color: AppTheme.primary),
            );
          }

          return Column(
            children: [
          // 左上角状态（连接中 / 请说话）
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: conn
                        ? const Color(0xFF4CAF50)
                        : active
                            ? AppTheme.primary
                            : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _statusLabel(strs,
                      active: active, connected: conn, heard: heard),
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Expanded(child: center),
          if (speaking)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.hearing, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text(strs.listeningHint,
                      style: const TextStyle(color: AppTheme.primary, fontSize: 13)),
                ],
              ),
            ),
          if (ttsBusy)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.graphic_eq, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text(strs.aiSpeakingHint,
                      style: const TextStyle(color: AppTheme.primary, fontSize: 13)),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (kDebugMode && voice != null)
                  ValueListenableBuilder<int>(
                    valueListenable: voice.micBytesSent,
                    builder: (context, sent, _) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${strs.diagSent}${(sent / 1024).toStringAsFixed(0)}KB'
                          '${strs.diagConn}${conn ? strs.connOk : strs.connFail}'
                          '${strs.diagRec}${active ? strs.recOn : strs.recOff}',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      );
                    },
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: voice?.micMuted ?? ValueNotifier(false),
                      builder: (context, muted, _) {
                        return _roundButton(
                          onTap: active ? () => voice?.toggleMicMuted() : null,
                          icon: muted ? Icons.mic_off : Icons.mic,
                          iconColor:
                              muted ? Colors.redAccent : AppTheme.primary,
                        );
                      },
                    ),
                    const SizedBox(width: 40),
                    _roundButton(
                      onTap: _hangUp,
                      icon: Icons.call_end,
                      iconColor: Colors.redAccent,
                    ),
                  ],
                ),
              ],
            ),
          ),
          ],
        );
      },
      ),
    );
  }

  Widget _roundButton({
    required VoidCallback? onTap,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x22000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Icon(icon, size: 26, color: iconColor),
      ),
    );
  }

  Widget _eventTile(VoiceEvent event) {
    final Widget child;
    switch (event) {
      case VoiceUserText():
        child = Align(
          alignment: Alignment.centerRight,
          child: _bubble(context.strs.userBubble, event.text, isUser: true),
        );
      case VoiceAssistantText():
        child = Align(
          alignment: Alignment.centerLeft,
          child: _bubble('AI', event.text, isUser: false),
        );
      case VoiceError():
        child = Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            event.message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
          ),
        );
    }
    return child;
  }

  Widget _bubble(String name, String text, {required bool isUser}) {
    return Container(
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
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          height: 1.4,
          color: isUser ? Colors.white : AppTheme.textPrimary,
        ),
      ),
    );
  }
}

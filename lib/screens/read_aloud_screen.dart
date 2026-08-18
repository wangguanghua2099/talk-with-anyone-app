// 朗读工具箱页：朗读网页（输入网址）、朗读文本、停止朗读
// 参考网页版右侧边栏朗读工具箱操作逻辑（无文件选择）
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/app_strings.dart';
import '../services/tts_service.dart';
import '../state/app_state.dart';
import '../theme.dart';

class ReadAloudScreen extends StatefulWidget {
  const ReadAloudScreen({super.key});

  @override
  State<ReadAloudScreen> createState() => _ReadAloudScreenState();
}

class _ReadAloudScreenState extends State<ReadAloudScreen> {
  final _urlController = TextEditingController();
  final _textController = TextEditingController();
  TtsService? _tts;
  bool _readingWeb = false;
  bool _reading = false;

  @override
  void dispose() {
    _urlController.dispose();
    _textController.dispose();
    _tts?.dispose();
    super.dispose();
  }

  TtsService _getTts() {
    final app = context.read<AppState>();
    return _tts ??= TtsService(baseUrl: app.baseUrl, token: app.token);
  }

  Future<void> _readWeb() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _toast(context.strs.enterWebUrl);
      return;
    }
    final service = context.read<AppState>().service;
    if (service == null) return;
    setState(() => _readingWeb = true);
    try {
      final content = await service.fetchWebContent(url);
      if (content.trim().isEmpty) {
        if (mounted) _toast(context.strs.noWebContent);
        return;
      }
      if (!mounted) return;
      await _readTextContent(content);
    } catch (e) {
      if (mounted) _toast('${context.strs.fetchWebFailed}$e');
    } finally {
      if (mounted) setState(() => _readingWeb = false);
    }
  }

  Future<void> _readInput() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      _toast(context.strs.enterReadText);
      return;
    }
    await _readTextContent(text);
  }

  Future<void> _readTextContent(String text) async {
    if (text.isEmpty) return;
    setState(() => _reading = true);
    final tts = _getTts();
    final app = context.read<AppState>();
    String? voice;
    try {
      final config = await app.service?.getConfig();
      final v = config?['ai_voice']?.toString();
      voice = (v == null || v.isEmpty) ? null : v;
    } catch (_) {}
    try {
      await tts.speak(text, voice: voice);
    } catch (e) {
      if (mounted) _toast('${context.strs.readFailed}$e');
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _stop() async {
    await _getTts().stop();
    if (mounted) setState(() => _reading = false);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final strs = context.strs;
    return Scaffold(
      appBar: AppBar(title: Text(strs.readAloud)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _card(
            children: [
              ListTile(
                leading: const Icon(Icons.public_outlined,
                    color: AppTheme.primary),
                title: Text(strs.readWeb),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _urlController,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        hintText: strs.webUrlHint,
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _readingWeb ? null : _readWeb,
                      icon: _readingWeb
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.language),
                      label: Text(strs.readWeb),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _card(
            children: [
              ListTile(
                leading: const Icon(Icons.notes_outlined,
                    color: AppTheme.primary),
                title: Text(strs.readText),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _textController,
                      minLines: 3,
                      maxLines: 8,
                      decoration: InputDecoration(
                        hintText: strs.readTextHint,
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _reading ? null : _readInput,
                      icon: const Icon(Icons.volume_up_outlined),
                      label: Text(strs.readText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _stop,
            icon: const Icon(Icons.stop, color: Colors.redAccent),
            label: Text(strs.stopReading),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              minimumSize: const Size.fromHeight(44),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Column(children: children),
    );
  }
}
// TTS 引擎页：引擎列表 + 当前引擎高亮，点击切换；切换后加载该引擎的音色
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/app_strings.dart';
import '../state/app_state.dart';
import '../theme.dart';

class TtsEngineScreen extends StatefulWidget {
  const TtsEngineScreen({super.key});

  @override
  State<TtsEngineScreen> createState() => _TtsEngineScreenState();
}

class _TtsEngineScreenState extends State<TtsEngineScreen> {
  final List<String> _engines = [];
  String _current = '';
  String _voicesSummary = '';
  bool _loading = true;
  bool _switching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = context.read<AppState>().service;
    if (service == null) {
      if (mounted) setState(() => _error = context.strs.notConnected);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await service.getTtsEngines();
      if (!mounted) return;
      setState(() {
        _engines
          ..clear()
          ..addAll(result.engines);
        _current = result.current;
        _loading = false;
      });
      await _loadVoiceSummary();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '${context.strs.loadFailed}${context.strs.colon}$e';
      });
    }
  }

  /// 加载当前引擎的音色列表，拼接成摘要展示（参考 tts-studio.js loadVoices）
  Future<void> _loadVoiceSummary() async {
    final service = context.read<AppState>().service;
    if (service == null) return;
    try {
      final voices = await service.getTtsVoices();
      if (!mounted) return;
      setState(() {
        _voicesSummary =
            voices.isEmpty ? '' : voices.join(context.strs.voiceSep);
      });
    } catch (_) {
      if (mounted) setState(() => _voicesSummary = '');
    }
  }

  Future<void> _switch(String engine) async {
    if (engine == _current || _switching) return;
    final service = context.read<AppState>().service;
    if (service == null) return;
    setState(() => _switching = true);
    try {
      await service.switchTtsEngine(engine);
      if (!mounted) return;
      setState(() {
        _current = engine;
        _voicesSummary = '';
      });
      await _loadVoiceSummary();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.strs.switchEngineOk}$engine')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.strs.switchEngineFailed}$e')),
      );
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strs = context.strs;
    return Scaffold(
      appBar: AppBar(title: Text(strs.ttsEngine)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _load, child: Text(strs.retry)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Text(
                      '${strs.currentEnginePrefix}$_current',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_voicesSummary.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '${strs.voicesPrefix}$_voicesSummary',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ..._engines.map((engine) {
                      final isCurrent = engine == _current;
                      return Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color:
                                isCurrent ? AppTheme.primary : AppTheme.border,
                            width: isCurrent ? 1.5 : 1,
                          ),
                        ),
                        child: ListTile(
                          leading: Icon(
                            isCurrent
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: isCurrent
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                          ),
                          title: Text(
                            engine,
                            style: TextStyle(
                              fontWeight: isCurrent
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isCurrent
                                  ? AppTheme.primary
                                  : AppTheme.textPrimary,
                            ),
                          ),
                          subtitle: isCurrent
                              ? Text(
                                  strs.currentEngine,
                                  style: const TextStyle(fontSize: 12),
                                )
                              : null,
                          trailing: _switching
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : null,
                          onTap: isCurrent ? null : () => _switch(engine),
                        ),
                      );
                    }),
                  ],
                ),
    );
  }
}
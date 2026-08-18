// 自定义音色页：音色列表 + 添加（名称/参考音频/参考文本）+ 删除
// 参考网页版 custom-voice.js 的操作逻辑
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/app_strings.dart';
import '../state/app_state.dart';
import '../theme.dart';

class CustomVoiceScreen extends StatefulWidget {
  const CustomVoiceScreen({super.key});

  @override
  State<CustomVoiceScreen> createState() => _CustomVoiceScreenState();
}

class _CustomVoiceScreenState extends State<CustomVoiceScreen> {
  List<Map<String, dynamic>> _voices = [];
  bool _loading = true;
  bool _adding = false;
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
      final voices = await service.getCustomVoices();
      if (!mounted) return;
      setState(() {
        _voices = voices;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '${context.strs.loadFailed}${context.strs.colon}$e';
      });
    }
  }

  Future<void> _add() async {
    final nameController = TextEditingController();
    final refTextController = TextEditingController();
    String? fileName;
    List<int>? fileBytes;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.strs.addCustomVoiceTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: context.strs.voiceName,
                    hintText: context.strs.voiceNameHint,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final file = await FilePicker.pickFile(
                      type: FileType.audio,
                    );
                    if (file != null) {
                      final bytes = await file.readAsBytes();
                      setDialogState(() {
                        fileName = file.name;
                        fileBytes = bytes;
                      });
                    }
                  },
                  icon: const Icon(Icons.audio_file_outlined),
                  label: Text(
                    fileName == null
                        ? context.strs.selectRefAudio
                        : '${context.strs.selectedFilePrefix}$fileName',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: refTextController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: context.strs.refTextLabel,
                    hintText: context.strs.refTextHint,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.strs.cancel),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.strs.enterVoiceName)),
                  );
                  return;
                }
                if (fileBytes == null || fileName == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(context.strs.selectRefAudioRequired)),
                  );
                  return;
                }
                Navigator.pop(context);
                await _submitAdd(
                  name: name,
                  refText: refTextController.text.trim(),
                  fileName: fileName!,
                  fileBytes: fileBytes!,
                );
              },
              child: Text(context.strs.save),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    refTextController.dispose();
  }

  Future<void> _submitAdd({
    required String name,
    required String refText,
    required String fileName,
    required List<int> fileBytes,
  }) async {
    final service = context.read<AppState>().service;
    if (service == null) return;
    setState(() => _adding = true);
    try {
      await service.addCustomVoice(
        name: name,
        refText: refText,
        fileName: fileName,
        fileBytes: fileBytes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strs.customVoiceAdded)),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.strs.addVoiceFailed}$e')),
      );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _delete(String id, String name) async {
    final service = context.read<AppState>().service;
    if (service == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final strs = context.strs;
        return AlertDialog(
          title: Text(strs.deleteVoice),
          content: Text(strs.confirmDeleteVoiceMsg(name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(strs.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(strs.delete),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    try {
      await service.deleteCustomVoice(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strs.saved)),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.strs.deleteFailed}$e')),
      );
    }
  }

  String _formatTime(String iso) {
    if (iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final strs = context.strs;
    return Scaffold(
      appBar: AppBar(title: Text(strs.customVoice)),
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
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton.icon(
                        onPressed: _adding ? null : _add,
                        icon: const Icon(Icons.add),
                        label: Text(strs.addCustomVoiceTitle),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                        ),
                      ),
                    ),
                    if (_voices.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Center(
                          child: Text(
                            strs.noCustomVoices,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      )
                    else
                      ...List.generate(_voices.length, (i) {
                        final v = _voices[i];
                        final name = v['name']?.toString() ?? '';
                        final refText = v['ref_text']?.toString() ?? '';
                        final created = v['created_at']?.toString() ?? '';
                        return Card(
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppTheme.border),
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.record_voice_over,
                                color: AppTheme.primary),
                            title: Text(name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (refText.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      refText,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    _formatTime(created),
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              tooltip: strs.delete,
                              icon: const Icon(Icons.delete_outline,
                                  color: AppTheme.textSecondary),
                              onPressed: () =>
                                  _delete(v['id']?.toString() ?? '', name),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
    );
  }
}
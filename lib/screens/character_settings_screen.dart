// 角色设置页：角色名称 / 角色头像 / AI 角色设定 / 角色音色
// 编辑与新增共用；操作逻辑参考网页版右侧边栏与 character.js
// 数据存取：characters.json（PUT/POST /api/characters），AI 头像走 /api/avatar/upload target=ai
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/app_strings.dart';
import '../models/models.dart';
import '../services/image_compress.dart';
import '../state/app_state.dart';
import '../theme.dart';

class CharacterSettingsScreen extends StatefulWidget {
  const CharacterSettingsScreen({super.key, this.character});

  /// 传入已有角色则编辑；为 null 时进入新增模式
  final Character? character;

  @override
  State<CharacterSettingsScreen> createState() => _CharacterSettingsScreenState();
}

class _CharacterSettingsScreenState extends State<CharacterSettingsScreen> {
  final _nameController = TextEditingController();
  final _promptController = TextEditingController();
  String? _avatar;
  final List<String> _voices = [];
  String? _voice;
  String _engine = '';
  bool _loading = true;
  bool _saving = false;
  late final String _charId = widget.character?.id ?? '';
  late final bool _isNew = widget.character == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final app = context.read<AppState>();
    final service = app.service;
    if (service == null) {
      if (mounted) setState(() => _error = context.strs.notConnected);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final engines = await service.getTtsEngines();
      _engine = engines.current;
      final voices = await service.getTtsVoices();
      if (!mounted) return;
      final char = widget.character;
      final currentVoice = (char?.engineVoices[_engine] as String?) ??
          char?.aiVoice ??
          (voices.isNotEmpty ? voices.first : '');
      setState(() {
        _nameController.text = char?.displayName ?? '';
        _promptController.text = char?.aiPrompt ?? '';
        _avatar = (char?.aiAvatar.isNotEmpty ?? false) ? char!.aiAvatar : null;
        _voices
          ..clear()
          ..addAll(voices);
        _voice = currentVoice.isEmpty ? null : currentVoice;
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

  String? _error;

  Future<void> _pickAvatar() async {
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final dataUri = await compressImageToPngDataUri(bytes);
    if (dataUri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strs.imageProcessFailed)),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _avatar = dataUri);
  }

  Future<void> _save() async {
    final app = context.read<AppState>();
    final service = app.service;
    if (service == null) return;
    final strs = context.strs;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strs.characterNameRequired)),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final voice = _voice ?? '';
      final payload = <String, dynamic>{
        'name': name,
        'display_name': name,
        'ai_prompt': _promptController.text,
        if (voice.isNotEmpty) 'ai_voice': voice,
        if (voice.isNotEmpty && _engine.isNotEmpty)
          'engine_voices': {_engine: voice},
      };
      String charId = _charId;
      if (_isNew) {
        final created = await service.addCharacter(payload);
        charId = created.id;
      } else {
        await service.updateCharacter(charId, payload);
      }
      // 选定该角色（同步 config，也让后续 AI 头像上传落到该角色）
      await service.selectCharacter(charId);
      // 头像：编辑或新建都走 target=ai（保存到当前角色）
      if (_avatar != null && _avatar!.isNotEmpty) {
        await service.uploadAiAvatar(_avatar!);
      }
      await app.loadCharacters();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isNew ? strs.characterCreated : strs.characterSaved)),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.strs.saveFailed}$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strs = context.strs;
    final isNew = _isNew;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? strs.addCharacter : strs.characters),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(isNew ? strs.saveCharacterName : strs.save),
          ),
        ),
      ),
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
                    _card(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.badge_outlined,
                              color: AppTheme.primary),
                          title: Text(strs.characterName),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              hintText: strs.characterName,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _card(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.person_outline,
                              color: AppTheme.primary),
                          title: Text(strs.characterAvatar),
                          trailing: _AvatarPreview(
                            dataUri:
                                _avatar != null && _avatar!.isNotEmpty
                                    ? _avatar
                                    : null,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: _pickAvatar,
                              icon: const Icon(
                                Icons.photo_library_outlined,
                              ),
                              label: Text(strs.selectAvatar),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _card(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.assignment_outlined,
                              color: AppTheme.primary),
                          title: Text(strs.aiRolePrompt),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: TextField(
                            controller: _promptController,
                            minLines: 3,
                            maxLines: 8,
                            decoration: const InputDecoration(
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _card(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.record_voice_over_outlined,
                              color: AppTheme.primary),
                          title: Text(strs.characterVoice),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_engine.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    '${strs.currentEnginePrefix}$_engine',
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              if (_voices.isEmpty)
                                Text(
                                  strs.noVoices,
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13,
                                  ),
                                )
                              else
                                DropdownButtonFormField<String>(
                                  initialValue: _voice,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                  ),
                                  items: _voices
                                      .map((v) => DropdownMenuItem(
                                            value: v,
                                            child: Text(
                                              v,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _voice = v),
                                ),
                            ],
                          ),
                        ),
                      ],
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

class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview({required this.dataUri});

  final String? dataUri;

  @override
  Widget build(BuildContext context) {
    if (dataUri == null) {
      return const CircleAvatar(
        radius: 22,
        backgroundColor: AppTheme.primary,
        child: Icon(Icons.smart_toy_outlined, color: Colors.white),
      );
    }
    return ClipOval(
      child: Image.memory(
        base64Decode(dataUri!.split(',').last),
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ),
    );
  }
}
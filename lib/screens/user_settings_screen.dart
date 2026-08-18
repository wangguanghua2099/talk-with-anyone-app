// 用户设置页：用户名称 / 用户头像 / 用户角色设定 / 用户音色
// 操作逻辑参考网页版右侧边栏（保存到服务器 config），头像从手机上传
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/app_strings.dart';
import '../services/image_compress.dart';
import '../state/app_state.dart';
import '../theme.dart';

class UserSettingsScreen extends StatefulWidget {
  const UserSettingsScreen({super.key});

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
  final _nameController = TextEditingController();
  final _roleController = TextEditingController();
  String? _avatar;
  final List<String> _voices = [];
  String? _voice;
  bool _loading = true;
  bool _pickingAvatar = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    super.dispose();
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
      final config = await service.getConfig();
      final voices = await service.getTtsVoices();
      if (!mounted) return;
      setState(() {
        _nameController.text =
            config['user_name']?.toString() ?? '';
        _roleController.text =
            config['user_role_prompt']?.toString() ?? context.strs.defaultUserRole;
        _avatar = (config['user_avatar'] as String?) ?? '';
        _voices
          ..clear()
          ..addAll(voices);
        _voice = (config['user_voice'] as String?) ?? '';
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

  Future<void> _saveName() async {
    final service = context.read<AppState>().service;
    if (service == null) return;
    final val = _nameController.text.trim();
    final strs = context.strs;
    if (val.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strs.enterUserName)),
      );
      return;
    }
    try {
      await service.updateConfig({'user_name': val});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strs.userNameSaved)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.strs.saveFailed}$e')),
      );
    }
  }

  Future<void> _pickAvatar() async {
    if (_pickingAvatar) return;
    final service = context.read<AppState>().service;
    if (service == null) return;
    final strs = context.strs;
    try {
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
      setState(() => _pickingAvatar = true);
      await service.uploadUserAvatar(dataUri);
      if (!mounted) return;
      setState(() {
        _avatar = dataUri;
        _pickingAvatar = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strs.avatarUploaded)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _pickingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.strs.uploadFailed}$e')),
      );
    }
  }

  Future<void> _saveRole() async {
    final service = context.read<AppState>().service;
    if (service == null) return;
    try {
      await service.updateConfig({
        'user_role_prompt': _roleController.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strs.userRoleSaved)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.strs.saveFailed}$e')),
      );
    }
  }

  Future<void> _saveVoice() async {
    final service = context.read<AppState>().service;
    if (service == null) return;
    final val = _voice ?? '';
    if (val.isEmpty) return;
    try {
      await service.updateConfig({'user_voice': val});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strs.userVoiceSaved)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.strs.saveFailed}$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strs = context.strs;
    return Scaffold(
      appBar: AppBar(title: Text(strs.userSettings)),
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
                      context,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.badge_outlined,
                              color: AppTheme.primary),
                          title: Text(strs.userName),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                    hintText: strs.userName,
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: _saveName,
                                child: Text(strs.saveUserName),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _card(
                      context,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.person_outline,
                              color: AppTheme.primary),
                          title: Text(strs.avatar),
                          trailing: _AvatarPreview(dataUri: _avatar),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: _pickingAvatar ? null : _pickAvatar,
                              icon: _pickingAvatar
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.photo_library_outlined),
                              label: Text(strs.chooseFromDevice),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _card(
                      context,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.assignment_outlined,
                              color: AppTheme.primary),
                          title: Text(strs.userRolePrompt),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _roleController,
                                minLines: 3,
                                maxLines: 6,
                                decoration: InputDecoration(
                                  hintText: strs.defaultUserRole,
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton(
                                  onPressed: _saveRole,
                                  child: Text(strs.saveUserRole),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _card(
                      context,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.record_voice_over_outlined,
                              color: AppTheme.primary),
                          title: Text(strs.saveUserVoice),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_voices.isEmpty)
                                Text(
                                  strs.noVoices,
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13),
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
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton(
                                  onPressed: _saveVoice,
                                  child: Text(strs.saveUserVoice),
                                ),
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

  Widget _card(BuildContext context, {required List<Widget> children}) {
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
    if (dataUri == null || dataUri!.isEmpty) {
      return const CircleAvatar(
        radius: 22,
        backgroundColor: AppTheme.primary,
        child: Icon(Icons.person, color: Colors.white),
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
// 角色通讯录页：头像 + 名字的纵向列表
// 点击角色 = 选中并切换当前聊天角色；右上【查看角色】进入设置页，另有新增/删除按钮
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/app_strings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import 'character_settings_screen.dart';

class CharactersScreen extends StatelessWidget {
  const CharactersScreen({super.key});

  void _openSettings(BuildContext context, String? charId) {
    final app = context.read<AppState>();
    final char =
        charId == null ? null : app.characters.where((c) => c.id == charId).firstOrNull;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CharacterSettingsScreen(character: char),
      ),
    );
  }

  /// 点击角色：选中并切换为当前聊天角色
  Future<void> _select(BuildContext context, String id, String name) async {
    final app = context.read<AppState>();
    final strs = context.strs;
    try {
      await app.selectCharacter(id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strs.charSwitchFailed(name, e))),
      );
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strs.charSwitchOk(name))),
    );
  }

  /// 查看当前选定角色的设置页
  void _viewCurrent(BuildContext context) {
    final app = context.read<AppState>();
    final current = app.currentCharacter;
    if (current == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strs.selectCharacterFirst)),
      );
      return;
    }
    _openSettings(context, current.id);
  }

  Future<void> _deleteCurrent(BuildContext context) async {
    final app = context.read<AppState>();
    final service = app.service;
    final current = app.currentCharacter;
    if (service == null) return;
    if (current == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strs.selectCharacterFirst)),
      );
      return;
    }
    final strs = context.strs;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strs.deleteCharacterTitle(current.displayName)),
        content: Text(strs.confirmDeleteCharacter),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strs.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strs.deleteCharacter),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await service.deleteCharacter(current.id);
      await app.loadCharacters();
      final remaining = app.characters;
      if (remaining.isNotEmpty) {
        // 删除当前角色后自动切到剩余第一个
        await app.selectCharacter(remaining.first.id);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strs.characterDeleted)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.strs.deleteFailed}$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final strs = context.strs;
    final chars = app.characters;

    return Scaffold(
      appBar: AppBar(
        title: Text(strs.characters),
        actions: [
          IconButton(
            tooltip: strs.viewCharacter,
            icon: const Icon(Icons.visibility_outlined),
            onPressed: () => _viewCurrent(context),
          ),
          IconButton(
            tooltip: strs.addCharacter,
            icon: const Icon(Icons.add),
            onPressed: () => _openSettings(context, null),
          ),
          IconButton(
            tooltip: strs.deleteCharacter,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteCurrent(context),
          ),
        ],
      ),
      body: chars.isEmpty
          ? Center(
              child: Text(
                strs.noCharacters,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: chars.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, i) {
                final c = chars[i];
                final isCurrent = app.currentCharacter?.id == c.id;
                return Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isCurrent ? AppTheme.primary : AppTheme.border,
                      width: isCurrent ? 1.5 : 1,
                    ),
                  ),
                  child: ListTile(
                    leading: AppAvatar(
                      dataUri: c.aiAvatar,
                      name: c.displayName,
                      radius: 24,
                    ),
                    title: Text(
                      c.displayName,
                      style: TextStyle(
                        fontWeight:
                            isCurrent ? FontWeight.w600 : FontWeight.normal,
                        color: isCurrent ? AppTheme.primary : AppTheme.textPrimary,
                      ),
                    ),
                    subtitle: c.aiPrompt.isEmpty
                        ? null
                        : Text(
                            c.aiPrompt,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                    trailing: isCurrent
                        ? const Icon(Icons.check_circle, color: AppTheme.primary)
                        : null,
                    onTap: () => _select(context, c.id, c.displayName),
                  ),
                );
              },
            ),
    );
  }
}
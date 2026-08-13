// 角色通讯录页：头像 + 名字的纵向列表，点击切换当前聊天角色
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/app_strings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';

class CharactersScreen extends StatelessWidget {
  const CharactersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final strs = context.strs;
    final chars = app.characters;

    return Scaffold(
      appBar: AppBar(title: Text(strs.characters)),
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
                        : const Icon(
                            Icons.chevron_right,
                            color: AppTheme.textSecondary,
                          ),
                    onTap: () async {
                      if (isCurrent) {
                        Navigator.pop(context);
                        return;
                      }
                      try {
                        await app.selectCharacter(c.id);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$strs.switchedToCharacter「${c.displayName}」失败：$e')),
                          );
                        }
                        return;
                      }
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${strs.switchedToCharacter}「${c.displayName}」'),
                        ),
                      );
                      Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
    );
  }
}

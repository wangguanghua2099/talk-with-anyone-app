// 汉堡抽屉主框架。原文件拆分后这里只保留：
// Drawer 容器 + 新增会话 + 会话语义 + 底部服务器信息。
// 其余（角色/工具/设置等标签）见 drawer_menu.dart、conversations_list.dart 等。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/app_strings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'drawer/character_header.dart';
import 'drawer/conversations_list.dart';
import 'drawer/drawer_menu.dart';
import 'drawer/server_footer.dart';
import 'drawer/section_title.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final strs = context.strs;
    final cur = app.currentCharacter;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            DrawerCharacterHeader(
              avatarData: cur?.aiAvatar,
              name: cur?.displayName ?? 'AI',
              hint: strs.currentCharacter,
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline,
                        color: AppTheme.primary),
                    title: Text(
                      strs.newConversation,
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      final service = context.read<AppState>().service;
                      final app = context.read<AppState>();
                      if (service == null) return;
                      try {
                        await service.createConversation();
                        app.bumpConv();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${context.strs.createFailed}$e')),
                          );
                        }
                      }
                    },
                  ),
                  const Divider(height: 1),
                  DrawerSectionTitle(title: strs.conversations),
                  const DrawerConversations(),
                  const Divider(height: 1),
                  const DrawerMenu(),
                ],
              ),
            ),
            DrawerServerFooter(
              baseUrl: app.baseUrl,
              version: app.serverInfo?.version ?? '',
            ),
          ],
        ),
      ),
    );
  }
}
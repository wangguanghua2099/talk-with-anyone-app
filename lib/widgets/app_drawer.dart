// 汉堡抽屉：会话管理（新建/搜索/切换/重命名/删除）+ 角色入口 + 工具 + 设置
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/app_strings.dart';
import '../models/models.dart';
import '../screens/characters_screen.dart';
import '../screens/connect_screen.dart';
import '../screens/settings_screen.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'avatar.dart';

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
            _CharacterHeader(
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
                            SnackBar(content: Text('创建失败：$e')),
                          );
                        }
                      }
                    },
                  ),
                  const Divider(height: 1),
                  _SectionTitle(title: strs.conversations),
                  const _DrawerConversations(),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.people_outline,
                        color: AppTheme.primary),
                    title: Text(strs.characters),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppTheme.textSecondary),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CharactersScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _SectionTitle(title: strs.tools),
                  ListTile(
                    leading: const Icon(Icons.graphic_eq_outlined),
                    title: Text(strs.ttsStudio),
                    onTap: () => _comingSoon(context, strs.comingSoon),
                  ),
                  ListTile(
                    leading: const Icon(Icons.record_voice_over_outlined),
                    title: Text(strs.sttStudio),
                    onTap: () => _comingSoon(context, strs.comingSoon),
                  ),
                  const Divider(height: 1),
                  _SectionTitle(title: strs.settings),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: Text(strs.settings),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppTheme.textSecondary),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                ],
              ),
            ),
            _ServerFooter(
              baseUrl: app.baseUrl,
              version: app.serverInfo?.version ?? '',
            ),
          ],
        ),
      ),
    );
  }

  void _comingSoon(BuildContext context, String message) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _CharacterHeader extends StatelessWidget {
  const _CharacterHeader({
    required this.avatarData,
    required this.name,
    required this.hint,
  });

  final String? avatarData;
  final String name;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.primary,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Row(
        children: [
          AppAvatar(
            dataUri: avatarData,
            name: name,
            radius: 26,
            backgroundColor: Colors.white24,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hint,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ServerFooter extends StatelessWidget {
  const _ServerFooter({required this.baseUrl, required this.version});

  final String baseUrl;
  final String version;

  @override
  Widget build(BuildContext context) {
    final strs = context.strs;
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.dns_outlined,
                  size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$strs.server\n$baseUrl',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              Text(
                version,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await context.read<AppState>().disconnect();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const ConnectScreen()),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.link_off, size: 18),
              label: Text(strs.disconnect),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerConversations extends StatefulWidget {
  const _DrawerConversations();

  @override
  State<_DrawerConversations> createState() => _DrawerConversationsState();
}

class _DrawerConversationsState extends State<_DrawerConversations> {
  final _search = TextEditingController();
  int _loadedVersion = -1;
  Future<({List<Conversation> conversations, String currentId})>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final version = context.watch<AppState>().convVersion;
    if (version != _loadedVersion) {
      _loadedVersion = version;
      _future = _load();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<({List<Conversation> conversations, String currentId})> _load() async {
    final service = context.read<AppState>().service;
    final q = _search.text.trim();
    if (q.isEmpty) {
      if (service == null) {
        return (conversations: const <Conversation>[], currentId: '');
      }
      return service.getConversations();
    }
    if (service == null) return (conversations: const <Conversation>[], currentId: '');
    final list = await service.searchConversations(q);
    return (conversations: list, currentId: '');
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _switchTo(String id) async {
    final app = context.read<AppState>();
    final service = app.service;
    if (service == null) return;
    await service.switchConversation(id);
    app.bumpConv();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _rename(Conversation conv) async {
    final app = context.read<AppState>();
    final service = app.service;
    final controller = TextEditingController(text: conv.title);
    final strs = context.strs;
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strs.rename),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strs.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(strs.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title == null || title.isEmpty) return;
    if (service == null) return;
    await service.renameConversation(conv.id, title);
    app.bumpConv();
  }

  Future<void> _delete(Conversation conv) async {
    final app = context.read<AppState>();
    final service = app.service;
    if (service == null) return;
    await service.deleteConversation(conv.id);
    app.bumpConv();
  }

  @override
  Widget build(BuildContext context) {
    final strs = context.strs;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: TextField(
            controller: _search,
            onChanged: (_) => _reload(),
            decoration: InputDecoration(
              hintText: strs.searchConversation,
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        SizedBox(
          height: 260,
          child: FutureBuilder(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$strs.loadFailed：${snapshot.error}',
                          style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: _reload,
                        child: Text(strs.retry),
                      ),
                    ],
                  ),
                );
              }
              final data = snapshot.data!;
              final currentId = data.currentId;
              final convs = data.conversations;
              if (convs.isEmpty) {
                return const Center(
                  child: Text(
                    '暂无会话',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                );
              }
              return ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: convs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final conv = convs[i];
                  final isCurrent = conv.id == currentId;
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      isCurrent ? Icons.forum : Icons.forum_outlined,
                      size: 20,
                      color:
                          isCurrent ? AppTheme.primary : AppTheme.textSecondary,
                    ),
                    title: Text(
                      conv.title.isEmpty ? strs.untitled : conv.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('${conv.messageCount} ${strs.messageCount}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: strs.rename,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _rename(conv),
                        ),
                        IconButton(
                          tooltip: strs.delete,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () => _delete(conv),
                        ),
                      ],
                    ),
                    onTap: () => _switchTo(conv.id),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

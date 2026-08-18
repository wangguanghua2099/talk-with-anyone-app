// 抽屉会话列表：搜索 + 按月分组 + 时间显示 + 会话切换/重命名/删除。
// 分组/时间参考网页版 conversation.js：
//   按 updated_at||created_at 归月（YYYY.MM），组内保持服务器返回顺序
//   （新消息会 bump sort_order，自动置顶）；每条显示「M月D日 HH:mm」。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/app_strings.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';

class DrawerConversations extends StatefulWidget {
  const DrawerConversations({super.key});

  @override
  State<DrawerConversations> createState() => _DrawerConversationsState();
}

class _DrawerConversationsState extends State<DrawerConversations> {
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

  /// 会话时间（网页版 dateTimeFormat：M月D日 HH:mm）
  String _timeLabel(DateTime d, bool isEn) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return isEn ? '${d.month}/${d.day} $hh:$mi' : '${d.month}月${d.day}日 $hh:$mi';
  }

  /// 月份分组标题（网页版 groupByMonth 按月，这里显示为 YYYY年M月）
  String _monthLabel(DateTime d, bool isEn) {
    if (isEn) {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[d.month - 1]} ${d.year}';
    }
    return '${d.year}年${d.month}月';
  }

  /// 展平会话列表：按月份插入分组标题行。搜索时不过滤/不分组。
  List<Object> _buildRows(List<Conversation> convs, bool isEn, bool searching) {
    if (searching || convs.isEmpty) return convs.cast<Object>();
    final rows = <Object>[];
    final groups = <String, List<Conversation>>{};
    final order = <String>[];
    for (final c in convs) {
      final ts = DateTime.tryParse(
          c.updatedAt.isNotEmpty ? c.updatedAt : c.createdAt);
      if (ts == null) continue;
      final key = '${ts.year}.${ts.month.toString().padLeft(2, '0')}';
      if (!groups.containsKey(key)) {
        groups[key] = [];
        order.add(key);
      }
      groups[key]!.add(c);
    }
    for (final key in order) {
      final parts = key.split('.');
      final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
      rows.add(_monthLabel(d, isEn));
      rows.addAll(groups[key]!);
    }
    return rows;
  }

  Widget _monthHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF999999),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _convTile(Conversation conv, bool isCurrent) {
    final strs = context.strs;
    final app = context.read<AppState>();
    final isEn = app.isEn;
    final ts = DateTime.tryParse(
        conv.updatedAt.isNotEmpty ? conv.updatedAt : conv.createdAt);
    return ListTile(
      dense: true,
      leading: Icon(
        isCurrent ? Icons.forum : Icons.forum_outlined,
        size: 20,
        color: isCurrent ? AppTheme.primary : AppTheme.textSecondary,
      ),
      title: Text(
        conv.title.isEmpty ? strs.untitled : conv.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${ts == null ? '' : _timeLabel(ts, isEn)}  ·  ${conv.messageCount} ${strs.messageCount}',
      ),
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
                      Text('${strs.loadFailed}${strs.colon}${snapshot.error}',
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
                return Center(
                  child: Text(
                    strs.noConversations,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                );
              }
              final isEn = context.read<AppState>().isEn;
              final rows = _buildRows(convs, isEn, _search.text.trim().isNotEmpty);
              return ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: rows.length,
                itemBuilder: (context, r) {
                  final row = rows[r];
                  if (row is String) return _monthHeader(row);
                  final conv = row as Conversation;
                  return _convTile(conv, conv.id == currentId);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
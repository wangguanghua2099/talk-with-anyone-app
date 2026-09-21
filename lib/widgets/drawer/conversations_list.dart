// 抽屉会话列表：搜索 + 按月分组 + 时间显示 + 会话切换/重命名/删除。
// 分组/时间参考网页版 conversation.js：
//   按 updated_at||created_at 归月（YYYY.MM），组内保持服务器返回顺序
//   （新消息会 bump sort_order，自动置顶）；每条显示「M月D日 HH:mm」。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/app_strings.dart';
import '../../models/models.dart';
import '../../services/offline_cache.dart';
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
    final app = context.read<AppState>();
    final service = app.service;
    final q = _search.text.trim();
    if (service == null) {
      return (conversations: const <Conversation>[], currentId: '');
    }
    if (q.isNotEmpty) {
      // 搜索需要服务器：离线时无结果
      if (app.offline) {
        return (conversations: const <Conversation>[], currentId: '');
      }
      try {
        return (conversations: await service.searchConversations(q), currentId: '');
      } catch (_) {
        return (conversations: const <Conversation>[], currentId: '');
      }
    }
    try {
      final data = await service.getConversations();
      app.setOnline();
      return data;
    } catch (_) {
      // 断连：回退到上次同步的缓存列表（只读）
      final cached = await OfflineCache.loadConversations();
      final currentId = await OfflineCache.loadCurrentConversationId();
      app.setOffline();
      return (conversations: cached, currentId: currentId);
    }
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  void _needNetwork() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.strs.networkRequired)),
    );
  }

  Future<void> _switchTo(String id) async {
    final app = context.read<AppState>();
    final service = app.service;
    if (service == null) return;
    if (app.offline) {
      // 离线：只浏览该会话缓存的聊天记录，不切换服务器当前会话
      await app.setOfflineConv(id);
      if (mounted) Navigator.pop(context);
      return;
    }
    await service.switchConversation(id);
    app.bumpConv();
    if (mounted) Navigator.pop(context);
  }

  /// 搜索跳转（DeepSeek 式）：切换到该会话并定位到命中的消息。
  /// 消息下标由服务器 snippet_indices 给出（会话消息列表内 0-based）
  Future<void> _jumpTo(String id, int msgIndex) async {
    final app = context.read<AppState>();
    final service = app.service;
    if (service == null) return;
    if (app.offline) {
      await app.setOfflineConv(id);
      app.requestJumpToMessage(msgIndex);
      if (mounted) Navigator.pop(context);
      return;
    }
    try {
      await service.switchConversation(id);
    } catch (_) {
      _needNetwork();
      return;
    }
    app.requestJumpToMessage(msgIndex);
    if (mounted) Navigator.pop(context);
  }

  /// 关键词高亮片段：命中部分用主题色加粗（对应网页版 <mark> 高亮）
  List<InlineSpan> _highlight(String text, String keyword) {
    final spans = <InlineSpan>[];
    final kw = keyword.trim();
    if (kw.isEmpty) {
      spans.add(TextSpan(text: text));
      return spans;
    }
    final lower = text.toLowerCase();
    final kwLower = kw.toLowerCase();
    var start = 0;
    while (true) {
      final i = lower.indexOf(kwLower, start);
      if (i < 0) {
        if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (i > start) spans.add(TextSpan(text: text.substring(start, i)));
      spans.add(TextSpan(
        text: text.substring(i, i + kw.length),
        style: const TextStyle(
          color: AppTheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ));
      start = i + kw.length;
    }
    return spans;
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
    if (app.offline) {
      _needNetwork();
      return;
    }
    await service.renameConversation(conv.id, title);
    app.bumpConv();
  }

  Future<void> _delete(Conversation conv) async {
    final app = context.read<AppState>();
    final strs = context.strs;
    final title = conv.title.isEmpty ? strs.untitled : conv.title;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(strs.confirmDeleteConversation),
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
      ),
    );
    if (ok != true) return;
    if (app.offline) {
      _needNetwork();
      return;
    }
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

  Widget _convTile(Conversation conv, bool isCurrent, {bool searching = false}) {
    final strs = context.strs;
    final app = context.read<AppState>();
    final isEn = app.isEn;
    final ts = DateTime.tryParse(
        conv.updatedAt.isNotEmpty ? conv.updatedAt : conv.createdAt);
    // 搜索结果：显示该会话里第一条含关键词的消息片段（DeepSeek 式），
    // 点击直接跳到那条消息的位置
    final hasSnippet = searching && conv.snippets.isNotEmpty;
    final jumpIdx = hasSnippet && conv.snippetIndices.isNotEmpty
        ? conv.snippetIndices.first
        : -1;
    const subtitleStyle = TextStyle(
      fontSize: 12,
      color: AppTheme.textSecondary,
    );
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
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${ts == null ? '' : _timeLabel(ts, isEn)}  ·  ${conv.messageCount} ${strs.messageCount}',
          ),
          if (hasSnippet)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.subdirectory_arrow_right,
                      size: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: _highlight(conv.snippets.first, _search.text),
                        style: subtitleStyle.copyWith(fontSize: 12),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
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
      onTap: () =>
          jumpIdx >= 0 ? _jumpTo(conv.id, jumpIdx) : _switchTo(conv.id),
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
                  return _convTile(
                    conv,
                    conv.id == currentId,
                    searching: _search.text.trim().isNotEmpty,
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
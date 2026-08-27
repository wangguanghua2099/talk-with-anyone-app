// 知识库管理：库列表（激活/追加/删除）+ 新建上传/粘贴 + 检索测试 + 构建进度轮询
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/app_strings.dart';
import '../services/server_service.dart';
import '../state/app_state.dart';
import '../theme.dart';

class RagStudioScreen extends StatefulWidget {
  const RagStudioScreen({super.key});

  @override
  State<RagStudioScreen> createState() => _RagStudioScreenState();
}

class _RagStudioScreenState extends State<RagStudioScreen> {
  final _nameCtrl = TextEditingController();
  final _queryCtrl = TextEditingController();
  Timer? _poll;
  Map<String, dynamic>? _status;
  bool _loading = true;
  String _error = '';
  bool _creating = false;
  bool _searching = false;
  List<Map<String, dynamic>> _hits = [];
  String? _activeKb;

  ServerService? get _service => context.read<AppState>().service;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _nameCtrl.dispose();
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final service = _service;
    if (!mounted) return;
    if (service == null) {
      setState(() {
        _loading = false;
        _error = '未连接服务器 / not connected';
      });
      return;
    }
    try {
      // 加超时兜底：网络不通时避免永远停留在加载圈（看似空白页）
      final st = await service
          .getRagStatus()
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      final building = (st['building'] as Map<String, dynamic>?) ?? const {};
      final stage = (building['stage'] ?? '').toString();
      setState(() {
        _status = st;
        _loading = false;
        _error = '';
        _activeKb = ((st['config'] as Map<String, dynamic>?) ??
                const {})['active_kb']
            ?.toString();
      });
      // 构建未结束时每 1.5 秒轮询
      final active = stage.isNotEmpty && stage != 'done' && stage != 'error';
      if (active && _poll == null) {
        _poll = Timer.periodic(
          const Duration(milliseconds: 1500),
          (_) => _refresh(),
        );
      } else if (!active && _poll != null) {
        _poll?.cancel();
        _poll = null;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _createFromFile() async {
    final service = _service;
    if (service == null || _creating) return;
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['txt']);
    if (files.isEmpty) return;
    final f = files.single;
    final name = _nameCtrl.text.trim().isNotEmpty
        ? _nameCtrl.text.trim()
        : f.name.replaceAll(RegExp(r'\.txt$', caseSensitive: false), '');
    setState(() => _creating = true);
    try {
      final bytes = await f.readAsBytes();
      await service.createRagLibrary(
        name: name,
        fileName: f.name,
        fileBytes: bytes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strs.ragCreateOk)),
      );
      _nameCtrl.clear();
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.strs.loadFailed}$e')),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _append(String kbId) async {
    final service = _service;
    if (service == null) return;
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['txt']);
    if (files.isEmpty) return;
    final f = files.single;
    try {
      final bytes = await f.readAsBytes();
      await service.appendRagDocuments(
        kbId: kbId,
        fileName: f.name,
        fileBytes: bytes,
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.strs.loadFailed}$e')),
      );
    }
  }

  Future<void> _activate(String kbId) async {
    final service = _service;
    if (service == null) return;
    try {
      await service.activateRagLibrary(kbId);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.strs.loadFailed}$e')),
      );
    }
  }

  Future<void> _delete(String kbId) async {
    final strs = context.strs;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        content: Text(strs.ragConfirmDelete),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, false),
            child: Text(strs.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dlgCtx, true),
            child: Text(strs.ragDeleteLib),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final service = _service;
    if (service == null) return;
    try {
      await service.deleteRagLibrary(kbId);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.strs.deleteFailed}$e')),
      );
    }
  }

  Future<void> _search() async {
    final q = _queryCtrl.text.trim();
    final service = _service;
    if (q.isEmpty || service == null || _searching) return;
    setState(() => _searching = true);
    try {
      final hits = await service.ragQuery(q, kbId: _activeKb);
      if (!mounted) return;
      setState(() {
        _hits = hits;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hits = [];
        _searching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.strs.loadFailed}$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strs = context.strs;
    return Scaffold(
      appBar: AppBar(title: Text(strs.ragManager)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          '${strs.loadFailed}$_error',
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () {
                          setState(() => _loading = true);
                          _refresh();
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(strs.retry),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      _buildStatusCard(strs),
                      const SizedBox(height: 12),
                      _buildCreateCard(strs),
                      const SizedBox(height: 12),
                      _buildSearchCard(strs),
                      const SizedBox(height: 12),
                      _buildLibList(strs),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatusCard(AppStrings strs) {
    final emb = ((_status?['embedder'] as Map<String, dynamic>?) ??
        const {});
    final healthy = emb['healthy'] == true;
    final model = ((emb['model'] ?? '') as String)
        .replaceAll(RegExp(r'^.*[\\/]'), '');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                healthy ? Icons.dns : Icons.dns_outlined,
                size: 16,
                color: healthy ? Colors.green : Colors.redAccent,
              ),
              const SizedBox(width: 6),
              Text('${strs.ragEmbedService}: ${healthy ? strs.ragRunning : strs.ragOffline}',
                  style: const TextStyle(fontSize: 13)),
            ],
          ),
          if (model.isNotEmpty)
            Text('${strs.ragModel}: $model',
                style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildCreateCard(AppStrings strs) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strs.ragCreateKb,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                hintText: strs.ragNameHint,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _creating ? null : _createFromFile,
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: Text(strs.ragPickTxt),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _creating ? null : () => _pasteDialog(),
                    icon: const Icon(Icons.content_paste, size: 18),
                    label: Text(strs.ragPasteCreate),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 粘贴文本创建（对话框内持有 controller，pop 前取值）
  Future<void> _pasteDialog() async {
    final service = _service;
    if (service == null || _creating) return;
    final textCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text(context.strs.ragPasteCreate),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: textCtrl,
            autofocus: true,
            maxLines: 12,
            decoration:
                InputDecoration(hintText: context.strs.ragPasteHint),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, false),
            child: Text(context.strs.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dlgCtx, true),
            child: Text(context.strs.save),
          ),
        ],
      ),
    );
    final text = textCtrl.text.trim();
    textCtrl.dispose();
    if (ok != true || text.isEmpty) return;
    final name = _nameCtrl.text.trim().isNotEmpty
        ? _nameCtrl.text.trim()
        : '粘贴_${DateTime.now().millisecondsSinceEpoch}';
    setState(() => _creating = true);
    try {
      await service.createRagLibrary(
        name: name,
        fileName: '$name.txt',
        fileBytes: text.codeUnits,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strs.ragCreateOk)),
      );
      _nameCtrl.clear();
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.strs.loadFailed}$e')),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Widget _buildSearchCard(AppStrings strs) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strs.ragSearchTest,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryCtrl,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: strs.ragQueryHint,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _searching ? null : _search,
                  icon: _searching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.search),
                ),
              ],
            ),
            if (_hits.isNotEmpty)
              ..._hits.map((h) {
                final meta =
                    ((h['meta'] as Map<String, dynamic>?) ??
                        const {});
                final score = (h['score'] as num?) ?? 0.0;
                final text = (h['text'] ?? '').toString();
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${strs.ragScore}: ${score.toStringAsFixed(4)}'
                        '  ${strs.ragChapter}: ${meta['chapter'] ?? '-'}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(text,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary)),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildLibList(AppStrings strs) {
    final libs = ((_status?['libraries'] ?? const []) as List)
        .cast<Map<String, dynamic>>();
    final building = ((_status?['building'] as Map<String, dynamic>?) ??
        const {});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${strs.ragLibList} (${libs.length})',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (libs.isEmpty)
          Text(strs.ragEmptyList,
              style: const TextStyle(color: AppTheme.textSecondary)),
        ...libs.map((lib) {
          final kbId = (lib['kb_id'] ?? '').toString();
          final name = (lib['name'] ?? '').toString();
          final chunks = lib['chunk_count'] as int? ?? 0;
          final dim = lib['dim'] as int?;
          final isActive = kbId == _activeKb;
          final isBuilding = building['kb_id'] == kbId &&
              building['stage'] != 'done' &&
              building['stage'] != 'error';
          final buildFailed = building['kb_id'] == kbId &&
              building['stage'] == 'error';

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: isActive ? AppTheme.primary : AppTheme.border,
                width: isActive ? 1.5 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                      ),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            strs.ragActiveTag,
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.primary),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$chunks ${strs.ragChunkUnit}'
                    ' · ${strs.ragDim}: ${dim?.toString() ?? "-"}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  if (isBuilding) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${strs.ragBuilding} ${building['done'] ?? 0}/${building['total'] ?? '?'}',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.primary),
                        ),
                      ],
                    ),
                  ],
                  if (buildFailed) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${strs.ragBuildFailed}: ${building['error'] ?? ''}',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.redAccent),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!isActive)
                        TextButton(
                          onPressed: () => _activate(kbId),
                          child: Text(strs.ragSetActive),
                        ),
                      TextButton(
                        onPressed: () => _append(kbId),
                        child: Text(strs.ragAppend),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent),
                        onPressed: () => _delete(kbId),
                        child: Text(strs.ragDeleteLib),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

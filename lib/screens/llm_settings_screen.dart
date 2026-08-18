// LLM 设置页：后端 + API 地址 + Key + 模型，操作逻辑对齐网页版 config 边栏
// （app.js saveLLMConfig / applyLLMProfile / onLLMBackendChange / loadLLMModels）：
//   - local 后端隐藏 Key 与模型行；切后端时按 llm_profiles 自动回填专属配置
//   - 保存时除顶层 llm_backend/llm_url/llm_api_key/llm_model 外，
//     同时把该后端一行另存进 llm_profiles，便于来回切换后端免重复填写
//   - 「刷新模型列表」POST /api/llm/models 拿服务商模型填充下拉
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/app_strings.dart';
import '../services/server_service.dart';
import '../state/app_state.dart';
import '../theme.dart';

class LlmSettingsScreen extends StatefulWidget {
  const LlmSettingsScreen({super.key});

  @override
  State<LlmSettingsScreen> createState() => _LlmSettingsScreenState();
}

class _LlmSettingsScreenState extends State<LlmSettingsScreen> {
  String _backend = 'local';
  final _url = TextEditingController();
  final _apiKey = TextEditingController();
  String? _model;
  List<String> _models = const [];
  bool _loaded = false;
  bool _loadingModels = false;
  bool _saving = false;
  bool _showKey = false;

  static const _localBackend = 'local';

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _url.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  ServerService? get _service => context.read<AppState>().service;

  Future<void> _loadConfig() async {
    final service = _service;
    if (service == null) return;
    try {
      final c = await service.getConfig();
      if (!mounted) return;
      final profiles = (c['llm_profiles'] as Map?)?.cast<String, dynamic>() ?? {};
      final backend = (c['llm_backend'] as String?) ?? _localBackend;
      final custom = profiles[backend] as Map<String, dynamic>?;
      // 与该后端专属配置、或顶层配置本属于该后端时才回填（网页版 applyLLMProfile）
      final useTop =
          (custom == null || (custom['url'] as String? ?? '').isEmpty) &&
              (c['llm_backend'] as String? ?? _localBackend) == backend;
      setState(() {
        _backend = backend;
        _url.text = useTop
            ? (c['llm_url'] as String? ?? '').trim()
            : (custom?['url'] as String? ?? '');
        _apiKey.text = useTop
            ? (c['llm_api_key'] as String? ?? '')
            : (custom?['api_key'] as String? ?? '');
        _model = useTop
            ? (c['llm_model'] as String?)
            : (custom?['model'] as String?);
        _loaded = true;
      });
      if (backend != _localBackend) _loadModels();
    } catch (_) {}
  }

  void _onBackendChanged(String? value) {
    if (value == null) return;
    setState(() {
      _backend = value;
      _model = null;
      _models = const [];
    });
    _applyProfile(value);
    if (value != _localBackend) _loadModels();
  }

  /// 切换后端：从 llm_profiles 回填该后端的地址/Key/模型（网页版 applyLLMProfile）
  Future<void> _applyProfile(String backend) async {
    final service = _service;
    if (service == null) return;
    try {
      final c = await service.getConfig();
      if (!mounted) return;
      final profiles =
          (c['llm_profiles'] as Map?)?.cast<String, dynamic>() ?? {};
      final custom = profiles[backend] as Map<String, dynamic>?;
      final useTop =
          (custom == null || (custom['url'] as String? ?? '').isEmpty) &&
              (c['llm_backend'] as String? ?? _localBackend) == backend;
      setState(() {
        _url.text = useTop
            ? (c['llm_url'] as String? ?? '').trim()
            : (custom?['url'] as String? ?? '');
        _apiKey.text = useTop
            ? (c['llm_api_key'] as String? ?? '')
            : (custom?['api_key'] as String? ?? '');
        _model = useTop
            ? (c['llm_model'] as String?)
            : (custom?['model'] as String?);
      });
    } catch (_) {}
  }

  Future<void> _loadModels() async {
    final service = _service;
    if (service == null) return;
    final url = _url.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strs.apiUrlRequired)),
      );
      return;
    }
    setState(() => _loadingModels = true);
    try {
      final models = await service.getLlmModels(
        backend: _backend,
        url: url,
        apiKey: _apiKey.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _models = models;
        _loadingModels = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingModels = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.strs.llmModelsFailed}$e')),
      );
    }
  }

  Future<void> _save() async {
    final service = _service;
    if (service == null) return;
    final strs = context.strs;
    setState(() => _saving = true);
    try {
      final c = await service.getConfig();
      Map<String, dynamic> profiles =
          (c['llm_profiles'] as Map?)?.cast<String, dynamic>() ?? {};
      profiles = Map<String, dynamic>.from(profiles);
      profiles[_backend] = {
        'url': _url.text.trim(),
        'api_key': _apiKey.text.trim(),
        'model': _model ?? '',
      };
      await service.updateConfig({
        'llm_backend': _backend,
        'llm_url': _url.text.trim(),
        'llm_api_key': _apiKey.text.trim(),
        'llm_model': _model ?? '',
        'llm_profiles': profiles,
      });
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strs.llmSaved)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${strs.llmSaveFailed}$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strs = context.strs;
    final isLocal = _backend == _localBackend;
    return Scaffold(
      appBar: AppBar(title: Text(strs.llmSettings)),
      body: _loaded
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _label(context, strs.llmBackend),
                // 后端选择
                DropdownButtonFormField<String>(
                  initialValue: _backend,
                  isDense: true,
                  items: [
                    DropdownMenuItem(
                      value: 'local',
                      child: Text(strs.backendLocal),
                    ),
                    const DropdownMenuItem(
                      value: 'ollama',
                      child: Text('Ollama'),
                    ),
                    DropdownMenuItem(
                      value: 'openai',
                      child: Text(strs.backendOpenai),
                    ),
                  ],
                  onChanged: _onBackendChanged,
                ),
                const SizedBox(height: 16),
                _label(context, strs.apiUrl),
                TextField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    hintText: 'http://localhost:8082',
                  ),
                ),
                if (!isLocal) ...[
                  const SizedBox(height: 16),
                  _label(context, strs.apiKeyMasked),
                  TextField(
                    controller: _apiKey,
                    obscureText: !_showKey,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      hintText: 'sk-...',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showKey
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _showKey = !_showKey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _label(context, strs.model),
                  DropdownButtonFormField<String>(
                    initialValue: _models.contains(_model) ? _model : null,
                    isDense: true,
                    hint: Text(
                      _models.isEmpty ? strs.selectModel : '',
                    ),
                    items: _models
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(m),
                            ))
                        .toList(),
                    onChanged: _models.isEmpty
                        ? null
                        : (v) => setState(() => _model = v),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _loadingModels ? null : _loadModels,
                    icon: _loadingModels
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: Text(strs.refreshModels),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(strs.saveLLM),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _label(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}
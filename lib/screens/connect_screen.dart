// 连接设置页：输入服务器地址 + 访问口令，测试连接
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/app_strings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'chat_screen.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _testing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _urlController.text = app.baseUrl;
    _tokenController.text = app.token;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = context.strs.urlRequiredError);
      return;
    }
    setState(() {
      _testing = true;
      _error = null;
    });
    try {
      await context.read<AppState>().connect(
            baseUrl: url,
            token: _tokenController.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ChatScreen()),
      );
    } catch (e) {
      String msg;
      if (e is AuthException) {
        msg = context.strs.authFailed;
      } else {
        msg = '${context.strs.connectFailed}$e';
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strs = context.strs;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.record_voice_over, size: 72, color: AppTheme.primary),
                  const SizedBox(height: 12),
                  const Text(
                    'Talk With Anyone',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    strs.connectSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _urlController,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: strs.serverUrlLabel,
                      hintText: 'https://192.168.1.100:7862',
                      prefixIcon: const Icon(Icons.dns_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _tokenController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: strs.accessTokenLabel,
                      hintText: strs.accessTokenHint,
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _testing ? null : _test,
                    child: _testing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(strs.connectAndTest),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 设置页：LLM 设置（进入 llm_settings_screen）+ 语言切换
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/app_strings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'llm_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strs = context.strs;
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(strs.settings)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _group(
            context,
            [
              _navItem(context, Icons.smart_toy_outlined, strs.llmSettings,
                  const LlmSettingsScreen()),
            ],
          ),
          _group(
            context,
            [
              ListTile(
                leading: const Icon(Icons.language, color: AppTheme.primary),
                title: Text(strs.language),
                trailing: DropdownButton<String>(
                  value: app.isEn ? 'en' : 'zh',
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'zh', child: Text('简体中文')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    app.setLocale(isEn: v == 'en');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _group(BuildContext context, List<Widget> tiles) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            tiles[i],
          ],
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, IconData icon, String title, Widget page) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primary),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => page),
        );
      },
    );
  }
}
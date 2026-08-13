// 设置页（占位）：右侧边栏各功能项的入口，功能下期实现
import 'package:flutter/material.dart';

import '../i18n/app_strings.dart';
import '../theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strs = context.strs;
    return Scaffold(
      appBar: AppBar(title: Text(strs.settings)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _group(context, [
            _item(context, Icons.smart_toy_outlined, strs.llmSettings),
            _item(context, Icons.record_voice_over_outlined, strs.ttsEngine),
          ]),
          _group(context, [
            _item(context, Icons.person_outline, strs.userSettings),
            _item(context, Icons.volume_up_outlined, strs.readAloud),
          ]),
          _group(context, [
            _item(context, Icons.lock_outline, strs.accessToken),
            _item(context, Icons.language, strs.language),
            _item(context, Icons.bug_report_outlined, strs.debugLogs),
          ]),
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
      child: Column(children: tiles),
    );
  }

  Widget _item(BuildContext context, IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primary),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
      onTap: () {
        final strs = context.strs;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「$title」${strs.comingSoon}')),
        );
      },
    );
  }
}

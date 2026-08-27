// 抽屉功能标签区：角色 / 用户设置 / TTS 引擎 / 自定义音色 + 工具 + 设置
// 后续新增标签入口都在这里加，避免 app_drawer.dart 继续膨胀
import 'package:flutter/material.dart';

import '../../i18n/app_strings.dart';
import '../../screens/characters_screen.dart';
import '../../screens/custom_voice_screen.dart';
import '../../screens/rag_studio_screen.dart';
import '../../screens/read_aloud_screen.dart';
import '../../screens/settings_screen.dart';
import '../../screens/stt_studio_screen.dart';
import '../../screens/tts_engine_screen.dart';
import '../../screens/tts_studio_screen.dart';
import '../../screens/user_settings_screen.dart';
import '../../theme.dart';
import 'section_title.dart';

class DrawerMenu extends StatelessWidget {
  const DrawerMenu({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strs = context.strs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.people_outline, color: AppTheme.primary),
          title: Text(strs.characters),
          trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          onTap: () => _open(context, const CharactersScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.person_outline, color: AppTheme.primary),
          title: Text(strs.userSettings),
          trailing: const Icon(
            Icons.chevron_right,
            color: AppTheme.textSecondary,
          ),
          onTap: () => _open(context, const UserSettingsScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.record_voice_over_outlined,
              color: AppTheme.primary),
          title: Text(strs.ttsEngine),
          onTap: () => _open(context, const TtsEngineScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.palette_outlined, color: AppTheme.primary),
          title: Text(strs.customVoice),
          onTap: () => _open(context, const CustomVoiceScreen()),
        ),
        const Divider(height: 1),
        DrawerSectionTitle(title: strs.tools),
        ListTile(
          leading: const Icon(Icons.graphic_eq_outlined),
          title: Text(strs.ttsStudio),
          onTap: () => _open(context, const TtsStudioScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.record_voice_over_outlined),
          title: Text(strs.sttStudio),
          onTap: () => _open(context, const SttStudioScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.auto_stories_outlined),
          title: Text(strs.ragManager),
          onTap: () => _open(context, const RagStudioScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.volume_up_outlined),
          title: Text(strs.readAloud),
          onTap: () => _open(context, const ReadAloudScreen()),
        ),
        const Divider(height: 1),
        DrawerSectionTitle(title: strs.settings),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: Text(strs.settings),
          trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          onTap: () => _open(context, const SettingsScreen()),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
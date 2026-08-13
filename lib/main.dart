// 入口
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'state/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppState();
  await appState.initFromPrefs();
  runApp(
    ChangeNotifierProvider(
      create: (_) => appState,
      child: const TalkWithAnyoneApp(),
    ),
  );
}

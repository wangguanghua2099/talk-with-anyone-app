// App 根组件
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/chat_screen.dart';
import 'screens/connect_screen.dart';
import 'state/app_state.dart';
import 'theme.dart';

class TalkWithAnyoneApp extends StatelessWidget {
  const TalkWithAnyoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Talk With Anyone',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Consumer<AppState>(
        builder: (context, app, _) {
          return app.connected ? const ChatScreen() : const ConnectScreen();
        },
      ),
    );
  }
}

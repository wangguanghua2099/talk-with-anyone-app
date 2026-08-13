// 冒烟测试：连接页能正常渲染
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:talk_with_anyone_app/screens/connect_screen.dart';
import 'package:talk_with_anyone_app/state/app_state.dart';

void main() {
  testWidgets('连接页渲染', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const MaterialApp(home: ConnectScreen()),
      ),
    );
    expect(find.text('Talk With Anyone'), findsOneWidget);
    expect(find.text('连接并测试'), findsOneWidget);
  });
}

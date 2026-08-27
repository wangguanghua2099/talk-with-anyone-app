// 知识库管理页渲染回归测试：用服务器真实返回的 /api/rag/status 数据
// 验证 RagStudioScreen 能正常渲染（复现手机端"空白页"是否为渲染崩溃）
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:talk_with_anyone_app/screens/rag_studio_screen.dart';
import 'package:talk_with_anyone_app/services/server_service.dart';
import 'package:talk_with_anyone_app/state/app_state.dart';

const _realStatusJson = r'''
{"config":{"enabled":false,"active_kb":"kb_1787589952563_317585","top_k":4,"embed_url":"http://127.0.0.1:8089","embed_model":""},"libraries":[{"kb_id":"kb_1787514528696_918a19","name":"红楼梦nano768","chunk_count":4,"dim":768,"embedder":{"backend":"openai","model":"v5-nano-retrieval-Q8_0.gguf","dim":768},"files":["test_novel.txt"],"created_at":1787514528,"updated_at":1787514529},{"kb_id":"kb_1787566489888_3dd625","name":"红楼梦nano512","chunk_count":4,"dim":512,"embedder":{"backend":"openai","model":"v5-nano-retrieval-Q8_0.gguf","dim":512},"files":["test_novel.txt"],"created_at":1787566489,"updated_at":1787566490},{"kb_id":"kb_1787588559498_bf0657","name":"荷塘月色","chunk_count":30,"dim":512,"embedder":{"backend":"openai","model":"v5-nano-retrieval-Q8_0.gguf","dim":512},"files":["红楼梦癸酉本后28回摘要.txt","荷塘月色.txt"],"created_at":1787588559,"updated_at":1787600257},{"kb_id":"kb_1787589952563_317585","name":"红楼梦癸酉本108回","chunk_count":2727,"dim":512,"embedder":{"backend":"openai","model":"v5-nano-retrieval-Q8_0.gguf","dim":512},"files":["红楼梦癸酉本108回.txt","红楼梦癸酉本后28回摘要.txt"],"created_at":1787589952,"updated_at":1787599721},{"kb_id":"kb_1787601341413_6f31df","name":"红楼梦癸酉本后28回概要","chunk_count":25,"dim":512,"embedder":{"backend":"openai","model":"v5-nano-retrieval-Q8_0.gguf","dim":512},"files":["红楼梦癸酉本后28回概要.txt"],"created_at":1787601341,"updated_at":1787601343}],"building":null,"load_errors":{},"embedder":{"backend":"openai","model":"v5-nano-retrieval-Q8_0.gguf","url":"http://127.0.0.1:8089","healthy":true,"dim":null,"truncate_dim":512}}
''';

/// 只重写 getRagStatus，返回真实抓包数据；不发任何网络请求
class _FakeRagService extends ServerService {
  _FakeRagService() : super(baseUrl: 'https://fake.local', token: '');

  @override
  Future<Map<String, dynamic>> getRagStatus() async =>
      jsonDecode(_realStatusJson) as Map<String, dynamic>;
}

void main() {
  testWidgets('真实 /api/rag/status 数据渲染知识库页不崩溃', (tester) async {
    final state = AppState()..service = _FakeRagService();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: RagStudioScreen()),
      ),
    );
    // initState 触发 _refresh（异步），泵两帧让 future 完成并重建
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 页面应显示库列表与各分区，而不是空白/报错
    expect(find.textContaining('知识库列表'), findsOneWidget);
    expect(find.text('红楼梦癸酉本108回'), findsOneWidget);
    expect(find.textContaining('嵌入服务'), findsOneWidget);
  });
}

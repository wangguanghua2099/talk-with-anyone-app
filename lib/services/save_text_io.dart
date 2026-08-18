// 原生保存实现：
// - Android：通过平台通道写入公共 Downloads 目录（API 29+ 用 MediaStore 无需权限；
//   API ≤ 28 需 WRITE_EXTERNAL_STORAGE 运行时权限，MainActivity 会申请）。
// - 其他平台（iOS/桌面）：回退到应用文档目录。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

const _channel = MethodChannel('com.talkwithanyone/save');

Future<String> saveTextBytes(
  String text, {
  required String baseName,
}) async {
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final fileName = '${baseName}_$stamp.txt';
  if (Platform.isAndroid) {
    try {
      final bytes = Uint8List.fromList(utf8.encode(text));
      final saved = await _channel.invokeMethod<String>('saveFile', {
        'fileName': fileName,
        'mimeType': 'text/plain',
        'bytes': bytes,
      });
      if (saved != null && saved.isNotEmpty) return saved;
    } on PlatformException {
      // 保存失败（含权限被拒）：回退到应用文档目录
    } on MissingPluginException {
      // 非 Android 原生环境：回退
    }
  }
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(text, flush: true);
  return file.path;
}

// Web 保存实现：浏览器无本地文件系统
import 'dart:typed_data';

Future<String> saveAudioBytes(
  Uint8List bytes, {
  required String baseName,
}) async {
  throw UnsupportedError('Web 平台不支持保存到本地');
}
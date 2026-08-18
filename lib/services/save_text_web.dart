// Web 保存实现：浏览器无本地文件系统

// 与 save_audio_web 保持一致的签名（text 传进来但 web 不支持本地保存）
Future<String> saveTextBytes(
  String text, {
  required String baseName,
}) async {
  throw UnsupportedError('Web 平台不支持保存到本地');
}
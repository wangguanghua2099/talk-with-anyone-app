// Web 平台实现：浏览器负责证书校验（用户已信任证书），无需忽略
import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Dio createDio({required String baseUrl, required String token}) {
  return Dio(
    BaseOptions(
      baseUrl: _normalize(baseUrl),
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: token.trim().isEmpty ? null : {'Authorization': 'Bearer ${token.trim()}'},
    ),
  );
}

WebSocketChannel connectWs(Uri uri) {
  return WebSocketChannel.connect(uri);
}

String _normalize(String baseUrl) {
  var s = baseUrl.trim();
  if (s.isEmpty) return s;
  if (!s.startsWith('http://') && !s.startsWith('https://')) {
    s = 'https://$s';
  }
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

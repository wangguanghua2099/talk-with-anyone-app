// 原生平台（Android/iOS/桌面）实现：自签名证书一律信任
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Dio createDio({required String baseUrl, required String token}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: _normalize(baseUrl),
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: token.trim().isEmpty ? null : {'Authorization': 'Bearer ${token.trim()}'},
    ),
  );
  dio.httpClientAdapter = _TrustAllAdapter();
  return dio;
}

WebSocketChannel connectWs(Uri uri) {
  final client = HttpClient();
  client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  return IOWebSocketChannel.connect(uri, customClient: client);
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

/// 信任所有自签名证书（仅限局域网自用；若日后暴露公网请改为证书锁定）
class _TrustAllAdapter extends IOHttpClientAdapter {
  _TrustAllAdapter()
      : super(
          createHttpClient: () {
            final client = HttpClient();
            client.badCertificateCallback =
                (X509Certificate cert, String host, int port) => true;
            return client;
          },
        );
}

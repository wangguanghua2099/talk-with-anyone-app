// HTTP 客户端：统一处理 baseUrl、访问口令、局域网自签名证书
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ApiClient {
  /// 创建针对某台服务器的 Dio 实例。
  /// - 自签名证书一律信任（局域网自用场景）
  /// - access_token 非空时自动附加 Authorization 头
  static Dio create({required String baseUrl, required String token}) {
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

  /// 提取 baseUrl 前的 host，用于拼接 WebSocket 地址（同一主机）。
  static Uri webSocketUri(String baseUrl, String path, {String token = ''}) {
    final u = Uri.parse(_normalize(baseUrl));
    final scheme = u.scheme == 'https' ? 'wss' : 'ws';
    var uri = Uri(scheme: scheme, host: u.host, port: u.hasPort ? u.port : (u.scheme == 'https' ? 443 : 80), path: path);
    if (token.trim().isNotEmpty) {
      uri = uri.replace(queryParameters: {'token': token.trim()});
    }
    return uri;
  }

  /// 建立 WebSocket 连接（wss 到局域网自签名证书服务器，需忽略证书校验）
  static WebSocketChannel connectWs(Uri uri) {
    final client = HttpClient();
    client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    return IOWebSocketChannel.connect(uri, customClient: client);
  }

  /// 拼接带 token 与查询参数的 HTTP(S) URL（用于 TTS 流式等 GET 端点）。
  /// token 通过查询参数传递，因为播放器/流式请求无法自定义 Authorization 头。
  static Uri streamUri(
    String baseUrl,
    String path, {
    Map<String, String>? query,
    String token = '',
  }) {
    final u = Uri.parse(_normalize(baseUrl));
    var uri = Uri(
      scheme: u.scheme,
      host: u.host,
      port: u.hasPort ? u.port : (u.scheme == 'https' ? 443 : 80),
      path: path,
    );
    final params = <String, String>{...?query};
    if (token.trim().isNotEmpty) {
      params['token'] = token.trim();
    }
    if (params.isNotEmpty) {
      uri = uri.replace(queryParameters: params);
    }
    return uri;
  }

  /// 下载二进制（用于 TTS 非流式回退：GET /api/tts/download）
  static Future<Uint8List> downloadBytes({
    required String baseUrl,
    required String token,
    required String url,
  }) async {
    final dio = create(baseUrl: baseUrl, token: token);
    final resp = await dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(resp.data ?? const []);
  }

  static String _normalize(String baseUrl) {
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

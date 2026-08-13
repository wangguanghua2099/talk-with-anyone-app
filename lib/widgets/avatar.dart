// 角色/用户头像：支持服务器返回的 base64 data URI，失败时回退到首字符圆
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.dataUri,
    required this.name,
    this.radius = 20,
    this.backgroundColor,
  });

  final String? dataUri;
  final String name;
  final double radius;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final image = _decode();
    if (image != null) {
      return ClipOval(
        child: Image.memory(
          image,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }
    final letter = name.isNotEmpty ? name[0] : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? AppTheme.primary,
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Uint8List? _decode() {
    final uri = dataUri;
    if (uri == null || uri.isEmpty) return null;
    final idx = uri.indexOf(',');
    if (idx < 0) return null;
    try {
      return base64Decode(uri.substring(idx + 1));
    } catch (_) {
      return null;
    }
  }
}

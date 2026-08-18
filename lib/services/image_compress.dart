// 图片压缩：将任意格式图片压缩为边长不超过 400 的 PNG data URI
// 供头像上传使用（避免 config/character 内 base64 过大）
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart'
    show Canvas, FilterQuality, Paint, Rect;

Future<String?> compressImageToPngDataUri(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    const maxSide = 400.0;
    final scale = img.width >= img.height
        ? (maxSide / img.width)
        : (maxSide / img.height);
    final w = (img.width * scale).round().clamp(1, 400);
    final h = (img.height * scale).round().clamp(1, 400);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..filterQuality = FilterQuality.high;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      paint,
    );
    final picture = recorder.endRecording();
    final out = await picture.toImage(w, h);
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    out.dispose();
    codec.dispose();
    if (data == null) return null;
    return 'data:image/png;base64,${base64Encode(data.buffer.asUint8List())}';
  } catch (_) {
    return null;
  }
}
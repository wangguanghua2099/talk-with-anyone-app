// 打字机文本组件（对应 web 端 typewriter.js）：
// 流式增量进入 ValueListenable 缓冲区，按固定节奏逐字揭示：
// 基准 100 字/秒；积压过多时按"总时长不超过 maxDuration"自动加速；
// 点击文本立即显示全部（跳过后后续流式内容直接全量显示）。
// done=true 且全部放完后回调 onFinished（父级可换成最终静态文本）。
// 不显示打字光标（对齐豆包等主流 App 的流式输出样式）。
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class TypewriterText extends StatefulWidget {
  const TypewriterText({
    super.key,
    required this.buffer,
    this.done = false,
    this.style,
    this.cps = 100,
    this.maxDuration = const Duration(seconds: 3),
    this.onProgress,
    this.onFinished,
  });

  /// 已接收的全部文字（增量由父级累加进该 ValueListenable）
  final ValueListenable<String> buffer;

  /// 流是否已结束（completed/error/打断收尾）；放完剩余缓冲后回调 onFinished
  final bool done;

  final TextStyle? style;
  final int cps;
  final Duration maxDuration;
  final VoidCallback? onProgress;
  final VoidCallback? onFinished;

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  static const _tickMs = 40;

  Timer? _timer;
  String _buf = '';
  int _shown = 0;
  bool _skipped = false;
  bool _finished = false;
  late int _ticksPerCap;

  @override
  void initState() {
    super.initState();
    _buf = widget.buffer.value;
    widget.buffer.addListener(_onBufferChanged);
    _ticksPerCap = (widget.maxDuration.inMilliseconds / _tickMs).ceil();
    _maybeAnimate();
  }

  @override
  void didUpdateWidget(covariant TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.buffer, widget.buffer)) {
      oldWidget.buffer.removeListener(_onBufferChanged);
      widget.buffer.addListener(_onBufferChanged);
      _buf = widget.buffer.value;
      _maybeAnimate();
    }
    if (!oldWidget.done && widget.done) {
      _maybeAnimate();
    }
  }

  void _onBufferChanged() {
    _buf = widget.buffer.value;
    _maybeAnimate();
  }

  void _maybeAnimate() {
    if (_finished) return;
    if (_skipped) {
      // 跳过模式：后续流式内容直接全量显示
      _shown = _buf.length;
      _refresh(finished: widget.done);
      return;
    }
    if (_buf.isEmpty) return;
    _start();
    setState(() {});
  }

  void _start() {
    _timer ??= Timer.periodic(
        const Duration(milliseconds: _tickMs), (_) => _tick());
  }

  void _tick() {
    final backlog = _buf.length - _shown;
    if (backlog <= 0) {
      if (widget.done) _cleanup();
      return;
    }
    // 基准步长与"总时长上限"步长取大者
    final base = (widget.cps * _tickMs / 1000).ceil();
    final cap = (backlog / _ticksPerCap).ceil();
    _shown = (_buf.length).clamp(_shown, _shown + (base > cap ? base : cap));
    // 避免把 emoji 等代理对从中间切开（下一拍会自然补齐）
    if (_shown < _buf.length) {
      final last = _buf.codeUnitAt(_shown - 1);
      if (last >= 0xD800 && last <= 0xDBFF) _shown++;
    }
    setState(() {});
    widget.onProgress?.call();
    if (widget.done && _shown >= _buf.length) _cleanup();
  }

  /// 点击立即显示全部
  void _skip() {
    if (_finished) return;
    _skipped = true;
    _shown = _buf.length;
    _timer?.cancel();
    _timer = null;
    _refresh(finished: widget.done);
  }

  void _cleanup() {
    _shown = _buf.length;
    _timer?.cancel();
    _timer = null;
    _refresh(finished: true);
  }

  void _refresh({required bool finished}) {
    setState(() {});
    if (finished && !_finished) {
      _finished = true;
      widget.onFinished?.call();
    }
    widget.onProgress?.call();
  }

  @override
  void dispose() {
    widget.buffer.removeListener(_onBufferChanged);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _shown >= _buf.length
        ? _buf
        : _buf.substring(0, _shown);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _skipped || _finished ? null : _skip,
      child: Text(text, style: widget.style),
    );
  }
}

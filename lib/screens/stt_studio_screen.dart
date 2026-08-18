// 语音转文本页：参考网页版 stt-studio.js 的界面与逻辑
// 界面：圆形麦克风开关 + 状态文字 + 波形动画 + 识别文本区(带字数)
//       + 保存txt / 复制 / 清空 / 上传音频
// 录音：SttListenService 持续把 PCM16 发给 /ws/voice(mode=transcribe)，
//       服务器 VAD 说一句识别一句，逐句追加到文本区。
// 上传：file_picker 选音频 → /api/stt/transcribe → 追加文本。
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../i18n/app_strings.dart';
import '../services/save_text_io.dart'
    if (dart.library.js_interop) '../services/save_text_web.dart' as txt_saver;
import '../services/stt_listen_service.dart';
import '../state/app_state.dart';
import '../theme.dart';

class SttStudioScreen extends StatefulWidget {
  const SttStudioScreen({super.key});

  @override
  State<SttStudioScreen> createState() => _SttStudioScreenState();
}

class _SttStudioScreenState extends State<SttStudioScreen>
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();

  SttListenService? _svc;
  bool _listening = false;
  bool _uploading = false;
  String _status = '';

  late final AnimationController _waveAnim;
  bool _recordingWave = false;

  @override
  void initState() {
    super.initState();
    _waveAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    final app = context.read<AppState>();
    if (app.service != null) {
      _svc = SttListenService(baseUrl: app.baseUrl, token: app.token);
      _svc!.onText.listen((t) {
        if (!mounted) return;
        _appendText(t);
      });
      _svc!.onStatus.listen((s) {
        if (mounted) setState(() => _status = s);
      });
    }
  }

  @override
  void dispose() {
    _waveAnim.dispose();
    _textController.dispose();
    _svc?.dispose();
    super.dispose();
  }

  void _appendText(String text) {
    setState(() {
      final cur = _textController.text.trim();
      _textController.text = cur.isEmpty ? text : '$cur\n$text';
      _textController.selection =
          TextSelection.collapsed(offset: _textController.text.length);
    });
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _svc?.stop();
      if (mounted) {
        setState(() {
          _listening = false;
          _recordingWave = false;
          _status = context.strs.micOff;
        });
      }
      _waveAnim.stop();
      return;
    }
    try {
      await _svc?.start();
      if (!mounted) return;
      setState(() {
        _listening = true;
        _recordingWave = true;
      });
      _waveAnim.repeat();
    } catch (e) {
      if (!mounted) return;
      setState(() => _listening = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.strs.micStartFailed}$e')),
      );
    }
  }

  Future<void> _uploadAudio() async {
    final service = context.read<AppState>().service;
    if (service == null) return;
    final files = await FilePicker.pickFiles(
      type: FileType.any,
    );
    if (files.isEmpty) return;
    final f = files.single;
    setState(() => _uploading = true);
    try {
      final bytes = await f.readAsBytes();
      final text = await service.transcribeAudio(bytes);
      if (!mounted) return;
      if (text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strs.noSpeechDetected)),
        );
        return;
      }
      _appendText(text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strs.transcribeDone)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.strs.transcribeFailed}$e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _saveTxt() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strs.noTextToSave)),
      );
      return;
    }
    try {
      final path = await txt_saver.saveTextBytes(text, baseName: 'stt');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.strs.savedPathPrefix}$path')),
      );
    } on UnsupportedError {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strs.webSaveUnsupported)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.strs.saveFailed}$e')),
        );
      }
    }
  }

  Future<void> _copy() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strs.noTextToCopy)),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.strs.copied)),
    );
  }

  void _clear() {
    setState(() => _textController.clear());
  }

  @override
  Widget build(BuildContext context) {
    final strs = context.strs;
    return Scaffold(
      appBar: AppBar(title: Text(strs.sttStudio)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 麦克风控制
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _micButton(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _status.isEmpty ? strs.sttDefaultStatus : _status,
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    if (_recordingWave) _Waveform(anim: _waveAnim),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 识别文本区
          TextField(
            controller: _textController,
            maxLines: 10,
            minLines: 6,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: strs.sttRecognitionHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_textController.text.length} ${strs.charCount}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 12),
          // 操作按钮
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _saveTxt,
                icon: const Icon(Icons.save_alt, size: 18),
                label: Text(strs.saveTxt),
              ),
              OutlinedButton.icon(
                onPressed: _copy,
                icon: const Icon(Icons.copy, size: 18),
                label: Text(strs.copy),
              ),
              OutlinedButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: Text(strs.clear),
              ),
              OutlinedButton.icon(
                onPressed: _uploading ? null : _uploadAudio,
                icon: _uploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.folder_open, size: 18),
                label: Text(strs.uploadAudio),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            strs.sttTimeHint,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _micButton() {
    return GestureDetector(
      onTap: _toggleMic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: _listening ? Colors.redAccent : AppTheme.primary,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Icon(
          _listening ? Icons.mic : Icons.mic_none,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }
}

/// 网页版 sttWave 的简易波形动画：一排上下跳动的竖条
class _Waveform extends StatelessWidget {
  const _Waveform({required this.anim});

  final Animation<double> anim;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        final t = anim.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) {
            const base = 6.0;
            final h = base +
                (sin(t * 2 * pi + i * 0.9) + 1) * 6;
            return Container(
              width: 4,
              height: h,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
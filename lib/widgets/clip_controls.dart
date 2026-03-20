import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:bilibili_audio_clipper/providers/audio_provider.dart';
import 'package:bilibili_audio_clipper/providers/bilibili_provider.dart';
import 'package:bilibili_audio_clipper/providers/netease_provider.dart';

class ClipControls extends StatefulWidget {
  const ClipControls({super.key});

  @override
  State<ClipControls> createState() => _ClipControlsState();
}

class _ClipControlsState extends State<ClipControls> {
  late TextEditingController _startMinCtrl;
  late TextEditingController _startSecCtrl;
  late TextEditingController _endMinCtrl;
  late TextEditingController _endSecCtrl;
  final _fileNameCtrl = TextEditingController();

  bool _syncFromProvider = false;

  @override
  void initState() {
    super.initState();
    _startMinCtrl = TextEditingController(text: '0');
    _startSecCtrl = TextEditingController(text: '00');
    _endMinCtrl = TextEditingController(text: '0');
    _endSecCtrl = TextEditingController(text: '00');
  }

  @override
  void dispose() {
    _startMinCtrl.dispose();
    _startSecCtrl.dispose();
    _endMinCtrl.dispose();
    _endSecCtrl.dispose();
    _fileNameCtrl.dispose();
    super.dispose();
  }

  void _syncControllersFromProvider(AudioProvider provider) {
    _syncFromProvider = true;
    _startMinCtrl.text = provider.startMinutes.toString();
    _startSecCtrl.text = provider.startSeconds.toString().padLeft(2, '0');
    _endMinCtrl.text = provider.endMinutes.toString();
    _endSecCtrl.text = provider.endSeconds.toString().padLeft(2, '0');
    _syncFromProvider = false;
  }

  Widget _buildTimeField(TextEditingController ctrl, String hint) {
    return SizedBox(
      width: 52,
      child: CupertinoTextField(
        controller: ctrl,
        placeholder: hint,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildMarkButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE5F1FF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF007AFF),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Future<void> _saveToLocal(
    BuildContext context,
    AudioProvider audioProvider,
    BilibiliProvider bilibiliProvider,
  ) async {
    final srcPath = audioProvider.trimmedFilePath;
    if (srcPath == null) return;

    try {
      final title = bilibiliProvider.videoInfo?.title ?? 'audio';
      final safeName = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

      // 通过 MethodChannel 调用原生 MediaStore API 保存到 Downloads
      const channel = MethodChannel('com.biliaudioclipper/file_saver');
      await channel.invokeMethod('saveToDownloads', {
        'srcPath': srcPath,
        'fileName': '$safeName.m4a',
        'mimeType': 'audio/mp4',
      });

      if (context.mounted) {
        showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('保存成功'),
            content: Text('文件已保存到下载目录：\n$safeName.m4a'),
            actions: [
              CupertinoDialogAction(
                child: const Text('好'),
                onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('保存失败'),
            content: Text(e.toString()),
            actions: [
              CupertinoDialogAction(
                child: const Text('好'),
                onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<AudioProvider, BilibiliProvider, NeteaseProvider>(
      builder: (context, audioProvider, bilibiliProvider, neteaseProvider, _) {
        if (audioProvider.totalDuration == null) return const SizedBox.shrink();

        // When provider values change (e.g. from markStart/markEnd), sync controllers
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_syncFromProvider) {
            final newStartMin = audioProvider.startMinutes.toString();
            final newStartSec = audioProvider.startSeconds.toString().padLeft(2, '0');
            final newEndMin = audioProvider.endMinutes.toString();
            final newEndSec = audioProvider.endSeconds.toString().padLeft(2, '0');
            if (_startMinCtrl.text != newStartMin) _startMinCtrl.text = newStartMin;
            if (_startSecCtrl.text != newStartSec) _startSecCtrl.text = newStartSec;
            if (_endMinCtrl.text != newEndMin) _endMinCtrl.text = newEndMin;
            if (_endSecCtrl.text != newEndSec) _endSecCtrl.text = newEndSec;
          }
        });

        final isTrimming = audioProvider.trimState == TrimState.trimming;
        final audioPath = bilibiliProvider.audioFilePath;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '裁剪区间',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              // Start row
              Row(
                children: [
                  const SizedBox(
                    width: 36,
                    child: Text('开始', style: TextStyle(fontSize: 14, color: CupertinoColors.systemGrey)),
                  ),
                  _buildTimeField(_startMinCtrl, '分'),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(':', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  _buildTimeField(_startSecCtrl, '秒'),
                  const SizedBox(width: 12),
                  _buildMarkButton('标记起点', () {
                    audioProvider.markStart();
                    _syncControllersFromProvider(audioProvider);
                  }),
                ],
              ),
              const SizedBox(height: 10),

              // End row
              Row(
                children: [
                  const SizedBox(
                    width: 36,
                    child: Text('结束', style: TextStyle(fontSize: 14, color: CupertinoColors.systemGrey)),
                  ),
                  _buildTimeField(_endMinCtrl, '分'),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(':', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  _buildTimeField(_endSecCtrl, '秒'),
                  const SizedBox(width: 12),
                  _buildMarkButton('标记终点', () {
                    audioProvider.markEnd();
                    _syncControllersFromProvider(audioProvider);
                  }),
                ],
              ),
              const SizedBox(height: 16),

              // Trim button
              CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 12),
                borderRadius: BorderRadius.circular(10),
                color: CupertinoColors.white,
                onPressed: isTrimming || audioPath == null
                    ? null
                    : () {
                        // Sync manual input to provider before trimming
                        final startMin = int.tryParse(_startMinCtrl.text) ?? 0;
                        final startSec = int.tryParse(_startSecCtrl.text) ?? 0;
                        final endMin = int.tryParse(_endMinCtrl.text) ?? 0;
                        final endSec = int.tryParse(_endSecCtrl.text) ?? 0;
                        audioProvider.setStartTime(startMin, startSec);
                        audioProvider.setEndTime(endMin, endSec);
                        audioProvider.trimAudio(audioPath);
                      },
                child: isTrimming
                    ? const CupertinoActivityIndicator()
                    : Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF007AFF)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        child: const Text(
                          '裁剪',
                          style: TextStyle(color: Color(0xFF007AFF), fontSize: 15),
                        ),
                      ),
              ),

              // Trim error
              if (audioProvider.trimState == TrimState.error && audioProvider.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  audioProvider.errorMessage!,
                  style: const TextStyle(color: CupertinoColors.destructiveRed, fontSize: 13),
                ),
              ],

              // Trim success
              if (audioProvider.trimState == TrimState.done) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(CupertinoIcons.checkmark_circle_fill,
                        color: Color(0xFF34C759), size: 16),
                    const SizedBox(width: 6),
                    const Text('裁剪完成', style: TextStyle(color: Color(0xFF34C759), fontSize: 13)),
                    const Spacer(),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 0,
                      onPressed: () => _saveToLocal(context, audioProvider, bilibiliProvider),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.arrow_down_doc_fill,
                              color: Color(0xFF007AFF), size: 15),
                          SizedBox(width: 4),
                          Text('保存到本地',
                              style: TextStyle(color: Color(0xFF007AFF), fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // File name input
                Row(
                  children: [
                    Expanded(
                      child: CupertinoTextField(
                        controller: _fileNameCtrl,
                        placeholder: '输入文件名',
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        onChanged: (val) => neteaseProvider.setFileName(val),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '.m4a',
                      style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.systemGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (bilibiliProvider.videoInfo != null) ...[
                      const SizedBox(width: 6),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minSize: 0,
                        onPressed: () {
                          _fileNameCtrl.text = bilibiliProvider.videoInfo!.title;
                          neteaseProvider.setFileName(bilibiliProvider.videoInfo!.title);
                        },
                        child: const Icon(
                          CupertinoIcons.doc_on_clipboard,
                          color: Color(0xFF007AFF),
                          size: 18,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:bilibili_audio_clipper/providers/audio_provider.dart';
import 'package:bilibili_audio_clipper/providers/bilibili_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    return Consumer2<AudioProvider, BilibiliProvider>(
      builder: (context, audioProvider, bilibiliProvider, _) {
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
                const Row(
                  children: [
                    Icon(CupertinoIcons.checkmark_circle_fill,
                        color: Color(0xFF34C759), size: 16),
                    SizedBox(width: 6),
                    Text('裁剪完成', style: TextStyle(color: Color(0xFF34C759), fontSize: 13)),
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

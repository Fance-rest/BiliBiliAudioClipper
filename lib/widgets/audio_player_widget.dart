import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:bilibili_audio_clipper/providers/audio_provider.dart';

class AudioPlayerWidget extends StatelessWidget {
  const AudioPlayerWidget({super.key});

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, provider, _) {
        if (provider.totalDuration == null) return const SizedBox.shrink();

        final total = provider.totalDuration!;
        final current = provider.currentPosition;
        final progress = total.inMilliseconds > 0
            ? (current.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;

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
                '音频播放',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              // Seek / progress bar
              GestureDetector(
                onHorizontalDragUpdate: (details) {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  final width = box.size.width - 32; // subtract padding
                  final fraction = (details.localPosition.dx / width).clamp(0.0, 1.0);
                  final newPos = Duration(
                    milliseconds: (fraction * total.inMilliseconds).round(),
                  );
                  provider.seek(newPos);
                },
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicatorWidget(value: progress),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(current),
                          style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
                        ),
                        Text(
                          _formatDuration(total),
                          style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Play/pause button
              Center(
                child: GestureDetector(
                  onTap: () {
                    if (provider.isPlaying) {
                      provider.pause();
                    } else {
                      provider.play();
                    }
                  },
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Color(0xFF007AFF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      provider.isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                      color: CupertinoColors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A simple progress bar implemented using Cupertino-compatible primitives.
class LinearProgressIndicatorWidget extends StatelessWidget {
  final double value;
  const LinearProgressIndicatorWidget({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Stack(
          children: [
            Container(height: 4, width: width, color: const Color(0xFFE5E5EA)),
            Container(
              height: 4,
              width: width * value,
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        );
      },
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show LinearProgressIndicator, AlwaysStoppedAnimation;
import 'package:provider/provider.dart';
import 'package:bilibili_audio_clipper/providers/bilibili_provider.dart';

class LinkInput extends StatefulWidget {
  const LinkInput({super.key});

  @override
  State<LinkInput> createState() => _LinkInputState();
}

class _LinkInputState extends State<LinkInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BilibiliProvider>(
      builder: (context, provider, _) {
        final isLoading = provider.parseState == ParseState.loading;
        final isDownloading = provider.downloadState == DownloadState.downloading;

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
              // Input row
              Row(
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      controller: _controller,
                      placeholder: '粘贴B站链接或BV号',
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: const Color(0xFF007AFF),
                    borderRadius: BorderRadius.circular(8),
                    onPressed: isLoading
                        ? null
                        : () {
                            final text = _controller.text.trim();
                            if (text.isNotEmpty) {
                              provider.parseLink(text);
                            }
                          },
                    child: isLoading
                        ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                        : const Text(
                            '解析',
                            style: TextStyle(color: CupertinoColors.white, fontSize: 15),
                          ),
                  ),
                ],
              ),

              // Error message
              if (provider.parseState == ParseState.error && provider.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  provider.errorMessage!,
                  style: const TextStyle(color: CupertinoColors.destructiveRed, fontSize: 13),
                ),
              ],

              // Video info card
              if (provider.parseState == ParseState.success && provider.videoInfo != null) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        provider.videoInfo!.coverUrl,
                        width: 100,
                        height: 75,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 100,
                          height: 75,
                          color: const Color(0xFFE5E5EA),
                          child: const Icon(CupertinoIcons.photo, color: CupertinoColors.systemGrey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            provider.videoInfo!.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '时长：${_formatDuration(provider.videoInfo!.duration)}',
                            style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Download button
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: const Color(0xFF007AFF),
                  borderRadius: BorderRadius.circular(10),
                  onPressed: (isDownloading || provider.downloadState == DownloadState.done)
                      ? null
                      : () => provider.downloadAudio(),
                  child: provider.downloadState == DownloadState.done
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.checkmark_circle_fill,
                                color: CupertinoColors.white, size: 18),
                            SizedBox(width: 6),
                            Text('已下载', style: TextStyle(color: CupertinoColors.white)),
                          ],
                        )
                      : isDownloading
                          ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                          : const Text('下载音频', style: TextStyle(color: CupertinoColors.white)),
                ),

                // Download progress bar
                if (isDownloading) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: provider.downloadProgress,
                    backgroundColor: const Color(0xFFE5E5EA),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(provider.downloadProgress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
                    textAlign: TextAlign.right,
                  ),
                ],

                // Download error
                if (provider.downloadState == DownloadState.error && provider.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    provider.errorMessage!,
                    style: const TextStyle(color: CupertinoColors.destructiveRed, fontSize: 13),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

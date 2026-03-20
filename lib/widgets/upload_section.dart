import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show LinearProgressIndicator, AlwaysStoppedAnimation;
import 'package:provider/provider.dart';
import 'package:bilibili_audio_clipper/providers/bilibili_provider.dart';
import 'package:bilibili_audio_clipper/providers/audio_provider.dart';
import 'package:bilibili_audio_clipper/providers/netease_provider.dart';

class UploadSection extends StatefulWidget {
  const UploadSection({super.key});

  @override
  State<UploadSection> createState() => _UploadSectionState();
}

class _UploadSectionState extends State<UploadSection> {
  bool _dialogShown = false;

  void _showUploadSuccessDialog(
    BuildContext context,
    NeteaseProvider neteaseProvider,
    String? filePath,
  ) {
    if (_dialogShown) return;
    _dialogShown = true;

    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('上传成功'),
        content: const Text('文件已上传至网易云盘，是否保留本地文件？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              neteaseProvider.resetUpload();
              _dialogShown = false;
            },
            child: const Text('保留本地文件'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              if (filePath != null) {
                neteaseProvider.deleteLocalFile(filePath);
              }
              neteaseProvider.resetUpload();
              _dialogShown = false;
            },
            child: const Text('删除本地文件'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<BilibiliProvider, AudioProvider, NeteaseProvider>(
      builder: (context, bilibiliProvider, audioProvider, neteaseProvider, _) {
        // Only show when download is done
        if (bilibiliProvider.downloadState != DownloadState.done) {
          return const SizedBox.shrink();
        }

        // Determine which file to upload: trimmed takes priority
        final filePath = audioProvider.trimState == TrimState.done
            ? audioProvider.trimmedFilePath
            : bilibiliProvider.audioFilePath;

        // Show success dialog after build
        if (neteaseProvider.uploadState == UploadState.done) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showUploadSuccessDialog(context, neteaseProvider, filePath);
          });
        } else {
          _dialogShown = false;
        }

        final isUploading = neteaseProvider.uploadState == UploadState.uploading;

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
                '上传到网易云盘',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              // Upload button
              CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 14),
                color: const Color(0xFF34C759),
                borderRadius: BorderRadius.circular(10),
                onPressed: isUploading || filePath == null || !neteaseProvider.isLoggedIn
                    ? null
                    : () {
                        _dialogShown = false;
                        neteaseProvider.upload(filePath);
                      },
                child: isUploading
                    ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.cloud_upload_fill,
                              color: CupertinoColors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            '上传到网易云盘',
                            style: TextStyle(color: CupertinoColors.white, fontSize: 15),
                          ),
                        ],
                      ),
              ),

              // Upload progress bar
              if (isUploading) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: neteaseProvider.uploadProgress,
                  backgroundColor: const Color(0xFFE5E5EA),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34C759)),
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(neteaseProvider.uploadProgress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
                  textAlign: TextAlign.right,
                ),
              ],

              // Not logged in warning
              if (!neteaseProvider.isLoggedIn) ...[
                const SizedBox(height: 8),
                const Text(
                  '请先在设置中登录网易云账号',
                  style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
                  textAlign: TextAlign.center,
                ),
              ],

              // Upload error
              if (neteaseProvider.uploadState == UploadState.error &&
                  neteaseProvider.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  neteaseProvider.errorMessage!,
                  style: const TextStyle(color: CupertinoColors.destructiveRed, fontSize: 13),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

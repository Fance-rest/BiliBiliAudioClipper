import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:bilibili_audio_clipper/providers/bilibili_provider.dart';
import 'package:bilibili_audio_clipper/providers/audio_provider.dart';
import 'package:bilibili_audio_clipper/widgets/link_input.dart';
import 'package:bilibili_audio_clipper/widgets/audio_player_widget.dart';
import 'package:bilibili_audio_clipper/widgets/clip_controls.dart';
import 'package:bilibili_audio_clipper/widgets/upload_section.dart';
import 'package:bilibili_audio_clipper/pages/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _lastLoadedPath;

  @override
  Widget build(BuildContext context) {
    return Consumer2<BilibiliProvider, AudioProvider>(
      builder: (context, bilibiliProvider, audioProvider, _) {
        // Auto-load audio when download completes
        final audioPath = bilibiliProvider.audioFilePath;
        if (bilibiliProvider.downloadState == DownloadState.done &&
            audioPath != null &&
            audioPath != _lastLoadedPath) {
          _lastLoadedPath = audioPath;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            audioProvider.loadAudio(audioPath);
          });
        }

        return CupertinoPageScaffold(
          backgroundColor: const Color(0xFFF2F2F7),
          navigationBar: CupertinoNavigationBar(
            backgroundColor: const Color(0xFFF2F2F7),
            border: null,
            leading: const SizedBox.shrink(),
            middle: const Text(
              '音频提取',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => const SettingsPage()),
                );
              },
              child: const Icon(CupertinoIcons.settings, size: 24),
            ),
          ),
          child: const SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(top: 8, bottom: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinkInput(),
                  AudioPlayerWidget(),
                  ClipControls(),
                  UploadSection(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

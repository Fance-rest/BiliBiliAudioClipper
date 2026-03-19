import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:bilibili_audio_clipper/services/bilibili_service.dart';
import 'package:bilibili_audio_clipper/services/audio_service.dart';
import 'package:bilibili_audio_clipper/services/netease_service.dart';
import 'package:bilibili_audio_clipper/providers/bilibili_provider.dart';
import 'package:bilibili_audio_clipper/providers/audio_provider.dart';
import 'package:bilibili_audio_clipper/providers/netease_provider.dart';
import 'package:bilibili_audio_clipper/pages/home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final bilibiliService = BilibiliService();
    final audioService = AudioService();
    final neteaseService = NeteaseService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BilibiliProvider(bilibiliService)..restoreSession()),
        ChangeNotifierProvider(create: (_) => AudioProvider(audioService)),
        ChangeNotifierProvider(create: (_) => NeteaseProvider(neteaseService)..loadSettings()),
      ],
      child: const CupertinoApp(
        title: '音频提取',
        theme: CupertinoThemeData(primaryColor: Color(0xFF007AFF), scaffoldBackgroundColor: Color(0xFFF2F2F7)),
        home: HomePage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

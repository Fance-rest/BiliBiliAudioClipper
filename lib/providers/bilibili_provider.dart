import 'dart:convert';
import 'dart:io';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bilibili_audio_clipper/models/video_info.dart';
import 'package:bilibili_audio_clipper/services/bilibili_service.dart';

enum ParseState { idle, loading, success, error }
enum DownloadState { idle, downloading, done, error }

class BilibiliProvider extends ChangeNotifier {
  final BilibiliService _service;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const _cookiesKey = 'bilibili_cookies';

  ParseState parseState = ParseState.idle;
  DownloadState downloadState = DownloadState.idle;
  VideoInfo? videoInfo;
  String? audioFilePath;
  String? errorMessage;
  double downloadProgress = 0;
  bool isLoggedIn = false;

  BilibiliProvider(this._service);

  Future<void> restoreSession() async {
    final saved = await _secureStorage.read(key: _cookiesKey);
    if (saved != null) {
      final decoded = jsonDecode(saved) as Map<String, dynamic>;
      final cookies = decoded.map((k, v) => MapEntry(k, v as String));
      await _applyCookies(cookies);
      isLoggedIn = true;
      try { await _service.refreshWbiKeys(); } catch (_) {}
      notifyListeners();
    }
  }

  /// Converts a simple string map into [Cookie] objects and injects them.
  Future<void> _applyCookies(Map<String, String> cookies) async {
    final bilibiliCookies = cookies.entries
        .map((e) => Cookie(e.key, e.value))
        .toList();
    if (bilibiliCookies.isNotEmpty) {
      await _service.setCookies('bilibili.com', bilibiliCookies);
    }
  }

  Future<void> _saveCookies(Map<String, String> cookies) async {
    await _secureStorage.write(key: _cookiesKey, value: jsonEncode(cookies));
  }

  Future<void> _clearCookies() async {
    await _secureStorage.delete(key: _cookiesKey);
  }

  Future<void> parseLink(String input) async {
    parseState = ParseState.loading;
    errorMessage = null;
    videoInfo = null;
    notifyListeners();
    try {
      String resolvedInput = input;
      if (BilibiliService.isShortLink(input)) {
        resolvedInput = await _service.resolveShortLink(input);
      }
      final idResult = BilibiliService.extractVideoId(resolvedInput);
      await _service.fetchBuvid();
      videoInfo = await _service.fetchVideoInfo(
        bvid: idResult.bvid,
        avid: idResult.avid,
      );
      parseState = ParseState.success;
    } catch (e) {
      parseState = ParseState.error;
      errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> downloadAudio() async {
    if (videoInfo == null) return;
    downloadState = DownloadState.downloading;
    downloadProgress = 0;
    errorMessage = null;
    notifyListeners();
    try {
      final audioUrl = await _service.fetchAudioStreamUrl(
        bvid: videoInfo!.bvid,
        cid: videoInfo!.cid,
      );
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/${videoInfo!.bvid}.m4a';
      await _service.downloadAudio(
        audioUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) { downloadProgress = received / total; notifyListeners(); }
        },
      );
      audioFilePath = savePath;
      downloadState = DownloadState.done;
    } catch (e) {
      downloadState = DownloadState.error;
      errorMessage = e.toString();
    }
    notifyListeners();
  }

  String? qrCodeUrl;
  String? _qrcodeKey;
  String qrLoginStatus = '';

  Future<void> startQrLogin() async {
    final result = await _service.generateQrCode();
    qrCodeUrl = result['url'];
    _qrcodeKey = result['qrcode_key'];
    qrLoginStatus = '等待扫码...';
    notifyListeners();
    _pollQrLogin();
  }

  Future<void> _pollQrLogin() async {
    while (_qrcodeKey != null) {
      await Future.delayed(const Duration(seconds: 2));
      try {
        final data = await _service.pollQrCodeLogin(_qrcodeKey!);
        final code = data['code'] as int;
        if (code == 0) {
          // Login successful — extract cookies from the response data
          final cookiesRaw = data['cookie_info'] as Map<String, dynamic>?;
          final Map<String, String> cookies = {};
          if (cookiesRaw != null) {
            final cookieList = cookiesRaw['cookies'] as List<dynamic>?;
            if (cookieList != null) {
              for (final c in cookieList) {
                final m = c as Map<String, dynamic>;
                cookies[m['name'] as String] = m['value'] as String;
              }
            }
          }
          await _applyCookies(cookies);
          await _saveCookies(cookies);
          await _service.refreshWbiKeys();
          isLoggedIn = true;
          qrCodeUrl = null;
          _qrcodeKey = null;
          qrLoginStatus = '';
          notifyListeners();
          return;
        } else if (code == 86038) {
          // QR expired
          qrLoginStatus = '二维码已过期，请重试';
          qrCodeUrl = null;
          _qrcodeKey = null;
          notifyListeners();
          return;
        }
        // 86090 = scanned waiting confirm, 86101 = not scanned — keep polling
        if (code == 86090) { qrLoginStatus = '已扫码，请在手机上确认'; notifyListeners(); }
      } catch (e) {
        qrLoginStatus = e.toString();
        qrCodeUrl = null;
        _qrcodeKey = null;
        notifyListeners();
        return;
      }
    }
  }

  void cancelQrLogin() {
    _qrcodeKey = null;
    qrCodeUrl = null;
    qrLoginStatus = '';
    notifyListeners();
  }

  Future<void> logout() async {
    isLoggedIn = false;
    await _service.setCookies('bilibili.com', []);
    await _clearCookies();
    notifyListeners();
  }

  void reset() {
    parseState = ParseState.idle;
    downloadState = DownloadState.idle;
    videoInfo = null;
    audioFilePath = null;
    errorMessage = null;
    downloadProgress = 0;
    notifyListeners();
  }
}

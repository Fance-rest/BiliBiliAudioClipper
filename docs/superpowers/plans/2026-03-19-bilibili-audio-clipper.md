# BiliBili Audio Clipper Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Flutter Android app that downloads audio from Bilibili videos, trims it, and uploads to NetEase Cloud Music.

**Architecture:** Single-page Flutter app with three service layers (Bilibili API, FFmpeg audio processing, NetEase API), three providers for state management, and iOS-styled Cupertino UI. All building/releasing handled via GitHub Actions.

**Tech Stack:** Flutter 3.x, provider, dio, just_audio, ffmpeg_kit_flutter, shared_preferences, flutter_secure_storage, GitHub Actions

**Spec:** `docs/superpowers/specs/2026-03-19-bilibili-audio-clipper-design.md`

---

## File Map

```
lib/
├── main.dart                          # App entry, MultiProvider setup
├── models/
│   └── video_info.dart                # BiliBili video metadata model
├── services/
│   ├── bilibili_service.dart          # URL parsing, WBI signing, API calls, download
│   ├── audio_service.dart             # FFmpeg trim operations
│   └── netease_service.dart           # NetEase login + cloud upload
├── providers/
│   ├── bilibili_provider.dart         # Parse/download state (ChangeNotifier)
│   ├── audio_provider.dart            # Playback/trim state (ChangeNotifier)
│   └── netease_provider.dart          # NetEase login/upload state (ChangeNotifier)
├── pages/
│   ├── home_page.dart                 # Main page assembling all widgets
│   └── settings_page.dart             # Settings with 3 card sections
└── widgets/
    ├── link_input.dart                # URL input + parse button + video info display
    ├── audio_player_widget.dart       # Playback controls + seek bar
    ├── clip_controls.dart             # Time inputs + mark buttons + trim button
    └── upload_section.dart            # Rename input + upload button + progress

android/app/src/main/AndroidManifest.xml  # Add usesCleartextTraffic
.github/workflows/build.yml               # GitHub Actions CI/CD

test/
├── services/
│   ├── bilibili_service_test.dart     # URL parsing, WBI signing unit tests
│   └── audio_service_test.dart        # Time formatting tests
└── models/
    └── video_info_test.dart           # Model serialization tests
```

---

### Task 1: Flutter Project Scaffolding

**Files:**
- Create: Flutter project at repo root
- Modify: `pubspec.yaml` (dependencies)
- Modify: `android/app/src/main/AndroidManifest.xml` (cleartext HTTP, INTERNET permission)
- Modify: `android/app/build.gradle.kts` (minSdk 24)

- [ ] **Step 1: Create Flutter project**

Run:
```bash
flutter create --project-name bilibili_audio_clipper --org com.biliaudioclipper --platforms android .
```

This creates the Flutter project in the current directory. The `--platforms android` flag ensures only Android platform files are generated.

- [ ] **Step 2: Set minSdkVersion to 24**

In `android/app/build.gradle.kts`, find `minSdk` and change it to `24` (required by ffmpeg_kit_flutter).

```kotlin
android {
    defaultConfig {
        minSdk = 24  // was flutter.minSdkVersion
    }
}
```

- [ ] **Step 3: Add dependencies to pubspec.yaml**

Replace the `dependencies` and `dev_dependencies` sections:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  provider: ^6.1.2
  dio: ^5.4.3+1
  dio_cookie_manager: ^3.1.1
  cookie_jar: ^4.0.8
  just_audio: ^0.9.40
  ffmpeg_kit_flutter_audio: ^6.0.3
  shared_preferences: ^2.3.3
  flutter_secure_storage: ^9.2.2
  path_provider: ^2.1.4
  qr_flutter: ^4.1.0
  crypto: ^3.0.5

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
```

Note: We use `ffmpeg_kit_flutter_audio` (the audio-only variant) instead of the full `ffmpeg_kit_flutter` to minimize APK size.

- [ ] **Step 4: Enable cleartext HTTP in AndroidManifest.xml**

In `android/app/src/main/AndroidManifest.xml`, add `android:usesCleartextTraffic="true"` to the `<application>` tag:

```xml
<application
    android:usesCleartextTraffic="true"
    ...>
```

Also verify `android.permission.INTERNET` is present (Flutter includes it by default).

- [ ] **Step 5: Run flutter pub get**

```bash
flutter pub get
```

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: scaffold Flutter project with dependencies"
```

---

### Task 2: Data Models

**Files:**
- Create: `lib/models/video_info.dart`
- Create: `test/models/video_info_test.dart`

- [ ] **Step 1: Write VideoInfo model test**

```dart
// test/models/video_info_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bilibili_audio_clipper/models/video_info.dart';

void main() {
  group('VideoInfo', () {
    test('fromBiliResponse parses video view API response', () {
      final json = {
        'data': {
          'bvid': 'BV1xx411c7mD',
          'aid': 12345,
          'title': '测试视频标题',
          'pic': 'https://i0.hdslb.com/bfs/archive/test.jpg',
          'duration': 624,
          'pages': [
            {'cid': 67890, 'part': 'P1', 'duration': 624}
          ],
        }
      };
      final info = VideoInfo.fromBiliResponse(json);
      expect(info.bvid, 'BV1xx411c7mD');
      expect(info.aid, 12345);
      expect(info.title, '测试视频标题');
      expect(info.coverUrl, 'https://i0.hdslb.com/bfs/archive/test.jpg');
      expect(info.duration, const Duration(seconds: 624));
      expect(info.cid, 67890);
    });

    test('durationText formats duration as mm:ss', () {
      final info = VideoInfo(
        bvid: 'BV1test',
        aid: 1,
        title: 'test',
        coverUrl: '',
        duration: const Duration(minutes: 10, seconds: 24),
        cid: 1,
      );
      expect(info.durationText, '10:24');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/models/video_info_test.dart
```

Expected: FAIL — `video_info.dart` doesn't exist yet.

- [ ] **Step 3: Implement VideoInfo model**

```dart
// lib/models/video_info.dart

class VideoInfo {
  final String bvid;
  final int aid;
  final String title;
  final String coverUrl;
  final Duration duration;
  final int cid;

  const VideoInfo({
    required this.bvid,
    required this.aid,
    required this.title,
    required this.coverUrl,
    required this.duration,
    required this.cid,
  });

  factory VideoInfo.fromBiliResponse(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final pages = data['pages'] as List<dynamic>;
    final firstPage = pages[0] as Map<String, dynamic>;

    return VideoInfo(
      bvid: data['bvid'] as String,
      aid: data['aid'] as int,
      title: data['title'] as String,
      coverUrl: data['pic'] as String,
      duration: Duration(seconds: data['duration'] as int),
      cid: firstPage['cid'] as int,
    );
  }

  String get durationText {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/models/video_info_test.dart
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/models/ test/models/
git commit -m "feat: add VideoInfo data model"
```

---

### Task 3: Bilibili Service — URL Parsing & WBI Signing

**Files:**
- Create: `lib/services/bilibili_service.dart`
- Create: `test/services/bilibili_service_test.dart`

- [ ] **Step 1: Write URL parsing and WBI signing tests**

```dart
// test/services/bilibili_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bilibili_audio_clipper/services/bilibili_service.dart';

void main() {
  group('BilibiliService URL parsing', () {
    test('extracts BV id from full URL', () {
      expect(
        BilibiliService.extractVideoId('https://www.bilibili.com/video/BV1xx411c7mD'),
        ('BV1xx411c7mD', null),
      );
    });

    test('extracts BV id from URL with query params', () {
      final (bvid, _) = BilibiliService.extractVideoId(
        'https://www.bilibili.com/video/BV1xx411c7mD?p=1&share_source=copy_web',
      );
      expect(bvid, 'BV1xx411c7mD');
    });

    test('handles bare BV id input', () {
      expect(
        BilibiliService.extractVideoId('BV1xx411c7mD'),
        ('BV1xx411c7mD', null),
      );
    });

    test('handles AV number input', () {
      final (bvid, avid) = BilibiliService.extractVideoId('av12345');
      expect(bvid, isNull);
      expect(avid, 12345);
    });

    test('detects b23.tv short link', () {
      expect(
        BilibiliService.isShortLink('https://b23.tv/abc123'),
        isTrue,
      );
    });

    test('rejects invalid input', () {
      expect(
        () => BilibiliService.extractVideoId('not a link'),
        throwsFormatException,
      );
    });
  });

  group('WBI signing', () {
    test('getMixinKey applies permutation table correctly', () {
      // Known test case: imgKey + subKey = 64 chars -> 32 char mixinKey
      final imgKey = '7cd084941338484aae1ad9425b84077c';
      final subKey = '4932caff0ff746eab6f01bf08b70ac45';
      final mixinKey = BilibiliService.getMixinKey(imgKey, subKey);
      expect(mixinKey.length, 32);
    });

    test('signParams adds wts and w_rid', () {
      final params = {'bvid': 'BV1xx411c7mD'};
      final mixinKey = 'a' * 32;
      final signed = BilibiliService.signParams(params, mixinKey, wts: 1702200000);
      expect(signed.containsKey('wts'), isTrue);
      expect(signed.containsKey('w_rid'), isTrue);
      expect(signed['wts'], '1702200000');
    });

    test('signParams removes special characters from values', () {
      final params = {'test': "hello!'()*world"};
      final mixinKey = 'a' * 32;
      final signed = BilibiliService.signParams(params, mixinKey, wts: 1702200000);
      expect(signed['test'], 'helloworld');
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/services/bilibili_service_test.dart
```

Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement BilibiliService**

```dart
// lib/services/bilibili_service.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:bilibili_audio_clipper/models/video_info.dart';

class BilibiliService {
  static const _userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  static const _referer = 'https://www.bilibili.com';

  static const _mixinKeyEncTab = [
    46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35,
    27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13,
    37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4,
    22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11, 36, 20, 34, 44, 52,
  ];

  final Dio _dio;
  String? _mixinKey;
  String? _buvid3;
  String? _buvid4;
  Map<String, String> _cookies = {};

  BilibiliService({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options.headers = {
      'User-Agent': _userAgent,
      'Referer': _referer,
      'Origin': _referer,
    };
    _dio.options.followRedirects = false;
    _dio.options.validateStatus = (status) => status != null && status < 400;
  }

  // --- URL Parsing (static, pure functions) ---

  static (String?, int?) extractVideoId(String input) {
    input = input.trim();

    // Bare BV id
    final bvRegex = RegExp(r'^(BV[a-zA-Z0-9]+)$', caseSensitive: false);
    final bvMatch = bvRegex.firstMatch(input);
    if (bvMatch != null) {
      return (bvMatch.group(1)!, null);
    }

    // AV number
    final avRegex = RegExp(r'^av(\d+)$', caseSensitive: false);
    final avMatch = avRegex.firstMatch(input);
    if (avMatch != null) {
      return (null, int.parse(avMatch.group(1)!));
    }

    // Full URL
    final urlRegex = RegExp(r'bilibili\.com/video/(BV[a-zA-Z0-9]+)', caseSensitive: false);
    final urlMatch = urlRegex.firstMatch(input);
    if (urlMatch != null) {
      return (urlMatch.group(1)!, null);
    }

    // AV URL
    final avUrlRegex = RegExp(r'bilibili\.com/video/av(\d+)', caseSensitive: false);
    final avUrlMatch = avUrlRegex.firstMatch(input);
    if (avUrlMatch != null) {
      return (null, int.parse(avUrlMatch.group(1)!));
    }

    // Short link — caller should resolve via resolveShortLink first
    if (isShortLink(input)) {
      throw FormatException('Short link must be resolved first: $input');
    }

    throw FormatException('无法解析该链接，请检查链接格式: $input');
  }

  static bool isShortLink(String input) {
    return input.trim().contains('b23.tv/');
  }

  // --- WBI Signing (static, pure functions) ---

  static String getMixinKey(String imgKey, String subKey) {
    final combined = imgKey + subKey;
    final buffer = StringBuffer();
    for (final idx in _mixinKeyEncTab) {
      if (idx < combined.length) {
        buffer.write(combined[idx]);
      }
    }
    return buffer.toString().substring(0, 32);
  }

  static Map<String, String> signParams(
    Map<String, String> params,
    String mixinKey, {
    int? wts,
  }) {
    final timestamp = wts ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final newParams = Map<String, String>.from(params);
    newParams['wts'] = timestamp.toString();

    // Sort by key
    final sortedKeys = newParams.keys.toList()..sort();

    // Remove special chars from values
    final cleanParams = <String, String>{};
    for (final key in sortedKeys) {
      cleanParams[key] = newParams[key]!.replaceAll(RegExp(r"[!'()*]"), '');
    }

    // Build query string
    final queryParts = <String>[];
    for (final key in sortedKeys) {
      queryParts.add(
        '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(cleanParams[key]!)}',
      );
    }
    final queryString = queryParts.join('&');

    // MD5 hash
    final wRid = md5.convert(utf8.encode(queryString + mixinKey)).toString();
    cleanParams['w_rid'] = wRid;

    return cleanParams;
  }

  // --- API Methods ---

  Future<String> resolveShortLink(String shortUrl) async {
    try {
      final response = await _dio.head(shortUrl);
      final location = response.headers.value('location');
      if (location != null) return location;
    } on DioException catch (e) {
      if (e.response?.statusCode == 302 || e.response?.statusCode == 301) {
        final location = e.response?.headers.value('location');
        if (location != null) return location;
      }
    }
    throw Exception('无法解析短链接');
  }

  Future<void> fetchBuvid() async {
    final response = await _dio.get(
      'https://api.bilibili.com/x/frontend/finger/spi',
    );
    final data = response.data['data'];
    _buvid3 = data['b_3'];
    _buvid4 = data['b_4'];
  }

  void setCookies(Map<String, String> cookies) {
    _cookies = Map.from(cookies);
  }

  Map<String, String> get _allCookies {
    final all = Map<String, String>.from(_cookies);
    if (_buvid3 != null) all['buvid3'] = _buvid3!;
    if (_buvid4 != null) all['buvid4'] = _buvid4!;
    return all;
  }

  String get _cookieHeader {
    return _allCookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  Future<void> refreshWbiKeys() async {
    final response = await _dio.get(
      'https://api.bilibili.com/x/web-interface/nav',
      options: Options(headers: {'Cookie': _cookieHeader}),
    );
    final wbi = response.data['data']['wbi_img'];
    final imgUrl = wbi['img_url'] as String;
    final subUrl = wbi['sub_url'] as String;

    // Extract keys from URLs: take filename without extension
    final imgKey = imgUrl.split('/').last.split('.').first;
    final subKey = subUrl.split('/').last.split('.').first;
    _mixinKey = getMixinKey(imgKey, subKey);
  }

  Future<Map<String, dynamic>> _signedGet(String url, Map<String, String> params) async {
    if (_mixinKey == null) {
      await refreshWbiKeys();
    }

    var signed = signParams(params, _mixinKey!);
    try {
      final response = await _dio.get(
        url,
        queryParameters: signed,
        options: Options(headers: {'Cookie': _cookieHeader}),
      );
      final code = response.data['code'];
      if (code == -403 || code == -401) {
        // WBI key expired, refresh and retry
        await refreshWbiKeys();
        signed = signParams(params, _mixinKey!);
        final retry = await _dio.get(
          url,
          queryParameters: signed,
          options: Options(headers: {'Cookie': _cookieHeader}),
        );
        return retry.data;
      }
      return response.data;
    } on DioException {
      // Try refreshing keys on network errors too
      await refreshWbiKeys();
      signed = signParams(params, _mixinKey!);
      final retry = await _dio.get(
        url,
        queryParameters: signed,
        options: Options(headers: {'Cookie': _cookieHeader}),
      );
      return retry.data;
    }
  }

  Future<VideoInfo> fetchVideoInfo(String? bvid, int? avid) async {
    final params = <String, String>{};
    if (bvid != null) {
      params['bvid'] = bvid;
    } else if (avid != null) {
      params['aid'] = avid.toString();
    }

    final data = await _signedGet(
      'https://api.bilibili.com/x/web-interface/wbi/view',
      params,
    );
    return VideoInfo.fromBiliResponse(data);
  }

  Future<String> fetchAudioStreamUrl(String bvid, int cid) async {
    final data = await _signedGet(
      'https://api.bilibili.com/x/player/wbi/playurl',
      {
        'bvid': bvid,
        'cid': cid.toString(),
        'fnval': '4048',
        'fourk': '1',
        'qn': '125',
        'fnver': '0',
      },
    );

    final dash = data['data']['dash'];
    final audioStreams = dash['audio'] as List<dynamic>;

    // Sort by id (quality) descending, pick highest
    audioStreams.sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
    return audioStreams.first['baseUrl'] as String;
  }

  Future<String> downloadAudio(
    String audioUrl,
    String savePath, {
    void Function(int received, int total)? onProgress,
  }) async {
    await _dio.download(
      audioUrl,
      savePath,
      onReceiveProgress: onProgress,
      options: Options(
        headers: {
          'User-Agent': _userAgent,
          'Referer': _referer,
          'Origin': 'https://m.bilibili.com',
          'Cookie': _cookieHeader,
        },
      ),
    );
    return savePath;
  }

  // --- QR Code Login ---

  Future<({String url, String qrcodeKey})> generateQrCode() async {
    final response = await _dio.get(
      'https://passport.bilibili.com/x/passport-login/web/qrcode/generate',
    );
    final data = response.data['data'];
    return (url: data['url'] as String, qrcodeKey: data['qrcode_key'] as String);
  }

  /// Returns login cookies if successful, null if still waiting.
  /// Throws on expiration or error.
  Future<Map<String, String>?> pollQrCodeLogin(String qrcodeKey) async {
    final response = await _dio.get(
      'https://passport.bilibili.com/x/passport-login/web/qrcode/poll',
      queryParameters: {'qrcode_key': qrcodeKey},
    );
    final data = response.data['data'];
    final code = data['code'] as int;

    switch (code) {
      case 0: // Success
        // Extract cookies from response headers
        final setCookies = response.headers['set-cookie'] ?? [];
        final cookies = <String, String>{};
        for (final cookie in setCookies) {
          final parts = cookie.split(';').first.split('=');
          if (parts.length >= 2) {
            cookies[parts[0].trim()] = parts.sublist(1).join('=').trim();
          }
        }
        return cookies;
      case 86038: // QR code expired
        throw Exception('二维码已过期，请重新生成');
      case 86090: // Scanned, waiting for confirm
      case 86101: // Not scanned yet
        return null;
      default:
        throw Exception('登录失败: ${data['message']}');
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/services/bilibili_service_test.dart
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/bilibili_service.dart test/services/bilibili_service_test.dart
git commit -m "feat: add BilibiliService with URL parsing, WBI signing, and API methods"
```

---

### Task 4: Audio Service (FFmpeg Trimming)

**Files:**
- Create: `lib/services/audio_service.dart`
- Create: `test/services/audio_service_test.dart`

- [ ] **Step 1: Write time formatting tests**

```dart
// test/services/audio_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bilibili_audio_clipper/services/audio_service.dart';

void main() {
  group('AudioService', () {
    test('formatDuration converts Duration to FFmpeg time string', () {
      expect(
        AudioService.formatDuration(const Duration(minutes: 1, seconds: 23)),
        '00:01:23.000',
      );
    });

    test('formatDuration handles hours', () {
      expect(
        AudioService.formatDuration(
          const Duration(hours: 1, minutes: 5, seconds: 30),
        ),
        '01:05:30.000',
      );
    });

    test('formatDuration handles zero', () {
      expect(AudioService.formatDuration(Duration.zero), '00:00:00.000');
    });

    test('validateTrimRange rejects start >= end', () {
      expect(
        () => AudioService.validateTrimRange(
          const Duration(minutes: 5),
          const Duration(minutes: 3),
          const Duration(minutes: 10),
        ),
        throwsArgumentError,
      );
    });

    test('validateTrimRange rejects end > total', () {
      expect(
        () => AudioService.validateTrimRange(
          const Duration(minutes: 1),
          const Duration(minutes: 15),
          const Duration(minutes: 10),
        ),
        throwsArgumentError,
      );
    });

    test('validateTrimRange accepts valid range', () {
      // Should not throw
      AudioService.validateTrimRange(
        const Duration(minutes: 1),
        const Duration(minutes: 5),
        const Duration(minutes: 10),
      );
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/services/audio_service_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Implement AudioService**

```dart
// lib/services/audio_service.dart
import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_audio/return_code.dart';

class AudioService {
  static String formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    final millis = (d.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds.$millis';
  }

  static void validateTrimRange(Duration start, Duration end, Duration total) {
    if (start >= end) {
      throw ArgumentError('开始时间必须小于结束时间');
    }
    if (end > total) {
      throw ArgumentError('结束时间不能超过音频总时长');
    }
    if (start < Duration.zero) {
      throw ArgumentError('开始时间不能为负数');
    }
  }

  /// Trims audio using FFmpeg with -c copy (fast, no re-encoding).
  /// Returns the output file path on success.
  Future<String> trimAudio({
    required String inputPath,
    required String outputPath,
    required Duration start,
    required Duration end,
  }) async {
    final startStr = formatDuration(start);
    final endStr = formatDuration(end);

    final session = await FFmpegKit.execute(
      '-y -i "$inputPath" -ss $startStr -to $endStr -c copy "$outputPath"',
    );
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      return outputPath;
    } else {
      final logs = await session.getLogsAsString();
      throw Exception('裁剪失败: $logs');
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/services/audio_service_test.dart
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/audio_service.dart test/services/audio_service_test.dart
git commit -m "feat: add AudioService with FFmpeg trimming and time utilities"
```

---

### Task 5: NetEase Service (Login + Upload)

**Files:**
- Create: `lib/services/netease_service.dart`

- [ ] **Step 1: Implement NeteaseService**

```dart
// lib/services/netease_service.dart
import 'package:dio/dio.dart';

class NeteaseService {
  final Dio _dio;
  String _baseUrl;
  bool _isLoggedIn = false;
  String? _nickname;
  String? _avatarUrl;
  String? _phone;

  NeteaseService({String baseUrl = '', Dio? dio})
      : _baseUrl = baseUrl,
        _dio = dio ?? Dio();

  bool get isLoggedIn => _isLoggedIn;
  String? get nickname => _nickname;
  String? get avatarUrl => _avatarUrl;
  String? get phone => _phone;

  void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  String get baseUrl => _baseUrl;

  /// Send verification code to phone number.
  Future<void> sendCaptcha(String phone) async {
    final response = await _dio.get(
      '$_baseUrl/captcha/sent',
      queryParameters: {'phone': phone},
    );
    if (response.data['code'] != 200) {
      throw Exception('发送验证码失败: ${response.data['message'] ?? '未知错误'}');
    }
  }

  /// Login with phone number and verification code.
  Future<void> login(String phone, String captcha) async {
    final response = await _dio.get(
      '$_baseUrl/login/cellphone',
      queryParameters: {
        'phone': phone,
        'captcha': captcha,
      },
    );
    if (response.data['code'] != 200) {
      throw Exception('登录失败: ${response.data['message'] ?? '账号或验证码错误'}');
    }

    _isLoggedIn = true;
    _phone = phone;

    // Fetch user profile
    await _fetchProfile();
  }

  /// Check login status.
  Future<bool> checkLoginStatus() async {
    try {
      final response = await _dio.get('$_baseUrl/login/status');
      final profile = response.data['data']?['profile'];
      if (profile != null) {
        _isLoggedIn = true;
        _nickname = profile['nickname'];
        _avatarUrl = profile['avatarUrl'];
        return true;
      }
    } catch (_) {}
    _isLoggedIn = false;
    return false;
  }

  Future<void> _fetchProfile() async {
    try {
      final response = await _dio.get('$_baseUrl/login/status');
      final profile = response.data['data']?['profile'];
      if (profile != null) {
        _nickname = profile['nickname'];
        _avatarUrl = profile['avatarUrl'];
      }
    } catch (_) {}
  }

  /// Logout.
  Future<void> logout() async {
    try {
      await _dio.get('$_baseUrl/logout');
    } catch (_) {}
    _isLoggedIn = false;
    _nickname = null;
    _avatarUrl = null;
    _phone = null;
  }

  /// Upload audio file to cloud drive.
  Future<void> uploadToCloud(
    String filePath,
    String fileName, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final formData = FormData.fromMap({
      'songFile': await MultipartFile.fromFile(
        filePath,
        filename: fileName,
        contentType: DioMediaType('audio', 'mp4'),
      ),
    });

    final response = await _dio.post(
      '$_baseUrl/cloud',
      data: formData,
      onSendProgress: onProgress,
    );

    if (response.data['code'] != 200) {
      throw Exception('上传失败: ${response.data['message'] ?? '未知错误'}');
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/netease_service.dart
git commit -m "feat: add NeteaseService with login, logout, and cloud upload"
```

---

### Task 6: State Providers

**Files:**
- Create: `lib/providers/bilibili_provider.dart`
- Create: `lib/providers/audio_provider.dart`
- Create: `lib/providers/netease_provider.dart`

- [ ] **Step 1: Implement BilibiliProvider**

```dart
// lib/providers/bilibili_provider.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bilibili_audio_clipper/models/video_info.dart';
import 'package:bilibili_audio_clipper/services/bilibili_service.dart';
import 'dart:io';

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

  /// Call on app startup to restore saved B站 login cookies.
  Future<void> restoreSession() async {
    final saved = await _secureStorage.read(key: _cookiesKey);
    if (saved != null) {
      final cookies = Map<String, String>.from(jsonDecode(saved));
      _service.setCookies(cookies);
      isLoggedIn = true;
      try {
        await _service.refreshWbiKeys();
      } catch (_) {
        // Keys will be refreshed on first API call
      }
      notifyListeners();
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

      // Resolve short link first
      if (BilibiliService.isShortLink(input)) {
        resolvedInput = await _service.resolveShortLink(input);
      }

      final (bvid, avid) = BilibiliService.extractVideoId(resolvedInput);

      // Ensure BUVID is fetched
      await _service.fetchBuvid();

      videoInfo = await _service.fetchVideoInfo(bvid, avid);
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
        videoInfo!.bvid,
        videoInfo!.cid,
      );

      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/${videoInfo!.bvid}.m4a';

      await _service.downloadAudio(
        audioUrl,
        savePath,
        onProgress: (received, total) {
          if (total > 0) {
            downloadProgress = received / total;
            notifyListeners();
          }
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

  // --- QR Login ---

  String? qrCodeUrl;
  String? _qrcodeKey;
  String qrLoginStatus = '';

  Future<void> startQrLogin() async {
    final result = await _service.generateQrCode();
    qrCodeUrl = result.url;
    _qrcodeKey = result.qrcodeKey;
    qrLoginStatus = '等待扫码...';
    notifyListeners();

    // Start polling
    _pollQrLogin();
  }

  Future<void> _pollQrLogin() async {
    while (_qrcodeKey != null) {
      await Future.delayed(const Duration(seconds: 2));
      try {
        final cookies = await _service.pollQrCodeLogin(_qrcodeKey!);
        if (cookies != null) {
          _service.setCookies(cookies);
          await _saveCookies(cookies);
          await _service.refreshWbiKeys();
          isLoggedIn = true;
          qrCodeUrl = null;
          _qrcodeKey = null;
          qrLoginStatus = '';
          notifyListeners();
          return;
        }
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
    _service.setCookies({});
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
```

- [ ] **Step 2: Implement AudioProvider**

```dart
// lib/providers/audio_provider.dart
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bilibili_audio_clipper/services/audio_service.dart';

enum TrimState { idle, trimming, done, error }

class AudioProvider extends ChangeNotifier {
  final AudioService _service;
  final AudioPlayer _player = AudioPlayer();

  Duration? totalDuration;
  Duration currentPosition = Duration.zero;
  bool isPlaying = false;

  // Trim times (minutes and seconds separately for UI)
  int startMinutes = 0;
  int startSeconds = 0;
  int endMinutes = 0;
  int endSeconds = 0;

  TrimState trimState = TrimState.idle;
  String? trimmedFilePath;
  String? errorMessage;

  AudioProvider(this._service) {
    _player.positionStream.listen((pos) {
      currentPosition = pos;
      notifyListeners();
    });
    _player.durationStream.listen((dur) {
      totalDuration = dur;
      if (dur != null) {
        endMinutes = dur.inMinutes;
        endSeconds = dur.inSeconds % 60;
      }
      notifyListeners();
    });
    _player.playerStateStream.listen((state) {
      isPlaying = state.playing;
      notifyListeners();
    });
  }

  Duration get startTime => Duration(minutes: startMinutes, seconds: startSeconds);
  Duration get endTime => Duration(minutes: endMinutes, seconds: endSeconds);

  Future<void> loadAudio(String filePath) async {
    await _player.setFilePath(filePath);
    trimState = TrimState.idle;
    trimmedFilePath = null;
    notifyListeners();
  }

  Future<void> play() async => _player.play();
  Future<void> pause() async => _player.pause();
  Future<void> seek(Duration position) async => _player.seek(position);

  void markStart() {
    startMinutes = currentPosition.inMinutes;
    startSeconds = currentPosition.inSeconds % 60;
    notifyListeners();
  }

  void markEnd() {
    endMinutes = currentPosition.inMinutes;
    endSeconds = currentPosition.inSeconds % 60;
    notifyListeners();
  }

  void setStartTime(int minutes, int seconds) {
    startMinutes = minutes;
    startSeconds = seconds;
    notifyListeners();
  }

  void setEndTime(int minutes, int seconds) {
    endMinutes = minutes;
    endSeconds = seconds;
    notifyListeners();
  }

  Future<void> trimAudio(String inputPath) async {
    if (totalDuration == null) return;

    trimState = TrimState.trimming;
    errorMessage = null;
    notifyListeners();

    try {
      AudioService.validateTrimRange(startTime, endTime, totalDuration!);

      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/trimmed_${DateTime.now().millisecondsSinceEpoch}.m4a';

      trimmedFilePath = await _service.trimAudio(
        inputPath: inputPath,
        outputPath: outputPath,
        start: startTime,
        end: endTime,
      );
      trimState = TrimState.done;
    } catch (e) {
      trimState = TrimState.error;
      errorMessage = e.toString();
    }
    notifyListeners();
  }

  void reset() {
    _player.stop();
    totalDuration = null;
    currentPosition = Duration.zero;
    isPlaying = false;
    startMinutes = 0;
    startSeconds = 0;
    endMinutes = 0;
    endSeconds = 0;
    trimState = TrimState.idle;
    trimmedFilePath = null;
    errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 3: Implement NeteaseProvider**

```dart
// lib/providers/netease_provider.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bilibili_audio_clipper/services/netease_service.dart';

enum UploadState { idle, uploading, done, error }

class NeteaseProvider extends ChangeNotifier {
  final NeteaseService _service;

  UploadState uploadState = UploadState.idle;
  double uploadProgress = 0;
  String? errorMessage;
  String fileName = '';

  NeteaseProvider(this._service);

  bool get isLoggedIn => _service.isLoggedIn;
  String? get nickname => _service.nickname;
  String? get avatarUrl => _service.avatarUrl;
  String? get phone => _service.phone;
  String get baseUrl => _service.baseUrl;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('netease_api_url') ?? '';
    if (savedUrl.isNotEmpty) {
      _service.setBaseUrl(savedUrl);
    }
    // Check if still logged in
    if (savedUrl.isNotEmpty) {
      await _service.checkLoginStatus();
      notifyListeners();
    }
  }

  Future<void> setBaseUrl(String url) async {
    _service.setBaseUrl(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('netease_api_url', url);
    notifyListeners();
  }

  Future<void> sendCaptcha(String phone) async {
    await _service.sendCaptcha(phone);
  }

  Future<void> login(String phone, String captcha) async {
    await _service.login(phone, captcha);
    notifyListeners();
  }

  Future<void> logout() async {
    await _service.logout();
    notifyListeners();
  }

  void setFileName(String name) {
    fileName = name;
    notifyListeners();
  }

  Future<void> upload(String filePath) async {
    uploadState = UploadState.uploading;
    uploadProgress = 0;
    errorMessage = null;
    notifyListeners();

    try {
      final actualFileName = fileName.isEmpty ? 'audio' : fileName;
      await _service.uploadToCloud(
        filePath,
        '$actualFileName.m4a',
        onProgress: (sent, total) {
          if (total > 0) {
            uploadProgress = sent / total;
            notifyListeners();
          }
        },
      );
      uploadState = UploadState.done;
    } catch (e) {
      uploadState = UploadState.error;
      errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> deleteLocalFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  void resetUpload() {
    uploadState = UploadState.idle;
    uploadProgress = 0;
    errorMessage = null;
    notifyListeners();
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add lib/providers/
git commit -m "feat: add BilibiliProvider, AudioProvider, and NeteaseProvider"
```

---

### Task 7: App Entry Point

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Implement main.dart with MultiProvider**

```dart
// lib/main.dart
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
        ChangeNotifierProvider(
          create: (_) => BilibiliProvider(bilibiliService)..restoreSession(),
        ),
        ChangeNotifierProvider(create: (_) => AudioProvider(audioService)),
        ChangeNotifierProvider(
          create: (_) => NeteaseProvider(neteaseService)..loadSettings(),
        ),
      ],
      child: const CupertinoApp(
        title: '音频提取',
        theme: CupertinoThemeData(
          primaryColor: Color(0xFF007AFF),
          scaffoldBackgroundColor: Color(0xFFF2F2F7),
        ),
        home: HomePage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
```

- [ ] **Step 2: Create placeholder HomePage**

```dart
// lib/pages/home_page.dart
import 'package:flutter/cupertino.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('音频提取'),
      ),
      child: Center(child: Text('Coming soon')),
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart lib/pages/home_page.dart
git commit -m "feat: add app entry point with MultiProvider and CupertinoApp"
```

---

### Task 8: UI Widgets — Link Input

**Files:**
- Create: `lib/widgets/link_input.dart`

- [ ] **Step 1: Implement LinkInput widget**

Reference: `design/src/app/components/Home.tsx` lines 39-77 (Video Link Card).

```dart
// lib/widgets/link_input.dart
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

  @override
  Widget build(BuildContext context) {
    return Consumer<BilibiliProvider>(
      builder: (context, provider, _) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '视频链接',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: _controller,
                placeholder: '粘贴B站链接或BV号',
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: provider.parseState == ParseState.loading
                      ? null
                      : () => provider.parseLink(_controller.text),
                  child: provider.parseState == ParseState.loading
                      ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                      : const Text('解析'),
                ),
              ),

              // Error message
              if (provider.parseState == ParseState.error)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    provider.errorMessage ?? '解析失败',
                    style: const TextStyle(
                      color: CupertinoColors.destructiveRed,
                      fontSize: 13,
                    ),
                  ),
                ),

              // Video info result
              if (provider.videoInfo != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              provider.videoInfo!.coverUrl,
                              width: 100,
                              height: 75,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 100,
                                height: 75,
                                color: CupertinoColors.systemGrey5,
                                child: const Icon(CupertinoIcons.video_camera),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider.videoInfo!.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  provider.videoInfo!.durationText,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: CupertinoColors.systemGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton.filled(
                          onPressed: provider.downloadState == DownloadState.downloading
                              ? null
                              : () => provider.downloadAudio(),
                          child: provider.downloadState == DownloadState.downloading
                              ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                              : const Text('下载音频'),
                        ),
                      ),
                      // Download progress
                      if (provider.downloadState == DownloadState.downloading)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: provider.downloadProgress,
                                  backgroundColor: CupertinoColors.systemGrey5,
                                  valueColor: const AlwaysStoppedAnimation(Color(0xFF007AFF)),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '下载中... ${(provider.downloadProgress * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/widgets/link_input.dart
git commit -m "feat: add LinkInput widget with parse and download UI"
```

---

### Task 9: UI Widgets — Audio Player

**Files:**
- Create: `lib/widgets/audio_player_widget.dart`

- [ ] **Step 1: Implement AudioPlayerWidget**

Reference: `design/src/app/components/Home.tsx` lines 81-105 (Audio Player section).

```dart
// lib/widgets/audio_player_widget.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show LinearProgressIndicator, AlwaysStoppedAnimation;
import 'package:provider/provider.dart';
import 'package:bilibili_audio_clipper/providers/audio_provider.dart';

class AudioPlayerWidget extends StatelessWidget {
  const AudioPlayerWidget({super.key});

  String _formatTime(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, provider, _) {
        if (provider.totalDuration == null) {
          return const SizedBox.shrink();
        }

        final total = provider.totalDuration!;
        final current = provider.currentPosition;
        final progress = total.inMilliseconds > 0
            ? current.inMilliseconds / total.inMilliseconds
            : 0.0;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '音频裁剪',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              // Player card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // Seek bar
                    GestureDetector(
                      onTapDown: (details) {
                        final box = context.findRenderObject() as RenderBox;
                        // Approximate seek bar width
                        final width = box.size.width - 64; // padding
                        final fraction = (details.localPosition.dx - 16) / width;
                        final seekPos = Duration(
                          milliseconds: (total.inMilliseconds * fraction.clamp(0.0, 1.0)).toInt(),
                        );
                        provider.seek(seekPos);
                      },
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              backgroundColor: CupertinoColors.systemGrey5,
                              valueColor: const AlwaysStoppedAnimation(Color(0xFF007AFF)),
                              minHeight: 4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatTime(current),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                              Text(
                                _formatTime(total),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Play/Pause button
                    CupertinoButton(
                      onPressed: () {
                        if (provider.isPlaying) {
                          provider.pause();
                        } else {
                          provider.play();
                        }
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF007AFF),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          provider.isPlaying
                              ? CupertinoIcons.pause_fill
                              : CupertinoIcons.play_fill,
                          color: const Color(0xFF007AFF),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/widgets/audio_player_widget.dart
git commit -m "feat: add AudioPlayerWidget with playback controls and seek bar"
```

---

### Task 10: UI Widgets — Clip Controls

**Files:**
- Create: `lib/widgets/clip_controls.dart`

- [ ] **Step 1: Implement ClipControls widget**

Reference: `design/src/app/components/Home.tsx` lines 107-161 (Time input + trim button).

```dart
// lib/widgets/clip_controls.dart
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
  final _startMinCtrl = TextEditingController();
  final _startSecCtrl = TextEditingController();
  final _endMinCtrl = TextEditingController();
  final _endSecCtrl = TextEditingController();

  @override
  void dispose() {
    _startMinCtrl.dispose();
    _startSecCtrl.dispose();
    _endMinCtrl.dispose();
    _endSecCtrl.dispose();
    super.dispose();
  }

  void _syncFromProvider(AudioProvider provider) {
    _startMinCtrl.text = provider.startMinutes.toString();
    _startSecCtrl.text = provider.startSeconds.toString();
    _endMinCtrl.text = provider.endMinutes.toString();
    _endSecCtrl.text = provider.endSeconds.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audioProvider, _) {
        if (audioProvider.totalDuration == null) {
          return const SizedBox.shrink();
        }

        // Sync controllers when provider values change (e.g. from mark buttons)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_startMinCtrl.text != audioProvider.startMinutes.toString()) {
            _syncFromProvider(audioProvider);
          }
        });

        return Column(
          children: [
            // Time input card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // Start time row
                  _buildTimeRow(
                    label: '开始',
                    minCtrl: _startMinCtrl,
                    secCtrl: _startSecCtrl,
                    buttonLabel: '标记起点',
                    onMark: () {
                      audioProvider.markStart();
                      _syncFromProvider(audioProvider);
                    },
                    onChanged: (min, sec) {
                      audioProvider.setStartTime(min, sec);
                    },
                  ),
                  const SizedBox(height: 16),
                  // End time row
                  _buildTimeRow(
                    label: '结束',
                    minCtrl: _endMinCtrl,
                    secCtrl: _endSecCtrl,
                    buttonLabel: '标记终点',
                    onMark: () {
                      audioProvider.markEnd();
                      _syncFromProvider(audioProvider);
                    },
                    onChanged: (min, sec) {
                      audioProvider.setEndTime(min, sec);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Trim button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: CupertinoColors.white,
                  onPressed: audioProvider.trimState == TrimState.trimming
                      ? null
                      : () {
                          final biliProvider = context.read<BilibiliProvider>();
                          if (biliProvider.audioFilePath != null) {
                            audioProvider.trimAudio(biliProvider.audioFilePath!);
                          }
                        },
                  child: audioProvider.trimState == TrimState.trimming
                      ? const CupertinoActivityIndicator()
                      : const Text(
                          '裁剪',
                          style: TextStyle(
                            color: Color(0xFF007AFF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),

            // Trim error
            if (audioProvider.trimState == TrimState.error)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
                child: Text(
                  audioProvider.errorMessage ?? '裁剪失败',
                  style: const TextStyle(
                    color: CupertinoColors.destructiveRed,
                    fontSize: 13,
                  ),
                ),
              ),

            // Trim success
            if (audioProvider.trimState == TrimState.done)
              const Padding(
                padding: EdgeInsets.only(top: 8, left: 16, right: 16),
                child: Text(
                  '裁剪完成',
                  style: TextStyle(
                    color: CupertinoColors.activeGreen,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTimeRow({
    required String label,
    required TextEditingController minCtrl,
    required TextEditingController secCtrl,
    required String buttonLabel,
    required VoidCallback onMark,
    required void Function(int min, int sec) onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: const TextStyle(fontSize: 15),
          ),
        ),
        SizedBox(
          width: 64,
          child: CupertinoTextField(
            controller: minCtrl,
            placeholder: '分',
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(8),
            ),
            onChanged: (v) {
              onChanged(int.tryParse(v) ?? 0, int.tryParse(secCtrl.text) ?? 0);
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(':', style: TextStyle(fontSize: 15, color: CupertinoColors.systemGrey)),
        ),
        SizedBox(
          width: 64,
          child: CupertinoTextField(
            controller: secCtrl,
            placeholder: '秒',
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(8),
            ),
            onChanged: (v) {
              onChanged(int.tryParse(minCtrl.text) ?? 0, int.tryParse(v) ?? 0);
            },
          ),
        ),
        const Spacer(),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: const Color(0xFFE5F1FF),
          borderRadius: BorderRadius.circular(20),
          onPressed: onMark,
          child: Text(
            buttonLabel,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF007AFF),
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/widgets/clip_controls.dart
git commit -m "feat: add ClipControls widget with time input and mark buttons"
```

---

### Task 11: UI Widgets — Upload Section

**Files:**
- Create: `lib/widgets/upload_section.dart`

- [ ] **Step 1: Implement UploadSection widget**

Reference: `design/src/app/components/Home.tsx` lines 164-194 (Upload card) and `IOSAlert.tsx` (success dialog).

```dart
// lib/widgets/upload_section.dart
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
  final _nameController = TextEditingController();
  bool _initialized = false;
  bool _dialogShown = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _getFileToUpload(BilibiliProvider biliProvider, AudioProvider audioProvider) {
    // Use trimmed file if available, otherwise original download
    return audioProvider.trimmedFilePath ?? biliProvider.audioFilePath ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<BilibiliProvider, AudioProvider, NeteaseProvider>(
      builder: (context, biliProvider, audioProvider, neteaseProvider, _) {
        // Only show when audio is downloaded
        if (biliProvider.downloadState != DownloadState.done) {
          return const SizedBox.shrink();
        }

        // Initialize file name from video title
        if (!_initialized && biliProvider.videoInfo != null) {
          _nameController.text = biliProvider.videoInfo!.title;
          neteaseProvider.setFileName(biliProvider.videoInfo!.title);
          _initialized = true;
        }

        final filePath = _getFileToUpload(biliProvider, audioProvider);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '上传',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              // File name input
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoTextField(
                        controller: _nameController,
                        decoration: const BoxDecoration(),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        onChanged: (v) => neteaseProvider.setFileName(v),
                      ),
                    ),
                    const Text(
                      '.m4a',
                      style: TextStyle(
                        fontSize: 15,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Upload button
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: const Color(0xFF34C759),
                  onPressed: neteaseProvider.uploadState == UploadState.uploading
                      ? null
                      : () {
                          if (!neteaseProvider.isLoggedIn) {
                            _showError(context, '请先在设置中登录网易云账号');
                            return;
                          }
                          neteaseProvider.upload(filePath);
                        },
                  child: neteaseProvider.uploadState == UploadState.uploading
                      ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.cloud_upload, size: 18),
                            SizedBox(width: 8),
                            Text('上传到网易云盘'),
                          ],
                        ),
                ),
              ),

              // Upload progress
              if (neteaseProvider.uploadState == UploadState.uploading)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: neteaseProvider.uploadProgress,
                          backgroundColor: CupertinoColors.systemGrey5,
                          valueColor: const AlwaysStoppedAnimation(Color(0xFF34C759)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '上传中... ${(neteaseProvider.uploadProgress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    ],
                  ),
                ),

              // Upload error
              if (neteaseProvider.uploadState == UploadState.error)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    neteaseProvider.errorMessage ?? '上传失败',
                    style: const TextStyle(
                      color: CupertinoColors.destructiveRed,
                      fontSize: 13,
                    ),
                  ),
                ),

              // Upload success — show dialog (with guard to prevent repeated firing)
              if (neteaseProvider.uploadState == UploadState.done && !_dialogShown)
                Builder(
                  builder: (context) {
                    _dialogShown = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _showSuccessDialog(context, filePath, neteaseProvider);
                    });
                    return const SizedBox.shrink();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showError(BuildContext context, String message) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('确定'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(
    BuildContext context,
    String filePath,
    NeteaseProvider neteaseProvider,
  ) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('上传成功'),
        content: const Text('音频已上传到网易云盘'),
        actions: [
          CupertinoDialogAction(
            child: const Text('保留本地文件'),
            onPressed: () {
              _dialogShown = false;
              neteaseProvider.resetUpload();
              Navigator.pop(context);
            },
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('删除本地文件'),
            onPressed: () {
              _dialogShown = false;
              neteaseProvider.deleteLocalFile(filePath);
              neteaseProvider.resetUpload();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/widgets/upload_section.dart
git commit -m "feat: add UploadSection widget with rename, upload, and success dialog"
```

---

### Task 12: Settings Page

**Files:**
- Create: `lib/pages/settings_page.dart`

- [ ] **Step 1: Implement SettingsPage**

Reference: `design/src/app/components/Settings.tsx` + spec section 7 (B站 QR login section).

```dart
// lib/pages/settings_page.dart
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:bilibili_audio_clipper/providers/bilibili_provider.dart';
import 'package:bilibili_audio_clipper/providers/netease_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _apiUrlController = TextEditingController();
  final _phoneController = TextEditingController();
  final _captchaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final neteaseProvider = context.read<NeteaseProvider>();
    _apiUrlController.text = neteaseProvider.baseUrl;
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _phoneController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('设置'),
        previousPageTitle: '返回',
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBilibiliSection(),
              const SizedBox(height: 24),
              _buildApiSection(),
              const SizedBox(height: 24),
              _buildNeteaseSection(),
            ],
          ),
        ),
      ),
    );
  }

  // --- Section 1: B站账号 ---
  Widget _buildBilibiliSection() {
    return Consumer<BilibiliProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 8),
              child: Text(
                'B站账号',
                style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: provider.isLoggedIn
                  ? _buildBiliLoggedIn(provider)
                  : provider.qrCodeUrl != null
                      ? _buildBiliQrCode(provider)
                      : _buildBiliNotLoggedIn(provider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBiliNotLoggedIn(BilibiliProvider provider) {
    return CupertinoButton(
      padding: const EdgeInsets.all(16),
      onPressed: () => provider.startQrLogin(),
      child: const Row(
        children: [
          Text('未登录', style: TextStyle(fontSize: 15, color: CupertinoColors.systemGrey)),
          Spacer(),
          Text('扫码登录', style: TextStyle(fontSize: 15, color: Color(0xFF007AFF))),
          SizedBox(width: 4),
          Icon(CupertinoIcons.chevron_right, size: 16, color: CupertinoColors.systemGrey),
        ],
      ),
    );
  }

  Widget _buildBiliQrCode(BilibiliProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          QrImageView(
            data: provider.qrCodeUrl!,
            version: QrVersions.auto,
            size: 200,
          ),
          const SizedBox(height: 12),
          Text(
            provider.qrLoginStatus,
            style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
          ),
          const SizedBox(height: 12),
          CupertinoButton(
            onPressed: () => provider.cancelQrLogin(),
            child: const Text('取消', style: TextStyle(color: CupertinoColors.destructiveRed)),
          ),
        ],
      ),
    );
  }

  Widget _buildBiliLoggedIn(BilibiliProvider provider) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(CupertinoIcons.person_circle_fill, size: 50, color: Color(0xFF007AFF)),
              const SizedBox(width: 12),
              const Text('已登录', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        CupertinoButton(
          padding: const EdgeInsets.all(16),
          onPressed: () => provider.logout(),
          child: const Center(
            child: Text(
              '退出登录',
              style: TextStyle(color: CupertinoColors.destructiveRed, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }

  // --- Section 2: API 服务 ---
  Widget _buildApiSection() {
    return Consumer<NeteaseProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 8),
              child: Text(
                'API 服务',
                style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('服务器地址', style: TextStyle(fontSize: 15)),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: _apiUrlController,
                    placeholder: 'http://100.x.x.x:3000',
                    onChanged: (v) => provider.setBaseUrl(v),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // --- Section 3: 网易云账号 ---
  Widget _buildNeteaseSection() {
    return Consumer<NeteaseProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 8),
              child: Text(
                '网易云账号',
                style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: provider.isLoggedIn
                  ? _buildNeteaseLoggedIn(provider)
                  : _buildNeteaseLoginForm(provider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNeteaseLoginForm(NeteaseProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('手机号', style: TextStyle(fontSize: 15)),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _phoneController,
            placeholder: '请输入手机号',
            keyboardType: TextInputType.phone,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 16),
          const Text('验证码', style: TextStyle(fontSize: 15)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: _captchaController,
                  placeholder: '请输入验证码',
                  keyboardType: TextInputType.number,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                onPressed: () async {
                  try {
                    await provider.sendCaptcha(_phoneController.text);
                  } catch (e) {
                    if (mounted) {
                      showCupertinoDialog(
                        context: context,
                        builder: (_) => CupertinoAlertDialog(
                          title: const Text('错误'),
                          content: Text(e.toString()),
                          actions: [
                            CupertinoDialogAction(
                              child: const Text('确定'),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      );
                    }
                  }
                },
                child: const Text('获取验证码', style: TextStyle(fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              onPressed: () async {
                try {
                  await provider.login(_phoneController.text, _captchaController.text);
                } catch (e) {
                  if (mounted) {
                    showCupertinoDialog(
                      context: context,
                      builder: (_) => CupertinoAlertDialog(
                        title: const Text('登录失败'),
                        content: Text(e.toString()),
                        actions: [
                          CupertinoDialogAction(
                            child: const Text('确定'),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    );
                  }
                }
              },
              child: const Text('登录'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeteaseLoggedIn(NeteaseProvider provider) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (provider.avatarUrl != null)
                ClipOval(
                  child: Image.network(
                    provider.avatarUrl!,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      CupertinoIcons.person_circle_fill,
                      size: 50,
                    ),
                  ),
                )
              else
                const Icon(CupertinoIcons.person_circle_fill, size: 50),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.nickname ?? '已登录',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    if (provider.phone != null)
                      Text(
                        '${provider.phone!.substring(0, 3)}****${provider.phone!.substring(7)}',
                        style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(height: 1, color: CupertinoColors.separator),
        CupertinoButton(
          padding: const EdgeInsets.all(16),
          onPressed: () => provider.logout(),
          child: const Center(
            child: Text(
              '退出登录',
              style: TextStyle(color: CupertinoColors.destructiveRed, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/pages/settings_page.dart
git commit -m "feat: add SettingsPage with B站 QR login, API config, and NetEase login"
```

---

### Task 13: Assemble Home Page

**Files:**
- Modify: `lib/pages/home_page.dart`

- [ ] **Step 1: Implement full HomePage assembling all widgets**

```dart
// lib/pages/home_page.dart
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:bilibili_audio_clipper/providers/bilibili_provider.dart';
import 'package:bilibili_audio_clipper/providers/audio_provider.dart';
import 'package:bilibili_audio_clipper/pages/settings_page.dart';
import 'package:bilibili_audio_clipper/widgets/link_input.dart';
import 'package:bilibili_audio_clipper/widgets/audio_player_widget.dart';
import 'package:bilibili_audio_clipper/widgets/clip_controls.dart';
import 'package:bilibili_audio_clipper/widgets/upload_section.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Navigation bar with settings icon
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '音频提取',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(builder: (_) => const SettingsPage()),
                      );
                    },
                    child: const Text('⚙', style: TextStyle(fontSize: 28)),
                  ),
                ],
              ),
            ),
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                child: Consumer<BilibiliProvider>(
                  builder: (context, biliProvider, _) {
                    // When download completes, auto-load audio into player
                    if (biliProvider.downloadState == DownloadState.done &&
                        biliProvider.audioFilePath != null) {
                      final audioProvider = context.read<AudioProvider>();
                      if (audioProvider.totalDuration == null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          audioProvider.loadAudio(biliProvider.audioFilePath!);
                        });
                      }
                    }

                    return Column(
                      children: [
                        const LinkInput(),
                        if (biliProvider.downloadState == DownloadState.done) ...[
                          const AudioPlayerWidget(),
                          const ClipControls(),
                          const UploadSection(),
                        ],
                        const SizedBox(height: 32),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/pages/home_page.dart
git commit -m "feat: assemble HomePage with all widgets in linear flow"
```

---

### Task 14: GitHub Actions CI/CD

**Files:**
- Create: `.github/workflows/build.yml`

- [ ] **Step 1: Create GitHub Actions workflow**

```yaml
# .github/workflows/build.yml
name: Build & Release APK

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: 'zulu'
          java-version: '17'

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          channel: 'stable'

      - name: Get dependencies
        run: flutter pub get

      - name: Run tests
        run: flutter test

      - name: Decode keystore
        run: |
          echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 -d > android/app/keystore.jks

      - name: Create key.properties
        run: |
          echo "storePassword=${{ secrets.KEYSTORE_PASSWORD }}" > android/app/key.properties
          echo "keyPassword=${{ secrets.KEY_PASSWORD }}" >> android/app/key.properties
          echo "keyAlias=${{ secrets.KEY_ALIAS }}" >> android/app/key.properties
          echo "storeFile=keystore.jks" >> android/app/key.properties

      - name: Build APK
        run: flutter build apk --release

      - name: Upload APK artifact
        uses: actions/upload-artifact@v4
        with:
          name: release-apk
          path: build/app/outputs/flutter-apk/app-release.apk

      - name: Create Release
        if: startsWith(github.ref, 'refs/tags/')
        uses: softprops/action-gh-release@v2
        with:
          files: build/app/outputs/flutter-apk/app-release.apk
```

- [ ] **Step 2: Configure Android signing in build.gradle.kts**

Add keystore configuration to `android/app/build.gradle.kts`. Add before the `android {` block:

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystorePropertiesFile = rootProject.file("app/key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
```

Inside `android {`, add `signingConfigs` and update `buildTypes`:

```kotlin
android {
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
        }
    }
}
```

- [ ] **Step 3: Add key.properties to .gitignore**

Append to `.gitignore`:
```
# Signing
android/app/keystore.jks
android/key.properties
```

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/build.yml android/app/build.gradle.kts .gitignore
git commit -m "feat: add GitHub Actions workflow for APK build and release"
```

---

### Task 15: Generate Keystore & Configure GitHub Secrets

This task requires interactive steps with the user.

- [ ] **Step 1: Generate a keystore file**

Run locally:
```bash
keytool -genkey -v -keystore ~/biliaudio-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias biliaudio
```

It will prompt for passwords and identity info. Remember the passwords.

- [ ] **Step 2: Base64-encode the keystore**

```bash
base64 -i ~/biliaudio-release.jks | pbcopy
```

This copies the base64 string to clipboard.

- [ ] **Step 3: Add GitHub Secrets**

Guide the user to go to: GitHub repo → Settings → Secrets and variables → Actions → New repository secret

Add these 4 secrets:
- `KEYSTORE_BASE64`: paste the base64 from clipboard
- `KEYSTORE_PASSWORD`: the store password you chose
- `KEY_ALIAS`: `biliaudio`
- `KEY_PASSWORD`: the key password you chose

- [ ] **Step 4: Push code and create first tag**

```bash
git remote add origin https://github.com/<username>/<repo>.git
git push -u origin main
git tag v0.1.0
git push origin v0.1.0
```

This triggers the GitHub Actions build. Go to the repo's Actions tab to watch it.

- [ ] **Step 5: Download APK from GitHub Release**

Once the build succeeds, go to the repo's Releases page and download `app-release.apk`. Transfer to Android phone and install.

---

### Task 16: Final Smoke Test Checklist

Manual testing on device:

- [ ] **Step 1:** Open app, verify "音频提取" title and ⚙ settings icon render correctly
- [ ] **Step 2:** Go to Settings, verify all 3 sections (B站, API, 网易云) display correctly
- [ ] **Step 3:** In Settings, configure API server URL
- [ ] **Step 4:** In Settings, test B站 QR code login (scan with B站 app)
- [ ] **Step 5:** In Settings, test 网易云 login (phone + captcha)
- [ ] **Step 6:** On home page, paste a B站 video link and tap 解析
- [ ] **Step 7:** Verify video thumbnail, title, duration appear
- [ ] **Step 8:** Tap 下载音频, verify progress bar and download completes
- [ ] **Step 9:** Verify audio player appears with play/pause and seek bar
- [ ] **Step 10:** Test 标记起点/标记终点 while playing
- [ ] **Step 11:** Test manual time input (分/秒 boxes)
- [ ] **Step 12:** Tap 裁剪, verify "裁剪完成" appears
- [ ] **Step 13:** Modify file name, tap 上传到网易云盘
- [ ] **Step 14:** Verify upload progress and success dialog
- [ ] **Step 15:** Test both "保留本地文件" and "删除本地文件" options

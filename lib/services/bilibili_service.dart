import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import '../models/video_info.dart';

/// WBI permutation table (64 entries).
const List<int> _wbiMixinKeyTable = [
  46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35,
  27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13,
  37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4,
  22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11, 36, 20, 34, 44, 52,
];

const String _userAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/120.0.0.0 Safari/537.36';
const String _referer = 'https://www.bilibili.com';

// API endpoints
const String _apiVideoInfo =
    'https://api.bilibili.com/x/web-interface/wbi/view';
const String _apiPlayUrl =
    'https://api.bilibili.com/x/player/wbi/playurl';
const String _apiNav = 'https://api.bilibili.com/x/web-interface/nav';
const String _apiBuvid = 'https://api.bilibili.com/x/frontend/finger/spi';
const String _apiQrGenerate =
    'https://passport.bilibili.com/x/passport-login/web/qrcode/generate';
const String _apiQrPoll =
    'https://passport.bilibili.com/x/passport-login/web/qrcode/poll';

/// Result type for [BilibiliService.extractVideoId].
class VideoIdResult {
  final String? bvid;
  final int? avid;

  const VideoIdResult({this.bvid, this.avid});

  @override
  String toString() => 'VideoIdResult(bvid: $bvid, avid: $avid)';
}

class BilibiliService {
  final Dio _dio;
  final CookieJar _cookieJar;

  // Cached WBI keys
  String? _imgKey;
  String? _subKey;
  String? _cachedMixinKey;

  BilibiliService()
      : _cookieJar = CookieJar(),
        _dio = Dio(BaseOptions(
          headers: {
            'User-Agent': _userAgent,
            'Referer': _referer,
          },
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        )) {
    _dio.interceptors.add(CookieManager(_cookieJar));
  }

  // ---------------------------------------------------------------------------
  // Static helpers — URL parsing
  // ---------------------------------------------------------------------------

  /// Detects whether [input] is a b23.tv short link.
  static bool isShortLink(String input) {
    final trimmed = input.trim();
    return trimmed.contains('b23.tv/') ||
        trimmed.startsWith('https://b23.tv') ||
        trimmed.startsWith('http://b23.tv');
  }

  /// Extracts a BV id or AV number from [input].
  ///
  /// Supported formats:
  /// - Full URL: `https://www.bilibili.com/video/BV1xx411c7mD`
  /// - Bare BV:  `BV1xx411c7mD` (case-insensitive prefix)
  /// - AV number:`av12345` or `AV12345`
  ///
  /// Returns a [VideoIdResult] with either [bvid] or [avid] set.
  /// Throws [FormatException] for unrecognised input.
  /// Short links are NOT resolved here — call [resolveShortLink] first.
  static VideoIdResult extractVideoId(String input) {
    final s = input.trim();

    // Reject short links — caller must resolve first.
    if (isShortLink(s)) {
      throw FormatException('Short link must be resolved before parsing: $s');
    }

    // Full bilibili URL containing /video/BVxxx
    final urlBvRegex =
        RegExp(r'bilibili\.com/video/(BV[A-Za-z0-9]+)', caseSensitive: false);
    final urlBvMatch = urlBvRegex.firstMatch(s);
    if (urlBvMatch != null) {
      return VideoIdResult(bvid: urlBvMatch.group(1));
    }

    // Full bilibili URL containing /video/avXXX
    final urlAvRegex =
        RegExp(r'bilibili\.com/video/av(\d+)', caseSensitive: false);
    final urlAvMatch = urlAvRegex.firstMatch(s);
    if (urlAvMatch != null) {
      return VideoIdResult(avid: int.parse(urlAvMatch.group(1)!));
    }

    // Bare BV id
    final bareBvRegex = RegExp(r'^BV[A-Za-z0-9]+$', caseSensitive: false);
    if (bareBvRegex.hasMatch(s)) {
      return VideoIdResult(bvid: s);
    }

    // AV number (av12345)
    final bareAvRegex = RegExp(r'^av(\d+)$', caseSensitive: false);
    final bareAvMatch = bareAvRegex.firstMatch(s);
    if (bareAvMatch != null) {
      return VideoIdResult(avid: int.parse(bareAvMatch.group(1)!));
    }

    throw FormatException('Cannot extract video id from: $s');
  }

  // ---------------------------------------------------------------------------
  // Static helpers — WBI signing
  // ---------------------------------------------------------------------------

  /// Derives the 32-character mixin key from [imgKey] and [subKey] using the
  /// WBI permutation table.
  static String getMixinKey(String imgKey, String subKey) {
    final raw = imgKey + subKey; // 64-char string expected
    final buffer = StringBuffer();
    for (final idx in _wbiMixinKeyTable) {
      if (idx < raw.length) {
        buffer.write(raw[idx]);
      }
    }
    return buffer.toString().substring(0, 32);
  }

  /// Signs [params] with [mixinKey] following the WBI algorithm.
  ///
  /// 1. Adds `wts` = current Unix timestamp (seconds).
  /// 2. Sorts params by key.
  /// 3. Removes characters `!'()*` from each value.
  /// 4. URL-encodes, concatenates, appends mixinKey, MD5 → `w_rid`.
  ///
  /// Returns a new map containing all original params plus `wts` and `w_rid`.
  static Map<String, String> signParams(
    Map<String, String> params,
    String mixinKey, {
    int? wtsOverride, // for testing deterministic output
  }) {
    final wts = wtsOverride ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final combined = Map<String, String>.from(params)
      ..['wts'] = wts.toString();

    // Sort by key
    final sortedKeys = combined.keys.toList()..sort();

    // Build query string: remove !'()* from values
    final stripped = sortedKeys.map((k) {
      final v = combined[k]!.replaceAll(RegExp(r"[!'()*]"), '');
      return '${Uri.encodeQueryComponent(k)}=${Uri.encodeQueryComponent(v)}';
    }).join('&');

    final toHash = stripped + mixinKey;
    final wRid = md5.convert(utf8.encode(toHash)).toString();

    return {
      ...combined,
      'w_rid': wRid,
    };
  }

  // ---------------------------------------------------------------------------
  // Instance methods
  // ---------------------------------------------------------------------------

  /// Resolves a b23.tv short link and returns the full URL.
  Future<String> resolveShortLink(String shortUrl) async {
    // Follow redirects manually so we can capture the final URL.
    final response = await _dio.get<dynamic>(
      shortUrl,
      options: Options(
        followRedirects: false,
        validateStatus: (status) => status != null && status < 400,
      ),
    );
    final location = response.headers['location']?.first;
    if (location == null) {
      throw Exception('No redirect location for short link: $shortUrl');
    }
    return location;
  }

  /// Fetches and stores the BUVID3/BUVID4 cookies required by some APIs.
  Future<void> fetchBuvid() async {
    await _dio.get<dynamic>(_apiBuvid);
  }

  /// Injects external [cookies] (e.g. from QR-code login) into the cookie jar.
  Future<void> setCookies(String domain, List<Cookie> cookies) async {
    await _cookieJar.saveFromResponse(
      Uri.parse('https://$domain'),
      cookies,
    );
  }

  /// Fetches fresh WBI img/sub keys from the nav endpoint and caches them.
  Future<void> refreshWbiKeys() async {
    final response = await _dio.get<Map<String, dynamic>>(_apiNav);
    final data = response.data!['data'] as Map<String, dynamic>;
    final wbiImg = data['wbi_img'] as Map<String, dynamic>;

    String extractKey(String url) {
      final uri = Uri.parse(url);
      return uri.pathSegments.last.split('.').first;
    }

    _imgKey = extractKey(wbiImg['img_url'] as String);
    _subKey = extractKey(wbiImg['sub_url'] as String);
    _cachedMixinKey = getMixinKey(_imgKey!, _subKey!);
  }

  Future<String> _requireMixinKey() async {
    if (_cachedMixinKey == null) {
      await refreshWbiKeys();
    }
    return _cachedMixinKey!;
  }

  /// Fetches video metadata for [bvid] or [avid].
  Future<VideoInfo> fetchVideoInfo({String? bvid, int? avid}) async {
    assert(bvid != null || avid != null, 'Provide bvid or avid');

    final mixinKey = await _requireMixinKey();
    final rawParams = <String, String>{};
    if (bvid != null) rawParams['bvid'] = bvid;
    if (avid != null) rawParams['aid'] = avid.toString();

    final signed = signParams(rawParams, mixinKey);

    Response<Map<String, dynamic>> response;
    try {
      response = await _dio.get<Map<String, dynamic>>(
        _apiVideoInfo,
        queryParameters: signed,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 403 ||
          (e.response?.data != null &&
              (e.response!.data as Map)['code'] == -403)) {
        // Signature stale — refresh and retry once.
        await refreshWbiKeys();
        final retryParams = signParams(rawParams, _cachedMixinKey!);
        response = await _dio.get<Map<String, dynamic>>(
          _apiVideoInfo,
          queryParameters: retryParams,
        );
      } else {
        rethrow;
      }
    }

    return VideoInfo.fromBiliResponse(response.data!);
  }

  /// Fetches the best available audio stream URL for [bvid]/[cid].
  Future<String> fetchAudioStreamUrl({
    required String bvid,
    required int cid,
  }) async {
    final mixinKey = await _requireMixinKey();
    final rawParams = {
      'bvid': bvid,
      'cid': cid.toString(),
      'fnval': '4048',
      'fourk': '1',
      'qn': '125',
      'fnver': '0',
    };
    final signed = signParams(rawParams, mixinKey);

    final response = await _dio.get<Map<String, dynamic>>(
      _apiPlayUrl,
      queryParameters: signed,
    );

    final data = response.data!['data'] as Map<String, dynamic>;

    // Try DASH audio first
    if (data.containsKey('dash')) {
      final dash = data['dash'] as Map<String, dynamic>;
      final audioList = dash['audio'] as List<dynamic>;
      if (audioList.isNotEmpty) {
        final best = audioList[0] as Map<String, dynamic>;
        return best['baseUrl'] as String;
      }
    }

    // Fallback to durl
    final durl = data['durl'] as List<dynamic>;
    return (durl[0] as Map<String, dynamic>)['url'] as String;
  }

  /// Downloads an audio stream from [url] and saves it to [savePath].
  ///
  /// Progress is reported via [onReceiveProgress].
  Future<void> downloadAudio(
    String url,
    String savePath, {
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    await _dio.download(
      url,
      savePath,
      onReceiveProgress: onReceiveProgress,
      options: Options(
        headers: {
          'Referer': _referer,
          'User-Agent': _userAgent,
        },
      ),
    );
  }

  /// Generates a QR code login session.
  ///
  /// Returns a map with keys `url` (QR content) and `qrcode_key`.
  Future<Map<String, String>> generateQrCode() async {
    final response =
        await _dio.get<Map<String, dynamic>>(_apiQrGenerate);
    final data = response.data!['data'] as Map<String, dynamic>;
    return {
      'url': data['url'] as String,
      'qrcode_key': data['qrcode_key'] as String,
    };
  }

  /// Polls the QR code login status for [qrcodeKey].
  ///
  /// Returns the response `data` map which includes `code`:
  /// - `0`:     success (cookies are set)
  /// - `86038`: QR expired
  /// - `86090`: scanned, waiting for confirm
  /// - `86101`: not scanned yet
  Future<Map<String, dynamic>> pollQrCodeLogin(String qrcodeKey) async {
    final response = await _dio.get<Map<String, dynamic>>(
      _apiQrPoll,
      queryParameters: {'qrcode_key': qrcodeKey},
    );
    return response.data!['data'] as Map<String, dynamic>;
  }
}

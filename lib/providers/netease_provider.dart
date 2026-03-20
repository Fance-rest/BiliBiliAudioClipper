import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bilibili_audio_clipper/services/netease_service.dart';

enum UploadState { idle, uploading, done, error }

class NeteaseProvider extends ChangeNotifier {
  final NeteaseService _service;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const _apiUrlKey = 'netease_api_url';
  static const _cookieKey = 'netease_cookie';

  UploadState uploadState = UploadState.idle;
  double uploadProgress = 0;
  String? errorMessage;
  String fileName = '';

  String? qrCodeUrl;
  String? _qrcodeKey;
  String qrLoginStatus = '';
  Timer? _pollTimer;

  NeteaseProvider(this._service);

  bool get isLoggedIn => _service.isLoggedIn;
  String? get nickname => _service.nickname;
  String? get avatarUrl => _service.avatarUrl;
  String? get phone => _service.phone;
  String get baseUrl => _service.baseUrl;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_apiUrlKey) ?? '';
    final savedCookie = await _secureStorage.read(key: _cookieKey);

    debugPrint('[Netease] loadSettings: url=$savedUrl, cookie=${savedCookie != null ? '${savedCookie.substring(0, savedCookie.length.clamp(0, 50))}...' : 'null'}');

    if (savedUrl.isNotEmpty) {
      _service.setBaseUrl(savedUrl);
    }
    if (savedCookie != null && savedCookie.isNotEmpty) {
      _service.setCookieHeader(savedCookie);
    }
    if (savedUrl.isNotEmpty && savedCookie != null && savedCookie.isNotEmpty) {
      try {
        final loggedIn = await _service.checkLoginStatus();
        debugPrint('[Netease] checkLoginStatus result: $loggedIn');
        if (!loggedIn) {
          await _secureStorage.delete(key: _cookieKey);
          _service.setCookieHeader(null);
        }
      } catch (e) {
        debugPrint('[Netease] checkLoginStatus error: $e');
      }
    }
    notifyListeners();
  }

  Future<void> setBaseUrl(String url) async {
    _service.setBaseUrl(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiUrlKey, url);
    notifyListeners();
  }

  Future<void> startQrLogin() async {
    await cancelQrLogin();
    try {
      qrLoginStatus = '正在生成二维码...';
      notifyListeners();
      final result = await _service.generateQrCode();
      qrCodeUrl = result['qrimg']?.isNotEmpty == true ? result['qrimg'] : result['qrurl'];
      _qrcodeKey = result['key'];
      qrLoginStatus = '等待扫码...';
      notifyListeners();
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollQrLogin());
    } catch (e) {
      qrLoginStatus = '生成二维码失败: $e';
      notifyListeners();
    }
  }

  Future<void> _pollQrLogin() async {
    final key = _qrcodeKey;
    if (key == null) {
      return;
    }

    try {
      final data = await _service.pollQrCodeLogin(key);
      final code = data['code'] as int? ?? -1;
      if (code == 803) {
        final cookie = _service.cookieHeader;
        debugPrint('[Netease] QR login success, cookie=${cookie != null ? '${cookie.substring(0, cookie.length.clamp(0, 80))}...' : 'null'}');
        if (cookie != null && cookie.isNotEmpty) {
          await _secureStorage.write(key: _cookieKey, value: cookie);
          debugPrint('[Netease] Cookie saved to secure storage');
        } else {
          debugPrint('[Netease] WARNING: cookie is null/empty, not saved!');
        }
        qrCodeUrl = null;
        _qrcodeKey = null;
        qrLoginStatus = '';
        _pollTimer?.cancel();
        notifyListeners();
        return;
      }
      if (code == 800) {
        qrLoginStatus = '二维码已过期，请重试';
        qrCodeUrl = null;
        _qrcodeKey = null;
        _pollTimer?.cancel();
        notifyListeners();
        return;
      }
      if (code == 802) {
        qrLoginStatus = '已扫码，请在手机上确认';
        notifyListeners();
        return;
      }
      qrLoginStatus = '等待扫码...';
      notifyListeners();
    } catch (e) {
      qrLoginStatus = '扫码登录失败: $e';
      qrCodeUrl = null;
      _qrcodeKey = null;
      _pollTimer?.cancel();
      notifyListeners();
    }
  }

  Future<void> cancelQrLogin() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    _qrcodeKey = null;
    qrCodeUrl = null;
    qrLoginStatus = '';
    notifyListeners();
  }

  Future<void> logout() async {
    await _service.logout();
    await _secureStorage.delete(key: _cookieKey);
    await cancelQrLogin();
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
      await _service.uploadToCloud(filePath, '$actualFileName.m4a', onProgress: (sent, total) {
        if (total > 0) {
          uploadProgress = sent / total;
          notifyListeners();
        }
      });
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

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

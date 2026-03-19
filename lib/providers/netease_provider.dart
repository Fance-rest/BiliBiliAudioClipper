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

  Future<void> sendCaptcha(String phone) async => _service.sendCaptcha(phone);
  Future<void> login(String phone, String captcha) async { await _service.login(phone, captcha); notifyListeners(); }
  Future<void> logout() async { await _service.logout(); notifyListeners(); }

  void setFileName(String name) { fileName = name; notifyListeners(); }

  Future<void> upload(String filePath) async {
    uploadState = UploadState.uploading;
    uploadProgress = 0;
    errorMessage = null;
    notifyListeners();
    try {
      final actualFileName = fileName.isEmpty ? 'audio' : fileName;
      await _service.uploadToCloud(filePath, '$actualFileName.m4a', onProgress: (sent, total) {
        if (total > 0) { uploadProgress = sent / total; notifyListeners(); }
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
    if (await file.exists()) await file.delete();
  }

  void resetUpload() { uploadState = UploadState.idle; uploadProgress = 0; errorMessage = null; notifyListeners(); }
}

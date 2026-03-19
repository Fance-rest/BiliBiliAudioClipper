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

  Future<void> sendCaptcha(String phone) async {
    final response = await _dio.get('$_baseUrl/captcha/sent', queryParameters: {'phone': phone});
    if (response.data['code'] != 200) throw Exception('发送验证码失败: ${response.data['message'] ?? '未知错误'}');
  }

  Future<void> login(String phone, String captcha) async {
    final response = await _dio.get('$_baseUrl/login/cellphone', queryParameters: {'phone': phone, 'captcha': captcha});
    if (response.data['code'] != 200) throw Exception('登录失败: ${response.data['message'] ?? '账号或验证码错误'}');
    _isLoggedIn = true;
    _phone = phone;
    await _fetchProfile();
  }

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

  Future<void> logout() async {
    try {
      await _dio.get('$_baseUrl/logout');
    } catch (_) {}
    _isLoggedIn = false;
    _nickname = null;
    _avatarUrl = null;
    _phone = null;
  }

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
    if (response.data['code'] != 200) throw Exception('上传失败: ${response.data['message'] ?? '未知错误'}');
  }
}

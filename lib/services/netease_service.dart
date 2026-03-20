import 'package:dio/dio.dart';

class NeteaseService {
  final Dio _dio;
  String _baseUrl;
  String? _cookieHeader;
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
  String get baseUrl => _baseUrl;
  String? get cookieHeader => _cookieHeader;

  void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  void setCookieHeader(String? cookie) {
    _cookieHeader = (cookie == null || cookie.trim().isEmpty) ? null : cookie.trim();
  }

  void _requireBaseUrl() {
    if (_baseUrl.isEmpty) {
      throw StateError('请先设置网易云 API 服务地址');
    }
  }

  Options _requestOptions() {
    final headers = <String, dynamic>{};
    if (_cookieHeader != null) {
      headers['Cookie'] = _cookieHeader!;
    }
    return Options(headers: headers);
  }

  Map<String, dynamic> _responseMap(Response<dynamic> response) {
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    throw StateError('网易云 API 返回了无法识别的数据格式');
  }

  Exception _mapDioException(DioException error, String fallbackMessage) {
    final response = error.response;
    if (response != null) {
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final msg = data['msg'] ?? data['message'];
        final detail = data['detail'];
        if (msg != null && detail != null) {
          return Exception('$fallbackMessage: $msg ($detail)');
        }
        if (msg != null) {
          return Exception('$fallbackMessage: $msg');
        }
      } else if (data is Map) {
        final mapped = data.map((key, value) => MapEntry(key.toString(), value));
        final msg = mapped['msg'] ?? mapped['message'];
        final detail = mapped['detail'];
        if (msg != null && detail != null) {
          return Exception('$fallbackMessage: $msg ($detail)');
        }
        if (msg != null) {
          return Exception('$fallbackMessage: $msg');
        }
      }
      return Exception('$fallbackMessage: HTTP ${response.statusCode}');
    }
    return Exception('$fallbackMessage: ${error.message ?? error.type.name}');
  }

  Future<Map<String, String>> generateQrCode() async {
    _requireBaseUrl();

    final keyResponse = await _dio.get(
      '$_baseUrl/login/qr/key',
      options: _requestOptions(),
    );
    final keyData = _responseMap(keyResponse);
    final key = keyData['data']?['unikey'] as String?;
    if (key == null || key.isEmpty) {
      throw StateError('生成网易云扫码 key 失败');
    }

    final qrResponse = await _dio.get(
      '$_baseUrl/login/qr/create',
      queryParameters: {'key': key, 'qrimg': true},
      options: _requestOptions(),
    );
    final qrData = _responseMap(qrResponse);
    final qrUrl = qrData['data']?['qrurl'] as String?;
    final qrImg = qrData['data']?['qrimg'] as String?;
    if (qrUrl == null || qrUrl.isEmpty) {
      throw StateError('生成网易云二维码失败');
    }

    return {
      'key': key,
      'qrurl': qrUrl,
      'qrimg': qrImg ?? '',
    };
  }

  Future<Map<String, dynamic>> pollQrCodeLogin(String key) async {
    _requireBaseUrl();

    final response = await _dio.get(
      '$_baseUrl/login/qr/check',
      queryParameters: {
        'key': key,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      options: _requestOptions(),
    );
    final data = _responseMap(response);
    if (data['code'] == 803) {
      final cookie = data['cookie'] as String?;
      if (cookie != null && cookie.isNotEmpty) {
        setCookieHeader(cookie);
      }
      _isLoggedIn = true;
      await _fetchProfile();
    }
    return data;
  }

  Future<void> sendCaptcha(String phone) async {
    _requireBaseUrl();
    final response = await _dio.get(
      '$_baseUrl/captcha/sent',
      queryParameters: {'phone': phone},
      options: _requestOptions(),
    );
    if (response.data['code'] != 200) {
      throw Exception('发送验证码失败: ${response.data['message'] ?? '未知错误'}');
    }
  }

  Future<void> login(String phone, String captcha) async {
    _requireBaseUrl();
    final response = await _dio.get(
      '$_baseUrl/login/cellphone',
      queryParameters: {'phone': phone, 'captcha': captcha},
      options: _requestOptions(),
    );
    if (response.data['code'] != 200) {
      throw Exception('登录失败: ${response.data['message'] ?? '账号或验证码错误'}');
    }
    _isLoggedIn = true;
    _phone = phone;
    await _fetchProfile();
  }

  Future<bool> checkLoginStatus() async {
    _requireBaseUrl();
    try {
      final params = <String, dynamic>{
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      if (_cookieHeader != null) {
        params['cookie'] = _cookieHeader!;
      }
      final response = await _dio.get(
        '$_baseUrl/login/status',
        queryParameters: params,
        options: _requestOptions(),
      );
      final data = _responseMap(response);
      final profile = data['data']?['profile'];
      if (profile != null) {
        _isLoggedIn = true;
        _nickname = profile['nickname'] as String?;
        _avatarUrl = profile['avatarUrl'] as String?;
        return true;
      }
    } catch (_) {}
    _isLoggedIn = false;
    return false;
  }

  Future<void> _fetchProfile() async {
    try {
      final params = <String, dynamic>{
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      if (_cookieHeader != null) {
        params['cookie'] = _cookieHeader!;
      }
      final response = await _dio.get(
        '$_baseUrl/login/status',
        queryParameters: params,
        options: _requestOptions(),
      );
      final data = _responseMap(response);
      final profile = data['data']?['profile'];
      if (profile != null) {
        _nickname = profile['nickname'] as String?;
        _avatarUrl = profile['avatarUrl'] as String?;
      }
    } catch (_) {}
  }

  Future<void> logout() async {
    try {
      await _dio.get(
        '$_baseUrl/logout',
        options: _requestOptions(),
      );
    } catch (_) {}
    _isLoggedIn = false;
    _nickname = null;
    _avatarUrl = null;
    _phone = null;
    _cookieHeader = null;
  }

  Future<void> uploadToCloud(
    String filePath,
    String fileName, {
    void Function(int sent, int total)? onProgress,
  }) async {
    _requireBaseUrl();
    final formData = FormData.fromMap({
      'songFile': await MultipartFile.fromFile(
        filePath,
        filename: fileName,
        contentType: DioMediaType('audio', 'mp4'),
      ),
    });
    try {
      final params = <String, dynamic>{
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      if (_cookieHeader != null) {
        params['cookie'] = _cookieHeader!;
      }
      final response = await _dio.post(
        '$_baseUrl/cloud',
        data: formData,
        queryParameters: params,
        options: _requestOptions(),
        onSendProgress: onProgress,
      );
      if (response.data['code'] != 200) {
        throw Exception('上传失败: ${response.data['message'] ?? response.data['msg'] ?? '未知错误'}');
      }
    } on DioException catch (e) {
      throw _mapDioException(e, '上传失败');
    }
  }
}

import 'package:flutter/services.dart';

class AudioService {
  static const _channel = MethodChannel('com.biliaudioclipper/audio_trimmer');

  static String formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    final millis = (d.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds.$millis';
  }

  static void validateTrimRange(Duration start, Duration end, Duration total) {
    if (start >= end) throw ArgumentError('开始时间必须小于结束时间');
    if (end > total) throw ArgumentError('结束时间不能超过音频总时长');
    if (start < Duration.zero) throw ArgumentError('开始时间不能为负数');
  }

  Future<String> trimAudio({
    required String inputPath,
    required String outputPath,
    required Duration start,
    required Duration end,
  }) async {
    final result = await _channel.invokeMethod<String>('trimAudio', {
      'inputPath': inputPath,
      'outputPath': outputPath,
      'startUs': start.inMicroseconds,
      'endUs': end.inMicroseconds,
    });
    if (result == null) throw Exception('裁剪失败');
    return result;
  }
}

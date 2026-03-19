import 'package:flutter_test/flutter_test.dart';
import 'package:bilibili_audio_clipper/services/audio_service.dart';

void main() {
  group('AudioService', () {
    test('formatDuration converts Duration to FFmpeg time string', () {
      expect(AudioService.formatDuration(const Duration(minutes: 1, seconds: 23)), '00:01:23.000');
    });
    test('formatDuration handles hours', () {
      expect(AudioService.formatDuration(const Duration(hours: 1, minutes: 5, seconds: 30)), '01:05:30.000');
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
      AudioService.validateTrimRange(
        const Duration(minutes: 1),
        const Duration(minutes: 5),
        const Duration(minutes: 10),
      );
    });
  });
}

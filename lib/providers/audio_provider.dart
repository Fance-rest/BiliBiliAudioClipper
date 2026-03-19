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
  int startMinutes = 0;
  int startSeconds = 0;
  int endMinutes = 0;
  int endSeconds = 0;
  TrimState trimState = TrimState.idle;
  String? trimmedFilePath;
  String? errorMessage;

  AudioProvider(this._service) {
    _player.positionStream.listen((pos) { currentPosition = pos; notifyListeners(); });
    _player.durationStream.listen((dur) {
      totalDuration = dur;
      if (dur != null) { endMinutes = dur.inMinutes; endSeconds = dur.inSeconds % 60; }
      notifyListeners();
    });
    _player.playerStateStream.listen((state) { isPlaying = state.playing; notifyListeners(); });
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

  void markStart() { startMinutes = currentPosition.inMinutes; startSeconds = currentPosition.inSeconds % 60; notifyListeners(); }
  void markEnd() { endMinutes = currentPosition.inMinutes; endSeconds = currentPosition.inSeconds % 60; notifyListeners(); }
  void setStartTime(int minutes, int seconds) { startMinutes = minutes; startSeconds = seconds; notifyListeners(); }
  void setEndTime(int minutes, int seconds) { endMinutes = minutes; endSeconds = seconds; notifyListeners(); }

  Future<void> trimAudio(String inputPath) async {
    if (totalDuration == null) return;
    trimState = TrimState.trimming;
    errorMessage = null;
    notifyListeners();
    try {
      AudioService.validateTrimRange(startTime, endTime, totalDuration!);
      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/trimmed_${DateTime.now().millisecondsSinceEpoch}.m4a';
      trimmedFilePath = await _service.trimAudio(inputPath: inputPath, outputPath: outputPath, start: startTime, end: endTime);
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
    startMinutes = 0; startSeconds = 0;
    endMinutes = 0; endSeconds = 0;
    trimState = TrimState.idle;
    trimmedFilePath = null;
    errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() { _player.dispose(); super.dispose(); }
}

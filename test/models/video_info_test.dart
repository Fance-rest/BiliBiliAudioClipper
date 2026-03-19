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
        bvid: 'BV1test', aid: 1, title: 'test', coverUrl: '',
        duration: const Duration(minutes: 10, seconds: 24), cid: 1,
      );
      expect(info.durationText, '10:24');
    });
  });
}

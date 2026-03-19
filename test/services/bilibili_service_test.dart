import 'package:flutter_test/flutter_test.dart';
import 'package:bilibili_audio_clipper/services/bilibili_service.dart';

void main() {
  group('BilibiliService.extractVideoId', () {
    test('parses full bilibili URL with BV id', () {
      final result = BilibiliService.extractVideoId(
          'https://www.bilibili.com/video/BV1xx411c7mD');
      expect(result.bvid, 'BV1xx411c7mD');
      expect(result.avid, isNull);
    });

    test('parses full bilibili URL with AV id', () {
      final result = BilibiliService.extractVideoId(
          'https://www.bilibili.com/video/av12345');
      expect(result.avid, 12345);
      expect(result.bvid, isNull);
    });

    test('parses bare BV id', () {
      final result = BilibiliService.extractVideoId('BV1xx411c7mD');
      expect(result.bvid, 'BV1xx411c7mD');
    });

    test('parses bare AV number (lowercase)', () {
      final result = BilibiliService.extractVideoId('av99999');
      expect(result.avid, 99999);
    });

    test('parses bare AV number (uppercase)', () {
      final result = BilibiliService.extractVideoId('AV42');
      expect(result.avid, 42);
    });

    test('throws FormatException for short link', () {
      expect(
        () => BilibiliService.extractVideoId('https://b23.tv/AbCdEf'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException for invalid input', () {
      expect(
        () => BilibiliService.extractVideoId('not_a_valid_id'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('BilibiliService.isShortLink', () {
    test('returns true for b23.tv HTTPS URL', () {
      expect(
          BilibiliService.isShortLink('https://b23.tv/AbCdEf'), isTrue);
    });

    test('returns true for b23.tv HTTP URL', () {
      expect(BilibiliService.isShortLink('http://b23.tv/xyz'), isTrue);
    });

    test('returns false for full bilibili URL', () {
      expect(
        BilibiliService.isShortLink(
            'https://www.bilibili.com/video/BV1xx411c7mD'),
        isFalse,
      );
    });

    test('returns false for bare BV id', () {
      expect(BilibiliService.isShortLink('BV1xx411c7mD'), isFalse);
    });
  });

  group('BilibiliService.getMixinKey', () {
    test('applies permutation table and returns 32 chars', () {
      // Use a deterministic 64-char combined string.
      const imgKey = '0123456789abcdef0123456789abcdef'; // 32 chars
      const subKey = 'fedcba9876543210fedcba9876543210'; // 32 chars
      final key = BilibiliService.getMixinKey(imgKey, subKey);
      expect(key.length, 32);

      // Manually verify a few permuted positions against the table.
      // raw = imgKey + subKey (64 chars)
      final raw = imgKey + subKey;
      // The permutation table starts: [46,47,18,2,...]
      // So key[0] = raw[46], key[1] = raw[47], key[2] = raw[18], key[3] = raw[2]
      const table = [46, 47, 18, 2, 53, 8, 23, 32];
      for (var i = 0; i < table.length; i++) {
        expect(key[i], raw[table[i]], reason: 'Position $i mismatch');
      }
    });
  });

  group('BilibiliService.signParams', () {
    test('adds wts and w_rid to result', () {
      const mixinKey = 'abcdefghijklmnopqrstuvwxyz012345'; // 32 chars
      final params = {'foo': 'bar', 'baz': '42'};
      const fixedWts = 1700000000;
      final signed =
          BilibiliService.signParams(params, mixinKey, wtsOverride: fixedWts);

      expect(signed.containsKey('wts'), isTrue);
      expect(signed['wts'], fixedWts.toString());
      expect(signed.containsKey('w_rid'), isTrue);
      expect(signed['w_rid']!.length, 32); // MD5 hex = 32 chars
    });

    test('w_rid is deterministic for same inputs', () {
      const mixinKey = 'abcdefghijklmnopqrstuvwxyz012345';
      final params = {'video': 'BV1xx', 'cid': '123'};
      const fixedWts = 1700000001;
      final a = BilibiliService.signParams(params, mixinKey,
          wtsOverride: fixedWts);
      final b = BilibiliService.signParams(params, mixinKey,
          wtsOverride: fixedWts);
      expect(a['w_rid'], b['w_rid']);
    });

    test('removes special characters !"\'()* from values', () {
      const mixinKey = 'abcdefghijklmnopqrstuvwxyz012345';
      // Value contains characters that should be stripped.
      final params = {"key": "val!'()*ue"};
      const fixedWts = 1700000002;

      // Compute expected w_rid manually.
      // After stripping !'()* from "val!'()*ue" -> "value"
      // sorted keys: [key, wts]
      // query: key=value&wts=1700000002
      // toHash = "key=value&wts=1700000002" + mixinKey
      // w_rid = md5(toHash)
      final signed = BilibiliService.signParams(params, mixinKey,
          wtsOverride: fixedWts);

      // The w_rid should be an MD5 hex string.
      expect(signed['w_rid'], matches(RegExp(r'^[0-9a-f]{32}$')));

      // Verify determinism with clean value to confirm stripping occurred.
      final cleanParams = {"key": "value"};
      final cleanSigned = BilibiliService.signParams(cleanParams, mixinKey,
          wtsOverride: fixedWts);
      // Both should produce the same w_rid since dirty value strips to "value".
      expect(signed['w_rid'], cleanSigned['w_rid']);
    });

    test('params are sorted by key before signing', () {
      const mixinKey = 'abcdefghijklmnopqrstuvwxyz012345';
      final params1 = {'a': '1', 'b': '2', 'c': '3'};
      final params2 = {'c': '3', 'a': '1', 'b': '2'};
      const fixedWts = 1700000003;
      final s1 = BilibiliService.signParams(params1, mixinKey,
          wtsOverride: fixedWts);
      final s2 = BilibiliService.signParams(params2, mixinKey,
          wtsOverride: fixedWts);
      expect(s1['w_rid'], s2['w_rid']);
    });
  });
}

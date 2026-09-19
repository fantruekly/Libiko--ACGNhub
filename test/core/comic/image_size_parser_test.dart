import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/comic/comic_image.dart';

Uint8List png(int width, int height) {
  final bytes = Uint8List(24);
  bytes.setAll(0, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  bytes.setAll(12, 'IHDR'.codeUnits);
  final data = bytes.buffer.asByteData();
  data.setUint32(16, width);
  data.setUint32(20, height);
  return bytes;
}

Uint8List jpeg(int width, int height, {bool withAppSegment = false}) {
  final bytes = Uint8List(withAppSegment ? 31 : 11);
  bytes.setAll(0, [0xFF, 0xD8]);
  var offset = 2;
  if (withAppSegment) {
    bytes.setAll(2, [0xFF, 0xE0, 0x00, 0x10]);
    offset = 20;
  }
  bytes.setAll(offset, [0xFF, 0xC0, 0x00, 0x11, 0x08]);
  bytes[offset + 5] = (height >> 8) & 0xFF;
  bytes[offset + 6] = height & 0xFF;
  bytes[offset + 7] = (width >> 8) & 0xFF;
  bytes[offset + 8] = width & 0xFF;
  return bytes;
}

Uint8List webpHeader(String fourcc, int length) {
  final bytes = Uint8List(length);
  bytes.setAll(0, 'RIFF'.codeUnits);
  bytes.setAll(8, 'WEBP'.codeUnits);
  bytes.setAll(12, fourcc.codeUnits);
  return bytes;
}

Uint8List webpVp8(int width, int height) {
  final bytes = webpHeader('VP8 ', 30);
  bytes[23] = 0x9D;
  bytes[24] = 0x01;
  bytes[25] = 0x2A;
  bytes[26] = width & 0xFF;
  bytes[27] = (width >> 8) & 0x3F;
  bytes[28] = height & 0xFF;
  bytes[29] = (height >> 8) & 0x3F;
  return bytes;
}

Uint8List webpVp8l(int width, int height) {
  final bytes = webpHeader('VP8L', 25);
  final w = width - 1;
  final h = height - 1;
  bytes[20] = 0x2F;
  bytes[21] = w & 0xFF;
  bytes[22] = ((w >> 8) & 0x3F) | ((h & 0x03) << 6);
  bytes[23] = (h >> 2) & 0xFF;
  bytes[24] = (h >> 10) & 0x0F;
  return bytes;
}

Uint8List webpVp8x(int width, int height) {
  final bytes = webpHeader('VP8X', 30);
  final w = width - 1;
  final h = height - 1;
  bytes[24] = w & 0xFF;
  bytes[25] = (w >> 8) & 0xFF;
  bytes[26] = (w >> 16) & 0xFF;
  bytes[27] = h & 0xFF;
  bytes[28] = (h >> 8) & 0xFF;
  bytes[29] = (h >> 16) & 0xFF;
  return bytes;
}

void main() {
  group('parseImageSize', () {
    test('reads PNG IHDR dimensions', () {
      expect(parseImageSize(png(800, 600)), const Size(800, 600));
    });

    test('reads JPEG SOF dimensions', () {
      expect(parseImageSize(jpeg(1024, 768)), const Size(1024, 768));
    });

    test('skips preceding JPEG segments', () {
      expect(
        parseImageSize(jpeg(320, 200, withAppSegment: true)),
        const Size(320, 200),
      );
    });

    test('reads lossy WebP (VP8) dimensions', () {
      expect(parseImageSize(webpVp8(640, 480)), const Size(640, 480));
    });

    test('reads lossless WebP (VP8L) dimensions', () {
      expect(parseImageSize(webpVp8l(4, 3)), const Size(4, 3));
    });

    test('reads extended WebP (VP8X) dimensions', () {
      expect(parseImageSize(webpVp8x(1920, 1080)), const Size(1920, 1080));
    });

    test('returns null for unknown or truncated data', () {
      expect(parseImageSize(Uint8List(0)), isNull);
      expect(parseImageSize(Uint8List.fromList(List.filled(64, 0x42))), isNull);
      expect(parseImageSize(Uint8List.fromList([0xFF, 0xD8])), isNull);
      expect(parseImageSize(Uint8List(16)), isNull);
    });
  });

  group('medianRatio', () {
    test('returns the middle value for an odd count', () {
      expect(medianRatio([1.0, 1.6, 2.0]), 1.6);
    });

    test('averages the two middle values for an even count', () {
      expect(medianRatio([1.0, 1.5, 2.0, 2.5]), 1.75);
    });

    test('falls back when nothing is known', () {
      expect(medianRatio(const []), 1.4);
      expect(medianRatio([0.0, double.nan, -1.0]), 1.4);
    });

    test('ignores non-positive and non-finite entries', () {
      expect(medianRatio([0.0, 1.0, 3.0, double.infinity]), 2.0);
    });
  });
}

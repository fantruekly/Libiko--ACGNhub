import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/modules/anime/player_gestures.dart';

void main() {
  group('tapZoneFor', () {
    test('splits the width into thirds', () {
      expect(tapZoneFor(0, 300), TapZone.left);
      expect(tapZoneFor(99, 300), TapZone.left);
      expect(tapZoneFor(100, 300), TapZone.center);
      expect(tapZoneFor(199, 300), TapZone.center);
      expect(tapZoneFor(200, 300), TapZone.right);
      expect(tapZoneFor(300, 300), TapZone.right);
    });

    test('falls back to center for a non-positive width', () {
      expect(tapZoneFor(10, 0), TapZone.center);
      expect(tapZoneFor(10, -5), TapZone.center);
    });
  });

  group('seekTarget', () {
    test('adds the delta', () {
      expect(
        seekTarget(const Duration(seconds: 10), 15, const Duration(seconds: 100)),
        const Duration(seconds: 25),
      );
    });

    test('clamps at zero', () {
      expect(
        seekTarget(const Duration(seconds: 5), -15, const Duration(seconds: 100)),
        Duration.zero,
      );
    });

    test('clamps at the duration', () {
      expect(
        seekTarget(const Duration(seconds: 95), 15, const Duration(seconds: 100)),
        const Duration(seconds: 100),
      );
    });

    test('only clamps the lower bound when the duration is unknown', () {
      expect(
        seekTarget(const Duration(seconds: 10), 15, Duration.zero),
        const Duration(seconds: 25),
      );
    });
  });

  group('formatDuration', () {
    test('formats minutes and seconds', () {
      expect(formatDuration(Duration.zero), '00:00');
      expect(formatDuration(const Duration(seconds: 5)), '00:05');
      expect(formatDuration(const Duration(seconds: 65)), '01:05');
    });

    test('formats hours', () {
      expect(formatDuration(const Duration(seconds: 3661)), '1:01:01');
      expect(formatDuration(const Duration(seconds: 3600)), '1:00:00');
    });

    test('treats negative durations as zero', () {
      expect(formatDuration(const Duration(seconds: -5)), '00:00');
    });
  });
}

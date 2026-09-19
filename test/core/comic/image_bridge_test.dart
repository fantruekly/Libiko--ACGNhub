import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/comic/image_bridge.dart';

void main() {
  test('fillImageRangeAt copies a rectangle', () {
    final src = RgbaImage(2, 2, Uint8List.fromList(List.generate(16, (i) => i)));
    final dst = RgbaImage(2, 2, Uint8List(16));
    fillImageRangeAt(dst, 0, 0, src, 0, 0, 2, 2);
    expect(dst.data, src.data);
  });

  test('fillImageRangeAt handles a sub-rectangle offset', () {
    final src = RgbaImage(2, 2, Uint8List.fromList(List.generate(16, (i) => i)));
    final dst = RgbaImage(2, 2, Uint8List(16));
    fillImageRangeAt(dst, 1, 1, src, 0, 0, 1, 1);
    expect(dst.data.sublist((1 * 2 + 1) * 4, (1 * 2 + 1) * 4 + 4), [0, 1, 2, 3]);
  });
}

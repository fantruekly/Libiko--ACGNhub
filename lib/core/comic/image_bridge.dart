import 'dart:typed_data';

/// An in-memory RGBA8888 image used by the JS `Image` API.
class RgbaImage {
  final int width;
  final int height;
  final Uint8List data;
  RgbaImage(this.width, this.height, this.data);
}

/// Copies the [w]x[h] rectangle at ([sx],[sy]) of [src] to ([dx],[dy]) of [dst].
void fillImageRangeAt(RgbaImage dst, int dx, int dy, RgbaImage src, int sx,
    int sy, int w, int h) {
  for (var row = 0; row < h; row++) {
    final dyRow = dy + row;
    final syRow = sy + row;
    if (dyRow < 0 || dyRow >= dst.height || syRow < 0 || syRow >= src.height) {
      continue;
    }
    for (var col = 0; col < w; col++) {
      final dxCol = dx + col;
      final sxCol = sx + col;
      if (dxCol < 0 || dxCol >= dst.width || sxCol < 0 || sxCol >= src.width) {
        continue;
      }
      final di = (dyRow * dst.width + dxCol) * 4;
      final si = (syRow * src.width + sxCol) * 4;
      for (var c = 0; c < 4; c++) {
        dst.data[di + c] = src.data[si + c];
      }
    }
  }
}

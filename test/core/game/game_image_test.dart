import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/game/game_image.dart';

void main() {
  test('selects the referer by host', () {
    expect(gameImageHeadersFor('https://pan.nekogal.top/f/x.jpg')['Referer'],
        'https://www.nekogal.com/');
    expect(gameImageHeadersFor('https://www.nekogal.com/x.jpg')['Referer'],
        'https://www.nekogal.com/');
    expect(
        gameImageHeadersFor('https://game.galgamezywz.org/x.jpg')['Referer'],
        'https://game.galgamezywz.org/');
    expect(gameImageHeadersFor(null)['Referer'],
        'https://game.galgamezywz.org/');
  });
}

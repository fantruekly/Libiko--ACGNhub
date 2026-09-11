import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/video/gimy_source.dart';

void main() {
  test('parseSearch extracts title and /vod/ detail URL', () {
    const html = '''
    <div class="result">
      <a href="/vod/247676.html">葬送的芙莉莲</a>
    </div>''';

    final items = GimySource.parseSearch(html);
    expect(items, hasLength(1));
    expect(items.first.id, '247676');
    expect(items.first.title, '葬送的芙莉莲');
    expect(items.first.detailUrl, 'https://gimy.tv/vod/247676.html');
  });

  test('parseEpisodes extracts ordered /ep- play links', () {
    const html = '''
    <div class="playlist">
      <a href="/ep-247676-1-1.html">第1集</a>
      <a href="/ep-247676-1-2.html">第2集</a>
    </div>''';

    final eps = GimySource.parseEpisodes(html, 'https://gimy.tv');
    expect(eps, hasLength(2));
    expect(eps[0].index, 0);
    expect(eps[0].playUrl, 'https://gimy.tv/ep-247676-1-1.html');
    expect(eps[1].title, '第2集');
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/novel/models.dart';

void main() {
  test('Novel round-trips through JSON', () {
    const novel = Novel(
      id: '2059',
      title: '安达与岛村',
      author: '入间人间',
      coverUrl: 'https://x/2059s.jpg',
      tags: ['电击文库'],
      summary: '简介',
      extra: {'url': '/novel/2059.html'},
    );
    final restored = Novel.fromJson(
      json.decode(json.encode(novel.toJson())) as Map<String, dynamic>,
    );
    expect(restored.id, '2059');
    expect(restored.title, '安达与岛村');
    expect(restored.author, '入间人间');
    expect(restored.coverUrl, 'https://x/2059s.jpg');
    expect(restored.tags, ['电击文库']);
    expect(restored.summary, '简介');
    expect(restored.extra['url'], '/novel/2059.html');
  });

  test('Novel.fromJson tolerates missing optional fields', () {
    final n = Novel.fromJson(const {'id': '1', 'title': 'T'});
    expect(n.author, isNull);
    expect(n.coverUrl, isNull);
    expect(n.tags, isEmpty);
    expect(n.extra, isEmpty);
  });

  test('NovelBrowseGroup holds labeled options', () {
    const g = NovelBrowseGroup(label: '文库', options: [
      NovelBrowseOption(key: 'dengekibunko', label: '电击'),
    ]);
    expect(g.label, '文库');
    expect(g.options.single.key, 'dengekibunko');
    expect(g.options.single.label, '电击');
  });

  test('NovelDetail holds volumes with chapter refs', () {
    const detail = NovelDetail(
      novel: Novel(id: '5340', title: 'T'),
      volumes: [
        NovelVolume(title: '正文', url: 'https://x/vol_1.html', chapters: [
          NovelChapterRef(id: '333607', title: '封面'),
        ]),
      ],
    );
    expect(detail.volumes.single.title, '正文');
    expect(detail.volumes.single.chapters.single.id, '333607');
    expect(detail.volumes.single.chapters.single.title, '封面');
  });
}

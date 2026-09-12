import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/metadata/jikan_provider.dart';

void main() {
  test('parseList maps a Jikan response to Work items', () {
    final data = {
      'data': [
        {
          'mal_id': 52991,
          'title': 'Sousou no Frieren',
          'title_english': 'Frieren: Beyond Journey\'s End',
          'title_japanese': '葬送のフリーレン',
          'images': {
            'jpg': {
              'image_url': 'https://cdn/x.jpg',
              'large_image_url': 'https://cdn/x-l.jpg'
            },
          },
          'synopsis': '<p>A mage <i>journeys</i>.</p>',
          'genres': [
            {'name': 'Adventure'},
            {'name': 'Drama'},
          ],
          'studios': [
            {'name': 'Madhouse'},
          ],
          'episodes': 28,
          'score': 9.3,
          'status': 'Finished Airing',
          'year': 2023,
        }
      ]
    };

    final works = JikanProvider.parseList(data);

    expect(works, hasLength(1));
    final w = works.first;
    expect(w.id, 'jikan_52991');
    expect(w.title, 'Sousou no Frieren');
    expect(w.coverUrl, 'https://cdn/x-l.jpg');
    expect(w.summary, 'A mage journeys.');
    expect(w.tags, ['Adventure', 'Drama']);
    expect(w.malId, 52991);
    expect(w.extra['score'], 9.3);
    expect(w.extra['episodes'], 28);
    expect(w.extra['seasonYear'], 2023);
  });
}

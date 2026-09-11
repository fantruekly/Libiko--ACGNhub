import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/metadata/anilist_provider.dart';

void main() {
  final media = {
    'id': 21,
    'title': {'romaji': 'ONE PIECE', 'english': 'One Piece', 'native': 'ワンピース'},
    'coverImage': {'extraLarge': 'https://img/xl.jpg', 'large': 'https://img/l.jpg'},
    'bannerImage': 'https://img/banner.jpg',
    'description': 'A pirate <i>adventure</i>.',
    'genres': ['Action', 'Adventure'],
    'episodes': 1000,
    'duration': 24,
    'status': 'RELEASING',
    'season': 'FALL',
    'seasonYear': 1999,
    'format': 'TV',
    'averageScore': 88,
    'studios': {'nodes': [{'name': 'Toei Animation'}]},
  };

  test('parsePage maps AniList media to Work items', () {
    final works = AniListProvider.parsePage({
      'Page': {'media': [media]}
    });

    expect(works, hasLength(1));
    final w = works.first;
    expect(w.id, 'anilist_21');
    expect(w.title, 'ワンピース');
    expect(w.coverUrl, 'https://img/xl.jpg');
    expect(w.bannerUrl, 'https://img/banner.jpg');
    expect(w.summary, 'A pirate adventure.');
    expect(w.tags, ['Action', 'Adventure']);
    expect(w.anilistId, 21);
    expect(w.extra['score'], closeTo(8.8, 0.001));
    expect(w.extra['episodes'], 1000);
    expect(w.extra['seasonYear'], 1999);
    expect(w.extra['format'], 'TV');
    expect(w.extra['studios'], ['Toei Animation']);
  });

  test('parseAiring reads nested media', () {
    final works = AniListProvider.parseAiring({
      'Page': {
        'airingSchedules': [
          {'airingAt': 123, 'episode': 5, 'media': media}
        ]
      }
    });
    expect(works.single.id, 'anilist_21');
  });
}

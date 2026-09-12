class AnimeActor {
  final String name;
  final String? image;

  const AnimeActor({required this.name, this.image});
}

class AnimeCharacter {
  final String name;
  final String? relation;
  final String? image;
  final List<AnimeActor> actors;

  const AnimeCharacter({
    required this.name,
    this.relation,
    this.image,
    this.actors = const [],
  });
}

class RelatedWork {
  final int bangumiId;
  final String title;
  final String? relation;
  final String? image;

  const RelatedWork({
    required this.bangumiId,
    required this.title,
    this.relation,
    this.image,
  });
}

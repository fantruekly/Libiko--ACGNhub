import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/comic/comic_source.dart';
import 'package:libiko/core/comic/models.dart';
import 'package:libiko/modules/comic/comic_providers.dart';

class _FakeManager extends ComicSourceManager {
  _FakeManager(this._byKey, {this.throwKeys = const <String>{}});
  final Map<String, List<Comic>> _byKey;
  final Set<String> throwKeys;

  @override
  Future<List<Comic>> search(ComicSource source, String keyword,
      {int page = 1}) async {
    if (throwKeys.contains(source.key)) throw StateError('boom ${source.key}');
    return _byKey[source.key] ?? const [];
  }
}

ComicSource _source(String key) =>
    ComicSource(name: key, key: key, version: '1.0.0', canSearch: true);

ProviderContainer _container(
        ComicSourceManager manager, List<ComicSource> sources) =>
    ProviderContainer(overrides: [
      comicSourceManagerProvider.overrideWithValue(manager),
      comicSourcesProvider.overrideWith((ref) async => sources),
    ]);

void main() {
  test('maps comics with the source key', () async {
    final container = _container(
      _FakeManager({
        'a': [const Comic(id: '1', title: 'A1')],
      }),
      [_source('a')],
    );
    addTearDown(container.dispose);
    final results =
        await container.read(comicSearchSourceProvider(('a', 'x')).future);
    expect(results.single.comic.title, 'A1');
    expect(results.single.sourceKey, 'a');
  });

  test('a blank keyword is empty', () async {
    final container = _container(_FakeManager(const {}), [_source('a')]);
    addTearDown(container.dispose);
    expect(await container.read(comicSearchSourceProvider(('a', '  ')).future),
        isEmpty);
  });

  test('an unknown source is empty', () async {
    final container = _container(_FakeManager(const {}), [_source('a')]);
    addTearDown(container.dispose);
    expect(
        await container.read(comicSearchSourceProvider(('zzz', 'x')).future),
        isEmpty);
  });

  test('a failing source surfaces as an error', () async {
    final container =
        _container(_FakeManager(const {}, throwKeys: {'a'}), [_source('a')]);
    addTearDown(container.dispose);
    expect(container.read(comicSearchSourceProvider(('a', 'x')).future),
        throwsA(isA<StateError>()));
  });
}

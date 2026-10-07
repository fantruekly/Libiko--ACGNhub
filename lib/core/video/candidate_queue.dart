import 'headless_browser.dart';

/// Ordered fallback list of resolved candidates for one episode. The player
/// opens [current] and calls [advance] when playback fails.
class CandidateQueue {
  CandidateQueue([List<MediaCandidate> candidates = const []])
      : _items = List.of(candidates),
        _index = candidates.isEmpty ? -1 : 0;

  final List<MediaCandidate> _items;
  int _index;

  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;
  int get length => _items.length;

  MediaCandidate? get current =>
      (_index >= 0 && _index < _items.length) ? _items[_index] : null;

  bool get hasNext => _index + 1 < _items.length;

  MediaCandidate? advance() {
    if (!hasNext) return null;
    _index++;
    return _items[_index];
  }

  void reset() => _index = _items.isEmpty ? -1 : 0;
}

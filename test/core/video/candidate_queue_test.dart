import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/video/candidate_queue.dart';
import 'package:libiko/core/video/headless_browser.dart';

void main() {
  test('starts at the first candidate', () {
    final queue = CandidateQueue(const [
      MediaCandidate('https://a.m3u8'),
      MediaCandidate('https://b.m3u8'),
    ]);
    expect(queue.current?.url, 'https://a.m3u8');
    expect(queue.hasNext, isTrue);
  });

  test('advance walks the fallbacks', () {
    final queue = CandidateQueue(const [
      MediaCandidate('https://a.m3u8'),
      MediaCandidate('https://b.m3u8'),
    ]);
    expect(queue.advance()?.url, 'https://b.m3u8');
    expect(queue.hasNext, isFalse);
    expect(queue.advance(), isNull);
    expect(queue.current?.url, 'https://b.m3u8');
  });

  test('an empty queue has no current', () {
    final queue = CandidateQueue();
    expect(queue.isEmpty, isTrue);
    expect(queue.current, isNull);
    expect(queue.hasNext, isFalse);
    expect(queue.advance(), isNull);
  });
}

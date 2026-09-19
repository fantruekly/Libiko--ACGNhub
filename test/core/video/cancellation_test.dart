import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/video/cancellation.dart';

void main() {
  test('is not cancelled initially and reports cancellation', () {
    final token = CancellationToken();
    expect(token.isCancelled, isFalse);
    token.cancel();
    expect(token.isCancelled, isTrue);
  });

  test('fires listeners once and ignores duplicates', () {
    final token = CancellationToken();
    var calls = 0;
    token.addListener(() => calls++);
    token.cancel();
    token.cancel();
    expect(calls, 1);
  });

  test('a listener added after cancellation fires immediately', () {
    final token = CancellationToken()..cancel();
    var calls = 0;
    token.addListener(() => calls++);
    expect(calls, 1);
  });

  test('removed listeners do not fire', () {
    final token = CancellationToken();
    var calls = 0;
    void listener() => calls++;
    token.addListener(listener);
    token.removeListener(listener);
    token.cancel();
    expect(calls, 0);
  });

  test('runs every listener even when one throws', () {
    final token = CancellationToken();
    var second = 0;
    token.addListener(() => throw StateError('boom'));
    token.addListener(() => second++);
    token.cancel();
    expect(second, 1);
  });
}

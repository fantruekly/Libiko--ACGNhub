import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:libiko/core/models/work.dart';
import 'package:libiko/core/storage/database.dart';
import 'package:libiko/core/video/line_preference.dart';

Work work(String id, {String catalog = 'bgm'}) => Work(
    id: id,
    sourceId: catalog,
    sourceName: '',
    type: WorkType.anime,
    title: '同名作品');

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppDatabase.init();
  });
  test(
      'preferences persist per catalog work and source, expire and stay bounded',
      () async {
    var now = DateTime(2026, 1, 1);
    final store = LinePreferenceStore(clock: () => now);
    await store.record(work('1'), 'source-a', 'line-b');
    expect(
        LinePreferenceStore(clock: () => now).preferred(work('1'), 'source-a'),
        'line-b');
    expect(store.preferred(work('2'), 'source-a'), isNull);
    expect(store.preferred(work('1', catalog: 'other'), 'source-a'), isNull);
    expect(store.preferred(work('1'), 'source-b'), isNull);
    now = now.add(const Duration(days: 31));
    expect(store.preferred(work('1'), 'source-a'), isNull);
    for (var i = 2; i < 103; i++) {
      await store.record(work('$i'), 'source-a', 'line-a');
    }
    expect(store.preferred(work('2'), 'source-a'), isNull);
    expect(store.preferred(work('102'), 'source-a'), 'line-a');
  });
  test(
      'video evidence requires a frame, fresh dimensions and continuous progress',
      () {
    final evidence = LinePlaybackEvidence();
    for (var i = 1; i < 8; i++) {
      expect(evidence.progress(Duration(seconds: i), Duration(seconds: i)),
          isFalse);
    }
    evidence.frame = evidence.video = true;
    for (var i = 8; i < 13; i++) {
      expect(evidence.progress(Duration(seconds: i), Duration(seconds: i)),
          isFalse);
    }
    expect(
        evidence.progress(
            const Duration(seconds: 13), const Duration(seconds: 13)),
        isTrue);
    evidence.interrupt();
    expect(
        evidence.progress(
            const Duration(seconds: 14), const Duration(seconds: 14)),
        isFalse);
    expect(
        evidence.progress(
            const Duration(minutes: 5), const Duration(seconds: 15)),
        isFalse);
    // A new candidate cannot inherit the old candidate's frame/parameters.
    final next = LinePlaybackEvidence()..frame = true;
    expect(
        next.progress(const Duration(seconds: 20), const Duration(seconds: 20)),
        isFalse);
  });
}

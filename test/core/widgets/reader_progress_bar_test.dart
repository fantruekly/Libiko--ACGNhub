import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/widgets/reader_progress_bar.dart';

Widget _bar(double progress, {ValueChanged<double>? onSeek}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            height: 200,
            child: ReaderProgressBar(
              progress: progress,
              thumbColor: const Color(0xFF0000FF),
              onSeek: onSeek ?? (_) {},
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('the thumb tracks the progress fraction', (tester) async {
    await tester.pumpWidget(_bar(0.5));
    final thumb = tester
        .getRect(find.byKey(const ValueKey('reader-progress-thumb')));
    final bar = tester.getRect(find.byKey(const ValueKey('reader-progress-bar')));
    expect((thumb.center.dy - bar.top) / bar.height, closeTo(0.5, 0.05));
  });

  testWidgets('a vertical drag reports the fraction', (tester) async {
    double? reported;
    await tester.pumpWidget(_bar(0, onSeek: (v) => reported = v));
    await tester.drag(
        find.byKey(const ValueKey('reader-progress-bar')),
        const Offset(0, 50));
    await tester.pump();
    expect(reported, isNotNull);
    expect(reported!, greaterThan(0.3));
    expect(reported!, lessThan(1.0));
  });

  testWidgets('progress 0 and 1 put the thumb at the ends', (tester) async {
    Future<(double, double)> gaps(double progress) async {
      await tester.pumpWidget(_bar(progress));
      final thumb = tester
          .getRect(find.byKey(const ValueKey('reader-progress-thumb')));
      final bar = tester
          .getRect(find.byKey(const ValueKey('reader-progress-bar')));
      return (thumb.top - bar.top, thumb.bottom - bar.bottom);
    }

    expect((await gaps(0)).$1, closeTo(0, 0.01));
    expect((await gaps(1)).$2, closeTo(0, 0.01));
  });

  testWidgets('the bar has no track and is thin', (tester) async {
    await tester.pumpWidget(_bar(0.5));
    expect(find.byKey(const ValueKey('reader-progress-track')), findsNothing);
    final bar = tester.getRect(find.byKey(const ValueKey('reader-progress-bar')));
    final thumb = tester
        .getRect(find.byKey(const ValueKey('reader-progress-thumb')));
    expect(bar.width, 18);
    expect(thumb.width, 7);
  });
}

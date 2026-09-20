import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/widgets/reader_progress_bar.dart';

void main() {
  testWidgets('the thumb tracks the progress fraction', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            height: 200,
            child: ReaderProgressBar(
              progress: 0.5,
              trackColor: const Color(0x33000000),
              thumbColor: const Color(0xFF0000FF),
              onSeek: (_) {},
            ),
          ),
        ),
      ),
    ));

    final thumb = tester.getRect(
        find.byKey(const ValueKey('reader-progress-thumb')));
    final track = tester.getRect(
        find.byKey(const ValueKey('reader-progress-track')));
    final trackCenter = (thumb.center.dy - track.top) / track.height;
    expect(trackCenter, closeTo(0.5, 0.05));
  });

  testWidgets('a vertical drag reports the fraction', (tester) async {
    double? reported;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            height: 200,
            child: ReaderProgressBar(
              progress: 0,
              trackColor: const Color(0x33000000),
              thumbColor: const Color(0xFF0000FF),
              onSeek: (value) => reported = value,
            ),
          ),
        ),
      ),
    ));

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
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: 200,
              child: ReaderProgressBar(
                progress: progress,
                trackColor: const Color(0x33000000),
                thumbColor: const Color(0xFF0000FF),
                onSeek: (_) {},
              ),
            ),
          ),
        ),
      ));
      final thumb = tester
          .getRect(find.byKey(const ValueKey('reader-progress-thumb')));
      final track = tester
          .getRect(find.byKey(const ValueKey('reader-progress-track')));
      return (thumb.top - track.top, thumb.bottom - track.bottom);
    }

    final (topAtZero, _) = await gaps(0);
    expect(topAtZero, closeTo(0, 0.01));

    final (_, bottomAtOne) = await gaps(1);
    expect(bottomAtOne, closeTo(0, 0.01));
  });

  testWidgets('the bar is thin', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            height: 200,
            child: ReaderProgressBar(
              progress: 0.5,
              trackColor: const Color(0x33000000),
              thumbColor: const Color(0xFF0000FF),
              onSeek: (_) {},
            ),
          ),
        ),
      ),
    ));
    final track =
        tester.getRect(find.byKey(const ValueKey('reader-progress-track')));
    final bar =
        tester.getRect(find.byKey(const ValueKey('reader-progress-bar')));
    expect(track.width, 3);
    expect(bar.width, 18);
  });
}

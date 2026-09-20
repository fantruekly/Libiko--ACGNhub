import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/video/cancellation.dart';
import 'package:libiko/core/video/headless_browser.dart';
import 'package:libiko/modules/anime/resolve_dialog.dart';

Widget _host(Future<MediaCandidate?> Function() resolve, CancellationToken cancel,
    void Function(ResolveDialogResult) onResult) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            onResult(await showResolveDialog(context,
                resolve: resolve(), cancel: cancel));
          },
          child: const Text('go'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('cancelling the dialog cancels the resolve', (tester) async {
    final completer = Completer<MediaCandidate?>();
    final cancel = CancellationToken();
    ResolveDialogResult? result;
    await tester.pumpWidget(_host(() => completer.future, cancel, (r) => result = r));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('resolve-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('resolve-cancel')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(cancel.isCancelled, isTrue);
    expect(result!.cancelled, isTrue);
    expect(result!.stream, isNull);
  });

  testWidgets('completion closes the dialog with the stream', (tester) async {
    final completer = Completer<MediaCandidate?>();
    final cancel = CancellationToken();
    ResolveDialogResult? result;
    await tester.pumpWidget(_host(() => completer.future, cancel, (r) => result = r));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    completer.complete(const MediaCandidate('https://x/y.m3u8'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.byKey(const ValueKey('resolve-dialog')), findsNothing);
    expect(result!.cancelled, isFalse);
    expect(result!.stream!.url, 'https://x/y.m3u8');
    expect(cancel.isCancelled, isFalse);
  });
}

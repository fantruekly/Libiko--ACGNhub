import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/modules/comic/comic_detail_skeleton.dart';

void main() {
  testWidgets('renders a detail-shaped skeleton', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ComicDetailSkeleton()),
    ));
    expect(find.byKey(const ValueKey('comic-detail-skeleton')), findsOneWidget);
    // no multi-column shimmer card grid
    expect(find.byType(GridView), findsNothing);
  });
}

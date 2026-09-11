import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/widgets/rating_stars.dart';

void main() {
  testWidgets('8.5 renders 4 full stars, 1 half star, and the numeric label', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: RatingStars(score: 8.5))));
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
    expect(find.byIcon(Icons.star_half_rounded), findsOneWidget);
    expect(find.text('8.5'), findsOneWidget);
  });

  testWidgets('null renders nothing', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: RatingStars(score: null))));
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('0 renders no filled stars but the numeric label', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: RatingStars(score: 0))));
    expect(find.byIcon(Icons.star_rounded), findsNothing);
    expect(find.text('0.0'), findsOneWidget);
  });
}

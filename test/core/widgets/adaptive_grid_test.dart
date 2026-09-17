import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/widgets/adaptive_grid.dart';

void main() {
  testWidgets('desktop uses a 6-column SliverGrid', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: CustomScrollView(
        slivers: [
          SliverAdaptiveGrid(
            itemCount: 4,
            mobileColumns: 3,
            desktop: true,
            itemBuilder: _cell,
          ),
        ],
      ),
    ));
    expect(find.byType(SliverGrid), findsOneWidget);
    expect(find.byType(SliverMasonryGrid), findsNothing);
    final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 6);
    expect(delegate.mainAxisSpacing, 20);
    expect(delegate.crossAxisSpacing, 16);
    expect(delegate.childAspectRatio, 0.60);
  });

  testWidgets('desktop honours a custom column count', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: CustomScrollView(
        slivers: [
          SliverAdaptiveGrid(
            itemCount: 4,
            mobileColumns: 3,
            desktopColumns: 5,
            desktop: true,
            itemBuilder: _cell,
          ),
        ],
      ),
    ));
    final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 5);
  });

  testWidgets('mobile uses SliverMasonryGrid with the given column count',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: CustomScrollView(
        slivers: [
          SliverAdaptiveGrid(
            itemCount: 4,
            mobileColumns: 3,
            desktop: false,
            itemBuilder: _cell,
          ),
        ],
      ),
    ));
    expect(find.byType(SliverMasonryGrid), findsOneWidget);
    expect(find.byType(SliverGrid), findsNothing);
  });

  testWidgets('box version also switches by platform', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AdaptiveGridView(
        itemCount: 4,
        mobileColumns: 1,
        desktop: false,
        itemBuilder: _cell,
      ),
    ));
    expect(find.byType(MasonryGridView), findsOneWidget);
  });
}

Widget _cell(BuildContext _, int i) =>
    Container(height: 100, color: Colors.blue);

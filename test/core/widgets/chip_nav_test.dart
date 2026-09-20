import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/widgets/chip_nav.dart';

void main() {
  test('steps the inner level within range', () {
    expect(
      stepChipSelection(
          a: 0, aMin: 0, aMax: 1,
          b: 0, bMin: 0, bMax: 1,
          c: 0, cMin: 0, cMax: 2, delta: 1),
      (a: 0, b: 0, c: 1),
    );
  });

  test('inner level at its end falls through to the middle level', () {
    expect(
      stepChipSelection(
          a: 0, aMin: 0, aMax: 1,
          b: 0, bMin: 0, bMax: 1,
          c: 2, cMin: 0, cMax: 2, delta: 1),
      (a: 0, b: 1, c: 0),
    );
  });

  test('middle level at its end falls through to the outer level', () {
    expect(
      stepChipSelection(
          a: 0, aMin: 0, aMax: 1,
          b: 1, bMin: 0, bMax: 1,
          c: 2, cMin: 0, cMax: 2, delta: 1),
      (a: 1, b: 0, c: 0),
    );
  });

  test('outer level at its end returns null', () {
    expect(
      stepChipSelection(
          a: 1, aMin: 0, aMax: 1,
          b: 1, bMin: 0, bMax: 1,
          c: 2, cMin: 0, cMax: 2, delta: 1),
      isNull,
    );
  });

  test('backward from the middle minimum falls through to the outer level', () {
    expect(
      stepChipSelection(
          a: 1, aMin: 0, aMax: 1,
          b: 0, bMin: 0, bMax: 1,
          c: 0, cMin: 0, cMax: 2, delta: -1),
      (a: 0, b: 0, c: 0),
    );
  });

  test('a sentinel middle minimum (-1) is a valid step', () {
    expect(
      stepChipSelection(
          a: 0, aMin: 0, aMax: 1,
          b: 0, bMin: -1, bMax: 2,
          c: 0, cMin: 0, cMax: 0, delta: -1),
      (a: 0, b: -1, c: 0),
    );
  });

  test('a single-value level is skipped', () {
    expect(
      stepChipSelection(
          a: 0, aMin: 0, aMax: 1,
          b: 0, bMin: 0, bMax: 2,
          c: 0, cMin: 0, cMax: 0, delta: 1),
      (a: 0, b: 1, c: 0),
    );
  });
}

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_game_float_geometry.dart';

void main() {
  group('group_game_float_geometry', () {
    const screen = Size(390, 844);
    const child = Size(56, 268);
    const padding = EdgeInsets.fromLTRB(0, 47, 0, 34);

    test('defaultGroupGameFloatOffset anchors bottom-right', () {
      final offset = defaultGroupGameFloatOffset(
        screenSize: screen,
        childSize: child,
        bottomInset: 34,
      );
      expect(offset.dx, 390 - 56 - 12);
      expect(offset.dy, 844 - 268 - 120 - 34);
    });

    test('clampGroupGameFloatOffset keeps panel inside safe area', () {
      final clamped = clampGroupGameFloatOffset(
        offset: const Offset(-100, 9999),
        screenSize: screen,
        childSize: child,
        viewPadding: padding,
        edge: 8,
      );
      expect(clamped.dx, 8);
      expect(clamped.dy, 844 - 268 - 34 - 8);
    });

    test('snap prefers left when center is on left half', () {
      final snapped = snapGroupGameFloatOffsetToHorizontalEdge(
        offset: const Offset(100, 200),
        screenSize: screen,
        childSize: child,
        viewPadding: padding,
        edge: 8,
      );
      expect(snapped.dx, 8);
      expect(snapped.dy, 200);
    });

    test('snap prefers right when center is on right half', () {
      final snapped = snapGroupGameFloatOffsetToHorizontalEdge(
        offset: const Offset(250, 300),
        screenSize: screen,
        childSize: child,
        viewPadding: padding,
        edge: 8,
      );
      expect(snapped.dx, 390 - 56 - 8);
      expect(snapped.dy, 300);
    });
  });
}

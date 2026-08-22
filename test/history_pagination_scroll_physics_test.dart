import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/history_pagination_scroll_physics.dart';

class _FixedMetrics with ScrollMetrics {
  const _FixedMetrics({
    required this.pixels,
    required this.minScrollExtent,
    required this.maxScrollExtent,
  });

  @override
  final double pixels;

  @override
  final double minScrollExtent;

  @override
  final double maxScrollExtent;

  @override
  double get viewportDimension => 600;

  @override
  AxisDirection get axisDirection => AxisDirection.down;

  @override
  bool get outOfRange => false;

  @override
  double get devicePixelRatio => 1;

  @override
  bool get hasContentDimensions => true;

  @override
  bool get hasPixels => true;

  @override
  bool get hasViewportDimension => true;
}

void main() {
  group('HistoryPaginationScrollPhysics', () {
    test('compensates prepend growth when not pinned to old max', () {
      var compensate = true;
      final physics = HistoryPaginationScrollPhysics(
        shouldCompensate: () => compensate,
      );
      final oldPosition = _FixedMetrics(
        pixels: 420,
        minScrollExtent: 0,
        maxScrollExtent: 1200,
      );
      final newPosition = _FixedMetrics(
        pixels: 420,
        minScrollExtent: 0,
        maxScrollExtent: 1800,
      );

      final adjusted = physics.adjustPositionForNewDimensions(
        oldPosition: oldPosition,
        newPosition: newPosition,
        isScrolling: false,
        velocity: 0,
      );

      expect(adjusted, closeTo(1020, 0.01));
    });

    test('does not compensate prepend growth when near top', () {
      var compensate = true;
      final physics = HistoryPaginationScrollPhysics(
        shouldCompensate: () => compensate,
        pinnedNearTopTolerancePx: 160,
      );
      final oldPosition = _FixedMetrics(
        pixels: 1150,
        minScrollExtent: 0,
        maxScrollExtent: 1200,
      );
      final newPosition = _FixedMetrics(
        pixels: 1150,
        minScrollExtent: 0,
        maxScrollExtent: 1800,
      );

      final adjusted = physics.adjustPositionForNewDimensions(
        oldPosition: oldPosition,
        newPosition: newPosition,
        isScrolling: false,
        velocity: 0,
      );

      expect(adjusted, closeTo(1150, 0.01));
    });

    test('does not compensate prepend growth when overscrolling past top', () {
      var compensate = true;
      final physics = HistoryPaginationScrollPhysics(
        shouldCompensate: () => compensate,
        pinnedNearTopTolerancePx: 160,
      );
      const oldPosition = _FixedMetrics(
        pixels: 3688,
        minScrollExtent: 0,
        maxScrollExtent: 3608,
      );
      const newPosition = _FixedMetrics(
        pixels: 3688,
        minScrollExtent: 0,
        maxScrollExtent: 5540,
      );

      final adjusted = physics.adjustPositionForNewDimensions(
        oldPosition: oldPosition,
        newPosition: newPosition,
        isScrolling: false,
        velocity: 0,
      );

      expect(adjusted, closeTo(3688, 0.01));
    });

    test('does not compensate when disabled', () {
      final physics = HistoryPaginationScrollPhysics(
        shouldCompensate: () => false,
      );
      final oldPosition = _FixedMetrics(
        pixels: 420,
        minScrollExtent: 0,
        maxScrollExtent: 1200,
      );
      final newPosition = _FixedMetrics(
        pixels: 420,
        minScrollExtent: 0,
        maxScrollExtent: 1800,
      );

      final adjusted = physics.adjustPositionForNewDimensions(
        oldPosition: oldPosition,
        newPosition: newPosition,
        isScrolling: false,
        velocity: 0,
      );

      expect(adjusted, 420);
    });

    test('computeExtentDeltaRestorePixels matches prepend growth', () {
      final restored = HistoryPaginationScrollPhysics
          .computeExtentDeltaRestorePixels(
        anchorPixels: 22521.44,
        anchorMaxExtent: 22437.92,
        newMaxScrollExtent: 26185.56,
        minScrollExtent: 0,
      );
      expect(restored, closeTo(26185.56, 1.0));
    });

    test('wasOverscrollingPastTop detects iOS bounce past max', () {
      expect(
        HistoryPaginationScrollPhysics.wasOverscrollingPastTop(
          anchorPixels: 22521.44,
          anchorMaxExtent: 22437.92,
        ),
        isTrue,
      );
      expect(
        HistoryPaginationScrollPhysics.wasOverscrollingPastTop(
          anchorPixels: 22437.92,
          anchorMaxExtent: 22437.92,
        ),
        isFalse,
      );
    });
  });
}

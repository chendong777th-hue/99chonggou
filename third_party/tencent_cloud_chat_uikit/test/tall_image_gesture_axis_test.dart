import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/tall_image_scroll_preview.dart';

void main() {
  group('resolveTallImageGestureAxis', () {
    test('stays undecided before slop', () {
      expect(
        resolveTallImageGestureAxis(totalDelta: const Offset(5, 2), slop: 8),
        TallImageGestureAxis.undecided,
      );
    });

    test('locks horizontal only when dx clearly dominates', () {
      expect(
        resolveTallImageGestureAxis(
          totalDelta: const Offset(24, 12),
          slop: 8,
          horizontalDominance: 1.15,
        ),
        TallImageGestureAxis.horizontal,
      );
    });

    test('prefers vertical on near-diagonal swipe', () {
      expect(
        resolveTallImageGestureAxis(
          totalDelta: const Offset(20, 18),
          slop: 8,
          horizontalDominance: 1.15,
        ),
        TallImageGestureAxis.vertical,
      );
    });

    test('locks vertical when dy clearly dominates', () {
      expect(
        resolveTallImageGestureAxis(totalDelta: const Offset(8, 20), slop: 8),
        TallImageGestureAxis.vertical,
      );
    });
  });

  group('resolveTallImageScrollAxis', () {
    test('locks vertical when diagonal is only slightly horizontal', () {
      expect(
        resolveTallImageScrollAxis(totalDelta: const Offset(-8.7, -6.0)),
        TallImageGestureAxis.vertical,
      );
      expect(
        resolveTallImageScrollAxis(totalDelta: const Offset(-17.0, -18.0)),
        TallImageGestureAxis.vertical,
      );
    });

    test('locks horizontal only for near-pure horizontal swipe', () {
      expect(
        resolveTallImageScrollAxis(totalDelta: const Offset(-48, -6)),
        TallImageGestureAxis.horizontal,
      );
    });
  });

  group('tallImageShouldRouteGalleryPage', () {
    test('rejects diagonal swipe at edge', () {
      expect(
        tallImageShouldRouteGalleryPage(
          totalDelta: const Offset(-8.7, -6.0),
          atHorizontalEdge: true,
        ),
        isFalse,
      );
    });

    test('allows pure horizontal swipe at edge', () {
      expect(
        tallImageShouldRouteGalleryPage(
          totalDelta: const Offset(-48, -6),
          atHorizontalEdge: true,
        ),
        isTrue,
      );
    });

    test('allows short near-pure horizontal once past min travel', () {
      // 对齐线上误伤：dx=18 dy=2 曾被拒成竖滑导致闪屏。
      expect(
        tallImageShouldRouteGalleryPage(
          totalDelta: const Offset(18.3, 2.0),
          atHorizontalEdge: true,
        ),
        isTrue,
      );
    });

    test('still rejects too-short horizontal before min travel', () {
      expect(
        tallImageShouldRouteGalleryPage(
          totalDelta: const Offset(10.0, 1.0),
          atHorizontalEdge: true,
        ),
        isFalse,
      );
    });

    test('rejects zoomed diagonal swipe even at edge', () {
      expect(
        tallImageShouldRouteGalleryPage(
          totalDelta: const Offset(-56, -16),
          atHorizontalEdge: true,
          zoomed: true,
        ),
        isFalse,
      );
    });

    test('rejects short zoomed horizontal travel at edge', () {
      expect(
        tallImageShouldRouteGalleryPage(
          totalDelta: const Offset(-40, -2),
          atHorizontalEdge: true,
          zoomed: true,
        ),
        isFalse,
      );
    });

    test('allows long pure zoomed horizontal swipe at edge', () {
      expect(
        tallImageShouldRouteGalleryPage(
          totalDelta: const Offset(-56, -4),
          atHorizontalEdge: true,
          zoomed: true,
        ),
        isTrue,
      );
    });
  });

  group('clampTallImageTranslationY', () {
    test('clamps to top and bottom', () {
      expect(
        clampTallImageTranslationY(
          currentY: 0,
          deltaY: 20,
          viewportHeight: 800,
          contentHeight: 2000,
        ),
        0,
      );
      expect(
        clampTallImageTranslationY(
          currentY: 0,
          deltaY: -500,
          viewportHeight: 800,
          contentHeight: 2000,
        ),
        -500,
      );
      expect(
        clampTallImageTranslationY(
          currentY: -1100,
          deltaY: -200,
          viewportHeight: 800,
          contentHeight: 2000,
        ),
        -1200,
      );
    });

    test('short content stays at zero', () {
      expect(
        tallImageMinTranslationY(viewportHeight: 800, contentHeight: 600),
        0,
      );
      expect(
        clampTallImageTranslationY(
          currentY: 0,
          deltaY: -40,
          viewportHeight: 800,
          contentHeight: 600,
        ),
        0,
      );
    });
  });
}

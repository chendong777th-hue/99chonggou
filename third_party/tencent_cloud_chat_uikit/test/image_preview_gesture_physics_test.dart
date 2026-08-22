import 'dart:ui';

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_preview_gesture_physics.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_preview_resolution_utils.dart';

void main() {
  group('imagePreviewMatrixPanBounds', () {
    test('top-aligned tall image allows negative Y only', () {
      final bounds = imagePreviewMatrixPanBounds(
        viewport: const Size(400, 800),
        content: const Size(400, 2000),
        scale: 1.0,
        topAligned: true,
      );
      expect(bounds.minX, 0);
      expect(bounds.maxX, 0);
      expect(bounds.maxY, 0);
      expect(bounds.minY, 800 - 2000);
    });

    test('clamp keeps translation inside bounds', () {
      const bounds = ImagePreviewPanTranslationBounds(
        minX: -100,
        maxX: 0,
        minY: -500,
        maxY: 0,
      );
      expect(
        bounds.clamp(const Offset(50, 20)),
        const Offset(0, 0),
      );
      expect(
        bounds.clamp(const Offset(-200, -600)),
        const Offset(-100, -500),
      );
    });
  });

  group('imagePreviewDampedPanDelta', () {
    test('applies base pan damping in free region', () {
      const bounds = ImagePreviewPanTranslationBounds(
        minX: -200,
        maxX: 0,
        minY: -800,
        maxY: 0,
      );
      final delta = imagePreviewDampedPanDelta(
        delta: const Offset(100, 50),
        translation: const Offset(-150, -400),
        bounds: bounds,
        viewport: const Size(400, 800),
        panDamping: 0.8,
      );
      expect(delta.dx, closeTo(80, 0.01));
      expect(delta.dy, closeTo(40, 0.01));
    });

    test('reduces delta when overscrolling past top edge', () {
      const bounds = ImagePreviewPanTranslationBounds(
        minX: 0,
        maxX: 0,
        minY: -500,
        maxY: 0,
      );
      final free = imagePreviewDampedPanDelta(
        delta: const Offset(0, 40),
        translation: const Offset(0, -10),
        bounds: bounds,
        viewport: const Size(400, 800),
        panDamping: 0.8,
      );
      final edge = imagePreviewDampedPanDelta(
        delta: const Offset(0, 40),
        translation: const Offset(0, 5),
        bounds: bounds,
        viewport: const Size(400, 800),
        panDamping: 0.8,
      );
      expect(edge.dy.abs(), lessThan(free.dy.abs()));
      expect(edge.dy.abs(), greaterThan(0));
    });
  });

  group('imagePreviewEdgeDampingFactor', () {
    test('returns 1 when not overscrolling', () {
      expect(
        imagePreviewEdgeDampingFactor(
          overscrollPx: 0,
          viewportSpan: 400,
        ),
        1.0,
      );
    });

    test('stays within enterprise range', () {
      final shallow = imagePreviewEdgeDampingFactor(
        overscrollPx: 4,
        viewportSpan: 400,
      );
      final deep = imagePreviewEdgeDampingFactor(
        overscrollPx: 400,
        viewportSpan: 400,
      );
      expect(shallow, inInclusiveRange(imagePreviewEdgeDampingMin, imagePreviewEdgeDampingMax));
      expect(deep, inInclusiveRange(imagePreviewEdgeDampingMin, imagePreviewEdgeDampingMax));
      expect(deep, lessThan(shallow));
    });
  });

  group('imagePreviewApplyPanAxisLock', () {
    test('locks horizontal movement only', () {
      expect(
        imagePreviewApplyPanAxisLock(
          const Offset(10, 20),
          ImagePreviewPanAxisLock.horizontal,
        ),
        const Offset(10, 0),
      );
    });

    test('locks vertical movement only', () {
      expect(
        imagePreviewApplyPanAxisLock(
          const Offset(10, 20),
          ImagePreviewPanAxisLock.vertical,
        ),
        const Offset(0, 20),
      );
    });
  });

  group('imagePreviewMomentumMeetsMinVelocity', () {
    test('passes when one axis exceeds threshold after other zeroed', () {
      expect(
        imagePreviewMomentumMeetsMinVelocity(const Offset(0, 350), 320),
        isTrue,
      );
      expect(
        imagePreviewMomentumMeetsMinVelocity(const Offset(200, 200), 320),
        isFalse,
      );
      expect(
        imagePreviewMomentumMeetsMinVelocity(const Offset(200, 350), 320),
        isTrue,
      );
    });
  });

  group('imagePreviewMomentumStartVelocity', () {
    const tallProfile = ImagePreviewGestureProfile(
      panDamping: 0.80,
      inertialMinVelocity: 320,
      inertialDecayPerFrame: 0.92,
      panAxisPreference: ImagePreviewPanAxisPreference.vertical,
      allowPanAt1x: true,
      inertialSpeed: 280,
    );
    const bounds = ImagePreviewPanTranslationBounds(
      minX: -600,
      maxX: 0,
      minY: -3000,
      maxY: 0,
    );

    test('zoomed tall keeps horizontal and vertical inertia mid content', () {
      final scaled = imagePreviewMomentumStartVelocity(
        velocityPixelsPerSecond: const Offset(500, 800),
        zoomed: true,
        tallScrollMode: true,
        profile: tallProfile,
        bounds: bounds,
        translation: const Offset(-200, -500),
      );
      expect(scaled.dx, closeTo(500 * imagePreviewPanSpeed, 0.01));
      expect(scaled.dy, closeTo(800 * imagePreviewPanSpeed, 0.01));
    });

    test('zoomed tall zeros outbound horizontal inertia at left edge', () {
      final outbound = imagePreviewMomentumStartVelocity(
        velocityPixelsPerSecond: const Offset(-400, 250),
        zoomed: true,
        tallScrollMode: true,
        profile: tallProfile,
        bounds: bounds,
        translation: const Offset(-600, -500),
      );
      expect(outbound.dx, 0);
      expect(outbound.dy, closeTo(250 * imagePreviewPanSpeed, 0.01));

      final inbound = imagePreviewMomentumStartVelocity(
        velocityPixelsPerSecond: const Offset(400, 250),
        zoomed: true,
        tallScrollMode: true,
        profile: tallProfile,
        bounds: bounds,
        translation: const Offset(-600, -500),
      );
      expect(inbound.dx, closeTo(400 * imagePreviewPanSpeed, 0.01));
    });

    test('zoomed wide still applies profile damping and inertial boost', () {
      final scaled = imagePreviewMomentumStartVelocity(
        velocityPixelsPerSecond: const Offset(-500, 800),
        zoomed: true,
        tallScrollMode: false,
        profile: tallProfile,
        bounds: bounds,
        translation: const Offset(-600, -500),
      );
      expect(scaled.dx, closeTo(-500 * 0.8 * (280 / 400), 0.01));
      expect(scaled.dy, closeTo(800 * 0.8 * (280 / 400), 0.01));
    });
  });

  group('imagePreviewResolveZoomPanAxisLock', () {
    test('free preference with both boundaries stays free', () {
      expect(
        imagePreviewResolveZoomPanAxisLock(
          preference: ImagePreviewPanAxisPreference.free,
          computeHorizontalBoundary: true,
          computeVerticalBoundary: true,
          currentLock: ImagePreviewPanAxisLock.undecided,
          gestureTotalDelta: const Offset(30, 4),
          delta: const Offset(2, 20),
        ),
        ImagePreviewPanAxisLock.free,
      );
    });

    test('horizontal preference with both boundaries stays free when zoomed', () {
      expect(
        imagePreviewResolveZoomPanAxisLock(
          preference: ImagePreviewPanAxisPreference.horizontal,
          computeHorizontalBoundary: true,
          computeVerticalBoundary: true,
          currentLock: ImagePreviewPanAxisLock.undecided,
          gestureTotalDelta: const Offset(40, 5),
          delta: const Offset(5, 30),
        ),
        ImagePreviewPanAxisLock.free,
      );
    });

    test('vertical preference with both boundaries stays free when zoomed', () {
      expect(
        imagePreviewResolveZoomPanAxisLock(
          preference: ImagePreviewPanAxisPreference.vertical,
          computeHorizontalBoundary: true,
          computeVerticalBoundary: true,
          currentLock: ImagePreviewPanAxisLock.undecided,
          gestureTotalDelta: const Offset(4, 30),
          delta: const Offset(1, 10),
        ),
        ImagePreviewPanAxisLock.free,
      );
    });

    test('only vertical boundary forces vertical lock', () {
      expect(
        imagePreviewResolveZoomPanAxisLock(
          preference: ImagePreviewPanAxisPreference.free,
          computeHorizontalBoundary: false,
          computeVerticalBoundary: true,
          currentLock: ImagePreviewPanAxisLock.undecided,
          gestureTotalDelta: Offset.zero,
          delta: const Offset(10, 20),
        ),
        ImagePreviewPanAxisLock.vertical,
      );
    });
  });

  group('imagePreviewZoomPanDamping', () {
    const tallProfile = ImagePreviewGestureProfile(
      panDamping: 0.80,
      inertialMinVelocity: 320,
      inertialDecayPerFrame: 0.92,
      panAxisPreference: ImagePreviewPanAxisPreference.vertical,
      allowPanAt1x: true,
      inertialSpeed: 280,
    );

    test('tall manual drag is 1:1 like 1x', () {
      expect(
        imagePreviewZoomPanDamping(
          tallScrollMode: true,
          fromMomentum: false,
          profile: tallProfile,
        ),
        imagePreviewPanSpeed,
      );
    });

    test('tall momentum skips second damping', () {
      expect(
        imagePreviewZoomPanDamping(
          tallScrollMode: true,
          fromMomentum: true,
          profile: tallProfile,
        ),
        1.0,
      );
    });
  });

  group('imagePreviewScaleSnapDuration', () {
    test('keeps underscale snap under 100ms', () {
      expect(
        imagePreviewScaleSnapDuration.inMilliseconds,
        lessThanOrEqualTo(100),
      );
      expect(imagePreviewScaleSnapCurve, Curves.easeOut);
    });
  });

  group('mediaPreview tap vs gallery page drag', () {
    test('small movement is a tap not a page turn', () {
      expect(
        mediaPreviewIsTapGesture(
          accumulatedDistance: 8,
          totalScale: 1,
          initialScale: 1,
          velocityDistance: 40,
        ),
        isTrue,
      );
      expect(
        mediaPreviewShouldBeginPageDrag(
          alreadyDragging: false,
          horizontalIntent: true,
          pointerCount: 1,
          scale: 1,
          accumulatedDistance: 8,
        ),
        isFalse,
      );
    });

    test('horizontal swipe past slop can start paging', () {
      expect(
        mediaPreviewShouldBeginPageDrag(
          alreadyDragging: false,
          horizontalIntent: true,
          pointerCount: 1,
          scale: 1,
          accumulatedDistance: 30,
        ),
        isTrue,
      );
      expect(
        mediaPreviewIsTapGesture(
          accumulatedDistance: 30,
          totalScale: 1,
          initialScale: 1,
          velocityDistance: 40,
        ),
        isFalse,
      );
    });

    test('tap-like velocity is not a page fling', () {
      expect(kMediaPreviewTapMaxVelocity, lessThan(320));
    });
  });
}

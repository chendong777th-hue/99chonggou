import 'package:flutter_test/flutter_test.dart';
import 'package:extended_image/extended_image.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_screen_gallery_close.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/tall_image_gallery_scroll_gate.dart';

void main() {
  group('canScrollMediaPreviewGalleryPageAtScale', () {
    test('allows scroll at 1x', () {
      expect(
        canScrollMediaPreviewGalleryPageAtScale(
          totalScale: 1.0,
          baselineScale: 1.0,
          computeHorizontalBoundary: true,
          atLeftEdge: false,
          atRightEdge: false,
        ),
        isTrue,
      );
    });

    test('blocks scroll when zoomed and not at horizontal edge', () {
      expect(
        canScrollMediaPreviewGalleryPageAtScale(
          totalScale: 2.0,
          baselineScale: 1.0,
          computeHorizontalBoundary: true,
          atLeftEdge: false,
          atRightEdge: false,
        ),
        isFalse,
      );
    });

    test('allows scroll when zoomed at right edge', () {
      expect(
        canScrollMediaPreviewGalleryPageAtScale(
          totalScale: 2.0,
          baselineScale: 1.0,
          computeHorizontalBoundary: true,
          atLeftEdge: false,
          atRightEdge: true,
        ),
        isTrue,
      );
    });

    test('blocks scroll when zoomed without horizontal overflow', () {
      expect(
        canScrollMediaPreviewGalleryPageAtScale(
          totalScale: 2.0,
          baselineScale: 1.0,
          computeHorizontalBoundary: false,
          atLeftEdge: false,
          atRightEdge: false,
        ),
        isFalse,
      );
    });
  });

  group('canScrollMediaPreviewGalleryPage', () {
    test('null details allows scroll', () {
      expect(
        canScrollMediaPreviewGalleryPage(details: null, baselineScale: 1.0),
        isTrue,
      );
    });

    test('zoomed default details blocks scroll', () {
      final details = GestureDetails(totalScale: 2.0, offset: Offset.zero);
      expect(
        canScrollMediaPreviewGalleryPage(details: details, baselineScale: 1.0),
        isFalse,
      );
    });

    test('zoomed tall image blocks scroll when not at edge', () {
      expect(
        canScrollMediaPreviewGalleryPage(
          details: null,
          baselineScale: 1.0,
          tallImageGate: const TallImageGalleryScrollGate(
            scale: 1.5,
            atLeftEdge: false,
            atRightEdge: false,
            hasHorizontalScroll: true,
          ),
          tallImageVerticallyScrollable: true,
        ),
        isFalse,
      );
    });

    test('zoomed tall image allows scroll at horizontal edge', () {
      expect(
        canScrollMediaPreviewGalleryPage(
          details: null,
          baselineScale: 1.0,
          tallImageGate: const TallImageGalleryScrollGate(
            scale: 1.5,
            atLeftEdge: false,
            atRightEdge: true,
            hasHorizontalScroll: true,
          ),
          tallImageVerticallyScrollable: true,
        ),
        isTrue,
      );
    });

    test('1x tall image allows scroll when details is null', () {
      expect(
        canScrollMediaPreviewGalleryPage(
          details: null,
          baselineScale: 1.0,
          tallImageGate: TallImageGalleryScrollGate.initial,
          tallImageVerticallyScrollable: true,
        ),
        isTrue,
      );
    });
  });

  group('tallImageAtHorizontalPanEdge', () {
    test('allows when no horizontal scroll', () {
      expect(
        tallImageAtHorizontalPanEdge(
          translationX: 0,
          minX: -10,
          maxX: 10,
          hasHorizontalScroll: false,
          dragDx: -5,
        ),
        isTrue,
      );
    });

    test('left drag requires min edge', () {
      expect(
        tallImageAtHorizontalPanEdge(
          translationX: -10,
          minX: -10,
          maxX: 10,
          hasHorizontalScroll: true,
          dragDx: -5,
        ),
        isTrue,
      );
      expect(
        tallImageAtHorizontalPanEdge(
          translationX: 0,
          minX: -10,
          maxX: 10,
          hasHorizontalScroll: true,
          dragDx: -5,
        ),
        isFalse,
      );
    });

    test('right drag requires max edge', () {
      expect(
        tallImageAtHorizontalPanEdge(
          translationX: 10,
          minX: -10,
          maxX: 10,
          hasHorizontalScroll: true,
          dragDx: 5,
        ),
        isTrue,
      );
    });
  });

  group('resolveMediaPreviewGalleryIndex', () {
    test('returns 0 for single-image mode', () {
      expect(
        resolveMediaPreviewGalleryIndex(
          useGallery: false,
          currentIndex: 5,
          itemCount: 10,
          page: 3,
        ),
        0,
      );
    });

    test('prefers page controller page over stale currentIndex', () {
      expect(
        resolveMediaPreviewGalleryIndex(
          useGallery: true,
          currentIndex: 0,
          itemCount: 8,
          page: 3.2,
        ),
        3,
      );
    });

    test('falls back to currentIndex when page is null', () {
      expect(
        resolveMediaPreviewGalleryIndex(
          useGallery: true,
          currentIndex: 4,
          itemCount: 8,
        ),
        4,
      );
    });

    test('clamps page index to item bounds', () {
      expect(
        resolveMediaPreviewGalleryIndex(
          useGallery: true,
          currentIndex: 1,
          itemCount: 3,
          page: 9.8,
        ),
        2,
      );
    });
  });

  group('canHeroDismissToTarget', () {
    test('returns false for empty tag', () {
      expect(
        canHeroDismissToTarget(heroTag: '', targetIsLive: true),
        isFalse,
      );
    });

    test('returns false when target is not live', () {
      expect(
        canHeroDismissToTarget(heroTag: 'hero-1', targetIsLive: false),
        isFalse,
      );
    });

    test('returns true when tag is set and target is live', () {
      expect(
        canHeroDismissToTarget(heroTag: 'hero-1', targetIsLive: true),
        isTrue,
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_pin_hydrate_policy.dart';

void main() {
  group('shouldSkipPinnedDeferredReorder', () {
    test('skips only when pin matches and order sorted', () {
      expect(
        shouldSkipPinnedDeferredReorder(
          currentPinnedMatchesTarget: true,
          orderAlreadySorted: true,
        ),
        isTrue,
      );
      expect(
        shouldSkipPinnedDeferredReorder(
          currentPinnedMatchesTarget: true,
          orderAlreadySorted: false,
        ),
        isFalse,
      );
      expect(
        shouldSkipPinnedDeferredReorder(
          currentPinnedMatchesTarget: false,
          orderAlreadySorted: true,
        ),
        isFalse,
      );
    });
  });

  group('shouldForceReloadTypeHydrateAfterPin', () {
    test('false when moved index inside window', () {
      expect(
        shouldForceReloadTypeHydrateAfterPin(
          movedTypeIndex: 5,
          hydrateStart: 0,
          hydrateLength: 20,
        ),
        isFalse,
      );
    });

    test('true when moved index outside window', () {
      expect(
        shouldForceReloadTypeHydrateAfterPin(
          movedTypeIndex: 40,
          hydrateStart: 0,
          hydrateLength: 20,
        ),
        isTrue,
      );
      expect(
        shouldForceReloadTypeHydrateAfterPin(
          movedTypeIndex: 2,
          hydrateStart: 10,
          hydrateLength: 20,
        ),
        isTrue,
      );
    });

    test('false when moved index unknown or empty hydrate', () {
      expect(
        shouldForceReloadTypeHydrateAfterPin(
          movedTypeIndex: null,
          hydrateStart: 0,
          hydrateLength: 20,
        ),
        isFalse,
      );
      expect(
        shouldForceReloadTypeHydrateAfterPin(
          movedTypeIndex: 5,
          hydrateStart: 0,
          hydrateLength: 0,
        ),
        isFalse,
      );
    });
  });

  group('resolvePinHydrateCenterIndex', () {
    test('prefers viewport then mid then fallback', () {
      expect(
        resolvePinHydrateCenterIndex(
          viewportAnchorTypeIndex: 3,
          hydrateMidTypeIndex: 10,
          fallback: 0,
        ),
        3,
      );
      expect(
        resolvePinHydrateCenterIndex(
          viewportAnchorTypeIndex: null,
          hydrateMidTypeIndex: 10,
          fallback: 0,
        ),
        10,
      );
      expect(
        resolvePinHydrateCenterIndex(
          viewportAnchorTypeIndex: null,
          hydrateMidTypeIndex: null,
          fallback: 7,
        ),
        7,
      );
    });
  });
}

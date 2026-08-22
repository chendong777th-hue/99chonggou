import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_screen_gallery_close.dart';

void main() {
  test('media preview route fades the page on pop only', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/utils/'
      'media_preview_overlay_route.dart',
    ).readAsStringSync();

    expect(source.contains('FadeTransition('), isTrue);
    expect(source.contains('AnimationStatus.reverse'), isTrue);
    expect(source.contains('reverseCurve: mediaPreviewBackdropReverseCurve'),
        isTrue);
  });

  test('image hero return requires a live source target', () {
    expect(
      canHeroDismissToTarget(heroTag: 'image-1', targetIsLive: true),
      isTrue,
    );
    expect(
      canHeroDismissToTarget(heroTag: 'image-1', targetIsLive: false),
      isFalse,
    );
    expect(
      canHeroDismissToTarget(heroTag: '', targetIsLive: true),
      isFalse,
    );
  });

  test('image preview route and shell reveal the page under slide dismiss', () {
    final presenterSource = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/utils/'
      'media_preview_presenter.dart',
    ).readAsStringSync();
    final shellSource = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/widgets/'
      'media_preview_slide_shell.dart',
    ).readAsStringSync();
    final imageSource = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/widgets/image_screen.dart',
    ).readAsStringSync();

    expect(
      presenterSource.contains(
        'opaque || (PlatformUtils().isIOS && requiresOpaquePlatformView)',
      ),
      isTrue,
    );
    expect(
      shellSource.contains(
        'PlatformUtils().isIOS && opaquePlatformBackdrop',
      ),
      isTrue,
    );
    expect(imageSource.contains('opaquePlatformBackdrop: false'), isTrue);
  });

  test('preview screens keep image Hero enabled for reverse flight', () {
    final gallerySource = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/widgets/'
      'chat_media_gallery_screen.dart',
    ).readAsStringSync();
    final imageSource = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/widgets/image_screen.dart',
    ).readAsStringSync();

    expect(gallerySource.contains('canHeroDismissToTarget('), isTrue);
    expect(imageSource.contains('canHeroDismissToTarget('), isTrue);
    expect(
      gallerySource.contains(
        '_heroModeEnabled.value = closeItem.type == '
        'ChatMediaPreviewType.image',
      ),
      isTrue,
    );
  });

  test('tall image tap is not toggled again by the outer gesture', () {
    final imageSource = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/widgets/image_screen.dart',
    ).readAsStringSync();

    expect(
      imageSource.contains(
        '_loadedDisplayByIndex[index]?.verticallyScrollable == true',
      ),
      isTrue,
    );
    expect(
      imageSource.contains('onTap: () => _handleOuterImageTap(index)'),
      isTrue,
    );
    expect(
      imageSource.contains('onTap: () => _handleOuterImageTap(0)'),
      isTrue,
    );
  });

  test('media preview open flight uses a single source image without extra easing',
      () {
    final heroSource = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/widgets/image_hero.dart',
    ).readAsStringSync();
    final presenterSource = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/utils/'
      'media_preview_presenter.dart',
    ).readAsStringSync();
    final durationSource = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/utils/'
      'media_preview_video_utils.dart',
    ).readAsStringSync();
    final videoElemSource = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKitMessageItem/tim_uikit_chat_video_elem.dart',
    ).readAsStringSync();
    final imageSource = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/widgets/image_screen.dart',
    ).readAsStringSync();

    expect(heroSource.contains('return RectTween(begin: begin, end: end);'),
        isFalse);
    expect(heroSource.contains('mediaPreviewHeroRectTween('), isTrue);
    expect(heroSource.contains('fromHero.child'), isTrue);
    expect(heroSource.contains('BoxFit.cover'), isTrue);
    expect(heroSource.contains('toHero.child'), isFalse);
    expect(heroSource.contains('secondaryOpacity'), isFalse);
    expect(imageSource.contains('ImagePreviewDisplayBox('), isTrue);
    expect(imageSource.contains('width: boxSize.width'), isTrue);
    expect(presenterSource.contains('await WidgetsBinding.instance.endOfFrame'),
        isFalse);
    expect(
      durationSource.contains(
        'const Duration mediaPreviewBackdropDuration = Duration(milliseconds: 240);',
      ),
      isTrue,
    );
    expect(durationSource.contains('Curves.easeOutCubic'), isTrue);
    expect(
      videoElemSource.contains('transitionDuration: Duration.zero'),
      isFalse,
    );
  });

  test('gallery page view does not restore a shared PageStorage offset', () {
    final imageSource = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/widgets/image_screen.dart',
    ).readAsStringSync();
    expect(imageSource.contains("PageStorageKey"), isFalse);
    expect(imageSource.contains('if (!_entranceLatch.settled)'), isTrue);
  });

  test('gallery fling threshold ignores tap lift velocity', () {
    final physicsSource = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/utils/'
      'chat_media_gallery_scroll_physics.dart',
    ).readAsStringSync();
    expect(physicsSource.contains('minFlingVelocity => 320.0'), isTrue);
    expect(
      physicsSource.contains('dragStartDistanceMotionThreshold => 18.0'),
      isTrue,
    );
  });
}

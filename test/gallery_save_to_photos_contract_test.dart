import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gallery save avoids saveFile on iOS and wires chat save paths', () {
    final saveSource = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/utils/gallery_save_to_photos.dart',
    ).readAsStringSync();
    final pickUtilsSource = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/utils/chat_gallery_pick_utils.dart',
    ).readAsStringSync();
    final imageElemSource = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKitMessageItem/tim_uikit_chat_image_elem.dart',
    ).readAsStringSync();
    final conversationSaveSource = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitSearch/'
      'conversation_image_save.dart',
    ).readAsStringSync();
    final editedSaveSource = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/utils/image_edit/'
      'edited_image_gallery_save.dart',
    ).readAsStringSync();

    expect(saveSource.contains('_avoidSaveFileOnIos'), isTrue);
    expect(saveSource.contains('PlatformUtils().isIOS'), isTrue);
    expect(saveSource.contains('ImageGallerySaverPlus.saveImage'), isTrue);
    expect(
      saveSource.contains(
        'if (_avoidSaveFileOnIos) {\n      return false;\n    }',
      ),
      isTrue,
    );

    expect(pickUtilsSource.contains('OrderOptionType.updateDate'), isTrue);
    expect(pickUtilsSource.contains('asc: false'), isTrue);

    for (final source in [
      imageElemSource,
      conversationSaveSource,
      editedSaveSource,
    ]) {
      expect(source.contains('GallerySaveToPhotos'), isTrue);
      expect(source.contains('ImageGallerySaverPlus.saveFile'), isFalse);
    }
  });
}

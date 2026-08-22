import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_gallery_asset_sort.dart';

void main() {
  test('recent activity uses max of create and modify epoch', () {
    final asset = AssetEntity(
      id: 'a',
      typeInt: 1,
      width: 100,
      height: 100,
      duration: 0,
      createDateSecond: 100,
      modifiedDateSecond: 200,
    );
    expect(ChatGalleryAssetSort.recentActivityEpochSecond(asset), 200);
  });

  test('telegram-like picker wiring is present', () {
    final pickUtils = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/utils/chat_gallery_pick_utils.dart',
    ).readAsStringSync();
    final provider = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/utils/'
      'chat_gallery_asset_picker_provider.dart',
    ).readAsStringSync();
    final picker = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/utils/image_edit/'
      'editable_asset_picker.dart',
    ).readAsStringSync();

    expect(pickUtils.contains('telegramLikeFilterOptions'), isTrue);
    expect(pickUtils.contains('OrderOptionType.createDate'), isTrue);
    expect(pickUtils.contains('OrderOptionType.updateDate'), isTrue);
    expect(
        provider.contains('ChatGalleryAssetSort.compareByRecentActivityDesc'),
        isTrue);
    expect(provider.contains('currentPath = recent'), isTrue);
    expect(
      provider.contains('if (shouldReloadAssets)'),
      isTrue,
    );
    expect(pickUtils.contains('recentAlbumDisplayName'), isTrue);
    expect(pickUtils.contains('sortPathsByModifiedDate'), isTrue);
    expect(picker.contains('ChatGalleryAssetPickerProvider'), isTrue);
  });
}

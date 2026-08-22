import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile chat gallery uses original wechat picker presentation', () {
    final utilsSource = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/utils/chat_gallery_pick_utils.dart',
    ).readAsStringSync();
    final panelSource = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKitTextField/tim_uikit_more_panel.dart',
    ).readAsStringSync();
    final wideSource = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKitTextField/tim_uikit_text_field_layout/wide.dart',
    ).readAsStringSync();
    final builderSource = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/utils/image_edit/'
      'asset_picker_edit_builder_delegate.dart',
    ).readAsStringSync();
    final pickerSource = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/utils/image_edit/'
      'editable_asset_picker.dart',
    ).readAsStringSync();
    final viewerSource = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/utils/image_edit/'
      'asset_picker_edit_viewer_delegate.dart',
    ).readAsStringSync();

    expect(utilsSource.contains('shouldPreferCustomGalleryPicker'), isTrue);
    expect(
      utilsSource.contains(
        'if (Platform.isIOS || Platform.isAndroid) {\n      return true;',
      ),
      isTrue,
    );
    expect(panelSource.contains('preferCustomPicker'), isTrue);
    expect(
      panelSource
          .contains('ChatGalleryPickUtils.shouldPreferCustomGalleryPicker'),
      isTrue,
    );
    expect(wideSource.contains('EditableAssetPicker.pickAssets'), isTrue);
    expect(builderSource.contains('AssetPickerAppBar appBar'), isFalse);
    expect(builderSource.contains('Widget confirmButton('), isFalse);
    expect(builderSource.contains('Widget selectedBackdrop('), isFalse);
    expect(builderSource.contains('Widget pathEntitySelector('), isFalse);
    expect(utilsSource.contains('gridCount: config.gridCount'), isTrue);
    expect(utilsSource.contains('pickerTheme: config.pickerTheme'), isTrue);
    expect(utilsSource.contains('shouldRevertGrid: false'), isTrue);
    expect(
      pickerSource.contains('AssetPickerPageRoute<List<AssetEntity>>'),
      isTrue,
    );
    expect(pickerSource.contains('_SystemPickerSheetFrame'), isFalse);
    expect(pickerSource.contains('barrierDismissible: true'), isFalse);
    expect(viewerSource.contains('_dismissOffsetY'), isFalse);
    expect(viewerSource.contains('onVerticalDragUpdate'), isFalse);
  });

  test('app gallery entries share picker and recover transient empty loads',
      () {
    String source(String path) => File(path).readAsStringSync();

    final providerSource = source(
      'third_party/tencent_cloud_chat_uikit/lib/ui/utils/'
      'chat_gallery_asset_picker_provider.dart',
    );
    final utilsSource = source(
      'third_party/tencent_cloud_chat_uikit/lib/ui/utils/'
      'chat_gallery_pick_utils.dart',
    );
    final pickerSource = source(
      'third_party/tencent_cloud_chat_uikit/lib/ui/utils/image_edit/'
      'editable_asset_picker.dart',
    );
    final panelSource = source(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKitTextField/tim_uikit_more_panel.dart',
    );

    expect(providerSource.contains('_pathsLoadTail'), isTrue);
    expect(providerSource.contains('_assetsLoadTail'), isTrue);
    expect(providerSource.contains('_getPathsWithRecovery'), isTrue);
    expect(providerSource.contains('_galleryPathRetryDelays'), isTrue);
    expect(providerSource.contains('_galleryAssetRetryDelays'), isTrue);
    expect(providerSource.contains('_galleryQueryTimeout'), isTrue);
    expect(providerSource.contains('.timeout(_galleryQueryTimeout)'), isTrue);
    expect(providerSource.contains('_settleAsEmpty()'), isTrue);
    expect(providerSource.contains('picker_paths_exhausted'), isTrue);
    expect(providerSource.contains('picker_assets_exhausted'), isTrue);
    expect(providerSource.contains('picker_paths_preserved_previous'), isTrue);
    expect(providerSource.contains('picker_paths_query_begin'), isTrue);
    expect(providerSource.contains('picker_assets_query_begin'), isTrue);
    expect(providerSource.contains('picker_assets_state_applied'), isTrue);
    expect(providerSource.contains('picker_assets_reload_skipped'), isTrue);
    expect(providerSource.contains('picker_full_paths_deferred'), isTrue);
    expect(providerSource.contains('picker_full_paths_resumed'), isTrue);
    expect(providerSource.contains('markFirstThumbnailDisplayed'), isTrue);
    expect(providerSource.contains('getThumbnailFromPath'), isTrue);
    expect(
      providerSource.contains('picker_path_thumb_skipped_until_grid'),
      isTrue,
    );
    expect(providerSource.contains('DeliveryMode.fastFormat'), isTrue);
    expect(providerSource.contains('thumbnailDataWithOption'), isTrue);
    expect(providerSource.contains('thumbnailDataWithSize('), isFalse);
    expect(
      File('pubspec.yaml').readAsStringSync().contains(
            'path: third_party/photo_manager',
          ),
      isTrue,
    );
    expect(utilsSource.contains('_chatGalleryPageSize = 40'), isTrue);
    expect(
      providerSource.contains(
        '!onlyAll && (currentAssets.isEmpty || pathChanged || keepPreviousCount)',
      ),
      isTrue,
    );
    expect(providerSource.contains('currentPath?.path.id != requestedPath.id'),
        isTrue);
    expect(providerSource.contains('requestedPath.assetCountAsync'), isTrue);
    expect(
      providerSource.contains('isAssetsEmpty = updated.isEmpty;'),
      isTrue,
    );
    expect(utilsSource.contains('PhotoManager.clearFileCache()'), isFalse);
    expect(
      utilsSource.contains("(_, __, path) => path?.isAll ?? true"),
      isTrue,
    );
    expect(
      pickerSource.contains('prepareCustomGalleryPicker('),
      isFalse,
    );
    expect(
      pickerSource.contains(
        'initializeDelayDuration: _providerInitializeDelay',
      ),
      isTrue,
    );
    expect(pickerSource.contains('Duration.zero'), isTrue);
    expect(pickerSource.contains('Duration(milliseconds: 250)'), isFalse);
    expect(pickerSource.contains('trace: trace'), isTrue);
    expect(panelSource.contains('Permission.storage.value'), isFalse);
    expect(panelSource.contains('Permission.photos.value'), isFalse);

    for (final path in <String>[
      'lib/src/my_profile_detail.dart',
      'lib/src/group_info_detail.dart',
      'lib/src/create_group.dart',
      'lib/src/qr_code_scanner_page.dart',
      'lib/src/services/chat_background_service.dart',
      'lib/src/pages/moments/moments_cover_picker.dart',
      'lib/src/pages/moments/moments_compose_page.dart',
    ]) {
      expect(
        source(path).contains('AppGalleryPicker.'),
        isTrue,
        reason: '$path should use the shared WeChat gallery picker',
      );
    }

    final stickerSource =
        source('lib/src/pages/sticker/sticker_upload_page.dart');
    expect(
      stickerSource.contains('EditableAssetPicker.pickAssets('),
      isTrue,
    );
    expect(stickerSource.contains('await AssetPicker.pickAssets('), isFalse);
  });
}

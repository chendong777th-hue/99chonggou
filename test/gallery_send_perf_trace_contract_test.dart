import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gallery send perf trace is wired across all chat send modes', () {
    final traceSource = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/utils/gallery_send_perf_trace.dart',
    ).readAsStringSync();
    final panel = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKitTextField/tim_uikit_more_panel.dart',
    ).readAsStringSync();
    final wide = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKitTextField/tim_uikit_text_field_layout/wide.dart',
    ).readAsStringSync();
    final picker = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/utils/image_edit/'
      'editable_asset_picker.dart',
    ).readAsStringSync();

    expect(traceSource.contains("'mode=\$mode'"), isTrue);
    expect(traceSource.contains('[gallery_send_perf]'), isTrue);
    expect(traceSource.contains('slow_frame'), isTrue);
    expect(traceSource.contains('debugPrint(line)'), isTrue);
    expect(traceSource.contains('if (kReleaseMode)'), isTrue);
    expect(traceSource.contains('picker_first_thumbnail_ready'), isTrue);
    expect(traceSource.contains('picker_first_thumbnail_failed'), isTrue);

    for (final mode in [
      'more_panel_gallery',
      'more_panel_camera',
      'more_panel_web_image',
      'more_panel_web_video',
      'wide_mobile_album',
      'wide_desktop',
    ]) {
      expect(panel.contains(mode) || wide.contains(mode), isTrue);
    }

    expect(picker.contains('GallerySendPerfTrace? perf'), isTrue);
    expect(picker.contains('picker_permission_begin'), isTrue);
    expect(picker.contains('picker_failed'), isTrue);
    expect(picker.contains('picker_push_returned'), isTrue);
    expect(picker.contains('GalleryResolveOutcome'), isTrue);
    expect(picker.contains('cloudTimeout'), isTrue);
    expect(picker.contains('permissionLimited'), isTrue);
    expect(picker.contains('unsupportedOrCorrupt'), isTrue);
    expect(picker.contains('outcome=\${outcome.name}'), isTrue);
    expect(picker.contains('retries = 2'), isTrue);
    expect(panel.contains('resolve_categorized_failure'), isTrue);
    expect(panel.contains('outcome=oversize'), isTrue);
    expect(panel.contains('stage_failed'), isTrue);
    expect(
      File(
        'third_party/tencent_cloud_chat_uikit/lib/ui/utils/image_edit/'
        'asset_picker_edit_builder_delegate.dart',
      ).readAsStringSync().contains('_RecoveringGalleryThumbnail'),
      isTrue,
    );
    final gridBuilder = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/utils/image_edit/'
      'asset_picker_edit_builder_delegate.dart',
    ).readAsStringSync();
    expect(gridBuilder.contains('picker_thumbnail_retry'), isTrue);
    expect(gridBuilder.contains('_requestTimeout'), isTrue);
    expect(gridBuilder.contains('super.imageAndVideoItemBuilder'), isFalse);
    expect(gridBuilder.contains('imageProvider.imageFileType'), isFalse);
    expect(gridBuilder.contains('thumbnailDataWithOption'), isTrue);
    expect(gridBuilder.contains('DeliveryMode.fastFormat'), isTrue);
    expect(gridBuilder.contains('DeliveryMode.highQualityFormat'), isTrue);
    expect(gridBuilder.contains('ResizeMode.exact'), isTrue);
    expect(gridBuilder.contains('picker_thumbnail_upgraded'), isTrue);
    expect(gridBuilder.contains('_maxUpgradeConcurrent = 2'), isTrue);
    expect(gridBuilder.contains('_kEnableGridHqThumbnailUpgrade = true'), isTrue);
    expect(gridBuilder.contains('gaplessPlayback: true'), isTrue);
    expect(gridBuilder.contains('if (_decoded)'), isTrue);
    expect(gridBuilder.contains('precacheImage(provider, context)'), isTrue);
    expect(gridBuilder.contains('_memoryImage = provider'), isTrue);
    // Stable image key — must NOT remount on byte-length change (HQ flash).
    expect(
      gridBuilder.contains("gallery_\${widget.asset.id}_\$_generation"),
      isTrue,
    );
    expect(
      gridBuilder.contains('_\${_generation}_\${bytes.length}'),
      isFalse,
    );
    final firstBytesAssign = gridBuilder.indexOf('_memoryImage = MemoryImage(bytes)');
    final deferredUpgrade = gridBuilder.indexOf(
      'WidgetsBinding.instance.addPostFrameCallback',
    );
    final upgradeCall = gridBuilder.indexOf('await _upgrade(generation)');
    expect(firstBytesAssign, greaterThan(-1));
    expect(deferredUpgrade, greaterThan(firstBytesAssign));
    expect(upgradeCall, greaterThan(deferredUpgrade));
    expect(
      gridBuilder.contains('Duration(milliseconds: 120)'),
      isTrue,
    );
    expect(
      File(
        'third_party/photo_manager/android/src/main/kotlin/'
        'com/fluttercandies/photo_manager/thumb/ThumbnailUtil.kt',
      ).readAsStringSync(),
      allOf(
        contains('entity.path'),
        contains('decodeFileScaled'),
        contains('loadWithContentResolver'),
        contains('GLIDE_TIMEOUT_MS'),
      ),
    );
    expect(
      File(
        'third_party/photo_manager/darwin/photo_manager/Sources/'
        'photo_manager/core/PMManager.m',
      ).readAsStringSync().contains('localOnlyFinal'),
      isTrue,
    );
    expect(gridBuilder.contains('PMCancelToken'), isTrue);
    expect(gridBuilder.contains('PhotoManager.cancelRequest'), isTrue);
    expect(gridBuilder.contains('_maxConcurrent = 4'), isTrue);
    expect(gridBuilder.contains('AssetEntityImageProvider'), isFalse);
    expect(gridBuilder.contains('_imageProvider.evict()'), isFalse);
    expect(wide.contains('GallerySendPerfTrace'), isTrue);
    expect(panel.contains('desktop_file_picker_open'), isTrue);
    expect(panel.contains('camera_photo_pick_begin'), isTrue);
  });
}

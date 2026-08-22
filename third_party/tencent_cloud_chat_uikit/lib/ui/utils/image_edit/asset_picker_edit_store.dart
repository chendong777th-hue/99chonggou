import 'dart:io';

import 'package:flutter/foundation.dart';

/// 相册选图会话内缓存：assetId → 编辑后的临时文件。
class AssetPickerEditStore {
  AssetPickerEditStore._();

  static final AssetPickerEditStore instance = AssetPickerEditStore._();

  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  final Map<String, File> _editedByAssetId = <String, File>{};

  void beginSession() {
    _editedByAssetId.clear();
    revision.value++;
  }

  File? peek(String assetId) => _editedByAssetId[assetId];

  void put(String assetId, File file) {
    _editedByAssetId[assetId] = file;
    revision.value++;
  }

  bool has(String assetId) => _editedByAssetId.containsKey(assetId);
}

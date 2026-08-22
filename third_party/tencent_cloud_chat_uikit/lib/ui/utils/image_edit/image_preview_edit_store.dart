import 'dart:io';

import 'package:flutter/foundation.dart';

/// 全屏预览会话内：messageId → 编辑后的临时文件（用于刷新预览，不自动发送）。
class ImagePreviewEditStore {
  ImagePreviewEditStore._();

  static final ImagePreviewEditStore instance = ImagePreviewEditStore._();

  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  final Map<String, File> _editedByMessageId = <String, File>{};

  File? peek(String messageId) => _editedByMessageId[messageId];

  void put(String messageId, File file) {
    _editedByMessageId[messageId] = file;
    revision.value++;
  }

  void clear() {
    _editedByMessageId.clear();
    revision.value++;
  }
}

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

class ImageGalleryItem {
  final ImageProvider? imageProvider;
  final ImageProvider? placeholderImageProvider;
  final String heroTag;
  final String? messageID;
  final String? headerTitle;
  final String? headerSubtitle;
  final Future<void> Function()? downloadFn;
  final Future<void> Function(BuildContext previewContext)? editFn;
  final Future<void> Function(BuildContext previewContext)? sendFn;
  final Future<void> Function()? forwardFn;
  final Future<void> Function()? deleteFn;
  final V2TimMessage? sourceMessage;

  const ImageGalleryItem({
    required this.imageProvider,
    this.placeholderImageProvider,
    required this.heroTag,
    this.messageID,
    this.headerTitle,
    this.headerSubtitle,
    this.downloadFn,
    this.editFn,
    this.sendFn,
    this.forwardFn,
    this.deleteFn,
    this.sourceMessage,
  });

  V2TimMessage? get message => sourceMessage;
}

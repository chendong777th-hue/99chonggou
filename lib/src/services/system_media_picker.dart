import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Platform-neutral media selected by the application.
class PickedMedia {
  const PickedMedia({required this.path, this.fileBytes, this.name, this.mimeType, required this.isVideo, this.width, this.height, this.duration, this.isGif = false});
  final String path;
  final List<int>? fileBytes;
  final String? name;
  final String? mimeType;
  final bool isVideo;
  final int? width;
  final int? height;
  final Duration? duration;
  final bool isGif;
}

/// App-level picker seam. Native mobile currently uses image_picker; desktop
/// and web use file_picker. HarmonyOS requires a separately verified adapter
/// before it can be enabled and is intentionally not claimed here.
class SystemMediaPicker {
  SystemMediaPicker._();
  static final ImagePicker _imagePicker = ImagePicker();

  static Future<List<PickedMedia>> pickMultiple({bool allowVideo = true}) async {
    if (kIsWeb || !defaultTargetPlatform.name.contains('android') &&
        !defaultTargetPlatform.name.contains('iOS')) {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.media,
        withData: false,
      );
      return (result?.files ?? const <PlatformFile>[])
          .where((file) => file.path != null)
          .map((file) => PickedMedia(
                path: file.path!,
                name: file.name,
                isVideo: file.extension?.toLowerCase() == 'mp4',
              ))
          .toList(growable: false);
    }
    final files = await _imagePicker.pickMultipleMedia(
      requestFullMetadata: false,
    );
    return files
        .map((file) => PickedMedia(
              path: file.path,
              name: file.name,
              mimeType: file.mimeType,
              isVideo: file.mimeType?.startsWith('video/') ?? false,
            ))
        .where((file) => allowVideo || !file.isVideo)
        .toList(growable: false);
  }

  static Future<List<PickedMedia>> pickImages({int? maxAssets}) async {
    final media = await pickMultiple(allowVideo: false);
    return media.where((item) => !item.isVideo).take(maxAssets ?? media.length).toList(growable: false);
  }

  static Future<List<PickedMedia>> pickVideos({int? maxAssets}) async {
    final media = await pickMultiple(allowVideo: true);
    return media.where((item) => item.isVideo).take(maxAssets ?? media.length).toList(growable: false);
  }

  static Future<List<PickedMedia>> pickMedia({int? maxAssets}) async =>
      (await pickMultiple()).take(maxAssets ?? 1).toList(growable: false);
}

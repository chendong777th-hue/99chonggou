/// 与后端 `POST /stickers/upload` 的 `mediaType` 字段对齐。
class StickerUploadMediaType {
  StickerUploadMediaType._();

  static const String image = 'image';
  static const String gif = 'gif';
  static const String video = 'video';

  static const int staticMaxBytes = 2 * 1024 * 1024;
  static const int gifMaxBytes = 5 * 1024 * 1024;
  static const int videoMaxBytes = 50 * 1024 * 1024;
  static const int videoMaxDurationSec = 10;

  static const Set<String> videoExtensions = {
    'mp4',
    'mov',
    'webm',
  };

  static bool isVideoPath(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot >= path.length - 1) {
      return false;
    }
    return videoExtensions.contains(path.substring(dot + 1).toLowerCase());
  }

  static bool isVideoMime(String? mime) {
    if (mime == null || mime.isEmpty) {
      return false;
    }
    final m = mime.toLowerCase();
    return m.contains('video/');
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// 气泡本地档：优先 THUMB；没有缩略图时才用大图/原图/归档。
class ChatBubbleLocalImageChoice {
  const ChatBubbleLocalImageChoice({
    required this.path,
    required this.isThumbFallback,
  });

  final String path;

  /// `true` 表示这是 THUMB 本地文件（列表首选，不是“没大图才凑合”）。
  final bool isThumbFallback;
}

/// 列表气泡这一帧该画什么。
enum ChatBubbleDisplaySource {
  localLarge,
  network,
  localThumb,
  none,
}

class ChatBubbleDisplayPlan {
  const ChatBubbleDisplayPlan({
    required this.source,
    required this.useNetwork,
    this.localPath,
  });

  final ChatBubbleDisplaySource source;
  final bool useNetwork;
  final String? localPath;
}

/// 在线时要把气泡档落到哪。
enum ChatBubbleImagePersistAction {
  none,
  sdkDownloadThumb,
  httpPersistArchive,
}

/// 本地文件选择：type=1 THUMB → type=2 大图 → 原图 → 归档/SDK 额外路径。
ChatBubbleLocalImageChoice? resolveChatBubbleLocalImageChoice({
  String? largeLocalUrl,
  String? originalLocalUrl,
  String? extraLargeLocalUrl,
  String? archiveCachePath,
  String? thumbLocalUrl,
  required bool Function(String path) fileExists,
  bool allowThumbFallback = true,
}) {
  if (allowThumbFallback) {
    final thumb = thumbLocalUrl?.trim() ?? '';
    if (thumb.isNotEmpty && fileExists(thumb)) {
      return ChatBubbleLocalImageChoice(
        path: thumb,
        isThumbFallback: true,
      );
    }
  }
  for (final candidate in [
    largeLocalUrl,
    originalLocalUrl,
    extraLargeLocalUrl,
    archiveCachePath,
  ]) {
    final path = candidate?.trim() ?? '';
    if (path.isNotEmpty && fileExists(path)) {
      return ChatBubbleLocalImageChoice(
        path: path,
        isThumbFallback: false,
      );
    }
  }
  return null;
}

ChatBubbleDisplayPlan planChatBubbleDisplay({
  required bool hasNetworkUrl,
  ChatBubbleLocalImageChoice? local,
  /// 本会话网图已成功出过一帧：继续用网络，勿切本地 thumb（落盘留给下次冷启动）。
  bool keepNetworkAfterFrameReady = false,
}) {
  if (keepNetworkAfterFrameReady && hasNetworkUrl) {
    return ChatBubbleDisplayPlan(
      source: ChatBubbleDisplaySource.network,
      useNetwork: true,
      localPath: local?.path,
    );
  }
  if (local != null && local.isThumbFallback) {
    return ChatBubbleDisplayPlan(
      source: ChatBubbleDisplaySource.localThumb,
      useNetwork: false,
      localPath: local.path,
    );
  }
  if (local != null) {
    return ChatBubbleDisplayPlan(
      source: ChatBubbleDisplaySource.localLarge,
      useNetwork: false,
      localPath: local.path,
    );
  }
  if (hasNetworkUrl) {
    return ChatBubbleDisplayPlan(
      source: ChatBubbleDisplaySource.network,
      useNetwork: true,
    );
  }
  return const ChatBubbleDisplayPlan(
    source: ChatBubbleDisplaySource.none,
    useNetwork: false,
  );
}

ChatBubbleImagePersistAction resolveChatBubbleImagePersistAction({
  required bool isSelf,
  required bool isArchive,
  required bool hasUsableHttpUrl,
  required bool hasBubbleLocalFile,
}) {
  if (isSelf || hasBubbleLocalFile) {
    return ChatBubbleImagePersistAction.none;
  }
  if (isArchive) {
    return hasUsableHttpUrl
        ? ChatBubbleImagePersistAction.httpPersistArchive
        : ChatBubbleImagePersistAction.none;
  }
  return ChatBubbleImagePersistAction.sdkDownloadThumb;
}

bool shouldCallSdkImageDownload({
  required ChatBubbleImagePersistAction action,
}) {
  return action == ChatBubbleImagePersistAction.sdkDownloadThumb;
}

/// 归档图不能走 SDK `downloadMessage`，按 msgID 把 HTTP 存到应用目录。
class ChatBubbleArchiveImageStore {
  ChatBubbleArchiveImageStore._();

  static final ChatBubbleArchiveImageStore instance =
      ChatBubbleArchiveImageStore._();

  static const dirName = 'chat_bubble_archive_images';
  static const _maxFileNameLength = 120;

  static final Map<String, Future<String?>> _inFlight =
      <String, Future<String?>>{};

  Directory? _cachedDir;

  @visibleForTesting
  static void resetForTest() {
    _inFlight.clear();
    instance._cachedDir = null;
  }

  @visibleForTesting
  static String fileNameForMsgId(String msgID) {
    final trimmed = msgID.trim();
    if (trimmed.isEmpty) {
      return 'unknown';
    }
    final sanitized = trimmed.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    if (sanitized.isEmpty) {
      return 'unknown';
    }
    if (sanitized.length <= _maxFileNameLength) {
      return sanitized;
    }
    return sanitized.substring(0, _maxFileNameLength);
  }

  @visibleForTesting
  static File fileFor({
    required Directory directory,
    required String msgID,
  }) {
    return File('${directory.path}/${fileNameForMsgId(msgID)}');
  }

  String? existingPathSync(String msgID) {
    final dir = _cachedDir;
    if (dir == null) {
      return null;
    }
    final file = fileFor(directory: dir, msgID: msgID);
    try {
      if (file.existsSync() && file.lengthSync() > 0) {
        return file.path;
      }
    } catch (_) {}
    return null;
  }

  Future<String?> existingPath(String msgID) async {
    final dir = await _directory();
    final file = fileFor(directory: dir, msgID: msgID);
    if (await file.exists() && await file.length() > 0) {
      return file.path;
    }
    return null;
  }

  Future<String?> ensureCached({
    required String msgID,
    required String url,
    Future<List<int>> Function(String url)? loadBytes,
  }) {
    final key = msgID.trim();
    if (key.isEmpty) {
      return Future<String?>.value(null);
    }
    final pending = _inFlight[key];
    if (pending != null) {
      return pending;
    }
    final task = _ensureCachedOnce(
      msgID: key,
      url: url,
      loadBytes: loadBytes,
    );
    _inFlight[key] = task;
    return task.whenComplete(() {
      if (identical(_inFlight[key], task)) {
        _inFlight.remove(key);
      }
    });
  }

  Future<String?> _ensureCachedOnce({
    required String msgID,
    required String url,
    Future<List<int>> Function(String url)? loadBytes,
  }) async {
    final dir = await _directory();
    return persistHttpToFile(
      directory: dir,
      msgID: msgID,
      url: url,
      loadBytes: loadBytes ?? defaultLoadBytes,
    );
  }

  static Future<String?> persistHttpToFile({
    required Directory directory,
    required String msgID,
    required String url,
    required Future<List<int>> Function(String url) loadBytes,
  }) async {
    final file = fileFor(directory: directory, msgID: msgID);
    if (await file.exists() && await file.length() > 0) {
      return file.path;
    }
    final bytes = await loadBytes(url);
    if (bytes.isEmpty) {
      return null;
    }
    await directory.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static Future<List<int>> defaultLoadBytes(String url) async {
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const <int>[];
    }
    return response.bodyBytes;
  }

  Future<Directory> _directory() async {
    final cached = _cachedDir;
    if (cached != null) {
      return cached;
    }
    final root = await getApplicationSupportDirectory();
    final dir = Directory('${root.path}/$dirName');
    _cachedDir = dir;
    return dir;
  }
}

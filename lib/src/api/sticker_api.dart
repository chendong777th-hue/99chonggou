import 'dart:io';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';
import 'package:tencent_cloud_chat_demo/src/models/sticker_models.dart';
import 'package:tencent_cloud_chat_demo/utils/api_response_util.dart';
import 'package:tencent_cloud_chat_demo/utils/object_url_normalize.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_constants.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_media.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_upload_media.dart';

class StickerApi {
  StickerApi._();
  static final StickerApi instance = StickerApi._();

  Dio get _dio => ApiClient.instance.dio;

  List<StickerPack> _parsePackList(dynamic data) {
    final rows = extractApiList(data, listKeys: const ['packs']);
    return rows
        .whereType<Map>()
        .map((e) => StickerPack.fromJson(Map<String, dynamic>.from(e)))
        .where((p) => p.packId.isNotEmpty)
        .toList();
  }

  List<FavoriteSticker> _parseFavoriteList(dynamic data) {
    final out = <FavoriteSticker>[];
    final rows = extractApiList(
      data,
      listKeys: const ['favorites', 'items'],
    );
    for (final row in rows) {
      if (row is String && row.trim().isNotEmpty) {
        out.add(
          FavoriteSticker(
            stickerId: row.trim(),
            thumbUrl: '',
            originUrl: '',
          ),
        );
        continue;
      }
      if (row is Map) {
        final fav = FavoriteSticker.fromJson(Map<String, dynamic>.from(row));
        if (fav.stickerId.isNotEmpty) {
          out.add(fav);
        }
      }
    }
    final payload = unwrapApiPayload(data);
    if (payload is Map) {
      final ids = payload['stickerIds'];
      if (ids is List) {
        for (final id in ids) {
          final s = id?.toString().trim() ?? '';
          if (s.isEmpty || out.any((f) => f.stickerId == s)) {
            continue;
          }
          out.add(
            FavoriteSticker(stickerId: s, thumbUrl: '', originUrl: ''),
          );
        }
      }
    }
    return out;
  }

  /// 部分后端把收藏放在 `GET /me/sticker-packs` 的 `favorites` 包里。
  List<FavoriteSticker> favoritesFromPacks(List<StickerPack> packs) {
    final out = <FavoriteSticker>[];
    for (final pack in packs) {
      if (!StickerConstants.serverFavoritesPackIds.contains(pack.packId)) {
        continue;
      }
      for (final s in pack.stickers) {
        out.add(
          FavoriteSticker(
            stickerId: s.stickerId,
            thumbUrl: s.thumbUrl,
            originUrl: s.originUrl,
            mediaType: s.mediaType,
          ),
        );
      }
    }
    return out;
  }

  Future<List<StickerPack>> listMyPacks() async {
    final res = await _dio.get('/me/sticker-packs');
    return _parsePackList(res.data);
  }

  Future<void> updatePackOrder(List<String> packIds) async {
    await _dio.put('/me/sticker-packs/order', data: {
      'packIds': packIds,
    });
  }

  Future<void> uninstallPack(String packId) async {
    final encoded = Uri.encodeComponent(packId.trim());
    await _dio.delete('/me/sticker-packs/$encoded');
  }

  Future<List<FavoriteSticker>> listFavorites() async {
    final res = await _dio.get('/me/stickers/favorites');
    return _parseFavoriteList(res.data);
  }

  Future<void> addFavorite(String stickerId) async {
    await _dio.post('/me/stickers/favorites', data: {
      'stickerId': stickerId.trim(),
    });
  }

  Future<void> removeFavorite(String stickerId) async {
    final encoded = Uri.encodeComponent(stickerId.trim());
    await _dio.delete('/me/stickers/favorites/$encoded');
  }

  Future<StickerItem> uploadSticker(
    File file, {
    String? mediaType,
    bool isGif = false,
  }) async {
    final path = file.path.toLowerCase();
    final video = mediaType == StickerUploadMediaType.video ||
        StickerUploadMediaType.isVideoPath(path);
    final gif = !video &&
        (mediaType == StickerUploadMediaType.gif ||
            isGif ||
            path.endsWith('.gif'));
    final filename = _uploadFilename(path, gif: gif, video: video);
    final fileLength = await file.length();
    _logUpload(
      'request',
      extras: <String, Object?>{
        'path': file.path,
        'length': fileLength,
        'filename': filename,
        'mediaType': gif
            ? StickerUploadMediaType.gif
            : (video ? StickerUploadMediaType.video : ''),
        'gif': gif,
        'video': video,
      },
    );
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: filename,
      ),
      if (gif) 'mediaType': StickerUploadMediaType.gif,
      if (video) 'mediaType': StickerUploadMediaType.video,
    });
    try {
      final res = await _dio.post(
        '/stickers/upload',
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
      _logUpload(
        'response',
        extras: <String, Object?>{
          'status': res.statusCode,
          'data': res.data,
        },
      );
      return _stickerFromResponse(res.data);
    } on DioError catch (e) {
      _logUpload(
        'error',
        extras: <String, Object?>{
          'status': e.response?.statusCode,
          'message': e.message,
          'response': e.response?.data,
        },
      );
      rethrow;
    }
  }

  static const bool _uploadLogEnabled = false;

  void _logUpload(
    String event, {
    Map<String, Object?> extras = const {},
  }) {
    if (!_uploadLogEnabled) return;
    final buffer = StringBuffer('StickerUpload event=$event');
    for (final entry in extras.entries) {
      final value = entry.value;
      if (value == null) {
        continue;
      }
      final text = value.toString();
      if (text.isEmpty) {
        continue;
      }
      buffer.write(' ${entry.key}=${_compactLogValue(text)}');
    }
    final line = buffer.toString();
    developer.log(line, name: 'StickerUpload');
    // ignore: avoid_print
    print(line);
  }

  String _compactLogValue(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 500) {
      return normalized;
    }
    return '${normalized.substring(0, 500)}...';
  }

  String? _uploadFilename(String path,
      {required bool gif, required bool video}) {
    if (gif) {
      return 'sticker.gif';
    }
    if (video) {
      if (path.endsWith('.mov')) {
        return 'sticker.mov';
      }
      if (path.endsWith('.webm')) {
        return 'sticker.webm';
      }
      return 'sticker.mp4';
    }
    return null;
  }

  Map<String, dynamic> _stickerPayloadMap(dynamic raw) {
    final payload = unwrapApiPayload(raw);
    var map = payload is Map
        ? Map<String, dynamic>.from(payload)
        : (raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});
    final nested = map['sticker'];
    if (nested is Map) {
      map = {
        ...Map<String, dynamic>.from(nested),
        ...map,
      };
    }
    return map;
  }

  StickerItem _stickerFromResponse(dynamic raw) {
    return _stickerFromMap(_stickerPayloadMap(raw));
  }

  StickerItem _stickerFromMap(Map<String, dynamic> m) {
    final thumb = normalizeObjectUrl(m['thumbUrl']?.toString() ?? '');
    final origin = normalizeObjectUrl(m['originUrl']?.toString() ?? '');
    var mediaType = StickerMediaType.fromJson(m['mediaType']);
    if (mediaType == StickerMediaType.image &&
        (StickerMediaType.isGifUrl(origin) ||
            StickerMediaType.isGifUrl(thumb))) {
      mediaType = StickerMediaType.gif;
    }
    return StickerItem.fromJson({
      ...m,
      'thumbUrl': thumb,
      'originUrl': origin,
      'mediaType': mediaType,
    });
  }

  Future<void> addToCustomPack(String stickerId) async {
    await _dio.post('/me/sticker-packs/custom/items', data: {
      'stickerId': stickerId.trim(),
    });
  }

  Future<void> removeFromCustomPack(String stickerId) async {
    final encoded = Uri.encodeComponent(stickerId.trim());
    await _dio.delete('/me/sticker-packs/custom/items/$encoded');
  }

  Future<StickerBatchResult> batchGetStickers(List<String> stickerIds) async {
    final ids = stickerIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) {
      return const StickerBatchResult(items: [], missing: []);
    }
    final batch = ids.length > 50 ? ids.sublist(0, 50) : ids;
    final res = await _dio.post('/stickers/batch', data: {
      'stickerIds': batch,
    });
    return _parseBatchResult(res.data);
  }

  StickerBatchResult _parseBatchResult(dynamic raw) {
    final payload = unwrapApiPayload(raw);
    if (payload is! Map) {
      return const StickerBatchResult(items: [], missing: []);
    }
    final map = Map<String, dynamic>.from(payload);
    final items = <StickerItem>[];
    final rawItems = map['items'];
    if (rawItems is List) {
      for (final row in rawItems) {
        if (row is! Map) {
          continue;
        }
        final item = _stickerFromMap(Map<String, dynamic>.from(row));
        if (item.stickerId.isNotEmpty) {
          items.add(item);
        }
      }
    }
    final missing = <String>[];
    final rawMissing = map['missing'];
    if (rawMissing is List) {
      for (final id in rawMissing) {
        final s = id?.toString().trim() ?? '';
        if (s.isNotEmpty) {
          missing.add(s);
        }
      }
    }
    return StickerBatchResult(items: items, missing: missing);
  }

  Future<StickerItem> getSticker(String stickerId) async {
    final encoded = Uri.encodeComponent(stickerId.trim());
    final res = await _dio.get('/stickers/$encoded');
    final item = _stickerFromResponse(res.data);
    if (item.stickerId.isEmpty &&
        item.displayUrl(preferAnimated: false).isEmpty) {
      throw StateError('sticker payload empty');
    }
    return item;
  }
}

class StickerBatchResult {
  const StickerBatchResult({
    required this.items,
    required this.missing,
  });

  final List<StickerItem> items;
  final List<String> missing;
}

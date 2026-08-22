import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/api/sticker_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/sticker_models.dart';
import 'package:tencent_cloud_chat_demo/utils/object_url_normalize.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_constants.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_media.dart';

class StickerRepository {
  StickerRepository._();
  static final StickerRepository instance = StickerRepository._();

  final Map<String, StickerItem> _cache = {};
  final Map<String, Future<StickerItem?>> _pending = {};
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  void _notifyRevision() {
    revision.value++;
  }

  bool _hasDisplayUrl(StickerItem item) {
    return item.displayUrl(preferAnimated: false).isNotEmpty;
  }

  bool _sameCachedItem(StickerItem a, StickerItem b) {
    return a.stickerId == b.stickerId &&
        a.thumbUrl == b.thumbUrl &&
        a.originUrl == b.originUrl &&
        a.mediaType == b.mediaType &&
        a.width == b.width &&
        a.height == b.height;
  }

  void putCache(StickerItem item) {
    if (item.stickerId.isEmpty || !_hasDisplayUrl(item)) {
      return;
    }
    final existing = _cache[item.stickerId];
    if (existing != null && _sameCachedItem(existing, item)) {
      return;
    }
    _cache[item.stickerId] = item;
    _notifyRevision();
  }

  void putCaches(Iterable<StickerItem> items) {
    var changed = false;
    for (final item in items) {
      if (item.stickerId.isEmpty || !_hasDisplayUrl(item)) {
        continue;
      }
      final existing = _cache[item.stickerId];
      if (existing != null && _sameCachedItem(existing, item)) {
        continue;
      }
      _cache[item.stickerId] = item;
      changed = true;
    }
    if (changed) {
      _notifyRevision();
    }
  }

  StickerItem? getCached(String stickerId) => _cache[stickerId.trim()];

  /// 同步解析：消息内嵌 URL 或内存缓存（不发起网络请求）。
  StickerItem? resolveStickerItemSync(String data) {
    final trimmed = data.trim();
    if (trimmed.startsWith('http')) {
      return StickerItem(
        stickerId: '',
        thumbUrl: trimmed,
        originUrl: trimmed,
        mediaType: StickerMediaType.isGifUrl(trimmed)
            ? StickerMediaType.gif
            : StickerMediaType.image,
      );
    }
    final stickerId = parseStickerId(trimmed);
    if (stickerId == null) {
      return null;
    }
    final embedded = _itemFromEmbeddedUrls(trimmed, stickerId);
    if (embedded != null) {
      putCache(embedded);
      return embedded;
    }
    final cached = getCached(stickerId);
    if (cached != null && _hasDisplayUrl(cached)) {
      return cached;
    }
    return null;
  }

  String? parseStickerId(String data) =>
      StickerConstants.parseStickerIdFromData(data);

  StickerItem? _itemFromEmbeddedUrls(String data, String stickerId) {
    final embedded = StickerConstants.parseEmbeddedUrls(data);
    var thumb = normalizeObjectUrl(embedded.thumbUrl);
    var origin = normalizeObjectUrl(embedded.originUrl);
    if (thumb.isEmpty && origin.isEmpty) {
      return null;
    }
    if (thumb.isEmpty) {
      thumb = origin;
    }
    if (origin.isEmpty) {
      origin = thumb;
    }
    final mediaType = StickerMediaType.isGifUrl(origin) ||
            StickerMediaType.isGifUrl(thumb)
        ? StickerMediaType.gif
        : StickerMediaType.image;
    final item = StickerItem(
      stickerId: stickerId,
      thumbUrl: thumb,
      originUrl: origin,
      mediaType: mediaType,
    );
    return _hasDisplayUrl(item) ? item : null;
  }

  bool isDynamicFaceData(String data) {
    final t = data.trim();
    return t.startsWith('http') || t.startsWith(StickerConstants.stickerDataScheme);
  }

  Future<StickerItem?> resolveStickerItem(String data) async {
    final sync = resolveStickerItemSync(data);
    if (sync != null) {
      return sync;
    }
    final trimmed = data.trim();
    final stickerId = parseStickerId(trimmed);
    if (stickerId == null) {
      return null;
    }
    final cached = getCached(stickerId);
    if (cached != null) {
      if (_hasDisplayUrl(cached)) {
        return cached;
      }
      _cache.remove(stickerId);
    }
    final pending = _pending[stickerId];
    if (pending != null) {
      return pending;
    }

    final task = (() async {
      try {
        final item = await StickerApi.instance.getSticker(stickerId);
        if (!_hasDisplayUrl(item)) {
          return null;
        }
        putCache(item);
        return item;
      } catch (_) {
        return null;
      } finally {
        _pending.remove(stickerId);
      }
    })();
    _pending[stickerId] = task;
    return task;
  }

  Future<String?> resolveDisplayUrl(String data, {bool preferAnimated = true}) async {
    final item = await resolveStickerItem(data);
    if (item == null) {
      return null;
    }
    return item.displayUrl(preferAnimated: preferAnimated);
  }

  /// 批量预取未缓存的表情（`POST /stickers/batch`）。
  Future<void> prefetchStickerIds(Iterable<String> stickerIds) async {
    final missing = <String>[];
    for (final raw in stickerIds) {
      final id = raw.trim();
      if (id.isEmpty) {
        continue;
      }
      final cached = getCached(id);
      if (cached != null && _hasDisplayUrl(cached)) {
        continue;
      }
      if (_pending.containsKey(id)) {
        continue;
      }
      missing.add(id);
    }
    if (missing.isEmpty) {
      return;
    }
    try {
      final result = await StickerApi.instance.batchGetStickers(missing);
      putCaches(
        result.items.where(_hasDisplayUrl),
      );
    } catch (_) {}
  }

  void clear() {
    _cache.clear();
    _pending.clear();
    _notifyRevision();
  }
}

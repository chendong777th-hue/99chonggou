import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';
import 'package:tencent_cloud_chat_demo/src/models/favorite_message_models.dart';
import 'package:tencent_cloud_chat_demo/utils/api_response_util.dart';
import 'package:tencent_cloud_chat_demo/utils/dio_error_message.dart';
import 'package:tencent_cloud_chat_demo/utils/object_url_normalize.dart';

class FavoriteListResult {
  FavoriteListResult({
    required this.items,
    required this.total,
    required this.page,
    required this.size,
  });

  final List<FavoriteMessageItem> items;
  final int total;
  final int page;
  final int size;
}

class FavoriteMessageApi {
  FavoriteMessageApi._();
  static final FavoriteMessageApi instance = FavoriteMessageApi._();

  Dio get _dio => ApiClient.instance.dio;

  static String errorMessage(DioError e) => DioErrorMessage.forApp(e);

  FavoriteMessageItem _parseItem(dynamic raw) {
    final map = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final thumb = map['thumbUrl']?.toString();
    final media = map['mediaUrl']?.toString();
    if (thumb != null && thumb.isNotEmpty) {
      map['thumbUrl'] = normalizeObjectUrl(thumb);
    }
    if (media != null && media.isNotEmpty) {
      map['mediaUrl'] = normalizeObjectUrl(media);
    }
    return FavoriteMessageItem.fromJson(map);
  }

  Future<FavoriteListResult> list({
    FavoriteMessageType? type,
    int page = 0,
    int size = 100,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'size': size,
    };
    if (type != null) {
      query['type'] = type.apiValue;
    }
    final res = await _dio.get('/me/favorites', queryParameters: query);
    final payload = unwrapApiPayload(res.data);
    final rows = extractApiList(res.data, listKeys: const ['items']);
    final items = rows
        .map(_parseItem)
        .where((e) => e.id.isNotEmpty)
        .toList();
    var total = items.length;
    var pageOut = page;
    var sizeOut = size;
    if (payload is Map) {
      total = payload['total'] is int
          ? payload['total'] as int
          : int.tryParse(payload['total']?.toString() ?? '') ?? items.length;
      pageOut = payload['page'] is int
          ? payload['page'] as int
          : int.tryParse(payload['page']?.toString() ?? '') ?? page;
      sizeOut = payload['size'] is int
          ? payload['size'] as int
          : int.tryParse(payload['size']?.toString() ?? '') ?? size;
    }
    return FavoriteListResult(
      items: items,
      total: total,
      page: pageOut,
      size: sizeOut,
    );
  }

  /// 拉取全部收藏（自动翻页，最多 [maxItems] 条）。
  Future<List<FavoriteMessageItem>> listAll({int maxItems = 500}) async {
    final out = <FavoriteMessageItem>[];
    var page = 0;
    const size = 100;
    while (out.length < maxItems) {
      final batch = await list(page: page, size: size);
      out.addAll(batch.items);
      if (batch.items.isEmpty || out.length >= batch.total) {
        break;
      }
      page++;
    }
    return out;
  }

  Future<FavoriteMessageItem> getById(String id) async {
    final encoded = Uri.encodeComponent(id.trim());
    final res = await _dio.get('/me/favorites/$encoded');
    final payload = unwrapApiPayload(res.data);
    return _parseItem(payload is Map ? payload : res.data);
  }

  Future<FavoriteMessageItem> create(CreateFavoriteRequest request) async {
    final res = await _dio.post('/me/favorites', data: request.toJson());
    final payload = unwrapApiPayload(res.data);
    return _parseItem(payload is Map ? payload : res.data);
  }

  static String _uploadFilename(String path, FavoriteMessageType type) {
    final base = path.split('/').last;
    final dot = base.lastIndexOf('.');
    if (dot > 0 && dot < base.length - 1) {
      return base;
    }
    switch (type) {
      case FavoriteMessageType.image:
        return 'favorite.jpg';
      case FavoriteMessageType.video:
        return 'favorite.mp4';
      case FavoriteMessageType.text:
        return 'favorite.bin';
    }
  }

  static MediaType? _uploadMediaType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }
    if (lower.endsWith('.png')) {
      return MediaType('image', 'png');
    }
    if (lower.endsWith('.webp')) {
      return MediaType('image', 'webp');
    }
    if (lower.endsWith('.mp4')) {
      return MediaType('video', 'mp4');
    }
    if (lower.endsWith('.mov')) {
      return MediaType('video', 'quicktime');
    }
    return null;
  }

  static Future<MultipartFile> _multipartFile(
    File file,
    FavoriteMessageType type,
  ) async {
    final filename = _uploadFilename(file.path, type);
    final mediaType = _uploadMediaType(filename);
    return MultipartFile.fromFile(
      file.path,
      filename: filename,
      contentType: mediaType,
    );
  }

  Future<FavoriteMessageItem> upload({
    required File file,
    required FavoriteMessageType type,
    File? snapshot,
    int? durationSec,
    String? sourceConvLabel,
    String? sourceMsgId,
    String? sourceConvId,
    String? sourceSenderName,
  }) async {
    final metadata = <String, dynamic>{
      'type': type.apiValue,
      if (durationSec != null) 'durationSec': durationSec,
      if (sourceConvLabel != null && sourceConvLabel.trim().isNotEmpty)
        'sourceConvLabel': sourceConvLabel.trim(),
      if (sourceMsgId != null && sourceMsgId.trim().isNotEmpty)
        'sourceMsgId': sourceMsgId.trim(),
      if (sourceConvId != null && sourceConvId.trim().isNotEmpty)
        'sourceConvId': sourceConvId.trim(),
      if (sourceSenderName != null && sourceSenderName.trim().isNotEmpty)
        'sourceSenderName': sourceSenderName.trim(),
    };
    final form = FormData.fromMap({
      'file': await _multipartFile(file, type),
      if (snapshot != null)
        'snapshot': await _multipartFile(snapshot, FavoriteMessageType.image),
      'metadata': jsonEncode(metadata),
    });
    final res = await _dio.post(
      '/me/favorites/upload',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    final payload = unwrapApiPayload(res.data);
    return _parseItem(payload is Map ? payload : res.data);
  }

  Future<FavoriteMessageItem> update({
    required String id,
    String? text,
    String? sourceConvLabel,
  }) async {
    final encoded = Uri.encodeComponent(id.trim());
    final body = <String, dynamic>{};
    if (text != null) {
      body['text'] = text;
    }
    if (sourceConvLabel != null) {
      body['sourceConvLabel'] = sourceConvLabel;
    }
    final res = await _dio.put('/me/favorites/$encoded', data: body);
    final payload = unwrapApiPayload(res.data);
    return _parseItem(payload is Map ? payload : res.data);
  }

  Future<void> delete(String id) async {
    final encoded = Uri.encodeComponent(id.trim());
    await _dio.delete('/me/favorites/$encoded');
  }

  Future<int> deleteMany(List<String> ids) async {
    if (ids.isEmpty) {
      return 0;
    }
    final res = await _dio.delete(
      '/me/favorites',
      data: {'ids': ids},
    );
    final payload = unwrapApiPayload(res.data);
    if (payload is Map) {
      return payload['deleted'] is int
          ? payload['deleted'] as int
          : int.tryParse(payload['deleted']?.toString() ?? '') ?? ids.length;
    }
    return ids.length;
  }
}

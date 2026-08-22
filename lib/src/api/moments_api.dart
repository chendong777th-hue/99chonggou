import 'dart:io';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';
import 'package:tencent_cloud_chat_demo/src/models/moments/moment_models.dart';
import 'package:tencent_cloud_chat_demo/src/models/moments/moment_settings_models.dart';
import 'package:tencent_cloud_chat_demo/utils/api_response_util.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

class MomentsPageResult {
  const MomentsPageResult({
    required this.items,
    required this.hasMore,
    this.nextCursor,
    this.visibleRangeDays,
  });

  final List<MomentPost> items;
  final String? nextCursor;
  final bool hasMore;
  final int? visibleRangeDays;
}

class MomentsNotificationsResult {
  const MomentsNotificationsResult({
    required this.items,
    required this.hasMore,
    required this.unreadCount,
    this.nextCursor,
  });

  final List<MomentNotification> items;
  final String? nextCursor;
  final bool hasMore;
  final int unreadCount;
}

class MomentsApi {
  MomentsApi._();

  static final MomentsApi instance = MomentsApi._();

  Dio get _dio => ApiClient.instance.dio;

  Future<MomentsPageResult> fetchFeed({
    String? cursor,
    int pageSize = 20,
  }) async {
    final res = await _dio.get(
      '/moments/feed',
      queryParameters: _pageQuery(cursor: cursor, pageSize: pageSize),
    );
    return _parsePostPage(res.data);
  }

  Future<MomentsPageResult> fetchUserMoments(
    String userId, {
    String? cursor,
    int pageSize = 20,
  }) async {
    final res = await _dio.get(
      '/moments/users/${Uri.encodeComponent(userId.trim())}',
      queryParameters: _pageQuery(cursor: cursor, pageSize: pageSize),
    );
    return _parsePostPage(res.data);
  }

  Future<MomentPost> fetchDetail(String momentId) async {
    final res = await _dio.get('/moments/${Uri.encodeComponent(momentId)}');
    final payload = unwrapApiPayload(res.data);
    if (payload is Map) {
      return MomentPost.fromJson(Map<String, dynamic>.from(payload));
    }
    throw StateError('invalid moment detail response');
  }

  Future<MomentAttachment> uploadMedia(MomentAttachment attachment) async {
    final path = attachment.path.trim();
    if (path.isEmpty || path.startsWith('http') || path.startsWith('assets/')) {
      return attachment;
    }
    final file = File(path);
    final filename = path.split(Platform.pathSeparator).last;
    final form = FormData.fromMap(<String, dynamic>{
      'file': await MultipartFile.fromFile(path, filename: filename),
      'type': attachment.type.apiValue,
      'clientMediaId': const Uuid().v4(),
    });
    final res = await _dio.post(
      '/moments/media/upload',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    final payload = unwrapApiPayload(res.data);
    if (payload is Map) {
      final uploaded =
          MomentAttachment.fromJson(Map<String, dynamic>.from(payload));
      return uploaded.copyWith(
        path: uploaded.path.isEmpty ? file.path : uploaded.path,
        durationSec: uploaded.durationSec ?? attachment.durationSec,
        width: uploaded.width ?? attachment.width,
        height: uploaded.height ?? attachment.height,
        sizeBytes: uploaded.sizeBytes ?? attachment.sizeBytes,
      );
    }
    throw StateError('invalid media upload response');
  }

  Future<MomentPost> createPost({
    required String text,
    required List<String> mediaIds,
    String? location,
    String visibility = 'FRIENDS',
    List<String> visibleUserIds = const [],
  }) async {
    final normalizedVisibility = visibility.trim().toUpperCase();
    final normalizedUserIds = visibleUserIds
        .map((id) => ChatIdFormat.rawUserUid(id))
        .where((id) => id.isNotEmpty)
        .toList();
    final res = await _dio.post(
      '/moments',
      data: <String, dynamic>{
        'text': text.trim(),
        'mediaIds': mediaIds,
        if ((location ?? '').trim().isNotEmpty) 'location': location!.trim(),
        'visibility': normalizedVisibility,
        if (normalizedVisibility == 'EXCLUDE' ||
            normalizedVisibility == 'PARTIAL')
          'visibleUserIds': normalizedUserIds,
      },
      options: Options(headers: <String, dynamic>{
        'Idempotency-Key': const Uuid().v4(),
      }),
    );
    final payload = unwrapApiPayload(res.data);
    if (payload is Map) {
      return MomentPost.fromJson(Map<String, dynamic>.from(payload));
    }
    throw StateError('invalid create moment response');
  }

  Future<void> deletePost(String momentId) async {
    await _dio.delete('/moments/${Uri.encodeComponent(momentId)}');
  }

  Future<MomentPost> like(String momentId, {MomentPost? current}) async {
    final res =
        await _dio.post('/moments/${Uri.encodeComponent(momentId)}/likes');
    return _resolveMomentMutation(momentId, res.data, current: current);
  }

  Future<MomentPost> unlike(String momentId, {MomentPost? current}) async {
    final res =
        await _dio.delete('/moments/${Uri.encodeComponent(momentId)}/likes/me');
    return _resolveMomentMutation(momentId, res.data, current: current);
  }

  Future<MomentPost> addComment(
    String momentId,
    String text, {
    String? replyToCommentId,
  }) async {
    final res = await _dio.post(
      '/moments/${Uri.encodeComponent(momentId)}/comments',
      data: <String, dynamic>{
        'text': text.trim(),
        'replyToCommentId': (replyToCommentId ?? '').trim().isEmpty
            ? null
            : replyToCommentId!.trim(),
      },
      options: Options(headers: <String, dynamic>{
        'Idempotency-Key': const Uuid().v4(),
      }),
    );
    return _resolveMomentMutation(momentId, res.data);
  }

  Future<void> deleteComment(String momentId, String commentId) async {
    await _dio.delete(
      '/moments/${Uri.encodeComponent(momentId)}/comments/${Uri.encodeComponent(commentId)}',
    );
  }

  Future<MomentsNotificationsResult> fetchNotifications({
    String? cursor,
    int pageSize = 20,
  }) async {
    final res = await _dio.get(
      '/moments/notifications',
      queryParameters: _pageQuery(cursor: cursor, pageSize: pageSize),
    );
    final payload = unwrapApiPayload(res.data);
    if (payload is! Map) {
      return const MomentsNotificationsResult(
        items: [],
        hasMore: false,
        unreadCount: 0,
      );
    }
    final map = Map<String, dynamic>.from(payload);
    final items = (map['items'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => MomentNotification.fromJson(Map<String, dynamic>.from(e)))
        .where((item) => item.id.trim().isNotEmpty)
        .toList();
    return MomentsNotificationsResult(
      items: items,
      nextCursor: map['nextCursor']?.toString(),
      hasMore: map['hasMore'] == true,
      unreadCount: _parseInt(map['unreadCount']) ?? 0,
    );
  }

  Future<void> markNotificationsRead({
    List<String> notificationIds = const [],
    bool readAll = false,
  }) async {
    await _dio.post(
      '/moments/notifications/read',
      data: <String, dynamic>{
        'notificationIds': notificationIds,
        'readAll': readAll,
      },
    );
  }

  Future<MomentsSettings> fetchSettings() async {
    final res = await _dio.get('/moments/settings');
    final payload = unwrapApiPayload(res.data);
    if (payload is Map) {
      return MomentsSettings.fromJson(Map<String, dynamic>.from(payload));
    }
    throw StateError('invalid moments settings response');
  }

  Future<MomentsSettings> updateSettings(MomentsSettingsPatch patch) async {
    if (patch.isEmpty) {
      return fetchSettings();
    }
    final res =
        await _dio.put('/moments/settings', data: patch.toRequestBody());
    final payload = unwrapApiPayload(res.data);
    if (payload is Map) {
      return MomentsSettings.fromJson(Map<String, dynamic>.from(payload));
    }
    throw StateError('invalid moments settings response');
  }

  Future<String> uploadCover(String filePath) async {
    final path = filePath.trim();
    if (path.isEmpty) {
      throw ArgumentError.value(filePath, 'filePath', 'cover path is empty');
    }
    final filename = path.split(Platform.pathSeparator).last;
    final form = FormData.fromMap(<String, dynamic>{
      'file': await MultipartFile.fromFile(path, filename: filename),
    });
    final res = await _dio.post(
      '/moments/cover/upload',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    final payload = unwrapApiPayload(res.data);
    if (payload is Map) {
      final coverUrl = payload['coverUrl']?.toString().trim() ?? '';
      if (coverUrl.isNotEmpty) {
        return coverUrl;
      }
    }
    throw StateError('invalid cover upload response');
  }

  Map<String, dynamic> _pageQuery({
    required String? cursor,
    required int pageSize,
  }) {
    return <String, dynamic>{
      if ((cursor ?? '').trim().isNotEmpty) 'cursor': cursor!.trim(),
      'pageSize': pageSize.clamp(1, 50),
    };
  }

  MomentsPageResult _parsePostPage(dynamic raw) {
    final payload = unwrapApiPayload(raw);
    if (payload is! Map) {
      return const MomentsPageResult(items: [], hasMore: false);
    }
    final map = Map<String, dynamic>.from(payload);
    final items = (map['items'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => MomentPost.fromJson(Map<String, dynamic>.from(e)))
        .where((item) => item.id.trim().isNotEmpty)
        .toList();
    return MomentsPageResult(
      items: items,
      nextCursor: map['nextCursor']?.toString(),
      hasMore: map['hasMore'] == true,
      visibleRangeDays: _parseVisibleRangeDays(map),
    );
  }

  int? _parseVisibleRangeDays(Map<String, dynamic> map) {
    final direct = map['visibleRangeDays'];
    if (direct is int) return direct;
    if (direct is String) return int.tryParse(direct.trim());
    final user = map['user'];
    if (user is Map) {
      final nested = Map<String, dynamic>.from(user)['visibleRangeDays'];
      if (nested is int) return nested;
      if (nested is String) return int.tryParse(nested.trim());
    }
    return null;
  }

  Future<MomentPost> _resolveMomentMutation(
    String momentId,
    dynamic raw, {
    MomentPost? current,
  }) async {
    final payload = unwrapApiPayload(raw);
    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload);
      if (momentJsonIsFullItem(map)) {
        return MomentPost.fromJson(map);
      }
      if (current != null && momentJsonIsLikeMutation(map)) {
        return mergeMomentLikeMutation(current, map);
      }
    }
    return fetchDetail(momentId);
  }

  int? _parseInt(dynamic raw) {
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }
}

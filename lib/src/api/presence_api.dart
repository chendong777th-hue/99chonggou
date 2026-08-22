import 'package:dio/dio.dart';

import 'api_client.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime/presence_last_seen_codec.dart';

export 'package:tencent_cloud_chat_demo/src/services/friend_realtime/presence_last_seen_codec.dart'
    show PresenceLastSeenBatch;

class PresenceApi {
  PresenceApi._();
  static final PresenceApi instance = PresenceApi._();

  Dio get _dio => ApiClient.instance.dio;

  Future<void> heartbeat() async {
    await ApiClient.instance.ensureDeviceIdReady();
    final deviceId = ApiClient.instance.deviceId;
    await _dio.post(
      '/me/heartbeat',
      data: deviceId.isNotEmpty ? {'deviceId': deviceId} : null,
    );
  }

  Future<PresenceLastSeenBatch> fetchLastSeen(List<String> userIds) async {
    final ids = PresenceLastSeenCodec.normalizeUserIds(userIds);
    if (ids.isEmpty) {
      return const PresenceLastSeenBatch(
        lastSeen: {},
        lastActiveVisibility: {},
      );
    }
    final res = await _dio.post(
      '/presence/last-seen',
      data: {'userIds': ids},
    );
    final payload = (res.data['data'] as Map?) ?? const {};
    return PresenceLastSeenCodec.parseBatch(
      Map<String, dynamic>.from(payload),
    );
  }
}

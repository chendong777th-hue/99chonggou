import 'package:dio/dio.dart';

import 'package:tencent_cloud_chat_demo/utils/api_response_util.dart';

import 'api_client.dart';

class ConversationNotifyItem {
  const ConversationNotifyItem({
    required this.chatType,
    required this.peerId,
    required this.muted,
  });

  final String chatType;
  final String peerId;
  final bool muted;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'chatType': chatType,
      'peerId': peerId,
      'muted': muted,
    };
  }

  factory ConversationNotifyItem.fromJson(Map<String, dynamic> json) {
    return ConversationNotifyItem(
      chatType: json['chatType']?.toString() ?? '',
      peerId: json['peerId']?.toString() ?? '',
      muted: _readBool(json['muted']),
    );
  }

  static bool _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == 'true' || text == '1';
  }
}

class ConversationNotifyBatchResult {
  const ConversationNotifyBatchResult({
    required this.ok,
    required this.count,
  });

  final bool ok;
  final int count;

  factory ConversationNotifyBatchResult.fromJson(Map<String, dynamic> json) {
    return ConversationNotifyBatchResult(
      ok: ConversationNotifyItem._readBool(json['ok']),
      count: _readInt(json['count']),
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class ConversationNotifyApi {
  ConversationNotifyApi._();

  static final ConversationNotifyApi instance = ConversationNotifyApi._();

  Dio get _dio => ApiClient.instance.dio;

  Future<void> updateMute({
    required String chatType,
    required String peerId,
    required bool muted,
  }) async {
    final type = chatType.trim().toLowerCase();
    final id = peerId.trim();
    if (type.isEmpty || id.isEmpty) {
      throw ArgumentError('chatType and peerId are required');
    }
    final res = await _dio.put(
      '/me/conversation-notify',
      data: <String, dynamic>{
        'chatType': type,
        'peerId': id,
        'muted': muted,
      },
    );
    _ensureOk(res.data);
  }

  Future<ConversationNotifyBatchResult> batchUpdate(
    List<ConversationNotifyItem> items,
  ) async {
    if (items.isEmpty) {
      return const ConversationNotifyBatchResult(ok: true, count: 0);
    }
    final res = await _dio.put(
      '/me/conversation-notify/batch',
      data: <String, dynamic>{
        'items': items.map((item) => item.toJson()).toList(growable: false),
      },
    );
    final payload = _payloadMap(res.data);
    return ConversationNotifyBatchResult.fromJson(payload);
  }

  Future<List<ConversationNotifyItem>> fetchMuted() async {
    final res = await _dio.get('/me/conversation-notify');
    final payload = unwrapApiPayload(res.data);
    if (payload is List) {
      return payload
          .whereType<Map>()
          .map((item) => ConversationNotifyItem.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .where((item) => item.peerId.isNotEmpty && item.chatType.isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }

  void _ensureOk(dynamic raw) {
    if (raw is Map) {
      final code = raw['code'];
      if (code is num && code != 0) {
        throw StateError(raw['message']?.toString() ?? 'sync mute failed');
      }
    }
    final payload = _payloadMap(raw);
    if (payload.isNotEmpty && !ConversationNotifyItem._readBool(payload['ok'])) {
      throw StateError('sync mute failed');
    }
  }

  Map<String, dynamic> _payloadMap(dynamic raw) {
    final payload = unwrapApiPayload(raw);
    if (payload is Map<String, dynamic>) {
      return payload;
    }
    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }
    return const <String, dynamic>{};
  }
}

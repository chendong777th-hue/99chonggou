import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/utils/api_response_util.dart';

import 'api_client.dart';

int? _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

bool _readBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  final text = value?.toString().trim().toLowerCase() ?? '';
  return text == 'true' || text == '1';
}

class ConversationPinItem {
  const ConversationPinItem({
    required this.chatType,
    required this.peerId,
    this.pinnedAt,
    this.updatedAt,
  });

  final String chatType;
  final String peerId;
  final int? pinnedAt;
  final int? updatedAt;

  factory ConversationPinItem.fromJson(Map<String, dynamic> json) {
    return ConversationPinItem(
      chatType: json['chatType']?.toString().trim().toLowerCase() ?? '',
      peerId: json['peerId']?.toString().trim() ?? '',
      pinnedAt: _asInt(json['pinnedAt'] ?? json['pinned_at']),
      updatedAt: _asInt(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toMutationJson({required bool pinned}) {
    return <String, dynamic>{
      'chatType': chatType,
      'peerId': peerId,
      'pinned': pinned,
    };
  }
}

class ConversationPinPage {
  const ConversationPinPage({
    required this.items,
    this.serverTime,
    this.updatedAt,
  });

  final List<ConversationPinItem> items;
  final int? serverTime;
  final int? updatedAt;

  static const ConversationPinPage empty = ConversationPinPage(
    items: <ConversationPinItem>[],
  );

  factory ConversationPinPage.fromJson(Map<String, dynamic> map) {
    final rawItems = map['items'];
    final items = <ConversationPinItem>[];
    if (rawItems is List) {
      for (final entry in rawItems) {
        if (entry is! Map) {
          continue;
        }
        final item = ConversationPinItem.fromJson(
          Map<String, dynamic>.from(entry),
        );
        if (item.chatType.isEmpty || item.peerId.isEmpty) {
          continue;
        }
        if (item.chatType != 'c2c' && item.chatType != 'group') {
          continue;
        }
        items.add(item);
      }
    }
    return ConversationPinPage(
      items: items,
      serverTime: _asInt(map['serverTime'] ?? map['server_time']),
      updatedAt: _asInt(map['updatedAt'] ?? map['updated_at']),
    );
  }
}

class ConversationPinMutationResult {
  const ConversationPinMutationResult({
    required this.ok,
    required this.chatType,
    required this.peerId,
    required this.pinned,
    this.pinnedAt,
    this.updatedAt,
    this.items = const <ConversationPinItem>[],
    this.serverTime,
  });

  final bool ok;
  final String chatType;
  final String peerId;
  final bool pinned;
  final int? pinnedAt;
  final int? updatedAt;
  final List<ConversationPinItem> items;
  final int? serverTime;

  factory ConversationPinMutationResult.fromJson(Map<String, dynamic> json) {
    final page = ConversationPinPage.fromJson(json);
    return ConversationPinMutationResult(
      ok: _readBool(json['ok']),
      chatType: json['chatType']?.toString().trim().toLowerCase() ?? '',
      peerId: json['peerId']?.toString().trim() ?? '',
      pinned: _readBool(json['pinned']),
      pinnedAt: _asInt(json['pinnedAt'] ?? json['pinned_at']),
      updatedAt: _asInt(json['updatedAt'] ?? json['updated_at']),
      items: page.items,
      serverTime: page.serverTime,
    );
  }
}

class ConversationPinBatchResult {
  const ConversationPinBatchResult({
    required this.ok,
    required this.count,
    this.updatedAt,
    this.items = const <ConversationPinItem>[],
    this.serverTime,
  });

  final bool ok;
  final int count;
  final int? updatedAt;
  final List<ConversationPinItem> items;
  final int? serverTime;

  factory ConversationPinBatchResult.fromJson(Map<String, dynamic> json) {
    final page = ConversationPinPage.fromJson(json);
    return ConversationPinBatchResult(
      ok: _readBool(json['ok']),
      count: _asInt(json['count']) ?? 0,
      updatedAt: _asInt(json['updatedAt'] ?? json['updated_at']),
      items: page.items,
      serverTime: page.serverTime,
    );
  }
}

class ConversationPinLimitExceededException implements Exception {
  const ConversationPinLimitExceededException([
    this.message = 'PIN_LIMIT_EXCEEDED',
  ]);

  final String message;

  @override
  String toString() => message;
}

/// 会话置顶多端同步 API（自建后端；腾讯为主时作跟写目标，不单独作为 UI 真相）。
class ConversationPinApi {
  ConversationPinApi._();

  static final ConversationPinApi instance = ConversationPinApi._();

  Dio get _dio => ApiClient.instance.dio;

  Future<ConversationPinPage> fetchAll() async {
    final res = await _dio.get('/me/pinned-conversations');
    final payload = unwrapApiPayload(res.data);
    if (payload is! Map) {
      return ConversationPinPage.empty;
    }
    return ConversationPinPage.fromJson(Map<String, dynamic>.from(payload));
  }

  Future<ConversationPinMutationResult> setPinned({
    required String chatType,
    required String peerId,
    required bool pinned,
  }) async {
    final type = chatType.trim().toLowerCase();
    final id = peerId.trim();
    if (type.isEmpty || id.isEmpty) {
      throw ArgumentError('chatType and peerId are required');
    }
    try {
      final res = await _dio.put(
        '/me/pinned-conversations',
        data: <String, dynamic>{
          'chatType': type,
          'peerId': id,
          'pinned': pinned,
        },
      );
      final payload = unwrapApiPayload(res.data);
      if (payload is Map) {
        return ConversationPinMutationResult.fromJson(
          Map<String, dynamic>.from(payload),
        );
      }
      return ConversationPinMutationResult(
        ok: true,
        chatType: type,
        peerId: id,
        pinned: pinned,
      );
    } on DioError catch (e) {
      _throwIfPinLimit(e);
      rethrow;
    }
  }

  Future<ConversationPinBatchResult> batchSetPinned(
    List<ConversationPinItem> items, {
    required bool pinned,
  }) async {
    if (items.isEmpty) {
      return const ConversationPinBatchResult(ok: true, count: 0);
    }
    try {
      final res = await _dio.put(
        '/me/pinned-conversations/batch',
        data: <String, dynamic>{
          'items': items
              .map((item) => item.toMutationJson(pinned: pinned))
              .toList(growable: false),
        },
      );
      final payload = unwrapApiPayload(res.data);
      if (payload is Map) {
        return ConversationPinBatchResult.fromJson(
          Map<String, dynamic>.from(payload),
        );
      }
      return ConversationPinBatchResult(ok: true, count: items.length);
    } on DioError catch (e) {
      _throwIfPinLimit(e);
      rethrow;
    }
  }

  void _throwIfPinLimit(DioError e) {
    final data = e.response?.data;
    if (data is Map) {
      final code = data['code']?.toString() ?? '';
      final message = data['message']?.toString() ?? '';
      final combined = '$code $message'.toUpperCase();
      if (combined.contains('PIN_LIMIT')) {
        throw ConversationPinLimitExceededException(
          message.isNotEmpty ? message : 'PIN_LIMIT_EXCEEDED',
        );
      }
    }
  }
}

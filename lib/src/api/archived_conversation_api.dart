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

class ArchivedConversationItem {
  const ArchivedConversationItem({
    required this.chatType,
    required this.peerId,
    this.archivedAt,
    this.updatedAt,
  });

  final String chatType;
  final String peerId;
  final int? archivedAt;
  final int? updatedAt;

  factory ArchivedConversationItem.fromJson(Map<String, dynamic> json) {
    return ArchivedConversationItem(
      chatType: json['chatType']?.toString().trim().toLowerCase() ?? '',
      peerId: json['peerId']?.toString().trim() ?? '',
      archivedAt: _asInt(json['archivedAt'] ?? json['archived_at']),
      updatedAt: _asInt(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toMutationJson({required bool archived}) {
    return <String, dynamic>{
      'chatType': chatType,
      'peerId': peerId,
      'archived': archived,
    };
  }
}

class ArchivedConversationPage {
  const ArchivedConversationPage({
    required this.items,
    this.serverTime,
    this.nextSince,
    this.hasMore = false,
  });

  final List<ArchivedConversationItem> items;
  final int? serverTime;
  final int? nextSince;
  final bool hasMore;

  static const ArchivedConversationPage empty = ArchivedConversationPage(
    items: <ArchivedConversationItem>[],
  );
}

class ArchivedConversationMutationResult {
  const ArchivedConversationMutationResult({
    required this.ok,
    required this.chatType,
    required this.peerId,
    required this.archived,
    this.archivedAt,
    this.updatedAt,
  });

  final bool ok;
  final String chatType;
  final String peerId;
  final bool archived;
  final int? archivedAt;
  final int? updatedAt;

  factory ArchivedConversationMutationResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return ArchivedConversationMutationResult(
      ok: _readBool(json['ok']),
      chatType: json['chatType']?.toString().trim().toLowerCase() ?? '',
      peerId: json['peerId']?.toString().trim() ?? '',
      archived: _readBool(json['archived']),
      archivedAt: _asInt(json['archivedAt'] ?? json['archived_at']),
      updatedAt: _asInt(json['updatedAt'] ?? json['updated_at']),
    );
  }
}

class ArchivedConversationBatchResult {
  const ArchivedConversationBatchResult({
    required this.ok,
    required this.count,
    this.updatedAt,
  });

  final bool ok;
  final int count;
  final int? updatedAt;

  factory ArchivedConversationBatchResult.fromJson(Map<String, dynamic> json) {
    return ArchivedConversationBatchResult(
      ok: _readBool(json['ok']),
      count: _asInt(json['count']) ?? 0,
      updatedAt: _asInt(json['updatedAt'] ?? json['updated_at']),
    );
  }
}

/// 会话归档多端同步 API。
class ArchivedConversationApi {
  ArchivedConversationApi._();

  static final ArchivedConversationApi instance = ArchivedConversationApi._();

  Dio get _dio => ApiClient.instance.dio;

  Future<ArchivedConversationPage> fetch({
    int? since,
    int limit = 500,
  }) async {
    final res = await _dio.get(
      '/me/archived-conversations',
      queryParameters: <String, dynamic>{
        if (since != null && since > 0) 'since': since,
        'limit': limit.clamp(1, 1000),
      },
    );
    final payload = unwrapApiPayload(res.data);
    if (payload is! Map) {
      return ArchivedConversationPage.empty;
    }
    final map = Map<String, dynamic>.from(payload);
    final rawItems = map['items'];
    final items = <ArchivedConversationItem>[];
    if (rawItems is List) {
      for (final entry in rawItems) {
        if (entry is! Map) {
          continue;
        }
        final item = ArchivedConversationItem.fromJson(
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
    return ArchivedConversationPage(
      items: items,
      serverTime: _asInt(map['serverTime'] ?? map['server_time']),
      nextSince: _asInt(map['nextSince'] ?? map['next_since']),
      hasMore: map['hasMore'] == true || map['has_more'] == true,
    );
  }

  Future<ArchivedConversationMutationResult> update({
    required String chatType,
    required String peerId,
    required bool archived,
  }) async {
    final type = chatType.trim().toLowerCase();
    final id = peerId.trim();
    if (type.isEmpty || id.isEmpty) {
      throw ArgumentError('chatType and peerId are required');
    }
    final res = await _dio.put(
      '/me/archived-conversations',
      data: <String, dynamic>{
        'chatType': type,
        'peerId': id,
        'archived': archived,
      },
    );
    final payload = unwrapApiPayload(res.data);
    if (payload is Map) {
      return ArchivedConversationMutationResult.fromJson(
        Map<String, dynamic>.from(payload),
      );
    }
    return ArchivedConversationMutationResult(
      ok: true,
      chatType: type,
      peerId: id,
      archived: archived,
    );
  }

  Future<ArchivedConversationBatchResult> batchUpdate(
    List<ArchivedConversationItem> items, {
    required bool archived,
  }) async {
    if (items.isEmpty) {
      return const ArchivedConversationBatchResult(ok: true, count: 0);
    }
    final res = await _dio.put(
      '/me/archived-conversations/batch',
      data: <String, dynamic>{
        'items': items
            .map((item) => item.toMutationJson(archived: archived))
            .toList(growable: false),
      },
    );
    final payload = unwrapApiPayload(res.data);
    if (payload is Map) {
      return ArchivedConversationBatchResult.fromJson(
        Map<String, dynamic>.from(payload),
      );
    }
    return ArchivedConversationBatchResult(ok: true, count: items.length);
  }
}

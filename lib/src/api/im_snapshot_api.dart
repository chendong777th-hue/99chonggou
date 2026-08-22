import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/utils/api_response_util.dart';

import 'api_client.dart';

/// `GET /im/snapshot` 业务失败（含限流）。
class ImSnapshotApiException implements Exception {
  ImSnapshotApiException(this.code, this.message);

  final String code;
  final String message;

  bool get isRateLimited {
    final upper = code.trim().toUpperCase();
    return upper == 'RATE_LIMITED' || upper.contains('RATE_LIMITED');
  }

  @override
  String toString() => 'ImSnapshotApiException($code): $message';
}

class ImSnapshotMessage {
  const ImSnapshotMessage({
    this.msgId,
    this.msgKey,
    this.seq,
    this.sender,
    this.time,
    this.type,
    this.text,
    this.msgBody = const <dynamic>[],
    this.status,
  });

  final String? msgId;
  final String? msgKey;
  final int? seq;
  final String? sender;

  /// 秒。
  final int? time;
  final String? type;
  final String? text;
  final List<dynamic> msgBody;
  final int? status;

  factory ImSnapshotMessage.fromJson(Map<String, dynamic> json) {
    final body = json['msgBody'];
    return ImSnapshotMessage(
      msgId: _asString(json['msgId'] ?? json['msg_id']),
      msgKey: _asString(json['msgKey'] ?? json['msg_key']),
      seq: _asInt(json['seq']),
      sender: _asString(json['sender']),
      time: _asInt(json['time']),
      type: _asString(json['type']),
      text: _asString(json['text']),
      msgBody: body is List ? List<dynamic>.from(body) : const <dynamic>[],
      status: _asInt(json['status']),
    );
  }
}

class ImSnapshotConversation {
  const ImSnapshotConversation({
    required this.conversationId,
    required this.chatType,
    required this.peerId,
    this.lastSeq,
    this.lastMessage,
  });

  final String conversationId;
  final String chatType;
  final String peerId;
  final int? lastSeq;
  final ImSnapshotMessage? lastMessage;

  factory ImSnapshotConversation.fromJson(Map<String, dynamic> json) {
    final chatType = (_asString(json['chatType'] ?? json['type']) ?? '')
        .trim()
        .toLowerCase();
    final last = json['lastMessage'];
    return ImSnapshotConversation(
      conversationId: (_asString(json['conversationId']) ?? '').trim(),
      chatType: chatType,
      peerId: (_asString(json['peerId']) ?? '').trim(),
      lastSeq: _asInt(json['lastSeq']),
      lastMessage: last is Map
          ? ImSnapshotMessage.fromJson(Map<String, dynamic>.from(last))
          : null,
    );
  }
}

class ImSnapshotPreloadBucket {
  const ImSnapshotPreloadBucket({
    required this.conversationId,
    required this.messages,
  });

  final String conversationId;
  final List<ImSnapshotMessage> messages;

  factory ImSnapshotPreloadBucket.fromJson(Map<String, dynamic> json) {
    final raw = json['messages'];
    final messages = <ImSnapshotMessage>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          messages.add(
            ImSnapshotMessage.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }
    }
    return ImSnapshotPreloadBucket(
      conversationId: (_asString(json['conversationId']) ?? '').trim(),
      messages: messages,
    );
  }
}

class ImSnapshotResponse {
  const ImSnapshotResponse({
    required this.conversations,
    required this.preload,
    required this.degraded,
  });

  final List<ImSnapshotConversation> conversations;
  final List<ImSnapshotPreloadBucket> preload;
  final bool degraded;

  static const ImSnapshotResponse empty = ImSnapshotResponse(
    conversations: <ImSnapshotConversation>[],
    preload: <ImSnapshotPreloadBucket>[],
    degraded: false,
  );

  factory ImSnapshotResponse.fromJson(Map<String, dynamic> json) {
    final rawConvs = json['conversations'];
    final conversations = <ImSnapshotConversation>[];
    if (rawConvs is List) {
      for (final e in rawConvs) {
        if (e is Map) {
          final item = ImSnapshotConversation.fromJson(
            Map<String, dynamic>.from(e),
          );
          if (item.conversationId.isNotEmpty) {
            conversations.add(item);
          }
        }
      }
    }
    final rawPreload = json['preload'];
    final preload = <ImSnapshotPreloadBucket>[];
    if (rawPreload is List) {
      for (final e in rawPreload) {
        if (e is Map) {
          final bucket = ImSnapshotPreloadBucket.fromJson(
            Map<String, dynamic>.from(e),
          );
          if (bucket.conversationId.isNotEmpty) {
            preload.add(bucket);
          }
        }
      }
    }
    return ImSnapshotResponse(
      conversations: conversations,
      preload: preload,
      degraded: json['degraded'] == true,
    );
  }
}

/// 自建后端 IM Snapshot（空库冷启动预热）。
class ImSnapshotApi {
  ImSnapshotApi._();

  static final ImSnapshotApi instance = ImSnapshotApi._();

  Dio get _dio => ApiClient.instance.dio;

  Future<ImSnapshotResponse> fetch({
    int limitC2c = 40,
    int limitGroup = 40,
    int limitMsg = 40,
  }) async {
    try {
      final res = await _dio.get(
        '/im/snapshot',
        queryParameters: <String, dynamic>{
          'limitC2c': _clampConv(limitC2c),
          'limitGroup': _clampConv(limitGroup),
          'limitMsg': _clampMsg(limitMsg),
        },
      );
      _throwIfBusinessFailed(res.data);
      final payload = unwrapApiPayload(res.data);
      if (payload is! Map) {
        return ImSnapshotResponse.empty;
      }
      return ImSnapshotResponse.fromJson(Map<String, dynamic>.from(payload));
    } on DioError catch (e) {
      if (_isRateLimitedDio(e)) {
        final msg = e.message;
        throw ImSnapshotApiException(
          'RATE_LIMITED',
          msg.isEmpty ? 'rate limited' : msg,
        );
      }
      rethrow;
    }
  }

  void _throwIfBusinessFailed(dynamic raw) {
    if (raw is! Map) {
      return;
    }
    final map = Map<String, dynamic>.from(raw);
    final code = map['code'];
    if (code == null || code == 0 || code == '0') {
      return;
    }
    final codeText = code.toString();
    final message = (map['message'] ?? map['msg'] ?? map['reason'] ?? codeText)
        .toString();
    throw ImSnapshotApiException(codeText, message);
  }

  bool _isRateLimitedDio(DioError error) {
    if (error.response?.statusCode == 429) {
      return true;
    }
    final data = error.response?.data;
    if (data is Map) {
      final code = (data['code'] ?? data['reason'] ?? '').toString().toUpperCase();
      if (code == 'RATE_LIMITED' || code.contains('RATE_LIMITED')) {
        return true;
      }
      final message =
          (data['message'] ?? data['msg'] ?? '').toString().toUpperCase();
      if (message.contains('RATE_LIMITED')) {
        return true;
      }
    }
    return false;
  }

  int _clampConv(int value) {
    if (value < 1) {
      return 1;
    }
    if (value > 50) {
      return 50;
    }
    return value;
  }

  int _clampMsg(int value) {
    if (value < 30) {
      return 30;
    }
    if (value > 50) {
      return 50;
    }
    return value;
  }
}

String? _asString(dynamic value) {
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

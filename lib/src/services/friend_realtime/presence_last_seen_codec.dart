import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

class PresenceLastSeenBatch {
  const PresenceLastSeenBatch({
    required this.lastSeen,
    required this.lastActiveVisibility,
  });

  final Map<String, int> lastSeen;
  final Map<String, String> lastActiveVisibility;
}

/// TCP `presence_last_seen` / HTTP `/presence/last-seen` 共用编解码与门禁。
class PresenceLastSeenCodec {
  PresenceLastSeenCodec._();

  static const int maxBatchSize = 200;
  static const int maxInflight = 3;

  static List<String> normalizeUserIds(Iterable<String> rawIds) {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in rawIds) {
      final id = ChatIdFormat.rawUserUid(raw);
      if (id.isEmpty || !seen.add(id)) {
        continue;
      }
      out.add(id);
    }
    return out;
  }

  static List<List<String>> chunkUserIds(
    List<String> userIds, {
    int size = maxBatchSize,
  }) {
    final ids = normalizeUserIds(userIds);
    if (ids.isEmpty) {
      return const [];
    }
    final chunkSize = size < 1 ? maxBatchSize : size;
    if (ids.length <= chunkSize) {
      return <List<String>>[ids];
    }
    final chunks = <List<String>>[];
    for (var i = 0; i < ids.length; i += chunkSize) {
      final end = i + chunkSize > ids.length ? ids.length : i + chunkSize;
      chunks.add(ids.sublist(i, end));
    }
    return chunks;
  }

  static Map<String, dynamic> pingFrame(String deviceId) {
    final map = <String, dynamic>{'type': 'ping'};
    final id = deviceId.trim();
    if (id.isNotEmpty) {
      map['deviceId'] = id;
    }
    return map;
  }

  static Map<String, dynamic> lastSeenRequestFrame({
    required String requestId,
    required List<String> userIds,
  }) {
    return <String, dynamic>{
      'type': 'presence_last_seen',
      'requestId': requestId,
      'userIds': normalizeUserIds(userIds),
    };
  }

  static String? requestIdOf(Map<String, dynamic> map) {
    final value = map['requestId'] ?? map['request_id'];
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static String? failCodeOf(Map<String, dynamic> map) {
    final value = map['code'];
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static PresenceLastSeenBatch parseBatch(Map<String, dynamic> map) {
    return PresenceLastSeenBatch(
      lastSeen: parseIntMap(map['lastSeen'] ?? map['last_seen']),
      lastActiveVisibility: parseStringMap(
        map['lastActiveVisibility'] ?? map['last_active_visibility'],
      ),
    );
  }

  static Map<String, int> parseIntMap(Object? raw) {
    if (raw is! Map) {
      return const <String, int>{};
    }
    final out = <String, int>{};
    raw.forEach((key, value) {
      final id = key?.toString().trim() ?? '';
      if (id.isEmpty) {
        return;
      }
      int? ts;
      if (value is int) {
        ts = value;
      } else if (value is num) {
        ts = value.toInt();
      } else {
        ts = int.tryParse(value?.toString().trim() ?? '');
      }
      if (ts != null) {
        out[id] = ts;
      }
    });
    return out;
  }

  static Map<String, String> parseStringMap(Object? raw) {
    if (raw is! Map) {
      return const <String, String>{};
    }
    final out = <String, String>{};
    raw.forEach((key, value) {
      final id = key?.toString().trim() ?? '';
      if (id.isEmpty) {
        return;
      }
      final text = value?.toString().trim() ?? '';
      if (text.isEmpty) {
        return;
      }
      out[id] = text;
    });
    return out;
  }
}

class PresenceLastSeenFailCode {
  PresenceLastSeenFailCode._();

  static const String invalidInput = 'INVALID_INPUT';
  static const String batchTooLarge = 'BATCH_TOO_LARGE';
  static const String tooManyInflight = 'TOO_MANY_INFLIGHT';
  static const String internal = 'INTERNAL';
  static const String timeout = 'TIMEOUT';
  static const String disconnected = 'DISCONNECTED';
  static const String notConnected = 'NOT_CONNECTED';
}

class PresenceLastSeenTcpException implements Exception {
  const PresenceLastSeenTcpException(
    this.code, {
    this.requestId,
  });

  final String code;
  final String? requestId;

  bool get shouldFallbackToHttp {
    switch (code) {
      case PresenceLastSeenFailCode.invalidInput:
        return false;
      default:
        return true;
    }
  }

  @override
  String toString() =>
      'PresenceLastSeenTcpException($code${requestId == null ? '' : ' requestId=$requestId'})';
}

/// TCP 已鉴权时停周期 HTTP 心跳；断线才回退 HTTP。
class PresenceKeepAlivePolicy {
  PresenceKeepAlivePolicy._();

  static bool shouldSendHttpHeartbeat({required bool tcpReady}) => !tcpReady;
}

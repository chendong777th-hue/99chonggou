import 'dart:convert';

import 'package:tencent_cloud_chat_demo/config.dart';

/// 解析 APNs / 极光 extras / 本地通知 payload，统一路由字段。
class PushPayloadNormalizer {
  PushPayloadNormalizer._();

  static Map<String, dynamic> normalize(dynamic raw) {
    final output = <String, dynamic>{};
    _collect(raw, output, depth: 0);
    final ext = output['ext'] ?? output['push_ext'] ?? output['extras'];
    if (ext is String && ext.trim().startsWith('{')) {
      _collect(_decodeJson(ext), output, depth: 0);
    }
    final nExtra = output['n_extra'] ?? output['cn.jpush.android.EXTRA'];
    if (nExtra is String && nExtra.trim().startsWith('{')) {
      _collect(_decodeJson(nExtra), output, depth: 0);
    }
    output.removeWhere((_, value) => value == null);
    return output;
  }

  static void _collect(
    dynamic raw,
    Map<String, dynamic> output, {
    required int depth,
  }) {
    if (depth > 4 || raw == null) {
      return;
    }
    if (raw is String) {
      final decoded = _decodeJson(raw);
      if (decoded != null) {
        _collect(decoded, output, depth: depth + 1);
      }
      return;
    }
    if (raw is! Map) {
      return;
    }
    raw.forEach((key, value) {
      if (key == null || value == null) {
        return;
      }
      final name = key.toString();
      if (value is Map) {
        if (name == 'extras' ||
            name == 'extra' ||
            name == 'data' ||
            name == 'payload' ||
            name == 'custom') {
          _collect(value, output, depth: depth + 1);
        }
        output.putIfAbsent(name, () => value);
        return;
      }
      if (value is String) {
        final trimmed = value.trim();
        output[name] = trimmed;
        if ((name == 'extras' ||
                name == 'extra' ||
                name == 'data' ||
                name == 'payload' ||
                name == 'custom' ||
                name == 'n_extra' ||
                name == 'cn.jpush.android.EXTRA') &&
            trimmed.startsWith('{')) {
          _collect(_decodeJson(trimmed), output, depth: depth + 1);
        }
        return;
      }
      output[name] = value;
    });
  }

  static dynamic _decodeJson(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  static String? resolveAvatarUrl(Map<String, dynamic> data) {
    return _read(data, const [
      'avatarThumbUrl',
      'avatar_thumb_url',
      'avatarUrl',
      'avatar_url',
      'senderFaceUrl',
      'groupFaceUrl',
      'faceUrl',
    ]);
  }

  static String? resolveConversationId(Map<String, dynamic> data) {
    final conversationID = _read(data, const [
      'conversationID',
      'conversationId',
      'conversation_id',
      'convId',
      'conv_id',
      'targetId',
      'target_id',
    ]);
    if (conversationID != null && conversationID.isNotEmpty) {
      return _normalizeConversationId(conversationID);
    }

    // 服务端 / TIMPush 偶发只带 threadId，conversationID 为空字符串。
    final threadId = _read(data, const ['threadId', 'thread_id']);
    if (threadId != null &&
        (threadId.startsWith('c2c_') || threadId.startsWith('group_'))) {
      return _normalizeConversationId(threadId);
    }

    final type = _read(data, const ['type'])?.toLowerCase() ?? '';
    final chatType =
        _read(data, const ['chatType', 'chat_type'])?.toLowerCase();
    if (type == 'register_welcome') {
      return 'c2c_99Messenger';
    }
    if (type == 'group_changed') {
      final changedGroupId = _read(data, const [
        'groupId',
        'groupID',
        'group_id',
      ]);
      if (changedGroupId != null && changedGroupId.isNotEmpty) {
        return _normalizeConversationId('group_$changedGroupId');
      }
    }
    if (type == 'platform_wallet_notice') {
      final official = IMDemoConfig.platformOfficialAccountId.trim();
      return official.isNotEmpty ? 'c2c_$official' : null;
    }

    final groupId = _read(data, const [
      'groupId',
      'groupID',
      'group_id',
    ]);
    if (groupId != null &&
        groupId.isNotEmpty &&
        (type == 'im_chat' ||
            type == 'chat_message' ||
            chatType == 'group' ||
            chatType == null && type.isEmpty)) {
      return _normalizeConversationId('group_$groupId');
    }

    final userId = _read(data, const [
      'fromAccount',
      'from_account',
      'sender',
      'senderId',
      'sender_id',
      'fromUserId',
      'from_user_id',
      'userID',
      'userId',
    ]);
    if (userId != null &&
        userId.isNotEmpty &&
        (type == 'im_chat' ||
            type == 'chat_message' ||
            chatType == 'c2c' ||
            chatType == null && type.isEmpty)) {
      return _normalizeConversationId('c2c_$userId');
    }

    return null;
  }

  static String _normalizeConversationId(String raw) {
    final id = raw.trim();
    if (id.isEmpty) {
      return id;
    }
    if (id.startsWith('c2c_') || id.startsWith('group_')) {
      return id;
    }
    if (id.startsWith('@TGS#')) {
      return 'group_$id';
    }
    return id;
  }

  static String? _read(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }
}

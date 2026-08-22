import 'package:tencent_cloud_chat_demo/src/utils/message_conversation_id.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

/// 钱包 IM 自定义消息体与会话目标解析（Chat 页 / 支付成功直发共用）。
class WalletCardImTarget {
  final String receiverUserId;
  final String groupId;

  const WalletCardImTarget({
    required this.receiverUserId,
    required this.groupId,
  });

  bool get isGroup => groupId.isNotEmpty;
  bool get isValid => receiverUserId.isNotEmpty || groupId.isNotEmpty;
}

class WalletCardImPayload {
  WalletCardImPayload._();

  static const _copyKeys = <String>[
    'packetCount',
    'count',
    'cnt',
    'totalCount',
    'claimedCount',
    'progress',
    'packetType',
    'receiverId',
    'receiverName',
    'receiverAvatar',
    'toUserId',
    'toUserName',
    'toUserAvatar',
    'receiveUserAvatar',
    'senderId',
    'senderUserId',
    'senderName',
    'senderNick',
    'senderAvatar',
    'fromUserId',
    'fromUserName',
    'fromUserAvatar',
  ];

  static bool resolveIsGroup(Map<String, dynamic> payload) {
    if (payload['isGroup'] == true) return true;
    final type = payload['type']?.toString() ?? '';
    if (type == 'wallet_group_transfer') return true;
    final packetType = payload['packetType']?.toString() ?? '';
    if (packetType == 'GROUP_TRANSFER') return true;
    final convId = payload['conversationId']?.toString() ?? '';
    if (MessageConversationId.looksLikeGroupConversationId(convId)) {
      return true;
    }
    return ChatIdFormat.looksLikeCommunityGroupId(convId) ||
        ChatIdFormat.isIMGroupOrCommunityId(convId);
  }

  static WalletCardImTarget resolveTarget(Map<String, dynamic> payload) {
    final convId = payload['conversationId']?.toString().trim() ?? '';
    if (convId.isEmpty) {
      return const WalletCardImTarget(receiverUserId: '', groupId: '');
    }
    if (resolveIsGroup(payload)) {
      return WalletCardImTarget(
        receiverUserId: '',
        groupId: ChatIdFormat.canonicalGroupStorageId(convId),
      );
    }
    return WalletCardImTarget(
      receiverUserId: ChatIdFormat.rawUserUid(
        MessageConversationId.normalizeComparableKey(convId),
      ),
      groupId: '',
    );
  }

  static String? firstNonEmptyString(Iterable<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static Map<String, dynamic> buildCustomData(
    Map<String, dynamic> payload, {
    required String conversationId,
  }) {
    final data = <String, dynamic>{
      'businessID': 'wallet_order',
      'version': 1,
      'conversationId': conversationId,
      'type': payload['type']?.toString() ?? '',
      'orderId': payload['orderId']?.toString() ?? '',
      'clientOrderId': payload['clientOrderId']?.toString() ?? '',
      'currency': payload['currency']?.toString() ?? '',
      'amount': payload['amount'],
      'status': payload['status']?.toString() ?? '',
    };
    final memo = firstNonEmptyString([payload['memo'], payload['greeting']]);
    if (memo != null) {
      data['memo'] = memo;
      data['greeting'] = memo;
    }
    final payloadType = payload['type']?.toString() ?? '';
    if (payloadType == 'wallet_transfer') {
      data['customType'] = 'wallet_transfer';
    } else if (payloadType == 'wallet_group_transfer') {
      data['customType'] = 'wallet_group_transfer';
    } else if (payloadType == 'wallet_red_packet') {
      data['customType'] = 'wallet_red_packet';
    }
    for (final key in _copyKeys) {
      final value = payload[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        data[key] = value;
      }
    }
    return data;
  }
}

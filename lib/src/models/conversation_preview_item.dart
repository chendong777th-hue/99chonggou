class ConversationPreviewItem {
  const ConversationPreviewItem({
    required this.conversationId,
    required this.scope,
    required this.title,
    required this.subtitle,
    required this.faceUrl,
    required this.unreadCount,
    required this.timestampMs,
    required this.pinned,
    this.groupType = '',
  });

  final String conversationId;
  final String scope;
  final String title;
  final String subtitle;
  final String faceUrl;
  final int unreadCount;
  final int timestampMs;
  final bool pinned;
  final String groupType;

  factory ConversationPreviewItem.fromJson(Map<String, dynamic> json) {
    return ConversationPreviewItem(
      conversationId: json['conversationId']?.toString() ?? '',
      scope: json['scope']?.toString() ?? 'c2c',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      faceUrl: json['faceUrl']?.toString() ?? '',
      unreadCount: _asInt(json['unreadCount']),
      timestampMs: _asInt(json['timestampMs']),
      pinned: json['pinned'] as bool? ?? false,
      groupType: json['groupType']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'conversationId': conversationId,
        'scope': scope,
        'title': title,
        'subtitle': subtitle,
        'faceUrl': faceUrl,
        'unreadCount': unreadCount,
        'timestampMs': timestampMs,
        'pinned': pinned,
        'groupType': groupType,
      };
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

class MomentsSettings {
  const MomentsSettings({
    this.coverUrl,
    this.visibleRangeDays = 0,
    this.blockedViewerIds = const [],
    this.hiddenAuthorIds = const [],
  });

  final String? coverUrl;
  final int visibleRangeDays;
  final List<String> blockedViewerIds;
  final List<String> hiddenAuthorIds;

  MomentsSettings copyWith({
    String? coverUrl,
    int? visibleRangeDays,
    List<String>? blockedViewerIds,
    List<String>? hiddenAuthorIds,
    bool clearCoverUrl = false,
  }) {
    return MomentsSettings(
      coverUrl: clearCoverUrl ? null : (coverUrl ?? this.coverUrl),
      visibleRangeDays: visibleRangeDays ?? this.visibleRangeDays,
      blockedViewerIds: blockedViewerIds ?? this.blockedViewerIds,
      hiddenAuthorIds: hiddenAuthorIds ?? this.hiddenAuthorIds,
    );
  }

  factory MomentsSettings.fromJson(Map<String, dynamic> json) {
    return MomentsSettings(
      coverUrl: _readNullableString(json['coverUrl']),
      visibleRangeDays: _parseInt(json['visibleRangeDays']) ?? 0,
      blockedViewerIds: _normalizeIds(json['blockedViewerIds']),
      hiddenAuthorIds: _normalizeIds(json['hiddenAuthorIds']),
    );
  }

  Map<String, dynamic> toJson() => {
        'coverUrl': coverUrl,
        'visibleRangeDays': visibleRangeDays,
        'blockedViewerIds': blockedViewerIds,
        'hiddenAuthorIds': hiddenAuthorIds,
      };
}

class MomentsSettingsPatch {
  const MomentsSettingsPatch({
    this.coverUrl,
    this.clearCoverUrl = false,
    this.visibleRangeDays,
    this.blockedViewerIds,
    this.hiddenAuthorIds,
  });

  final String? coverUrl;
  final bool clearCoverUrl;
  final int? visibleRangeDays;
  final List<String>? blockedViewerIds;
  final List<String>? hiddenAuthorIds;

  bool get isEmpty =>
      !clearCoverUrl &&
      coverUrl == null &&
      visibleRangeDays == null &&
      blockedViewerIds == null &&
      hiddenAuthorIds == null;

  Map<String, dynamic> toRequestBody() {
    final body = <String, dynamic>{};
    if (clearCoverUrl) {
      body['coverUrl'] = null;
    } else if (coverUrl != null) {
      body['coverUrl'] = coverUrl!.trim();
    }
    if (visibleRangeDays != null) {
      body['visibleRangeDays'] = visibleRangeDays;
    }
    if (blockedViewerIds != null) {
      body['blockedViewerIds'] = blockedViewerIds;
    }
    if (hiddenAuthorIds != null) {
      body['hiddenAuthorIds'] = hiddenAuthorIds;
    }
    return body;
  }
}

String? _readNullableString(dynamic raw) {
  if (raw == null) return null;
  final value = raw.toString().trim();
  return value.isEmpty ? null : value;
}

int? _parseInt(dynamic raw) {
  if (raw is int) return raw;
  return int.tryParse(raw?.toString() ?? '');
}

List<String> _normalizeIds(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .map((item) => ChatIdFormat.rawUserUid(item?.toString() ?? ''))
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList();
}

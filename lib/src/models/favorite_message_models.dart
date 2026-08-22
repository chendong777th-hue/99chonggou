import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';

/// 消息收藏类型（与后端 `type` 字段对齐）。
enum FavoriteMessageType {
  text,
  image,
  video,
}

extension FavoriteMessageTypeX on FavoriteMessageType {
  String get apiValue {
    switch (this) {
      case FavoriteMessageType.text:
        return 'TEXT';
      case FavoriteMessageType.image:
        return 'IMAGE';
      case FavoriteMessageType.video:
        return 'VIDEO';
    }
  }

  static FavoriteMessageType? fromApi(String? raw) {
    switch (raw?.toUpperCase()) {
      case 'TEXT':
        return FavoriteMessageType.text;
      case 'IMAGE':
        return FavoriteMessageType.image;
      case 'VIDEO':
        return FavoriteMessageType.video;
      default:
        return null;
    }
  }
}

/// 单条消息收藏（列表/详情展示）。
class FavoriteMessageItem {
  FavoriteMessageItem({
    required this.id,
    required this.type,
    required this.favoritedAt,
    this.updatedAt,
    this.text,
    this.thumbUrl,
    this.mediaUrl,
    this.localThumbPath,
    this.localMediaPath,
    this.durationSec,
    this.width,
    this.height,
    this.sourceSenderName,
    this.sourceConvLabel,
    this.sourceMsgId,
    this.sourceConvId,
    this.isManual = false,
  });

  final String id;
  final FavoriteMessageType type;
  final DateTime favoritedAt;
  final DateTime? updatedAt;
  final String? text;
  final String? thumbUrl;
  final String? mediaUrl;
  final String? localThumbPath;
  final String? localMediaPath;
  final int? durationSec;
  final int? width;
  final int? height;
  final String? sourceSenderName;
  final String? sourceConvLabel;
  final String? sourceMsgId;
  final String? sourceConvId;
  final bool isManual;

  FavoriteMessageItem copyWith({
    String? id,
    FavoriteMessageType? type,
    DateTime? favoritedAt,
    DateTime? updatedAt,
    String? text,
    String? thumbUrl,
    String? mediaUrl,
    String? localThumbPath,
    String? localMediaPath,
    int? durationSec,
    int? width,
    int? height,
    String? sourceSenderName,
    String? sourceConvLabel,
    String? sourceMsgId,
    String? sourceConvId,
    bool? isManual,
    bool clearText = false,
    bool clearThumbUrl = false,
    bool clearMediaUrl = false,
    bool clearLocalThumbPath = false,
    bool clearLocalMediaPath = false,
    bool clearSourceSenderName = false,
    bool clearSourceConvLabel = false,
    bool clearSourceMsgId = false,
    bool clearSourceConvId = false,
    bool clearDurationSec = false,
  }) {
    return FavoriteMessageItem(
      id: id ?? this.id,
      type: type ?? this.type,
      favoritedAt: favoritedAt ?? this.favoritedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      text: clearText ? null : (text ?? this.text),
      thumbUrl: clearThumbUrl ? null : (thumbUrl ?? this.thumbUrl),
      mediaUrl: clearMediaUrl ? null : (mediaUrl ?? this.mediaUrl),
      localThumbPath:
          clearLocalThumbPath ? null : (localThumbPath ?? this.localThumbPath),
      localMediaPath:
          clearLocalMediaPath ? null : (localMediaPath ?? this.localMediaPath),
      durationSec: clearDurationSec ? null : (durationSec ?? this.durationSec),
      width: width ?? this.width,
      height: height ?? this.height,
      sourceSenderName: clearSourceSenderName
          ? null
          : (sourceSenderName ?? this.sourceSenderName),
      sourceConvLabel: clearSourceConvLabel
          ? null
          : (sourceConvLabel ?? this.sourceConvLabel),
      sourceMsgId:
          clearSourceMsgId ? null : (sourceMsgId ?? this.sourceMsgId),
      sourceConvId:
          clearSourceConvId ? null : (sourceConvId ?? this.sourceConvId),
      isManual: isManual ?? this.isManual,
    );
  }

  /// 列表/详情展示用路径：本地文件优先，其次网络 URL。
  String? get displayThumbPathOrUrl {
    final local = localThumbPath?.trim() ?? '';
    if (local.isNotEmpty) return local;
    final thumb = thumbUrl?.trim() ?? '';
    if (thumb.isNotEmpty) return thumb;
    return displayMediaPathOrUrl;
  }

  String? get displayMediaPathOrUrl {
    final local = localMediaPath?.trim() ?? '';
    if (local.isNotEmpty) return local;
    final media = mediaUrl?.trim() ?? '';
    if (media.isNotEmpty) return media;
    final thumb = thumbUrl?.trim() ?? '';
    return thumb.isEmpty ? null : thumb;
  }

  bool get isLocalMedia {
    final path = displayMediaPathOrUrl ?? '';
    return path.isNotEmpty && !path.startsWith('http');
  }

  String get listPreview {
    final i18n = AppI18n.current;
    switch (type) {
      case FavoriteMessageType.text:
        final t = text?.trim() ?? '';
        return t.isEmpty
            ? i18n.t(
                zhHans: '文本',
                zhHant: '文字',
                en: 'Text',
                ja: 'テキスト',
                ko: '텍스트',
              )
            : t;
      case FavoriteMessageType.image:
        return i18n.t(
          zhHans: '图片',
          zhHant: '圖片',
          en: 'Image',
          ja: '画像',
          ko: '이미지',
        );
      case FavoriteMessageType.video:
        return i18n.t(
          zhHans: '视频',
          zhHant: '影片',
          en: 'Video',
          ja: '動画',
          ko: '동영상',
        );
    }
  }

  String? get displayMediaUrl {
    final local = localMediaPath?.trim() ?? '';
    if (local.isNotEmpty && local.startsWith('http')) {
      return local;
    }
    final m = mediaUrl?.trim() ?? '';
    if (m.isNotEmpty) return m;
    final t = thumbUrl?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.apiValue,
        'favoritedAt': favoritedAt.toUtc().toIso8601String(),
        if (text != null) 'text': text,
        if (thumbUrl != null) 'thumbUrl': thumbUrl,
        if (mediaUrl != null) 'mediaUrl': mediaUrl,
        if (localThumbPath != null) 'localThumbPath': localThumbPath,
        if (localMediaPath != null) 'localMediaPath': localMediaPath,
        if (durationSec != null) 'durationSec': durationSec,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (sourceSenderName != null) 'sourceSenderName': sourceSenderName,
        if (sourceConvLabel != null) 'sourceConvLabel': sourceConvLabel,
        if (sourceMsgId != null) 'sourceMsgId': sourceMsgId,
        if (sourceConvId != null) 'sourceConvId': sourceConvId,
        'isManual': isManual,
      };

  factory FavoriteMessageItem.fromJson(Map<String, dynamic> json) {
    return FavoriteMessageItem(
      id: json['id']?.toString() ?? '',
      type: FavoriteMessageTypeX.fromApi(json['type']?.toString()) ??
          FavoriteMessageType.text,
      favoritedAt: DateTime.tryParse(json['favoritedAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      text: json['text']?.toString(),
      thumbUrl: _nullableUrl(json['thumbUrl']),
      mediaUrl: _nullableUrl(json['mediaUrl']),
      localThumbPath: json['localThumbPath']?.toString(),
      localMediaPath: json['localMediaPath']?.toString(),
      durationSec: json['durationSec'] is int
          ? json['durationSec'] as int
          : int.tryParse(json['durationSec']?.toString() ?? ''),
      width: json['width'] is int
          ? json['width'] as int
          : int.tryParse(json['width']?.toString() ?? ''),
      height: json['height'] is int
          ? json['height'] as int
          : int.tryParse(json['height']?.toString() ?? ''),
      sourceSenderName: json['sourceSenderName']?.toString(),
      sourceConvLabel: json['sourceConvLabel']?.toString(),
      sourceMsgId: json['sourceMsgId']?.toString(),
      sourceConvId: json['sourceConvId']?.toString(),
      isManual: json['isManual'] as bool? ?? false,
    );
  }

  static String? _nullableUrl(dynamic raw) {
    final s = raw?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }
}

/// `POST /me/favorites` 请求体。
class CreateFavoriteRequest {
  CreateFavoriteRequest({
    required this.type,
    this.text,
    this.remoteMediaUrl,
    this.remoteThumbUrl,
    this.durationSec,
    this.sourceMsgId,
    this.sourceConvId,
    this.sourceSenderName,
    this.sourceConvLabel,
    this.remark,
  });

  final FavoriteMessageType type;
  final String? text;
  final String? remoteMediaUrl;
  final String? remoteThumbUrl;
  final int? durationSec;
  final String? sourceMsgId;
  final String? sourceConvId;
  final String? sourceSenderName;
  final String? sourceConvLabel;
  final String? remark;

  Map<String, dynamic> toJson() {
    final remarkText = remark?.trim() ?? '';
    return {
      'type': type.apiValue,
      if (text != null) 'text': text,
      if (remoteMediaUrl != null) 'remoteMediaUrl': remoteMediaUrl,
      if (remoteThumbUrl != null) 'remoteThumbUrl': remoteThumbUrl,
      if (durationSec != null) 'durationSec': durationSec,
      if (sourceMsgId != null) 'sourceMsgId': sourceMsgId,
      if (sourceConvId != null) 'sourceConvId': sourceConvId,
      if (sourceSenderName != null) 'sourceSenderName': sourceSenderName,
      if (sourceConvLabel != null) 'sourceConvLabel': sourceConvLabel,
      if (remarkText.isNotEmpty) 'remark': remarkText,
    };
  }
}

enum MomentMediaType {
  image,
  video,
}

extension MomentMediaTypeX on MomentMediaType {
  String get apiValue {
    switch (this) {
      case MomentMediaType.image:
        return 'IMAGE';
      case MomentMediaType.video:
        return 'VIDEO';
    }
  }

  static MomentMediaType fromApi(String? raw) {
    switch (raw?.toUpperCase()) {
      case 'VIDEO':
        return MomentMediaType.video;
      case 'IMAGE':
      default:
        return MomentMediaType.image;
    }
  }
}

class MomentUserSnapshot {
  const MomentUserSnapshot({
    required this.id,
    required this.name,
    required this.avatarUrl,
  });

  final String id;
  final String name;
  final String avatarUrl;

  bool get isEmpty =>
      id.trim().isEmpty && name.trim().isEmpty && avatarUrl.trim().isEmpty;

  MomentUserSnapshot copyWith({
    String? id,
    String? name,
    String? avatarUrl,
  }) {
    return MomentUserSnapshot(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatarUrl': avatarUrl,
      };

  factory MomentUserSnapshot.fromJson(Map<String, dynamic> json) {
    final remark = json['remark']?.toString().trim() ?? '';
    final nickname = json['nickname']?.toString().trim() ?? '';
    final name = json['name']?.toString().trim() ?? '';
    return MomentUserSnapshot(
      id: json['id']?.toString() ??
          json['userId']?.toString() ??
          json['userID']?.toString() ??
          '',
      name: remark.isNotEmpty
          ? remark
          : nickname.isNotEmpty
              ? nickname
              : name,
      avatarUrl: json['avatarUrl']?.toString() ??
          json['faceUrl']?.toString() ??
          json['avatar']?.toString() ??
          '',
    );
  }
}

class MomentAttachment {
  const MomentAttachment({
    required this.type,
    required this.path,
    this.mediaId,
    this.previewPath,
    this.durationSec,
    this.width,
    this.height,
    this.sizeBytes,
  });

  final MomentMediaType type;
  final String path;
  final String? mediaId;
  final String? previewPath;
  final int? durationSec;
  final int? width;
  final int? height;
  final int? sizeBytes;

  bool get isImage => type == MomentMediaType.image;
  bool get isVideo => type == MomentMediaType.video;

  String get displayPath => (previewPath?.trim().isNotEmpty ?? false)
      ? previewPath!.trim()
      : path.trim();

  MomentAttachment copyWith({
    MomentMediaType? type,
    String? path,
    String? mediaId,
    String? previewPath,
    int? durationSec,
    int? width,
    int? height,
    int? sizeBytes,
    bool clearMediaId = false,
    bool clearPreviewPath = false,
    bool clearDurationSec = false,
  }) {
    return MomentAttachment(
      type: type ?? this.type,
      path: path ?? this.path,
      mediaId: clearMediaId ? null : (mediaId ?? this.mediaId),
      previewPath: clearPreviewPath ? null : (previewPath ?? this.previewPath),
      durationSec: clearDurationSec ? null : (durationSec ?? this.durationSec),
      width: width ?? this.width,
      height: height ?? this.height,
      sizeBytes: sizeBytes ?? this.sizeBytes,
    );
  }

  Map<String, dynamic> toJson() => {
        if (mediaId != null) 'mediaId': mediaId,
        'type': type.apiValue,
        'path': path,
        if (previewPath != null) 'previewPath': previewPath,
        if (durationSec != null) 'durationSec': durationSec,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (sizeBytes != null) 'sizeBytes': sizeBytes,
      };

  factory MomentAttachment.fromJson(Map<String, dynamic> json) {
    return MomentAttachment(
      type: MomentMediaTypeX.fromApi(json['type']?.toString()),
      mediaId: json['mediaId']?.toString(),
      path: json['path']?.toString() ?? json['url']?.toString() ?? '',
      previewPath:
          json['previewPath']?.toString() ?? json['thumbUrl']?.toString(),
      durationSec: json['durationSec'] is int
          ? json['durationSec'] as int
          : int.tryParse(json['durationSec']?.toString() ?? ''),
      width: _parseInt(json['width']),
      height: _parseInt(json['height']),
      sizeBytes: _parseInt(json['sizeBytes']),
    );
  }
}

class MomentReaction {
  const MomentReaction({
    required this.id,
    required this.author,
    required this.createdAt,
  });

  final String id;
  final MomentUserSnapshot author;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'author': author.toJson(),
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory MomentReaction.fromJson(Map<String, dynamic> json) {
    return MomentReaction(
      id: json['id']?.toString() ?? '',
      author: MomentUserSnapshot.fromJson(
        Map<String, dynamic>.from(
          json['author'] as Map? ?? json['user'] as Map? ?? const {},
        ),
      ),
      createdAt: _parseApiTime(json['createdAt']) ?? DateTime.now(),
    );
  }
}

class MomentComment {
  const MomentComment({
    required this.id,
    required this.author,
    required this.text,
    required this.createdAt,
    this.replyToCommentId,
    this.replyToUser,
    this.canDelete = false,
  });

  final String id;
  final MomentUserSnapshot author;
  final String text;
  final DateTime createdAt;
  final String? replyToCommentId;
  final MomentUserSnapshot? replyToUser;
  final bool canDelete;

  bool get isReply =>
      (replyToCommentId?.trim().isNotEmpty ?? false) && replyToUser != null;

  /// 评论作者本人、动态作者，或后端显式下发 `canDelete` 时可删。
  bool canBeDeletedBy({
    required String selfId,
    required bool isPostOwner,
  }) {
    if (canDelete) {
      return true;
    }
    final id = selfId.trim();
    if (id.isEmpty) {
      return false;
    }
    return isPostOwner || author.id.trim() == id;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'author': author.toJson(),
        if (replyToCommentId != null) 'replyToCommentId': replyToCommentId,
        if (replyToUser != null) 'replyToUser': replyToUser!.toJson(),
        'text': text,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'canDelete': canDelete,
      };

  factory MomentComment.fromJson(Map<String, dynamic> json) {
    return MomentComment(
      id: json['id']?.toString() ?? json['commentId']?.toString() ?? '',
      author: MomentUserSnapshot.fromJson(
        Map<String, dynamic>.from(json['author'] as Map? ?? const {}),
      ),
      replyToCommentId: json['replyToCommentId']?.toString(),
      replyToUser: json['replyToUser'] is Map
          ? MomentUserSnapshot.fromJson(
              Map<String, dynamic>.from(json['replyToUser'] as Map),
            )
          : null,
      text: json['text']?.toString() ?? '',
      createdAt: _parseApiTime(json['createdAt']) ?? DateTime.now(),
      canDelete: json['canDelete'] == true ||
          json['canDelete'] == 1 ||
          json['canDelete']?.toString().toLowerCase() == 'true',
    );
  }
}

enum MomentNotificationType {
  like,
  comment,
  reply,
}

class MomentNotification {
  const MomentNotification({
    required this.id,
    required this.type,
    required this.actor,
    required this.postId,
    required this.postAuthor,
    required this.postText,
    required this.createdAt,
    this.comment,
    this.postPreviewPath,
    this.replyToUser,
  });

  final String id;
  final MomentNotificationType type;
  final MomentUserSnapshot actor;
  final String postId;
  final MomentUserSnapshot postAuthor;
  final String postText;
  final String? postPreviewPath;
  final MomentComment? comment;
  final MomentUserSnapshot? replyToUser;
  final DateTime createdAt;

  factory MomentNotification.fromJson(Map<String, dynamic> json) {
    final rawType = json['type']?.toString().toUpperCase() ?? '';
    final type = switch (rawType) {
      'LIKE' => MomentNotificationType.like,
      'COMMENT_REPLY' => MomentNotificationType.reply,
      'REPLY' => MomentNotificationType.reply,
      _ => MomentNotificationType.comment,
    };
    final previewMedia = json['momentPreviewMedia'];
    return MomentNotification(
      id: json['id']?.toString() ?? json['notificationId']?.toString() ?? '',
      type: type,
      actor: MomentUserSnapshot.fromJson(
        Map<String, dynamic>.from(json['actor'] as Map? ?? const {}),
      ),
      postId: json['postId']?.toString() ?? json['momentId']?.toString() ?? '',
      postAuthor: MomentUserSnapshot.fromJson(
        Map<String, dynamic>.from(
          json['postAuthor'] as Map? ??
              json['momentAuthor'] as Map? ??
              const {},
        ),
      ),
      postText:
          json['postText']?.toString() ?? json['momentText']?.toString() ?? '',
      postPreviewPath: previewMedia is Map
          ? (previewMedia['thumbUrl']?.toString() ??
              previewMedia['url']?.toString())
          : json['postPreviewPath']?.toString(),
      comment: json['comment'] is Map
          ? MomentComment.fromJson(
              Map<String, dynamic>.from(json['comment'] as Map),
            )
          : null,
      replyToUser: json['replyToUser'] is Map
          ? MomentUserSnapshot.fromJson(
              Map<String, dynamic>.from(json['replyToUser'] as Map),
            )
          : null,
      createdAt: _parseApiTime(json['createdAt']) ?? DateTime.now(),
    );
  }
}

enum MomentVisibilityMode {
  friends,
  exclude,
  partial,
}

extension MomentVisibilityModeApi on MomentVisibilityMode {
  String get apiValue {
    switch (this) {
      case MomentVisibilityMode.friends:
        return 'FRIENDS';
      case MomentVisibilityMode.exclude:
        return 'EXCLUDE';
      case MomentVisibilityMode.partial:
        return 'PARTIAL';
    }
  }
}

class MomentPublishPrivacy {
  const MomentPublishPrivacy({
    this.mode = MomentVisibilityMode.friends,
    this.selectedUsers = const [],
  });

  final MomentVisibilityMode mode;
  final List<MomentUserSnapshot> selectedUsers;

  String summaryLabel() {
    switch (mode) {
      case MomentVisibilityMode.friends:
        return '所有好友';
      case MomentVisibilityMode.exclude:
        if (selectedUsers.isEmpty) return '不给谁看';
        return '不给谁看 · ${selectedUsers.length}人';
      case MomentVisibilityMode.partial:
        if (selectedUsers.isEmpty) return '部分可见';
        return '部分可见 · ${selectedUsers.length}人';
    }
  }
}

class MomentDraft {
  MomentDraft({
    required this.text,
    required List<MomentAttachment> attachments,
    required this.updatedAt,
    this.location,
    this.privacy = const MomentPublishPrivacy(),
  }) : attachments = List.unmodifiable(attachments);

  final String text;
  final List<MomentAttachment> attachments;
  final DateTime updatedAt;
  final String? location;
  final MomentPublishPrivacy privacy;

  bool get isEmpty =>
      text.trim().isEmpty && attachments.isEmpty && (location ?? '').isEmpty;

  MomentDraft copyWith({
    String? text,
    List<MomentAttachment>? attachments,
    DateTime? updatedAt,
    String? location,
    MomentPublishPrivacy? privacy,
    bool clearText = false,
    bool clearAttachments = false,
    bool clearLocation = false,
  }) {
    return MomentDraft(
      text: clearText ? '' : (text ?? this.text),
      attachments:
          clearAttachments ? const [] : (attachments ?? this.attachments),
      updatedAt: updatedAt ?? this.updatedAt,
      location: clearLocation ? null : (location ?? this.location),
      privacy: privacy ?? this.privacy,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'attachments': attachments.map((e) => e.toJson()).toList(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        if ((location ?? '').trim().isNotEmpty) 'location': location!.trim(),
        'privacyMode': privacy.mode.name,
        'privacyUserIds':
            privacy.selectedUsers.map((user) => user.id).toList(),
      };

  factory MomentDraft.fromJson(Map<String, dynamic> json) {
    final attachments = (json['attachments'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => MomentAttachment.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final modeName = json['privacyMode']?.toString() ?? '';
    final mode = MomentVisibilityMode.values.firstWhere(
      (item) => item.name == modeName,
      orElse: () => MomentVisibilityMode.friends,
    );
    final userIds = (json['privacyUserIds'] as List? ?? const [])
        .map((e) => e.toString())
        .where((id) => id.trim().isNotEmpty)
        .toList();
    return MomentDraft(
      text: json['text']?.toString() ?? '',
      attachments: attachments,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      location: json['location']?.toString(),
      privacy: MomentPublishPrivacy(
        mode: mode,
        selectedUsers: userIds
            .map(
              (id) => MomentUserSnapshot(
                id: id,
                name: id,
                avatarUrl: '',
              ),
            )
            .toList(),
      ),
    );
  }
}

class MomentPost {
  MomentPost({
    required this.id,
    required this.author,
    required this.text,
    required List<MomentAttachment> attachments,
    required List<MomentReaction> likes,
    required List<MomentComment> comments,
    required this.createdAt,
    this.updatedAt,
    this.location,
    this.likedByMe = false,
    this.likeCountValue,
    this.commentCountValue,
  })  : attachments = List.unmodifiable(attachments),
        likes = List.unmodifiable(likes),
        comments = List.unmodifiable(comments);

  final String id;
  final MomentUserSnapshot author;
  final String text;
  final List<MomentAttachment> attachments;
  final List<MomentReaction> likes;
  final List<MomentComment> comments;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? location;
  final bool likedByMe;
  final int? likeCountValue;
  final int? commentCountValue;

  bool get hasMedia => attachments.isNotEmpty;
  bool get isTextOnly => attachments.isEmpty;
  int get likeCount => likeCountValue ?? likes.length;
  int get commentCount => commentCountValue ?? comments.length;

  MomentAttachment? get firstAttachment =>
      attachments.isEmpty ? null : attachments.first;

  bool isOwnedBy(String userId) {
    return author.id.trim().isNotEmpty && author.id.trim() == userId.trim();
  }

  bool likedBy(String userId) {
    final id = userId.trim();
    if (id.isEmpty) return false;
    return likedByMe || likes.any((item) => item.author.id.trim() == id);
  }

  MomentPost copyWith({
    String? id,
    MomentUserSnapshot? author,
    String? text,
    List<MomentAttachment>? attachments,
    List<MomentReaction>? likes,
    List<MomentComment>? comments,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? location,
    bool? likedByMe,
    int? likeCountValue,
    int? commentCountValue,
    bool clearLocation = false,
  }) {
    return MomentPost(
      id: id ?? this.id,
      author: author ?? this.author,
      text: text ?? this.text,
      attachments: attachments ?? this.attachments,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      location: clearLocation ? null : (location ?? this.location),
      likedByMe: likedByMe ?? this.likedByMe,
      likeCountValue: likeCountValue ?? this.likeCountValue,
      commentCountValue: commentCountValue ?? this.commentCountValue,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'author': author.toJson(),
        'text': text,
        'attachments': attachments.map((e) => e.toJson()).toList(),
        'likes': likes.map((e) => e.toJson()).toList(),
        'comments': comments.map((e) => e.toJson()).toList(),
        'likedByMe': likedByMe,
        if (likeCountValue != null) 'likeCount': likeCountValue,
        if (commentCountValue != null) 'commentCount': commentCountValue,
        'createdAt': createdAt.toUtc().toIso8601String(),
        if (updatedAt != null)
          'updatedAt': updatedAt!.toUtc().toIso8601String(),
        if (location != null) 'location': location,
      };

  factory MomentPost.fromJson(Map<String, dynamic> json) {
    final likesRaw = _pickLikeList(json);
    final commentsRaw = _pickCommentList(json);
    return MomentPost(
      id: json['id']?.toString() ?? json['momentId']?.toString() ?? '',
      author: MomentUserSnapshot.fromJson(
        Map<String, dynamic>.from(json['author'] as Map? ?? const {}),
      ),
      text: json['text']?.toString() ?? '',
      attachments: (json['attachments'] as List? ??
              json['mediaList'] as List? ??
              const [])
          .whereType<Map>()
          .map((e) => MomentAttachment.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      likes: likesRaw
          .map((e) => MomentReaction.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      comments: commentsRaw
          .map((e) => MomentComment.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      createdAt: _parseApiTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseApiTime(json['updatedAt']),
      location: json['location']?.toString(),
      likedByMe: json['likedByMe'] == true,
      likeCountValue: _parseInt(json['likeCount']),
      commentCountValue: _parseInt(json['commentCount']),
    );
  }
}

class MomentPostPage {
  const MomentPostPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
    this.fromCache = false,
    this.notice,
    this.visibleRangeDays,
  });

  final List<MomentPost> items;
  final String? nextCursor;
  final bool hasMore;
  final bool fromCache;
  final String? notice;
  final int? visibleRangeDays;
}

List<Map<String, dynamic>> _parseMapList(dynamic raw) {
  return (raw as List? ?? const [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

/// Feed / 用户动态：优先 `likesPreview`；详情：仅 `likes`。
List<Map<String, dynamic>> _pickLikeList(Map<String, dynamic> json) {
  if (json.containsKey('likesPreview')) {
    return _parseMapList(json['likesPreview']);
  }
  return _parseMapList(json['likes']);
}

/// Feed / 用户动态：优先 `commentsPreview`；详情：仅 `comments`。
List<Map<String, dynamic>> _pickCommentList(Map<String, dynamic> json) {
  if (json.containsKey('commentsPreview')) {
    return _parseMapList(json['commentsPreview']);
  }
  return _parseMapList(json['comments']);
}

/// 点赞/取消点赞接口的部分响应，合并进已有 [MomentPost]。
MomentPost mergeMomentLikeMutation(
  MomentPost current,
  Map<String, dynamic> json,
) {
  final likesRaw = json.containsKey('likesPreview')
      ? _parseMapList(json['likesPreview'])
      : current.likes
          .map(
            (item) => {
              'user': item.author.toJson(),
              'createdAt': item.createdAt.millisecondsSinceEpoch,
            },
          )
          .toList();
  return current.copyWith(
    likedByMe: json.containsKey('likedByMe')
        ? json['likedByMe'] == true
        : current.likedByMe,
    likeCountValue: _parseInt(json['likeCount']) ?? current.likeCountValue,
    likes: likesRaw
        .map((e) => MomentReaction.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

bool momentJsonIsFullItem(Map<String, dynamic> json) {
  return json.containsKey('author') &&
      (json.containsKey('text') || json.containsKey('mediaList'));
}

bool momentJsonIsLikeMutation(Map<String, dynamic> json) {
  return json.containsKey('likeCount') || json.containsKey('likesPreview');
}

int? _parseInt(dynamic raw) {
  if (raw is int) return raw;
  return int.tryParse(raw?.toString() ?? '');
}

DateTime? _parseApiTime(dynamic raw) {
  if (raw is int) {
    final ms = raw < 1000000000000 ? raw * 1000 : raw;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  }
  final value = raw?.toString().trim() ?? '';
  if (value.isEmpty) return null;
  final millis = int.tryParse(value);
  if (millis != null) {
    final ms = millis < 1000000000000 ? millis * 1000 : millis;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  }
  return DateTime.tryParse(value)?.toLocal();
}

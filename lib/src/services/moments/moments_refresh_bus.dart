import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime/friend_realtime_event.dart';

class MomentsRefreshHint {
  const MomentsRefreshHint({
    required this.action,
    this.momentId,
    this.authorUserId,
    this.actorUserId,
    this.liked,
    this.likeCount,
    this.commentId,
    this.replyToCommentId,
    this.commentCount,
    this.pushTs,
  });

  final String action;
  final String? momentId;
  final String? authorUserId;
  final String? actorUserId;
  final bool? liked;
  final int? likeCount;
  final String? commentId;
  final String? replyToCommentId;
  final int? commentCount;
  final int? pushTs;

  factory MomentsRefreshHint.fromRealtime(FriendRealtimeEvent event) {
    return MomentsRefreshHint(
      action: event.action?.trim().toLowerCase() ?? '',
      momentId: event.momentId?.trim(),
      authorUserId: event.authorUserId?.trim() ?? event.fromUserId.trim(),
      actorUserId: event.actorUserId?.trim(),
      liked: event.liked,
      likeCount: event.likeCount,
      commentId: event.commentId?.trim(),
      replyToCommentId: event.replyToCommentId?.trim(),
      commentCount: event.commentCount,
      pushTs: event.ts,
    );
  }
}

class MomentsRefreshBus {
  MomentsRefreshBus._();

  static final MomentsRefreshBus instance = MomentsRefreshBus._();

  final ValueNotifier<MomentsRefreshHint?> lastRefresh =
      ValueNotifier<MomentsRefreshHint?>(null);
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  void notify(MomentsRefreshHint hint) {
    if (hint.action.trim().isEmpty) {
      return;
    }
    revision.value++;
    lastRefresh.value = hint;
  }
}

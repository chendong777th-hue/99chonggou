import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/errors/app_error.dart';
import 'package:tencent_cloud_chat_demo/src/api/moments_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/moments/moment_models.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_error_mapper.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_local_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_self_info_view_model.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

class MomentsStore {
  MomentsStore._();

  static const String _draftKeyPrefix = 'moments_draft_v1_';
  static String? debugAccountScopeOverride;
  static MomentUserSnapshot? debugSelfSnapshotOverride;

  static String safeLoginUserId() {
    try {
      return TIMUIKitCore.getInstance().loginInfo.userID.trim();
    } catch (_) {
      return '';
    }
  }

  static String accountScope() {
    final override = debugAccountScopeOverride?.trim() ?? '';
    if (override.isNotEmpty) return override;
    return accountScopeForUserId(safeLoginUserId());
  }

  static String accountScopeForUserId(String? userId) {
    final raw = (userId ?? '').trim();
    if (raw.isEmpty) return '_guest';
    return raw.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  static String _draftKey() => '$_draftKeyPrefix${accountScope()}';

  /// 注销：删除该账号朋友圈草稿 prefs。
  static Future<void> clearDraftForOwner(String? ownerUserId) async {
    final scope = accountScopeForUserId(ownerUserId);
    if (scope.isEmpty || scope == '_guest') {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_draftKeyPrefix$scope');
  }

  static MomentPostPage _postPageFromApi(MomentsPageResult page) {
    return MomentPostPage(
      items: page.items,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
      visibleRangeDays: page.visibleRangeDays,
    );
  }

  static List<MomentPost> seedPosts() {
    final self = _selfSnapshot();
    return <MomentPost>[
      MomentPost(
        id: 'seed_1',
        author: const MomentUserSnapshot(
          id: 'friend_1001',
          name: '林远',
          avatarUrl: 'assets/custom_face_resource/4350/yz08@2x.png',
        ),
        text: '周末把项目里朋友圈入口先做出来了，后面再接后端。',
        attachments: const [
          MomentAttachment(
            type: MomentMediaType.image,
            path: 'assets/chat_backgrounds/scenery.png',
          ),
        ],
        likes: [
          MomentReaction(
            id: 'like_1',
            author: const MomentUserSnapshot(
              id: 'friend_1002',
              name: '苏予',
              avatarUrl: 'assets/custom_face_resource/4351/ys04@2x.png',
            ),
            createdAt: DateTime(2026, 6, 25, 18, 12),
          ),
        ],
        comments: [
          MomentComment(
            id: 'comment_1',
            author: const MomentUserSnapshot(
              id: 'friend_1003',
              name: '陈屿',
              avatarUrl: 'assets/custom_face_resource/4352/gcs03@2x.png',
            ),
            text: '这个入口放个人页挺合适。',
            createdAt: DateTime(2026, 6, 25, 18, 20),
          ),
          MomentComment(
            id: 'comment_1_reply',
            author: const MomentUserSnapshot(
              id: 'friend_1002',
              name: '苏予',
              avatarUrl: 'assets/custom_face_resource/4351/ys04@2x.png',
            ),
            replyToCommentId: 'comment_1',
            replyToUser: const MomentUserSnapshot(
              id: 'friend_1003',
              name: '陈屿',
              avatarUrl: 'assets/custom_face_resource/4352/gcs03@2x.png',
            ),
            text: '对，放在关系入口里更自然。',
            createdAt: DateTime(2026, 6, 25, 18, 28),
          ),
        ],
        createdAt: DateTime(2026, 6, 25, 17, 48),
        location: '深圳',
      ),
      MomentPost(
        id: 'seed_2',
        author: const MomentUserSnapshot(
          id: 'friend_1004',
          name: '青禾',
          avatarUrl: 'assets/custom_face_resource/4351/ys11@2x.png',
        ),
        text: '把长列表卡片做得更紧凑一点，信息密度才像聊天产品。',
        attachments: const [
          MomentAttachment(
            type: MomentMediaType.image,
            path: 'assets/icon_wechat_moments.jpg',
          ),
        ],
        likes: [],
        comments: [],
        createdAt: DateTime(2026, 6, 24, 22, 15),
        location: '上海',
      ),
      MomentPost(
        id: 'seed_3',
        author: self,
        text: '今天先把朋友圈前端做成可用版本，后端接口后面补。',
        attachments: const [
          MomentAttachment(
            type: MomentMediaType.image,
            path: 'assets/chat_backgrounds/beauty.png',
          ),
          MomentAttachment(
            type: MomentMediaType.image,
            path: 'assets/chat_backgrounds/scenery.png',
          ),
        ],
        likes: [],
        comments: [
          MomentComment(
            id: 'comment_2',
            author: const MomentUserSnapshot(
              id: 'friend_1005',
              name: '阿澄',
              avatarUrl: 'assets/custom_face_resource/4352/gcs07@2x.png',
            ),
            text: '先把流程跑通很重要。',
            createdAt: DateTime(2026, 6, 26, 10, 1),
          ),
        ],
        createdAt: DateTime(2026, 6, 26, 9, 36),
        location: '杭州',
      ),
    ];
  }

  static MomentUserSnapshot _selfSnapshot() {
    final override = debugSelfSnapshotOverride;
    if (override != null && !override.isEmpty) {
      return override;
    }
    String id = '';
    String name = '';
    String avatar = '';
    try {
      final info = serviceLocator<TUISelfInfoViewModel>().loginInfo;
      id = info?.userID?.trim() ?? '';
      name = info?.nickName?.trim() ?? '';
      avatar = info?.faceUrl?.trim() ?? '';
    } catch (_) {}
    return MomentUserSnapshot(
      id: id.isEmpty ? 'self' : id,
      name: name.isEmpty ? '我' : name,
      avatarUrl: avatar.isEmpty ? 'assets/default_avatar.png' : avatar,
    );
  }

  static Future<List<MomentPost>> loadFeed() async {
    final page = await loadFeedPage();
    return page.items;
  }

  static Future<List<MomentPost>> loadUserMoments(String userId) async {
    final page = await loadUserMomentsPage(userId);
    return page.items;
  }

  static Future<MomentPostPage> loadFeedPage({
    String? cursor,
    int pageSize = 20,
  }) async {
    final scope = MomentsLocalStore.feedScope();
    try {
      final page = _postPageFromApi(
        await MomentsApi.instance.fetchFeed(
          cursor: cursor,
          pageSize: pageSize,
        ),
      );
      await MomentsLocalStore.instance.savePage(
        ownerUserId: accountScope(),
        scope: scope,
        page: page,
        replace: (cursor ?? '').trim().isEmpty,
      );
      return page;
    } catch (e) {
      return _cachedPageOrThrow(
        error: e,
        scope: scope,
        allowCache: (cursor ?? '').trim().isEmpty,
      );
    }
  }

  static Future<MomentPostPage> loadUserMomentsPage(
    String userId, {
    String? cursor,
    int pageSize = 20,
  }) async {
    final id = userId.trim();
    if (id.isEmpty) return const MomentPostPage(items: [], hasMore: false);
    final scope = MomentsLocalStore.userScope(id);
    try {
      final page = _postPageFromApi(
        await MomentsApi.instance.fetchUserMoments(
          id,
          cursor: cursor,
          pageSize: pageSize,
        ),
      );
      await MomentsLocalStore.instance.savePage(
        ownerUserId: accountScope(),
        scope: scope,
        page: page,
        replace: (cursor ?? '').trim().isEmpty,
      );
      return page;
    } catch (e) {
      return _cachedPageOrThrow(
        error: e,
        scope: scope,
        allowCache: (cursor ?? '').trim().isEmpty,
      );
    }
  }

  static Future<List<MomentPost>> loadLocalFeed() async {
    final page = await MomentsLocalStore.instance.loadPage(
      ownerUserId: accountScope(),
      scope: MomentsLocalStore.feedScope(),
    );
    return page.items;
  }

  static Future<void> saveFeed(List<MomentPost> posts) async {
    await MomentsLocalStore.instance.savePage(
      ownerUserId: accountScope(),
      scope: MomentsLocalStore.feedScope(),
      page: MomentPostPage(items: posts, hasMore: false),
      replace: true,
    );
  }

  static Future<MomentPostPage> _cachedPageOrThrow({
    required Object error,
    required String scope,
    required bool allowCache,
  }) async {
    final mapped = MomentsErrorMapper.map(error);
    if (allowCache) {
      final cached = await MomentsLocalStore.instance.loadPage(
        ownerUserId: accountScope(),
        scope: scope,
      );
      if (cached.items.isNotEmpty) {
        return MomentPostPage(
          items: cached.items,
          nextCursor: cached.nextCursor,
          hasMore: false,
          fromCache: true,
          notice: mapped.userMessage,
          visibleRangeDays: cached.visibleRangeDays,
        );
      }
    }
    throw AppException(mapped);
  }

  static Future<MomentDraft?> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey());
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      return MomentDraft.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveDraft(MomentDraft? draft) async {
    final prefs = await SharedPreferences.getInstance();
    if (draft == null) {
      await prefs.remove(_draftKey());
      return;
    }
    await prefs.setString(_draftKey(), jsonEncode(draft.toJson()));
  }

  static Future<MomentPost?> findPost(String postId) async {
    try {
      return await MomentsApi.instance.fetchDetail(postId);
    } catch (e) {
      final error = MomentsErrorMapper.map(e);
      if (error.code == 'MOMENT_NOT_FOUND') {
        return null;
      }
      throw AppException(error);
    }
  }

  static Future<List<MomentNotification>> loadNotifications() async {
    final page = await loadNotificationsPage();
    return page.items;
  }

  static Future<MomentsNotificationsResult> loadNotificationsPage({
    String? cursor,
  }) {
    return MomentsApi.instance.fetchNotifications(
      cursor: cursor,
      pageSize: 20,
    );
  }

  static Future<int> fetchNotificationUnreadCount() async {
    try {
      final page = await MomentsApi.instance.fetchNotifications(pageSize: 1);
      return page.unreadCount;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> markNotificationsRead({
    List<String> notificationIds = const [],
    bool readAll = false,
  }) {
    return MomentsApi.instance.markNotificationsRead(
      notificationIds: notificationIds,
      readAll: readAll,
    );
  }

  static Future<MomentPost> upsertPost(MomentPost post) async {
    await MomentsLocalStore.instance.upsertPost(
      ownerUserId: accountScope(),
      post: post,
    );
    return post;
  }

  static Future<void> deletePost(String postId) async {
    try {
      await MomentsApi.instance.deletePost(postId);
      await MomentsLocalStore.instance.deletePost(
        ownerUserId: accountScope(),
        postId: postId,
      );
    } catch (e) {
      throw MomentsErrorMapper.exception(e, action: 'delete');
    }
  }

  static Future<MomentPost> toggleLike(
    String postId, {
    MomentPost? current,
  }) async {
    try {
      final selfId = safeLoginUserId();
      final liked = current?.likedBy(selfId) ??
          (await MomentsApi.instance.fetchDetail(postId)).likedBy(selfId);
      final updated = liked
          ? await MomentsApi.instance.unlike(postId, current: current)
          : await MomentsApi.instance.like(postId, current: current);
      return upsertPost(updated);
    } catch (e) {
      throw MomentsErrorMapper.exception(e, action: 'like');
    }
  }

  static Future<MomentPost> addComment(
    String postId,
    String text, {
    MomentUserSnapshot? author,
    String? replyToCommentId,
  }) async {
    final content = text.trim();
    if (content.isEmpty) {
      throw ArgumentError.value(text, 'text', 'comment text is empty');
    }
    try {
      return upsertPost(
        await MomentsApi.instance.addComment(
          postId,
          content,
          replyToCommentId: replyToCommentId,
        ),
      );
    } catch (e) {
      throw MomentsErrorMapper.exception(e, action: 'comment');
    }
  }

  static Future<MomentPost> deleteComment(
    String postId,
    String commentId,
  ) async {
    final momentId = postId.trim();
    final id = commentId.trim();
    if (momentId.isEmpty || id.isEmpty) {
      throw ArgumentError('postId and commentId are required');
    }
    try {
      await MomentsApi.instance.deleteComment(momentId, id);
      return upsertPost(await MomentsApi.instance.fetchDetail(momentId));
    } catch (e) {
      throw MomentsErrorMapper.exception(e, action: 'delete');
    }
  }

  static Future<MomentPost> createPost({
    required String text,
    required List<MomentAttachment> attachments,
    String? location,
    MomentPublishPrivacy privacy = const MomentPublishPrivacy(),
    void Function(int completed, int total)? onUploadProgress,
  }) async {
    try {
      final uploaded = <MomentAttachment>[];
      final total = attachments.length;
      for (var index = 0; index < attachments.length; index++) {
        onUploadProgress?.call(index, total);
        uploaded.add(await MomentsApi.instance.uploadMedia(attachments[index]));
      }
      if (total > 0) {
        onUploadProgress?.call(total, total);
      }
      final mediaIds = uploaded
          .map((item) => item.mediaId?.trim() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      final visibleUserIds = privacy.selectedUsers
          .map((user) => user.id.trim())
          .where((id) => id.isNotEmpty)
          .toList();
      final created = await MomentsApi.instance.createPost(
        text: text,
        mediaIds: mediaIds,
        location: location,
        visibility: privacy.mode.apiValue,
        visibleUserIds: visibleUserIds,
      );
      final mergedAttachments = <MomentAttachment>[];
      for (var index = 0; index < created.attachments.length; index++) {
        final server = created.attachments[index];
        MomentAttachment? local;
        final serverId = server.mediaId?.trim() ?? '';
        if (serverId.isNotEmpty) {
          for (final candidate in uploaded) {
            if (candidate.mediaId?.trim() == serverId) {
              local = candidate;
              break;
            }
          }
        }
        if (local == null && index < uploaded.length) local = uploaded[index];
        mergedAttachments.add(server.copyWith(
          width: server.width ?? local?.width,
          height: server.height ?? local?.height,
          durationSec: server.durationSec ?? local?.durationSec,
        ));
      }
      return upsertPost(created.copyWith(attachments: mergedAttachments));
    } catch (e) {
      throw MomentsErrorMapper.exception(e, action: 'publish');
    }
  }

  static Future<void> bootstrapDraftFromCurrentText(String text) async {
    final draft = MomentDraft(
      text: text,
      attachments: const [],
      updatedAt: DateTime.now(),
    );
    await saveDraft(draft);
  }
}

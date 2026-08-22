import 'package:tencent_cloud_chat_demo/src/models/moments/moment_models.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_error_mapper.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_store.dart';

class MomentsFeedController {
  MomentsFeedController({
    String? authorId,
  }) : authorId = authorId?.trim() ?? '';

  final String authorId;

  bool loading = true;
  bool loadingMore = false;
  bool hasMore = false;
  List<MomentPost> posts = const [];
  MomentDraft? draft;
  String? error;
  String? loadMoreError;
  String? _nextCursor;
  int? authorVisibleRangeDays;

  bool get isProfileList => authorId.isNotEmpty;

  Future<void> load({bool showRefreshing = false}) async {
    if (!showRefreshing) {
      loading = true;
      error = null;
      loadMoreError = null;
    }
    try {
      final results = await Future.wait([
        isProfileList
            ? MomentsStore.loadUserMomentsPage(authorId)
            : MomentsStore.loadFeedPage(),
        MomentsStore.loadDraft(),
      ]);
      final page = results[0] as MomentPostPage;
      posts = page.items;
      _nextCursor = page.nextCursor;
      hasMore = page.hasMore && (page.nextCursor?.trim().isNotEmpty ?? false);
      if (isProfileList) {
        authorVisibleRangeDays = page.visibleRangeDays;
      }
      loadingMore = false;
      loadMoreError = null;
      draft = results[1] as MomentDraft?;
      loading = false;
      error = page.fromCache ? page.notice : null;
    } catch (e) {
      loading = false;
      loadingMore = false;
      error = MomentsErrorMapper.map(e).userMessage;
    }
  }

  Future<void> loadMore() async {
    final cursor = _nextCursor?.trim() ?? '';
    if (loadingMore || !hasMore || cursor.isEmpty) {
      return;
    }
    loadingMore = true;
    loadMoreError = null;
    try {
      final page = isProfileList
          ? await MomentsStore.loadUserMomentsPage(authorId, cursor: cursor)
          : await MomentsStore.loadFeedPage(cursor: cursor);
      posts = _mergePosts(posts, page.items);
      _nextCursor = page.nextCursor;
      hasMore = page.hasMore && (page.nextCursor?.trim().isNotEmpty ?? false);
      loadingMore = false;
    } catch (e) {
      loadingMore = false;
      loadMoreError = MomentsErrorMapper.map(e).userMessage;
    }
  }

  Future<void> refreshAfterNavigation() async {
    await load(showRefreshing: true);
  }

  Future<void> refreshDraft() async {
    draft = await MomentsStore.loadDraft();
  }

  Future<void> toggleLike(MomentPost post) async {
    final updated =
        await MomentsStore.toggleLike(post.id, current: post);
    _replacePost(updated);
  }

  Future<void> addComment(
    MomentPost post,
    String text, {
    String? replyToCommentId,
  }) async {
    final updated = await MomentsStore.addComment(
      post.id,
      text,
      replyToCommentId: replyToCommentId,
    );
    _replacePost(updated);
  }

  Future<void> deleteComment(MomentPost post, String commentId) async {
    final updated = await MomentsStore.deleteComment(post.id, commentId);
    _replacePost(updated);
  }

  Future<void> deletePost(MomentPost post) async {
    await MomentsStore.deletePost(post.id);
    await load(showRefreshing: true);
  }

  List<MomentPost> _mergePosts(
    List<MomentPost> current,
    List<MomentPost> incoming,
  ) {
    if (incoming.isEmpty) {
      return current;
    }
    final seen = current.map((post) => post.id).toSet();
    final merged = <MomentPost>[...current];
    for (final post in incoming) {
      if (seen.add(post.id)) {
        merged.add(post);
      }
    }
    return merged;
  }

  void _replacePost(MomentPost next) {
    posts = posts
        .map((post) => post.id == next.id ? next : post)
        .toList(growable: false);
  }
}

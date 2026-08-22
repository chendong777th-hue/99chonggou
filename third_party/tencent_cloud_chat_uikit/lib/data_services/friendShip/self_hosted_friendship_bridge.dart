import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';

class SelfHostedFriendshipAddResult {
  const SelfHostedFriendshipAddResult({
    required this.outcome,
    this.requestId,
  });

  final String outcome;
  final int? requestId;

  bool get isPending => outcome == 'pending';
  bool get isAutoAccepted => outcome == 'auto_accepted';
  bool get isRestored => outcome == 'restored';
}

/// 本地搜索 ID 分页（Phase 3）。
class SelfHostedIdSearchPage {
  const SelfHostedIdSearchPage({
    required this.ids,
    this.nextCursor,
    required this.hasMore,
  });

  final List<String> ids;
  final String? nextCursor;
  final bool hasMore;

  static const empty = SelfHostedIdSearchPage(
    ids: <String>[],
    nextCursor: null,
    hasMore: false,
  );
}

typedef SelfHostedFriendListLoader = Future<List<V2TimFriendInfo>> Function();
typedef SelfHostedFriendLocalSearcher = Future<SelfHostedIdSearchPage> Function({
  required String keyword,
  int limit,
  String? cursor,
});
typedef SelfHostedFriendHydrator = Future<List<V2TimFriendInfo>> Function(
  List<String> userIds,
);
typedef SelfHostedFriendRequestCreator = Future<SelfHostedFriendshipAddResult>
    Function({
  required String userID,
  String? addSource,
  String? addWording,
});
typedef SelfHostedFriendDelete = Future<void> Function(String userID);
typedef SelfHostedFriendRemarkUpdater = Future<void> Function({
  required String userID,
  required String remark,
});
typedef SelfHostedFriendChecker = Future<bool> Function(String userID);
typedef SelfHostedFriendResultTypeResolver = Future<int> Function(String userID);
typedef SelfHostedPendingCountLoader = Future<int> Function();

/// Bridge from the reusable UIKit package to 99chat-server self-hosted friends.
///
/// The app configures these callbacks at startup.  When configured, friendship
/// list/add/delete/remark operations stop using IM SNS and call the app backend.
class SelfHostedFriendshipBridge {
  SelfHostedFriendshipBridge._();

  static SelfHostedFriendListLoader? _loadFriendList;
  static SelfHostedFriendListLoader? _loadFriendListFromNetwork;
  static SelfHostedFriendRequestCreator? _createFriendRequest;
  static SelfHostedFriendDelete? _deleteFriend;
  static SelfHostedFriendRemarkUpdater? _updateRemark;
  static SelfHostedFriendChecker? _isFriend;
  static SelfHostedFriendResultTypeResolver? _resolveFriendResultType;
  static SelfHostedPendingCountLoader? _loadPendingIncomingCount;
  static SelfHostedFriendLocalSearcher? _searchFriendsLocal;
  static SelfHostedFriendHydrator? _hydrateFriends;

  static bool get enabled => _loadFriendList != null;

  static bool get localSearchEnabled => _searchFriendsLocal != null;

  static void configure({
    SelfHostedFriendListLoader? loadFriendList,
    SelfHostedFriendListLoader? loadFriendListFromNetwork,
    SelfHostedFriendRequestCreator? createFriendRequest,
    SelfHostedFriendDelete? deleteFriend,
    SelfHostedFriendRemarkUpdater? updateRemark,
    SelfHostedFriendChecker? isFriend,
    SelfHostedFriendResultTypeResolver? resolveFriendResultType,
    SelfHostedPendingCountLoader? loadPendingIncomingCount,
    SelfHostedFriendLocalSearcher? searchFriendsLocal,
    SelfHostedFriendHydrator? hydrateFriends,
  }) {
    _loadFriendList = loadFriendList;
    _loadFriendListFromNetwork = loadFriendListFromNetwork;
    _createFriendRequest = createFriendRequest;
    _deleteFriend = deleteFriend;
    _updateRemark = updateRemark;
    _isFriend = isFriend;
    _resolveFriendResultType = resolveFriendResultType;
    _loadPendingIncomingCount = loadPendingIncomingCount;
    _searchFriendsLocal = searchFriendsLocal;
    _hydrateFriends = hydrateFriends;
  }

  static void clear() {
    _loadFriendList = null;
    _loadFriendListFromNetwork = null;
    _createFriendRequest = null;
    _deleteFriend = null;
    _updateRemark = null;
    _isFriend = null;
    _resolveFriendResultType = null;
    _loadPendingIncomingCount = null;
    _searchFriendsLocal = null;
    _hydrateFriends = null;
  }

  static Future<SelfHostedIdSearchPage> searchFriendsLocal({
    required String keyword,
    int limit = 80,
    String? cursor,
  }) async {
    final searcher = _searchFriendsLocal;
    if (searcher == null) {
      return SelfHostedIdSearchPage.empty;
    }
    return searcher(keyword: keyword, limit: limit, cursor: cursor);
  }

  static Future<List<V2TimFriendInfo>> hydrateFriends(
    List<String> userIds,
  ) async {
    final hydrator = _hydrateFriends;
    if (hydrator == null || userIds.isEmpty) {
      return const <V2TimFriendInfo>[];
    }
    return hydrator(userIds);
  }

  static Future<List<V2TimFriendInfo>> loadFriendList() async {
    final loader = _loadFriendList;
    if (loader == null) return const <V2TimFriendInfo>[];
    return loader();
  }

  static Future<List<V2TimFriendInfo>> loadFriendListFromNetwork() async {
    final loader = _loadFriendListFromNetwork;
    if (loader == null) return const <V2TimFriendInfo>[];
    return loader();
  }

  static Future<SelfHostedFriendshipAddResult> createFriendRequest({
    required String userID,
    String? addSource,
    String? addWording,
  }) async {
    final creator = _createFriendRequest;
    if (creator == null) {
      return const SelfHostedFriendshipAddResult(outcome: 'pending');
    }
    return creator(userID: userID, addSource: addSource, addWording: addWording);
  }

  static Future<void> deleteFriend(String userID) async {
    final deleter = _deleteFriend;
    if (deleter == null) return;
    await deleter(userID);
  }

  static Future<void> updateRemark({
    required String userID,
    required String remark,
  }) async {
    final updater = _updateRemark;
    if (updater == null) return;
    await updater(userID: userID, remark: remark);
  }

  static Future<bool> isFriend(String userID) async {
    final checker = _isFriend;
    if (checker != null) {
      return checker(userID);
    }
    final list = await loadFriendList();
    return list.any((item) => item.userID == userID);
  }

  static Future<int> resolveFriendResultType(String userID) async {
    final resolver = _resolveFriendResultType;
    if (resolver != null) {
      return resolver(userID);
    }
    final list = await loadFriendList();
    for (final item in list) {
      if (item.userID == userID) {
        final canMessage = item.friendCustomInfo?['canMessage'] == '1';
        return canMessage ? 3 : 1;
      }
    }
    return 0;
  }

  static Future<int> loadPendingIncomingCount() async {
    final loader = _loadPendingIncomingCount;
    if (loader == null) return 0;
    return loader();
  }
}

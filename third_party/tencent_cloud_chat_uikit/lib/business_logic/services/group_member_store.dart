import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_jitter_diag.dart';

class GroupMemberChange {
  final String groupID;
  final String userID;
  final V2TimGroupMemberFullInfo? member;

  const GroupMemberChange({
    required this.groupID,
    required this.userID,
    this.member,
  });
}

class GroupMemberStore extends ChangeNotifier {
  GroupMemberStore._();

  static final GroupMemberStore instance = GroupMemberStore._();

  final Map<String, Map<String, V2TimGroupMemberFullInfo>> _data = {};
  final Map<String, Map<String, String>> _nameCardOverrides = {};
  final Map<String, String> _friendRemarkOverrides = {};
  final Map<String, String> _nicknameOverrides = {};
  final Map<String, String> _faceUrlOverrides = {};
  final Map<String, ValueNotifier<int>> _avatarRevisions = {};
  GroupMemberChange? _lastChange;
  Timer? _notifyCoalesceTimer;

  /// Push / 入群成员一条条 put 时合并成一帧通知，避免会话列表 lastMsg 跟着抖。
  static const Duration _notifyCoalesce = Duration(milliseconds: 48);

  GroupMemberChange? get lastChange => _lastChange;

  String _avatarRevisionKey(String groupID, String userID) =>
      '${groupID.trim()}|${userID.trim()}';

  ValueListenable<int> avatarListenable(String groupID, String userID) {
    final key = _avatarRevisionKey(groupID, userID);
    return _avatarRevisions.putIfAbsent(key, () => ValueNotifier<int>(0));
  }

  void _scheduleCoalescedNotify() {
    _notifyCoalesceTimer?.cancel();
    _notifyCoalesceTimer = Timer(_notifyCoalesce, () {
      _notifyCoalesceTimer = null;
      notifyListeners();
    });
  }

  void _notifyAvatarUsers(String groupID, Iterable<String> userIDs) {
    final groupKey = groupID.trim();
    if (groupKey.isEmpty) {
      return;
    }
    for (final rawUserID in userIDs.toSet()) {
      final userID = rawUserID.trim();
      if (userID.isEmpty) {
        continue;
      }
      final key = _avatarRevisionKey(groupKey, userID);
      final revision =
          _avatarRevisions.putIfAbsent(key, () => ValueNotifier<int>(0));
      revision.value++;
    }
  }

  void putMembers(String groupID, Iterable<V2TimGroupMemberFullInfo?> members,
      {bool notify = false}) {
    final key = groupID.trim();
    if (key.isEmpty) {
      return;
    }
    final changedUserIDs = <String>{};
    for (final member in members) {
      final userID = (member?.userID ?? '').trim();
      if (member == null || userID.isEmpty) {
        continue;
      }
      _applyOverrides(key, member);
      final bucket =
          _data.putIfAbsent(key, () => <String, V2TimGroupMemberFullInfo>{});
      final prev = bucket[userID];
      // 仅在真正新增或头像/名片变化时算 changed，避免进页重复 hydrate 空通知。
      if (prev == null ||
          prev.faceUrl != member.faceUrl ||
          prev.nickName != member.nickName ||
          prev.nameCard != member.nameCard ||
          prev.friendRemark != member.friendRemark) {
        changedUserIDs.add(userID);
      }
      bucket[userID] = member;
    }
    if (changedUserIDs.isNotEmpty && notify) {
      ChatJitterDiag.logGroupMemberStore(
        action: 'putMembers',
        groupId: key,
        memberCount: _data[key]?.length,
        notify: true,
      );
      _notifyAvatarUsers(key, changedUserIDs);
      _scheduleCoalescedNotify();
    }
  }

  Set<String> avatarRefreshUserIDs(
    String groupID,
    Iterable<V2TimGroupMemberFullInfo?> members,
  ) {
    final key = groupID.trim();
    if (key.isEmpty) {
      return const <String>{};
    }
    final changedUserIDs = <String>{};
    final bucket = _data[key];
    for (final member in members) {
      final userID = (member?.userID ?? '').trim();
      if (member == null || userID.isEmpty) {
        continue;
      }
      final prev = bucket?[userID];
      if (prev == null ||
          prev.faceUrl != member.faceUrl ||
          prev.nickName != member.nickName ||
          prev.nameCard != member.nameCard ||
          prev.friendRemark != member.friendRemark) {
        changedUserIDs.add(userID);
      }
    }
    return changedUserIDs;
  }

  /// 供调用方判断静默 putMembers 后是否还需要主动 notify。
  bool wouldAvatarRefreshMatter(
    String groupID,
    Iterable<V2TimGroupMemberFullInfo?> members,
  ) {
    return avatarRefreshUserIDs(groupID, members).isNotEmpty;
  }

  void putMember(String groupID, V2TimGroupMemberFullInfo? member,
      {bool notify = true}) {
    final key = groupID.trim();
    final userID = (member?.userID ?? '').trim();
    if (key.isEmpty || member == null || userID.isEmpty) {
      return;
    }
    _applyOverrides(key, member);
    final bucket =
        _data.putIfAbsent(key, () => <String, V2TimGroupMemberFullInfo>{});
    final previous = bucket[userID];
    final changed = previous == null ||
        previous.faceUrl != member.faceUrl ||
        previous.nickName != member.nickName ||
        previous.nameCard != member.nameCard ||
        previous.friendRemark != member.friendRemark;
    bucket[userID] = member;
    _lastChange =
        GroupMemberChange(groupID: key, userID: userID, member: member);
    if (notify && changed) {
      ChatJitterDiag.logGroupMemberStore(
        action: 'putMember',
        groupId: key,
        memberCount: _data[key]?.length,
        notify: true,
      );
      _notifyAvatarUsers(key, <String>[userID]);
      _scheduleCoalescedNotify();
    }
  }

  void _applyOverrides(String groupID, V2TimGroupMemberFullInfo member) {
    final userID = member.userID.trim();
    if (userID.isEmpty) {
      return;
    }
    final groupOverrides = _nameCardOverrides[groupID];
    if (groupOverrides != null && groupOverrides.containsKey(userID)) {
      member.nameCard = groupOverrides[userID];
    }
    if (_friendRemarkOverrides.containsKey(userID)) {
      member.friendRemark = _friendRemarkOverrides[userID];
    }
    if (_nicknameOverrides.containsKey(userID)) {
      member.nickName = _nicknameOverrides[userID];
    }
    if (_faceUrlOverrides.containsKey(userID)) {
      member.faceUrl = _faceUrlOverrides[userID];
    }
  }

  /// 将资料页拿到的最新公开资料覆盖到所有群成员快照。
  ///
  /// 覆盖值同时保留给后续 [putMember]/[putMembers]，避免 SDK 的旧成员
  /// 快照在退出聊天后再次把新头像、昵称顶回去。
  void putProfileForUser({
    required String userID,
    String? nickName,
    String? faceUrl,
    bool notify = true,
  }) {
    final uid = userID.trim();
    if (uid.isEmpty) {
      return;
    }
    final nicknameValue = nickName?.trim();
    final faceUrlValue = faceUrl?.trim();
    if (nicknameValue != null && nicknameValue.isNotEmpty) {
      _nicknameOverrides[uid] = nicknameValue;
    }
    if (faceUrlValue != null && faceUrlValue.isNotEmpty) {
      _faceUrlOverrides[uid] = faceUrlValue;
    }
    if ((nicknameValue == null || nicknameValue.isEmpty) &&
        (faceUrlValue == null || faceUrlValue.isEmpty)) {
      return;
    }

    final changedGroups = <String>[];
    for (final entry in _data.entries) {
      final member = entry.value[uid];
      if (member == null) {
        continue;
      }
      final previousNickname = member.nickName;
      final previousFaceUrl = member.faceUrl;
      _applyOverrides(entry.key, member);
      if (previousNickname != member.nickName ||
          previousFaceUrl != member.faceUrl) {
        entry.value[uid] = member;
        changedGroups.add(entry.key);
      }
    }
    if (changedGroups.isNotEmpty) {
      _lastChange = GroupMemberChange(groupID: '', userID: uid);
    }
    if (notify && changedGroups.isNotEmpty) {
      for (final groupID in changedGroups) {
        _notifyAvatarUsers(groupID, <String>[uid]);
      }
      _scheduleCoalescedNotify();
    }
  }

  void putNameCard({
    required String groupID,
    required String userID,
    required String nameCard,
    V2TimGroupMemberFullInfo? member,
    bool notify = true,
  }) {
    final key = groupID.trim();
    final uid = userID.trim();
    if (key.isEmpty || uid.isEmpty) {
      return;
    }
    _nameCardOverrides.putIfAbsent(key, () => <String, String>{})[uid] =
        nameCard;
    final group =
        _data.putIfAbsent(key, () => <String, V2TimGroupMemberFullInfo>{});
    final current =
        member ?? group[uid] ?? V2TimGroupMemberFullInfo(userID: uid);
    final changed = current.nameCard != nameCard;
    current.nameCard = nameCard;
    group[uid] = current;
    _lastChange = GroupMemberChange(groupID: key, userID: uid, member: current);
    if (notify && changed) {
      _notifyAvatarUsers(key, <String>[uid]);
      _scheduleCoalescedNotify();
    }
  }

  /// 主动广播一次变更，供监听方（如聊天页群头像）在成员数据已就位、
  /// 但没有走 put* 写入的场景下触发局部刷新。
  void notifyChatAvatarRefresh() {
    ChatJitterDiag.logGroupMemberStore(
      action: 'notifyChatAvatarRefresh',
      notify: true,
    );
    notifyListeners();
  }

  /// 只刷新指定成员的头像监听器，避免群内所有可见头像同时 rebuild。
  void notifyChatAvatarRefreshForUsers(
    String groupID,
    Iterable<String> userIDs,
  ) {
    final users =
        userIDs.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    if (groupID.trim().isEmpty || users.isEmpty) {
      return;
    }
    ChatJitterDiag.logGroupMemberStore(
      action: 'notifyChatAvatarRefreshForUsers',
      groupId: groupID.trim(),
      memberCount: users.length,
      notify: true,
    );
    _notifyAvatarUsers(groupID, users);
  }

  V2TimGroupMemberFullInfo? memberOf(String groupID, String userID) {
    return _data[groupID.trim()]?[userID.trim()];
  }

  List<V2TimGroupMemberFullInfo> membersForGroup(String groupID) {
    final group = _data[groupID.trim()];
    if (group == null || group.isEmpty) {
      return const <V2TimGroupMemberFullInfo>[];
    }
    return group.values.toList(growable: false);
  }

  void putFriendRemarkForUser(String userID, String friendRemark,
      {bool notify = true}) {
    final uid = userID.trim();
    if (uid.isEmpty) {
      return;
    }
    _friendRemarkOverrides[uid] = friendRemark;
    if (_data.isEmpty) {
      return;
    }
    final changedGroups = <String>[];
    for (final entry in _data.entries) {
      final group = entry.value;
      final member = group[uid];
      if (member != null && member.friendRemark != friendRemark) {
        member.friendRemark = friendRemark;
        group[uid] = member;
        changedGroups.add(entry.key);
      }
    }
    if (changedGroups.isNotEmpty) {
      _lastChange = GroupMemberChange(groupID: '', userID: uid);
      if (notify) {
        for (final groupID in changedGroups) {
          _notifyAvatarUsers(groupID, <String>[uid]);
        }
        _scheduleCoalescedNotify();
      }
    }
  }

  /// 用户资料头像变更时，写回内存中已缓存群的该成员 faceUrl（不凭空建成员）。
  void putFaceUrlForUser(String userID, String faceUrl, {bool notify = true}) {
    final uid = userID.trim();
    final face = faceUrl.trim();
    if (uid.isEmpty || face.isEmpty || _data.isEmpty) {
      return;
    }
    final changedGroups = <String>[];
    for (final entry in _data.entries) {
      final group = entry.value;
      final member = group[uid];
      if (member == null) {
        continue;
      }
      if ((member.faceUrl ?? '').trim() == face) {
        continue;
      }
      member.faceUrl = face;
      group[uid] = member;
      changedGroups.add(entry.key);
    }
    if (changedGroups.isEmpty) {
      return;
    }
    _lastChange = GroupMemberChange(groupID: '', userID: uid);
    if (notify) {
      for (final groupID in changedGroups) {
        _notifyAvatarUsers(groupID, <String>[uid]);
      }
      _scheduleCoalescedNotify();
    }
  }

  void removeMembers(String groupID, Iterable<String?> userIDs,
      {bool notify = true}) {
    final key = groupID.trim();
    final group = _data[key];
    if (group == null) {
      return;
    }
    final changedUserIDs = <String>{};
    for (final userID in userIDs) {
      final uid = userID?.trim() ?? '';
      if (uid.isEmpty) {
        continue;
      }
      if (group.remove(uid) != null) {
        changedUserIDs.add(uid);
      }
    }
    if (changedUserIDs.isNotEmpty && notify) {
      _notifyAvatarUsers(key, changedUserIDs);
      _scheduleCoalescedNotify();
    }
  }

  /// 登出或切换账号时清空内存缓存，避免跨账号串数据。
  void clear({bool notify = true}) {
    _notifyCoalesceTimer?.cancel();
    _notifyCoalesceTimer = null;
    if (_data.isEmpty &&
        _nameCardOverrides.isEmpty &&
        _friendRemarkOverrides.isEmpty &&
        _nicknameOverrides.isEmpty &&
        _faceUrlOverrides.isEmpty &&
        _lastChange == null) {
      return;
    }
    _data.clear();
    _nameCardOverrides.clear();
    _friendRemarkOverrides.clear();
    _nicknameOverrides.clear();
    _faceUrlOverrides.clear();
    _lastChange = null;
    if (notify) {
      for (final revision in _avatarRevisions.values) {
        revision.value++;
      }
      notifyListeners();
    }
  }
}

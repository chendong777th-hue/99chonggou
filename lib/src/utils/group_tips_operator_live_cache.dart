import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/group_tips_message_helper.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

/// TCP / change-events 写入的内存操作者缓存，供 GroupTips 首帧同步解析。
class GroupTipsOperatorLiveCache {
  GroupTipsOperatorLiveCache._();

  static final GroupTipsOperatorLiveCache instance =
      GroupTipsOperatorLiveCache._();

  static const matchWindowSec = 120;

  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  final Map<String, List<GroupTipsOperatorLiveEntry>> _entriesByGroup =
      <String, List<GroupTipsOperatorLiveEntry>>{};

  void clear() {
    _entriesByGroup.clear();
    revision.value++;
  }

  void clearGroup(String groupId) {
    final id = _normalizeGroupId(groupId);
    if (id.isEmpty) {
      return;
    }
    if (_entriesByGroup.remove(id) == null) {
      return;
    }
    revision.value++;
  }

  void upsert(GroupTipsOperatorLiveEntry entry) {
    final groupId = _normalizeGroupId(entry.groupId);
    if (groupId.isEmpty || entry.previewAbstract.trim().isEmpty) {
      return;
    }
    final existing = List<GroupTipsOperatorLiveEntry>.from(
      _entriesByGroup[groupId] ?? const <GroupTipsOperatorLiveEntry>[],
    );
    existing.removeWhere(
      (item) =>
          item.changeEventId.isNotEmpty &&
          item.changeEventId == entry.changeEventId,
    );
    existing.add(entry);
    if (existing.length > 200) {
      existing.removeRange(0, existing.length - 200);
    }
    _entriesByGroup[groupId] = existing;
    revision.value++;
  }

  void warmEntries(List<GroupTipsOperatorLiveEntry> entries) {
    for (final entry in entries) {
      upsert(entry);
    }
  }

  GroupTipsOperatorLiveEntry? matchMessage(V2TimMessage message) {
    if (!GroupTipsMessageHelper.isGroupTipsMessage(message)) {
      return null;
    }
    if (GroupTipsMessageHelper.isLocalGroupTips(message)) {
      return null;
    }
    final tips = message.groupTipsElem;
    if (tips == null) {
      return null;
    }
    final groupId = _normalizeGroupId(message.groupID ?? tips.groupID);
    if (groupId.isEmpty) {
      return null;
    }
    final entries = _entriesByGroup[groupId];
    if (entries == null || entries.isEmpty) {
      return null;
    }

    final patchId = GroupTipsMessageHelper.operatorPatchChangeEventId(message);
    if (patchId != null && patchId.isNotEmpty) {
      for (final entry in entries) {
        if (entry.changeEventId == patchId) {
          return entry;
        }
      }
    }

    if (!GroupTipsMessageHelper.isImAdministratorMemberTip(message)) {
      return null;
    }

    final action = GroupTipsMessageHelper.actionForTipsType(tips.type);
    if (action == null) {
      return null;
    }
    final members = GroupTipsMessageHelper.memberUserIdsFromTips(tips);
    final messageSeq = _messageSeq(message);
    final messageSec = _messageTimestampSec(message);

    GroupTipsOperatorLiveEntry? best;
    var bestScore = -1;
    for (final entry in entries) {
      if (entry.action != action) {
        continue;
      }
      if (!_sameMemberSet(entry.memberUserIds, members)) {
        continue;
      }
      var score = 0;
      if (entry.imMsgSeq != null &&
          entry.imMsgSeq! > 0 &&
          messageSeq != null &&
          entry.imMsgSeq == messageSeq) {
        score = 100;
      } else if (messageSec > 0 && entry.occurredAtSec > 0) {
        final delta = (messageSec - entry.occurredAtSec).abs();
        if (delta <= matchWindowSec) {
          score = 80 - delta;
        }
      } else {
        score = 10;
      }
      if (score > bestScore) {
        bestScore = score;
        best = entry;
      }
    }
    return bestScore >= 0 ? best : null;
  }

  String? previewForMessage(V2TimMessage message) {
    final entry = matchMessage(message);
    final preview = entry?.previewAbstract.trim() ?? '';
    if (preview.isEmpty) {
      return null;
    }
    return GroupTipsMessageHelper.normalizeGroupTipPreviewDisplay(preview);
  }

  String? operatorUserIdForMessage(V2TimMessage message) {
    final entry = matchMessage(message);
    final operator = entry?.operatorUserId.trim() ?? '';
    return operator.isEmpty ? null : operator;
  }

  /// 横幅 / 通知展示前等待 TCP 或 change-events 写入 live cache。
  static Future<String?> waitForPreview(
    V2TimMessage message, {
    Duration timeout = const Duration(milliseconds: 2400),
  }) async {
    final existing = GroupTipsMessageHelper.resolvedMemberTipPreview(message);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    if (!GroupTipsMessageHelper.isPendingAdministratorMemberTip(message)) {
      return existing;
    }

    final completer = Completer<String?>();
    Timer? deadlineTimer;

    void check() {
      final preview = GroupTipsMessageHelper.resolvedMemberTipPreview(message);
      if (preview != null && preview.isNotEmpty && !completer.isCompleted) {
        completer.complete(preview);
      }
    }

    void onRevision() => check();

    instance.revision.addListener(onRevision);
    deadlineTimer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    await Future<void>.delayed(Duration.zero);
    check();
    if (completer.isCompleted) {
      deadlineTimer.cancel();
      instance.revision.removeListener(onRevision);
      return completer.future;
    }

    final result = await completer.future;
    deadlineTimer.cancel();
    instance.revision.removeListener(onRevision);
    return result;
  }

  bool _sameMemberSet(List<String> left, List<String> right) {
    final normalizedLeft = left
        .map(ChatIdFormat.rawUserUid)
        .where((item) => item.isNotEmpty)
        .toList()
      ..sort();
    final normalizedRight = right
        .map(ChatIdFormat.rawUserUid)
        .where((item) => item.isNotEmpty)
        .toList()
      ..sort();
    if (normalizedLeft.length != normalizedRight.length) {
      return false;
    }
    for (var index = 0; index < normalizedLeft.length; index++) {
      if (normalizedLeft[index] != normalizedRight[index]) {
        return false;
      }
    }
    return true;
  }

  int? _messageSeq(V2TimMessage message) {
    return int.tryParse(message.seq?.toString() ?? '');
  }

  int _messageTimestampSec(V2TimMessage message) {
    final ts = message.timestamp ?? 0;
    if (ts <= 0) {
      return 0;
    }
    if (ts >= 1000000000000) {
      return ts ~/ 1000;
    }
    return ts;
  }

  String _normalizeGroupId(String groupId) {
    return ChatIdFormat.canonicalGroupStorageId(groupId);
  }
}

class GroupTipsOperatorLiveEntry {
  const GroupTipsOperatorLiveEntry({
    required this.changeEventId,
    required this.groupId,
    required this.action,
    required this.operatorUserId,
    required this.memberUserIds,
    required this.occurredAtSec,
    required this.previewAbstract,
    this.imMsgSeq,
  });

  final String changeEventId;
  final String groupId;
  final String action;
  final String operatorUserId;
  final List<String> memberUserIds;
  final int occurredAtSec;
  final String previewAbstract;
  final int? imMsgSeq;
}

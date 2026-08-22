import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_live_models.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

/// In-memory cache for `GET /me/live-index` used by the group conversation list.
class GroupLiveIndexStore extends ChangeNotifier {
  GroupLiveIndexStore._();

  static final GroupLiveIndexStore instance = GroupLiveIndexStore._();

  final Map<String, GroupLiveIndexItem> _items = <String, GroupLiveIndexItem>{};
  int _revision = 0;
  String? _etag;

  int get revision => _revision;

  String? get etag => _etag;

  Iterable<GroupLiveIndexItem> get items => _items.values;

  GroupLiveIndexItem? itemForGroup(String? groupId) {
    final normalized = _normalizeGroupId(groupId);
    if (normalized.isEmpty) {
      return null;
    }
    return _items[normalized];
  }

  bool hasActiveSlot(String? groupId) => itemForGroup(groupId) != null;

  void applySnapshot(
    GroupLiveIndexSnapshot snapshot, {
    String? etag,
  }) {
    final next = <String, GroupLiveIndexItem>{};
    for (final item in snapshot.items) {
      final groupId = _normalizeGroupId(item.groupId);
      if (groupId.isEmpty || !item.status.isActiveSlot) {
        continue;
      }
      next[groupId] = GroupLiveIndexItem(
        groupId: groupId,
        liveSessionId: item.liveSessionId,
        status: item.status,
        version: item.version,
        roomName: item.roomName,
        anchorUserId: item.anchorUserId,
        scheduledStartAt: item.scheduledStartAt,
        startedAt: item.startedAt,
      );
    }
    _replaceAll(
      next,
      revision: snapshot.revision,
      etag: etag,
    );
  }

  void applyTcpPatch({
    required String groupId,
    required Map<String, dynamic> detail,
  }) {
    final normalized = _normalizeGroupId(groupId);
    if (normalized.isEmpty) {
      return;
    }
    final item = GroupLiveIndexItem.fromTcpDetail(
      detail,
      groupId: normalized,
    );
    if (!item.status.isActiveSlot) {
      if (!_items.containsKey(normalized)) {
        return;
      }
      _items.remove(normalized);
      notifyListeners();
      return;
    }
    final prev = _items[normalized];
    if (prev != null && prev.version >= item.version && item.version > 0) {
      return;
    }
    _items[normalized] = item;
    notifyListeners();
  }

  void applyLocalSession(GroupLiveSession session, {int version = 0}) {
    final normalized = _normalizeGroupId(session.groupId);
    if (normalized.isEmpty) {
      return;
    }
    if (!session.status.isActiveSlot) {
      if (_items.remove(normalized) != null) {
        notifyListeners();
      }
      return;
    }
    final resolvedVersion = version > 0
        ? version
        : (_items[normalized]?.version ?? 0) + 1;
    final prev = _items[normalized];
    if (prev != null &&
        resolvedVersion > 0 &&
        prev.version >= resolvedVersion) {
      return;
    }
    _items[normalized] = GroupLiveIndexItem(
      groupId: normalized,
      liveSessionId: session.liveSessionId,
      status: session.status,
      version: resolvedVersion,
      roomName: session.roomName,
      anchorUserId: session.anchorUserId,
      scheduledStartAt: session.scheduledStartAt,
      startedAt: session.startedAt,
    );
    notifyListeners();
  }

  void clear() {
    if (_items.isEmpty && _revision == 0 && (_etag?.isEmpty ?? true)) {
      return;
    }
    _items.clear();
    _revision = 0;
    _etag = null;
    notifyListeners();
  }

  void _replaceAll(
    Map<String, GroupLiveIndexItem> next, {
    required int revision,
    String? etag,
  }) {
    final etagText = etag?.trim() ?? '';
    final changed = revision != _revision ||
        etagText != (_etag ?? '') ||
        !_sameItems(_items, next);
    _items
      ..clear()
      ..addAll(next);
    _revision = revision;
    _etag = etagText.isEmpty ? _etag : etagText;
    if (changed) {
      notifyListeners();
    }
  }

  bool _sameItems(
    Map<String, GroupLiveIndexItem> a,
    Map<String, GroupLiveIndexItem> b,
  ) {
    if (a.length != b.length) {
      return false;
    }
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null) {
        return false;
      }
      final left = entry.value;
      if (left.liveSessionId != other.liveSessionId ||
          left.status != other.status ||
          left.version != other.version) {
        return false;
      }
    }
    return true;
  }

  String _normalizeGroupId(String? groupId) {
    return ChatIdFormat.normalizeGroupId(groupId);
  }
}

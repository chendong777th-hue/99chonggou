import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/src/services/session_identity.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';

/// 群系统通知（管理员变更等）按账号持久化，重启或其它端登录同一账号后可恢复展示。
class GroupSystemNoticeHistoryService {
  GroupSystemNoticeHistoryService._();

  static final GroupSystemNoticeHistoryService instance =
      GroupSystemNoticeHistoryService._();

  static const String _storagePrefix = 'groupSystemNoticeHistory_v1_';
  static const int _maxItems = 200;

  Timer? _persistDebounce;
  TUIChatGlobalModel? _attachedModel;
  VoidCallback? _modelListener;
  SessionIdentity? _attachedIdentity;

  String _storageKeyForOwner(String userId) {
    final owner = ChatIdFormat.rawUserUid(userId);
    if (owner.isEmpty) {
      return '${_storagePrefix}anonymous';
    }
    return '$_storagePrefix$owner';
  }

  Future<void> hydrate(TUIChatGlobalModel model) async {
    final identity = SessionIdentityService.instance.capture();
    if (identity.ownerUserId.isEmpty) return;
    final saved = await _load(identity);
    if (!SessionIdentityService.instance.isCurrent(identity)) return;
    if (saved.isEmpty) {
      return;
    }
    final existingIds = model.groupSystemNoticeList.map((e) => e.id).toSet();
    for (final item in saved) {
      if (existingIds.contains(item.id)) {
        continue;
      }
      model.addGroupSystemNotice(item);
    }
  }

  void attachPersistence(TUIChatGlobalModel model) {
    if (identical(_attachedModel, model)) {
      return;
    }
    detachPersistence();
    _attachedModel = model;
    final identity = SessionIdentityService.instance.capture();
    if (identity.ownerUserId.isEmpty) return;
    _attachedIdentity = identity;
    _modelListener = () {
      _persistDebounce?.cancel();
      _persistDebounce = Timer(const Duration(milliseconds: 250), () {
        if (_attachedIdentity != identity ||
            !SessionIdentityService.instance.isCurrent(identity)) {
          return;
        }
        unawaited(_save(model.groupSystemNoticeList, identity));
      });
    };
    model.addListener(_modelListener!);
  }

  void detachPersistence() {
    _persistDebounce?.cancel();
    _persistDebounce = null;
    if (_attachedModel != null && _modelListener != null) {
      _attachedModel!.removeListener(_modelListener!);
    }
    _attachedModel = null;
    _modelListener = null;
    _attachedIdentity = null;
  }

  Future<void> clearForOwner(String? ownerUserId) async {
    final owner = ChatIdFormat.rawUserUid(ownerUserId);
    detachPersistence();
    if (owner.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKeyForOwner(owner));
  }

  Future<List<GroupSystemNoticeItem>> _load(SessionIdentity identity) async {
    final prefs = await SharedPreferences.getInstance();
    if (!SessionIdentityService.instance.isCurrent(identity)) {
      return const [];
    }
    final raw = prefs.getString(_storageKeyForOwner(identity.ownerUserId));
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map((item) => _fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.groupID.isNotEmpty && item.id.isNotEmpty)
          .toList(growable: false);
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint(
          'GroupSystemNoticeHistoryService.load failed: $error\n$stack',
        );
      }
      return const [];
    }
  }

  Future<void> _save(
    List<GroupSystemNoticeItem> notices,
    SessionIdentity identity,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (!SessionIdentityService.instance.isCurrent(identity)) return;
    final payload =
        notices.take(_maxItems).map(_toJson).toList(growable: false);
    await prefs.setString(
      _storageKeyForOwner(identity.ownerUserId),
      jsonEncode(payload),
    );
  }

  Map<String, dynamic> _toJson(GroupSystemNoticeItem notice) {
    return <String, dynamic>{
      'id': notice.id,
      'groupID': notice.groupID,
      'groupName': notice.groupName,
      'groupFaceUrl': notice.groupFaceUrl,
      'type': notice.type.name,
      'operatorUserID': notice.operatorUserID,
      'operatorName': notice.operatorName,
      'targetUserID': notice.targetUserID,
      'targetName': notice.targetName,
      'timestamp': notice.timestamp,
    };
  }

  GroupSystemNoticeItem _fromJson(Map<String, dynamic> json) {
    final typeName = json['type']?.toString() ?? '';
    final type = GroupSystemNoticeType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => GroupSystemNoticeType.grantAdministrator,
    );
    return GroupSystemNoticeItem(
      id: json['id']?.toString() ?? '',
      groupID: json['groupID']?.toString() ?? '',
      groupName: json['groupName']?.toString() ?? '',
      groupFaceUrl: json['groupFaceUrl']?.toString() ?? '',
      type: type,
      operatorUserID: json['operatorUserID']?.toString() ?? '',
      operatorName: json['operatorName']?.toString() ?? '',
      targetUserID: json['targetUserID']?.toString() ?? '',
      targetName: json['targetName']?.toString() ?? '',
      timestamp: json['timestamp'] is int
          ? json['timestamp'] as int
          : int.tryParse(json['timestamp']?.toString() ?? '') ?? 0,
    );
  }
}

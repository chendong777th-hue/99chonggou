import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/core_services_implements.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

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

  String _storageKey() {
    final userId = ChatIdFormat.rawUserUid(
      serviceLocator<CoreServicesImpl>().loginUserInfo?.userID ?? '',
    );
    if (userId.isEmpty) {
      return '${_storagePrefix}anonymous';
    }
    return '$_storagePrefix$userId';
  }

  Future<void> hydrate(TUIChatGlobalModel model) async {
    final saved = await _load();
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
    _modelListener = () {
      _persistDebounce?.cancel();
      _persistDebounce = Timer(const Duration(milliseconds: 250), () {
        unawaited(_save(model.groupSystemNoticeList));
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
  }

  Future<List<GroupSystemNoticeItem>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey());
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

  Future<void> _save(List<GroupSystemNoticeItem> notices) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = notices.take(_maxItems).map(_toJson).toList(growable: false);
    await prefs.setString(_storageKey(), jsonEncode(payload));
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

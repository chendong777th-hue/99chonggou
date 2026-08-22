import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/api/friend_request_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/friend_request_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_local/friend_sync_service.dart';
import 'package:tencent_cloud_chat_sdk/enum/friend_application_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_application.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_application.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/friend_became_friends_message.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_request_notice_service.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

const String friendApplicationHistoryKey = 'friendApplicationHandledHistory';
const String friendRequestDismissedKeysPref = 'friendRequestDismissedKeys';

class FriendApplicationHelper {
  static TUIFriendShipViewModel get _friendshipViewModel =>
      serviceLocator<TUIFriendShipViewModel>();

  static const int _maxAttempts = 3;
  static final Set<String> _handlingApplicationKeys = <String>{};

  static bool _beginHandle(String userID, String action) {
    final key = '$action:$userID';
    if (!_handlingApplicationKeys.add(key)) {
      return false;
    }
    return true;
  }

  static void _endHandle(String userID, String action) {
    _handlingApplicationKeys.remove('$action:$userID');
  }

  static Future<List<FriendRequestRecord>> loadHandledHistory() async {
    try {
      final remote = await FriendRequestApi.instance.fetchHandledHistory();
      final sorted = _sortRecords(remote);
      await _saveHandledHistoryLocal(sorted);
      return _filterDismissed(sorted);
    } catch (_) {}

    return _filterDismissed(await _loadHandledHistoryLocal());
  }

  static Future<Set<String>> _loadDismissedKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(friendRequestDismissedKeysPref)?.toSet() ??
        <String>{};
  }

  static Future<void> _markDismissed(FriendRequestRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = await _loadDismissedKeys();
    keys.add(record.identityKey);
    if (record.hasServerId) {
      keys.add('id_${record.id}');
    }
    await prefs.setStringList(friendRequestDismissedKeysPref, keys.toList());
  }

  static bool _isDismissed(FriendRequestRecord record, Set<String> dismissed) {
    if (dismissed.contains(record.identityKey)) {
      return true;
    }
    if (record.hasServerId && dismissed.contains('id_${record.id}')) {
      return true;
    }
    return false;
  }

  static Future<List<FriendRequestRecord>> _filterDismissed(
    List<FriendRequestRecord> records,
  ) async {
    if (records.isEmpty) {
      return records;
    }
    final dismissed = await _loadDismissedKeys();
    if (dismissed.isEmpty) {
      return records;
    }
    return records
        .where((record) => !_isDismissed(record, dismissed))
        .toList(growable: false);
  }

  static Future<List<FriendRequestRecord>> loadIncomingPending() async {
    try {
      final records = await FriendRequestApi.instance.fetchIncomingPending();
      records.sort((a, b) => b.displayTimestamp.compareTo(a.displayTimestamp));
      return _filterDismissed(records);
    } catch (_) {
      return const <FriendRequestRecord>[];
    }
  }

  static Future<List<FriendRequestRecord>> loadSentRequests() async {
    try {
      final records = await FriendRequestApi.instance.fetchSent();
      records.sort((a, b) => b.displayTimestamp.compareTo(a.displayTimestamp));
      return _filterDismissed(records);
    } catch (_) {
      return const <FriendRequestRecord>[];
    }
  }

  static Future<List<FriendRequestRecord>> loadOutgoingPending() async {
    try {
      final records = await FriendRequestApi.instance.fetchOutgoingPending();
      records.sort((a, b) => b.displayTimestamp.compareTo(a.displayTimestamp));
      return records;
    } catch (_) {
      return const <FriendRequestRecord>[];
    }
  }

  static Future<List<FriendRequestRecord>> _loadHandledHistoryLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(friendApplicationHistoryKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return _sortRecords(
        decoded
            .map((item) =>
                FriendRequestRecord.fromJson(item as Map<String, dynamic>))
            .where((item) => item.userID.isNotEmpty)
            .toList(),
      );
    } catch (_) {
      return [];
    }
  }

  static List<FriendRequestRecord> _sortRecords(
      List<FriendRequestRecord> records) {
    final next = List<FriendRequestRecord>.from(records);
    next.sort((a, b) => b.displayTimestamp.compareTo(a.displayTimestamp));
    return next;
  }

  static List<FriendRequestRecord> _dedupeLatestByPeer(
    List<FriendRequestRecord> records,
  ) {
    final sorted = _sortRecords(records);
    final seen = <String>{};
    final result = <FriendRequestRecord>[];
    for (final item in sorted) {
      final userId = item.userID.trim();
      if (userId.isEmpty || !seen.add(userId)) {
        continue;
      }
      result.add(item);
    }
    return result;
  }

  static Future<void> _saveHandledHistoryLocal(
    List<FriendRequestRecord> records,
  ) async {
    final normalized = _dedupeLatestByPeer(records);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      friendApplicationHistoryKey,
      jsonEncode(normalized.map((e) => e.toLocalJson()).toList()),
    );
  }

  static Future<void> _appendHistoryRecord(FriendRequestRecord record) async {
    final history = await _loadHandledHistoryLocal();
    history.removeWhere((item) => item.userID == record.userID);
    history.insert(0, record);
    final sorted = _dedupeLatestByPeer(history);
    await _saveHandledHistoryLocal(sorted);
  }

  /// 自动通过 / 恢复好友：写入「新的朋友」已处理历史（本地）。
  static Future<void> recordBecameFriendsHistory({
    required String userID,
    String nickname = '',
    String faceUrl = '',
    String addSource = 'auto',
    String direction = FriendRequestDirection.unknown,
  }) async {
    final peer = userID.trim();
    if (peer.isEmpty) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final nick = nickname.trim();
    try {
      await _appendHistoryRecord(
        FriendRequestRecord(
          userID: peer,
          nickname: nick.isNotEmpty ? nick : peer,
          faceUrl: faceUrl.trim(),
          addWording: '',
          addSource: addSource.trim().isEmpty ? 'auto' : addSource.trim(),
          addTime: now,
          status: 'accepted',
          handledAt: now,
          direction: direction,
        ),
      );
    } catch (e) {
      debugPrint('FriendApplicationHelper recordBecameFriendsHistory failed: $e');
    }
  }

  static Future<void> _refreshApplicationsOnly() async {
    await Future.delayed(const Duration(milliseconds: 280));
    await _friendshipViewModel.loadContactApplicationData();
    await FriendRequestNoticeService.instance.refreshPendingCount();
  }

  static Future<void> _refreshFriendListAfterAccept({
    required String peerUserId,
    String? nickname,
    String? faceUrl,
  }) async {
    await FriendSyncService.instance.onBecameFriends(
      peerUserId: peerUserId,
      nickname: nickname,
      avatarUrl: faceUrl,
      reason: 'friend_accept',
    );
  }

  /// Friend list / conversation rebuild should finish before the caller pops.
  /// Tip sending and application refresh can continue in the background.
  static Future<void> _runPostAcceptSideEffects({
    required String peerUserId,
    String? nickname,
    String? faceUrl,
  }) async {
    try {
      await _refreshFriendListAfterAccept(
        peerUserId: peerUserId,
        nickname: nickname,
        faceUrl: faceUrl,
      );
      unawaited(
        FriendBecameFriendsNotifier.notifyIfBecameFriends(
          peerUserId: peerUserId,
        ),
      );
      unawaited(_refreshApplicationsOnly());
    } catch (e) {
      debugPrint('FriendApplicationHelper post-accept side effects failed: $e');
    }
  }

  static void _scheduleApplicationsRefreshOnly() {
    unawaited(() async {
      try {
        await _refreshApplicationsOnly();
      } catch (e) {
        debugPrint(
          'FriendApplicationHelper applications refresh failed: $e',
        );
      }
    }());
  }

  static void _toastBusy() {
    ToastUtils.toast(AppI18n.current.t(
      zhHans: '处理中，请稍候',
      zhHant: '處理中，請稍候',
      en: 'Processing, please wait',
      ja: '処理中です。しばらくお待ちください',
      ko: '처리 중입니다. 잠시만 기다려 주세요',
    ));
  }

  static void _toastAccepted() {
    ToastUtils.toast(AppI18n.current.t(
      zhHans: '已同意好友申请',
      zhHant: '已同意好友申請',
      en: 'Friend request accepted',
      ja: '友達申請を承認しました',
      ko: '친구 요청을 수락했습니다',
    ));
  }

  static void _toastRejected() {
    ToastUtils.toast(AppI18n.current.t(
      zhHans: '已拒绝好友申请',
      zhHant: '已拒絕好友申請',
      en: 'Friend request declined',
      ja: '友達申請を拒否しました',
      ko: '친구 요청을 거절했습니다',
    ));
  }

  static FriendApplicationTypeEnum _resolveApplicationType(
    V2TimFriendApplication application,
  ) {
    final typeIndex = application.type;
    if (typeIndex >= 0 && typeIndex < FriendApplicationTypeEnum.values.length) {
      return FriendApplicationTypeEnum.values[typeIndex];
    }
    return FriendApplicationTypeEnum.V2TIM_FRIEND_APPLICATION_COME_IN;
  }

  static Future<bool> deletePendingApplications(
    List<V2TimFriendApplication> applications,
  ) async {
    if (applications.isEmpty) {
      return true;
    }
    final sdk = TIMUIKitCore.getSDKInstance();
    var allOk = true;
    for (final application in applications) {
      final userID = application.userID.trim();
      if (userID.isEmpty) {
        continue;
      }
      final res = await sdk.getFriendshipManager().deleteFriendApplication(
            type: _resolveApplicationType(application),
            userID: userID,
          );
      if (res.code != 0) {
        allOk = false;
      }
    }
    await _refreshApplicationsOnly();
    return allOk;
  }

  static Future<void> deleteHandledRecords(
    List<FriendRequestRecord> records,
  ) async {
    if (records.isEmpty) {
      return;
    }
    await _removeFromLocalHistoryCache(records);
    for (final record in records) {
      if (!record.hasServerId) {
        continue;
      }
      try {
        await FriendRequestApi.instance.deleteHistory(record);
      } catch (_) {}
    }
  }

  static Future<void> _removeFromLocalHistoryCache(
    List<FriendRequestRecord> records,
  ) async {
    if (records.isEmpty) {
      return;
    }
    final history = await _loadHandledHistoryLocal();
    final identityKeys = records.map((item) => item.identityKey).toSet();
    history.removeWhere((item) => identityKeys.contains(item.identityKey));
    await _saveHandledHistoryLocal(history);
  }

  static Future<void> _deleteIncomingRequestIds(List<int> ids) async {
    if (ids.isEmpty) {
      return;
    }
    final api = FriendRequestApi.instance;
    if (ids.length == 1) {
      await api.deleteIncomingById(ids.first);
      return;
    }
    await api.deleteIncomingBatch(ids);
  }

  static Future<void> _deleteSentRequestIds(List<int> ids) async {
    if (ids.isEmpty) {
      return;
    }
    final api = FriendRequestApi.instance;
    if (ids.length == 1) {
      await api.deleteSentById(ids.first);
      return;
    }
    await api.deleteSentBatch(ids);
  }

  /// 删除「新的朋友」列表中的记录（左滑/批量删除）。
  ///
  /// 对接文档：
  /// - 对方添加我 pending → DELETE /friend-requests/incoming/{id}
  /// - 我添加对方 → DELETE /friend-requests/sent/{id}
  /// - 旧历史已处理 → DELETE /friend-application/history/{id}
  static Future<void> deleteListRecords(
    List<FriendRequestRecord> records,
  ) async {
    if (records.isEmpty) {
      return;
    }

    final incomingRequestIds = <int>[];
    final sentRequestIds = <int>[];
    final historyRecords = <FriendRequestRecord>[];
    final noServerIdRecords = <FriendRequestRecord>[];

    for (final record in records) {
      if (!record.hasServerId) {
        noServerIdRecords.add(record);
        continue;
      }
      if (record.isOutgoing) {
        sentRequestIds.add(record.id!);
      } else if (record.isPending) {
        incomingRequestIds.add(record.id!);
      } else {
        historyRecords.add(record);
      }
    }

    if (incomingRequestIds.isNotEmpty) {
      await _deleteIncomingRequestIds(incomingRequestIds);
    }
    if (sentRequestIds.isNotEmpty) {
      await _deleteSentRequestIds(sentRequestIds);
    }
    for (final record in historyRecords) {
      if (!record.hasServerId) {
        continue;
      }
      await FriendRequestApi.instance.deleteHistory(record);
    }
    await _removeFromLocalHistoryCache(records);

    for (final record in noServerIdRecords) {
      await _markDismissed(record);
    }

    await _refreshApplicationsOnly();
  }

  static Future<bool> _runWithRetry(
    Future<dynamic> Function() action,
  ) async {
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(milliseconds: 400 * attempt));
      }
      final result = await action();
      if (result != null && result.resultCode == 0) {
        return true;
      }
    }
    return false;
  }

  static void _toastFailure() {
    ToastUtils.toast(AppI18n.current.t(
      zhHans: '处理失败，请刷新后重试',
      zhHant: '處理失敗，請刷新後重試',
      en: 'Failed to process. Refresh and try again.',
      ja: '処理に失敗しました。更新してから再試行してください。',
      ko: '처리에 실패했습니다. 새로고침 후 다시 시도해 주세요.',
    ));
  }

  static Future<bool> acceptRecord(FriendRequestRecord record) async {
    if (!record.hasServerId || !_beginHandle(record.identityKey, 'accept')) {
      if (!record.hasServerId) {
        ToastUtils.toast(AppI18n.current.t(
          zhHans: '申请记录缺少 ID，请刷新后重试',
          zhHant: '申請記錄缺少 ID，請刷新後重試',
          en: 'Request ID is missing. Refresh and try again.',
          ja: 'Request ID is missing. Refresh and try again.',
          ko: 'Request ID is missing. Refresh and try again.',
        ));
      } else {
        _toastBusy();
      }
      return false;
    }
    try {
      await FriendRequestApi.instance.acceptById(record.id!);
      final handled = record.copyWith(
        status: 'accepted',
        handledAt: DateTime.now().millisecondsSinceEpoch,
      );
      try {
        await _appendHistoryRecord(handled);
      } catch (e) {
        debugPrint('FriendApplicationHelper acceptRecord history failed: $e');
      }
      _toastAccepted();
      await _runPostAcceptSideEffects(
        peerUserId: record.userID,
        nickname: record.nickname,
        faceUrl: record.faceUrl,
      );
      return true;
    } catch (_) {
      _toastFailure();
      return false;
    } finally {
      _endHandle(record.identityKey, 'accept');
    }
  }

  static Future<bool> rejectRecord(FriendRequestRecord record) async {
    if (!record.hasServerId || !_beginHandle(record.identityKey, 'reject')) {
      if (!record.hasServerId) {
        ToastUtils.toast(AppI18n.current.t(
          zhHans: '申请记录缺少 ID，请刷新后重试',
          zhHant: '申請記錄缺少 ID，請刷新後重試',
          en: 'Request ID is missing. Refresh and try again.',
          ja: 'Request ID is missing. Refresh and try again.',
          ko: 'Request ID is missing. Refresh and try again.',
        ));
      } else {
        _toastBusy();
      }
      return false;
    }
    try {
      await FriendRequestApi.instance.rejectById(record.id!);
      final handled = record.copyWith(
        status: 'rejected',
        handledAt: DateTime.now().millisecondsSinceEpoch,
      );
      try {
        await _appendHistoryRecord(handled);
      } catch (e) {
        debugPrint('FriendApplicationHelper rejectRecord history failed: $e');
      }
      _toastRejected();
      _scheduleApplicationsRefreshOnly();
      return true;
    } catch (_) {
      _toastFailure();
      return false;
    } finally {
      _endHandle(record.identityKey, 'reject');
    }
  }

  static Future<bool> accept(V2TimFriendApplication application) async {
    if (!_beginHandle(application.userID, 'accept')) {
      _toastBusy();
      return false;
    }
    try {
      final ok = await _runWithRetry(
        () => _friendshipViewModel.acceptFriendApplication(
          application.userID,
          application.type,
        ),
      );
      if (!ok) {
        _toastFailure();
        return false;
      }
      final record = FriendRequestRecord.fromApplication(
        application,
        status: 'accepted',
      );
      try {
        await FriendRequestApi.instance.accept(record);
      } catch (_) {}
      try {
        await _appendHistoryRecord(record);
      } catch (e) {
        debugPrint('FriendApplicationHelper accept history failed: $e');
      }
      _toastAccepted();
      await _runPostAcceptSideEffects(
        peerUserId: application.userID,
        nickname: application.nickname,
        faceUrl: application.faceUrl,
      );
      return true;
    } catch (_) {
      _toastFailure();
      return false;
    } finally {
      _endHandle(application.userID, 'accept');
    }
  }

  static Future<bool> reject(V2TimFriendApplication application) async {
    if (!_beginHandle(application.userID, 'reject')) {
      _toastBusy();
      return false;
    }
    try {
      final ok = await _runWithRetry(
        () => _friendshipViewModel.refuseFriendApplication(
          application.userID,
          application.type,
        ),
      );
      if (!ok) {
        _toastFailure();
        return false;
      }
      final record = FriendRequestRecord.fromApplication(
        application,
        status: 'rejected',
      );
      try {
        await FriendRequestApi.instance.reject(record);
      } catch (_) {}
      try {
        await _appendHistoryRecord(record);
      } catch (e) {
        debugPrint('FriendApplicationHelper reject history failed: $e');
      }
      _toastRejected();
      _scheduleApplicationsRefreshOnly();
      return true;
    } catch (_) {
      _toastFailure();
      return false;
    } finally {
      _endHandle(application.userID, 'reject');
    }
  }
}

// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'dart:js_util';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimConversationListener.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_sdk/web/enum/event_enum.dart';
import 'package:tencent_cloud_chat_sdk/web/manager/im_sdk_plugin_js.dart';
import 'package:tencent_cloud_chat_sdk/web/models/v2_tim_delete_conversation.dart';
import 'package:tencent_cloud_chat_sdk/web/models/v2_tim_get_conversation_list.dart';
import 'package:tencent_cloud_chat_sdk/web/models/v2_tim_pin_conversation.dart';
import 'package:tencent_cloud_chat_sdk/web/utils/utils.dart';

class V2TIMConversationManager {
  static final Map<String, V2TimConversationListener> _conversationListener =
      {};
  static bool _jsListenerBound = false;

  V2TIMConversationManager();

  /// Prefer live [V2TIMManagerWeb.timWeb]. Keep as dynamic — casting to
  /// [TencentCloudChat]? has caused false nulls under DDC/JS interop.
  static dynamic get _tim => V2TIMManagerWeb.timWeb;

  static Future<dynamic> _waitForTim({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final existing = _tim;
    if (existing != null) {
      return existing;
    }
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final tim = _tim;
      if (tim != null) {
        return tim;
      }
    }
    return _tim;
  }

  /// Bind JS conversation listener once TIM instance exists.
  /// Safe to call before initSDK (no-op) and again after SDK_READY.
  ///
  /// [force]：先 off 再 on。Web 热重载 / 长连接抖动后，旧 allowInterop 可能已失效，
  /// 但 `_jsListenerBound` 仍为 true，会导致会话预览与消息同时停更。
  static void ensureJsListenerBound({bool force = false}) {
    final tim = _tim;
    if (tim == null) {
      _jsListenerBound = false;
      return;
    }
    if (_conversationListener.isEmpty) {
      return;
    }
    if (_jsListenerBound && !force) {
      return;
    }
    try {
      if (_jsListenerBound || force) {
        try {
          tim.off(EventType.CONVERSATION_LIST_UPDATED, _conversationListenerWeb);
        } catch (_) {}
      }
      tim.on(EventType.CONVERSATION_LIST_UPDATED, _conversationListenerWeb);
      _jsListenerBound = true;
      debugPrint(
        'V2TIMConversationManager: JS conversation listener bound force=$force',
      );
    } catch (e) {
      _jsListenerBound = false;
      debugPrint('V2TIMConversationManager: bind listener failed: $e');
    }
  }

  static void resetJsListenerBound() {
    _jsListenerBound = false;
  }

  static void resetJsListenerBoundForTest() {
    resetJsListenerBound();
  }

  static final _conversationListenerWeb = allowInterop((res) async {
    List<dynamic> conversationList =
        await GetConversationList.formateConversationList(jsToMap(res)['data']);
    final convList =
        conversationList.map((e) => V2TimConversation.fromJson(e)).toList();
    for (var listener in _conversationListener.values) {
      listener.onConversationChanged(convList);
    }
  });

/*
  注意：web只有一个update回调(新增也在里面)，这个回调不做初始化磨平操作，native有新的会话
  即会在初始化时调用这个监听
*/
  Future<V2TimValueCallback<List<V2TimConversationOperationResult>>>
      deleteConversationList({
    required List<String> conversationIDList,
    required bool clearMessage,
  }) async {
    print("deleteConversationList $conversationIDList");
    final tim = await _waitForTim();
    if (tim == null) {
      return CommonUtils.returnErrorForValueCb<
          List<V2TimConversationOperationResult>>('TIM web instance is null');
    }
    await wrappedPromiseToFuture(
      tim.deleteConversation(
        mapToJSObj({
          "conversationIDList": conversationIDList,
          "clearHistoryMessage": clearMessage,
        }),
      ),
    );
    return V2TimValueCallback<List<V2TimConversationOperationResult>>.fromJson({
      "code": 0,
      "data": [],
    });
  }

  void setConversationListener(
      V2TimConversationListener listener, String? listenerUuid) async {
    final uuid = listenerUuid;
    if (uuid == null || uuid.isEmpty) {
      return;
    }
    _conversationListener[uuid] = listener;
    // main.dart installs listeners before initSDK — never bang-null here.
    ensureJsListenerBound();
  }

  void makeConversationListenerEventData(_channel, String type, data) {
    CommonUtils.emitEvent(_channel, "conversationListener", type, data);
  }

  // web 中参数无法传递分页信息
  Future<V2TimValueCallback<V2TimConversationResult>>
      getConversationList() async {
    try {
      final tim = await _waitForTim();
      debugPrint(
        'V2TIMConversationManager.getConversationList: '
        'timNull=${tim == null} rawNull=${V2TIMManagerWeb.timWeb == null}',
      );
      if (tim == null) {
        return CommonUtils.returnErrorForValueCb<V2TimConversationResult>(
          'TIM web instance is null',
        );
      }
      ensureJsListenerBound();
      final res = await wrappedPromiseToFuture(tim.getConversationList());
      debugPrint("orginal list: $res");
      log(res);
      final rawList = jsToMap(res.data)['conversationList'];
      final asList = rawList is List
          ? rawList
          : (rawList == null
              ? const <dynamic>[]
              : List<dynamic>.from(rawList as Iterable));
      final conversationList =
          await GetConversationList.formateConversationList(asList);
      debugPrint(
        'V2TIMConversationManager.getConversationList: '
        'formattedCount=${conversationList.length}',
      );
      return CommonUtils.returnSuccess<V2TimConversationResult>(
          GetConversationList.formatReturn(conversationList));
    } catch (error, stack) {
      debugPrint(
        'V2TIMConversationManager.getConversationList failed: $error\n$stack',
      );
      return CommonUtils.returnErrorForValueCb<V2TimConversationResult>(
          error.toString());
    }
  }

  // 和getConversationList 调用的是相同的方法, 此项接口返回的数据没有getConversationProfile全
  Future<dynamic> getConversationListByConversationIds(param) async {
    try {
      final tim = await _waitForTim();
      if (tim == null) {
        return CommonUtils.returnErrorForValueCb<List<V2TimConversation>>(
            'TIM web instance is null');
      }
      var res = await wrappedPromiseToFuture(
          tim.getConversationList(param["conversationIDList"]));
      var conversationList = await GetConversationList.formateConversationList(
          jsToMap(res.data)['conversationList']);
      return CommonUtils.returnSuccess<List<V2TimConversation>>(
          conversationList);
    } catch (err) {
      return CommonUtils.returnErrorForValueCb<List<V2TimConversation>>(err);
    }
  }

  // web中的方法名字是： getConversationProfile
  Future<V2TimValueCallback<V2TimConversation>> getConversation({
    required String conversationID,
  }) async {
    try {
      final tim = await _waitForTim();
      if (tim == null) {
        return CommonUtils.returnErrorForValueCb<V2TimConversation>(
            'TIM web instance is null');
      }
      var res =
          await wrappedPromiseToFuture(tim.getConversationProfile(conversationID));

      return CommonUtils.returnSuccess<V2TimConversation>(
          await GetConversationList.formateConversationListItem(
              jsToMap(jsToMap(res.data)['conversation'])));
    } catch (err) {
      return CommonUtils.returnErrorForValueCb<V2TimConversation>(err);
    }
  }

  Future<dynamic> deleteConversation(conversationParams) async {
    try {
      final tim = await _waitForTim();
      if (tim == null) {
        return CommonUtils.returnError('TIM web instance is null');
      }
      await promiseToFuture(tim.deleteConversation(
          DeleteConversation.formateParams(conversationParams)));

      return CommonUtils.returnSuccessWithDesc('ok');
    } catch (err) {
      return CommonUtils.returnError(err.toString());
    }
  }

  Future<dynamic> pinConversation(params) async {
    try {
      final tim = await _waitForTim();
      if (tim == null) {
        return CommonUtils.returnError('TIM web instance is null');
      }
      final formatedParams = PinConversation.formateParams(params);
      final res = await promiseToFuture(tim.pinConversation(formatedParams));
      return CommonUtils.returnSuccessForCb(jsToMap(res)['conversationID']);
    } catch (err) {
      return CommonUtils.returnError(err);
    }
  }

  // web不存在添加草稿功能
  Future<dynamic> setConversationDraft() async {
    debugPrint("web不支持添加草稿功能");
    return CommonUtils.returnError(
        "setConversationDraft feature does not exist on the web");
  }

  // web不存在获得未读消息总数此功能
  Future<dynamic> getTotalUnreadMessageCount() async {
    debugPrint("web不支持获得未读消息总数此功能");
    return CommonUtils.returnErrorForValueCb<int>(
        "getTotalUnreadMessageCount feature does not exist on the web");
  }

  Future<void> removeConversationListener({
    String? listenerUuid,
    required bool hasListener,
  }) async {
    if (listenerUuid != null && listenerUuid.isNotEmpty) {
      _conversationListener.remove(listenerUuid);
      if (_conversationListener.isNotEmpty) {
        return;
      }
    }
    if (!hasListener) {
      _conversationListener.clear();
    }
    if (_conversationListener.isEmpty && _jsListenerBound) {
      final tim = _tim;
      if (tim != null) {
        try {
          tim.off(
              EventType.CONVERSATION_LIST_UPDATED, _conversationListenerWeb);
        } catch (_) {}
      }
      _jsListenerBound = false;
    }
  }
}

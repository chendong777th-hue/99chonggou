import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitTextField/tim_uikit_text_field_layout/narrow.dart';

enum ActionType {
  hideAllPanel,
  hideAccessoryPanel,
  longPressToAt,
  setTextField,
  requestFocus,
  handleAtMember,
}

class TIMUIKitInputTextFieldController extends ChangeNotifier {
  TextEditingController? textEditingController = TextEditingController();
  ActionType? actionType;
  String? atUserName;
  String? atUserID;
  String inputText = "";
  bool notifyOnSetTextField = true;
  V2TimGroupMemberFullInfo? groupMemberFullInfo;
  TIMUIKitTextFieldLayoutNarrowState? _narrowState;

  /// 表情 / 更多 / 键盘 / 语音输入等面板是否展开。
  bool isInputPanelOpen = false;

  /// 刚打开附属面板后短暂忽略「滑动收起」，避免列表惯性滚动误关面板。
  int _ignoreAccessoryDismissUntilMs = 0;
  bool _notifyScheduled = false;
  bool _disposed = false;

  TIMUIKitInputTextFieldController([TextEditingController? controller]) {
    if (controller != null) {
      textEditingController = controller;
    }
  }

  void attachNarrowState(TIMUIKitTextFieldLayoutNarrowState state) {
    _narrowState = state;
  }

  void detachNarrowState(TIMUIKitTextFieldLayoutNarrowState state) {
    if (identical(_narrowState, state)) {
      _narrowState = null;
    }
  }

  void _notifySafely() {
    if (_disposed) {
      return;
    }
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
      return;
    }
    if (_notifyScheduled) {
      return;
    }
    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (!_disposed) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _narrowState = null;
    super.dispose();
  }

  void updateInputPanelOpen(bool open) {
    if (isInputPanelOpen == open) {
      return;
    }
    isInputPanelOpen = open;
    _notifySafely();
  }

  /// text field unfocused and hide all panel
  hideAllPanel() {
    actionType = ActionType.hideAllPanel;
    _notifySafely();
  }

  /// 仅关闭表情 / 更多 / 语音面板，保留输入框焦点与系统键盘。
  void hideAccessoryPanels() {
    if (!isInputPanelOpen) {
      return;
    }
    _ignoreAccessoryDismissUntilMs = 0;
    actionType = ActionType.hideAccessoryPanel;
    _notifySafely();
  }

  /// 右滑取消返回等场景：按系统 viewInsets 重新对齐输入栏。
  void syncLayoutFromViewInsets() {
    _narrowState?.syncLayoutFromViewInsets();
  }

  void markAccessoryPanelOpening() {
    _ignoreAccessoryDismissUntilMs =
        DateTime.now().millisecondsSinceEpoch + 400;
  }

  bool shouldIgnoreAccessoryDismiss() {
    return DateTime.now().millisecondsSinceEpoch <
        _ignoreAccessoryDismissUntilMs;
  }

  int _suppressKeyboardGeometrySyncUntilMs = 0;

  void _extendKeyboardGeometrySyncSuppression(int durationMs) {
    final until = DateTime.now().millisecondsSinceEpoch + durationMs;
    if (until > _suppressKeyboardGeometrySyncUntilMs) {
      _suppressKeyboardGeometrySyncUntilMs = until;
    }
  }

  /// 发送消息后短暂抑制键盘几何同步，避免与滚底动画抢帧导致键盘抖动。
  void markOutgoingMessageSend() {
    _extendKeyboardGeometrySyncSuppression(350);
  }

  /// 键盘发送开始时提前抑制几何同步，覆盖失焦收键盘的短暂回落。
  void markKeyboardSendRetain() {
    _extendKeyboardGeometrySyncSuppression(400);
  }

  bool shouldSuppressKeyboardGeometrySync() {
    return DateTime.now().millisecondsSinceEpoch <
        _suppressKeyboardGeometrySyncUntilMs;
  }

  longPressToAt(String? userName, String? userID) {
    actionType = ActionType.longPressToAt;
    atUserName = userName;
    atUserID = userID;
    _notifySafely();
  }

  setTextField(String text, {bool notifyChanged = true}) {
    inputText = text;
    notifyOnSetTextField = notifyChanged;
    actionType = ActionType.setTextField;
    _notifySafely();
  }

  requestFocus() {
    actionType = ActionType.requestFocus;
    _notifySafely();
  }

  handleAtMember(V2TimGroupMemberFullInfo? memberInfo) {
    actionType = ActionType.handleAtMember;
    groupMemberFullInfo = memberInfo;
    _notifySafely();
  }
}

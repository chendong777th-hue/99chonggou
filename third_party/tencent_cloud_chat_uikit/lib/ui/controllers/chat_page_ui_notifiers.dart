import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';

/// Page-scoped UI signals for the *currently open* chat list.
///
/// [historyPosition] / [userScrolling] are the SSOT while the list is mounted;
/// [TUIChatGlobalModel] mirrors them via [attachOpenChatPageUi] so inbound
/// message logic can keep reading the familiar global getters.
///
/// Input-panel open state is **not** here: [InputPanelController] owns the
/// four panel flags; [TIMUIKitInputTextFieldController.isInputPanelOpen] is
/// the derived bool used by list dismiss.
class ChatPageUiNotifiers {
  ChatPageUiNotifiers();

  /// Logical list position for the currently open conversation only.
  final ValueNotifier<HistoryMessagePosition> historyPosition =
      ValueNotifier<HistoryMessagePosition>(HistoryMessagePosition.bottom);

  /// User finger is actively dragging the open chat list.
  final ValueNotifier<bool> userScrolling = ValueNotifier<bool>(false);

  void dispose() {
    historyPosition.dispose();
    userScrolling.dispose();
  }
}

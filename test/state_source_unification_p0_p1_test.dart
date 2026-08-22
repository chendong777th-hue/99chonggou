import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/controllers/chat_page_ui_notifiers.dart';
import 'package:tencent_cloud_chat_uikit/ui/controllers/input_panel_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatPageUiNotifiers open-page scroll SSOT', () {
    setUpAll(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      setupServiceLocator();
    });

    test('attach mirrors userScrolling and historyPosition', () {
      final global = serviceLocator<TUIChatGlobalModel>();
      final page = ChatPageUiNotifiers();
      global.attachOpenChatPageUi(
        conversationId: 'c2c_u1',
        historyPosition: page.historyPosition,
        userScrolling: page.userScrolling,
      );

      global.setChatListUserScrolling(true);
      expect(page.userScrolling.value, isTrue);
      expect(global.isChatListUserScrolling, isTrue);

      global.setMessageListPosition(
        'c2c_u1',
        HistoryMessagePosition.inTwoScreen,
        notify: false,
      );
      expect(page.historyPosition.value, HistoryMessagePosition.inTwoScreen);
      expect(
        global.getMessageListPosition('c2c_u1'),
        HistoryMessagePosition.inTwoScreen,
      );

      global.detachOpenChatPageUi(
        historyPosition: page.historyPosition,
        userScrolling: page.userScrolling,
      );
      page.dispose();
      expect(global.isChatListUserScrolling, isFalse);
    });
  });

  group('InputPanelController SSOT', () {
    test('derived open reflects accessories and keyboard', () {
      final panel = InputPanelController()..showEmojiPanel = true;
      expect(panel.isAnyAccessoryOpen, isTrue);
      expect(panel.isAnyPanelOpen(hasFocus: false), isTrue);
      panel.hideAllPanels();
      expect(panel.isAnyPanelOpen(hasFocus: false), isFalse);
      expect(panel.isAnyPanelOpen(hasFocus: true), isTrue);
    });
  });

  group('ChatPageUiNotifiers shape', () {
    test('no longer exposes inputPanelOpen', () {
      final page = ChatPageUiNotifiers();
      expect(page.historyPosition, isA<ValueNotifier<HistoryMessagePosition>>());
      expect(page.userScrolling, isA<ValueNotifier<bool>>());
      page.dispose();
    });
  });
}

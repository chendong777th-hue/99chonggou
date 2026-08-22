import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/chat.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_chat_route.dart';
import 'package:tencent_cloud_chat_demo/src/platform/route_handler.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_history_peek_bootstrap.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';

void main() {
  test('chat open chain compiles in the app package context', () {
    Chat? chat;
    ChatHistoryPeekBootstrap? bootstrap;
    RouteHandler? routeHandler;
    TUIChatSeparateViewModel? viewModel;

    expect(chat, isNull);
    expect(bootstrap, isNull);
    expect(routeHandler, isNull);
    expect(viewModel, isNull);
    expect(appChatRoute, isNotNull);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_history_warm_scheduler.dart';
import 'package:tencent_cloud_chat_uikit/ui/constants/history_message_constant.dart';

void main() {
  test('open / warm window count is 20 (not legacy 40)', () {
    expect(HistoryMessageDartConstant.getCount, 20);
    expect(HistoryMessageDartConstant.initialOpenFetchCount, 20);
    expect(
      ConversationHistoryWarmScheduler.warmCount,
      HistoryMessageDartConstant.initialOpenFetchCount,
    );
  });
}

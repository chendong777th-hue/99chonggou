import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = File(
    'third_party/tencent_cloud_chat_uikit/lib/data_services/message/'
    'message_service_implement.dart',
  ).readAsStringSync();
  final viewModel = File(
    'third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/'
    'tui_chat_separate_view_model.dart',
  ).readAsStringSync();
  final webManager = File(
    'third_party/tencent_cloud_chat_sdk/lib/web/manager/'
    'v2_tim_message_manager.dart',
  ).readAsStringSync();
  final markReadStart = viewModel.indexOf('markMessageAsRead({');
  final markReadEnd = viewModel.indexOf(
    'Future<void> loadSelfMemberInfo',
    markReadStart < 0 ? 0 : markReadStart,
  );
  final markReadMethod = markReadStart >= 0 && markReadEnd > markReadStart
      ? viewModel.substring(markReadStart, markReadEnd)
      : viewModel;

  test('UIKit read APIs do not short-circuit Web as successful no-ops', () {
    expect(
      service,
      isNot(contains("mark read ignored on web")),
    );
    expect(
      service,
      isNot(contains("mark read no permission ignored on web")),
    );
    expect(
      markReadMethod,
      isNot(contains('PlatformUtils().isWeb')),
    );
    expect(markReadMethod, contains('markGroupMessageAsRead('));
  });

  test('Web receipt manager preserves non-zero SDK results', () {
    expect(webManager, contains('_readReceiptValueError'));
    expect(webManager, contains('_readReceiptError'));
    expect(
      webManager,
      isNot(contains(
        'return CommonUtils.returnSuccess<List<V2TimMessageReceipt>>([]);',
      )),
    );
    expect(
      webManager,
      isNot(contains('return CommonUtils.returnSuccessForCb([]);')),
    );
    expect(
      webManager,
      isNot(contains("return CommonUtils.returnError('设置已读失败');")),
    );
    expect(webManager, contains("'setMessageRead failed:"));
  });

  test('service normalizes receipt IDs before calling the SDK', () {
    expect(service, contains('.where((id) => id.isNotEmpty)'));
    expect(service, contains('.sendMessageReadReceipts(messageIDList: normalizedIDs)'));
    expect(service, contains('.getMessageReadReceipts(messageIDList: normalizedIDs)'));
  });
}

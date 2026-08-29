import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_delta.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_history_coverage.dart';

void main() {
  test('delta kinds and proof kinds keep transport separate from continuity', () {
    expect(MessageDeltaKind.values, contains(MessageDeltaKind.revoke));
    expect(MessageDeltaKind.values, contains(MessageDeltaKind.delete));
    expect(
      MessageHistoryProofKind.transportObserved.index,
      isNot(MessageHistoryProofKind.serverContinuity.index),
    );
  });

  test('production wiring exposes durable mutation and recovery boundaries', () {
    final writer = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/'
      'message_reconciliation_writer.dart',
    ).readAsStringSync();
    final global = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/'
      'tui_chat_global_model.dart',
    ).readAsStringSync();
    final store = File(
      'lib/src/services/message_history_coverage_store.dart',
    ).readAsStringSync();
    final recovery = File('lib/src/services/im_recovery_service.dart')
        .readAsStringSync();

    expect(writer, contains('serverTombstones'));
    expect(writer, contains('applyDelta'));
    expect(global, contains('commitMessageDelta'));
    expect(global, contains('explicitDeletes'));
    expect(store, contains('message_history_coverage_ranges'));
    expect(store, contains('message_history_coverage_pages'));
    expect(recovery, contains('_runBoundedCoverageRecoveryScan'));
  });
}

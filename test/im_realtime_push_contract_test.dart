import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/services/push_msgkey_dedup.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/gap_detector.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/inbound_reorder_buffer.dart';
import 'package:tencent_cloud_chat_sdk/enum/conversation_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';

void main() {
  group('IM-07 Push identity boundary', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final dedup = PushMsgKeyDedup.instance;
      dedup.clear();
      await dedup.persist();
    });

    test('uses the formal msgID as the shared SDK/Push identity', () {
      final message = V2TimMessage.fromJson(<String, Object?>{
        'message_msg_id': 'formal-msg-7',
        'message_sender': 'bob',
        'message_conv_type': ConversationType.V2TIM_C2C,
        'message_conv_id': 'bob',
        'message_risk_type_identified': 0,
        'message_elem_array': <Object?>[],
      });

      expect(
        PushMsgKeyDedup.instance.msgKeyFromMessage(message),
        'formal-msg-7',
      );
    });

    test('persists a push claim so a later SDK callback cannot alert twice',
        () async {
      final dedup = PushMsgKeyDedup.instance;
      await dedup.ensureReady();

      expect(dedup.tryClaim('msg-7'), isTrue);
      await dedup.persist();
      await dedup.reloadForTesting();

      expect(dedup.wasHandled('msg-7'), isTrue);
      expect(dedup.tryClaim('msg-7'), isFalse);
    });

    test('does not let a failed local alert permanently suppress the message',
        () async {
      final dedup = PushMsgKeyDedup.instance;
      await dedup.ensureReady();

      expect(dedup.tryClaim('msg-failed'), isTrue);
      dedup.releaseClaim('msg-failed');
      await dedup.persist();

      expect(dedup.wasHandled('msg-failed'), isFalse);
      expect(dedup.tryClaim('msg-failed'), isTrue);
    });

    test('clears persisted claims at the account logout boundary', () async {
      final dedup = PushMsgKeyDedup.instance;
      await dedup.ensureReady();

      expect(dedup.tryClaim('account-a-msg'), isTrue);
      await dedup.persist();

      dedup.clear();
      await dedup.persist();
      await dedup.reloadForTesting();

      expect(dedup.wasHandled('account-a-msg'), isFalse);
    });
  });

  group('IM-07 production wiring', () {
    test('ordinary messages and calls use separate listener namespaces', () {
      final adapter = File(
        'lib/src/services/im/tencent_advanced_message_adapter.dart',
      ).readAsStringSync();
      final sync = File(
        'lib/src/services/conversation_local/conversation_sync_service.dart',
      ).readAsStringSync();
      final call = File('lib/src/services/livekit_call_signaling.dart')
          .readAsStringSync();

      expect(adapter, contains("eventNamespace: 'chat'"));
      expect(sync, contains('TencentAdvancedMessageAdapter'));
      expect(sync, contains('handleAppRealtimeMessage(payload)'));
      expect(call, contains('class LiveKitCallSignaling'));
      expect(call, contains('businessID'));
      expect(call, contains('lk_call'));
      expect(call, isNot(contains('addAdvancedMsgListener')));
    });

    test('listener lifecycle and platform notification filters are wired', () {
      final sync = File(
        'lib/src/services/conversation_local/conversation_sync_service.dart',
      ).readAsStringSync();
      final android = File(
        'android/app/src/main/kotlin/vip/ninechat/pro/notification/'
        'AppSystemNotificationPlugin.kt',
      ).readAsStringSync();
      final ios = File('ios/Runner/AppDelegate.swift').readAsStringSync();

      expect(sync, contains('_realtimeLifecycleTail'));
      expect(sync, contains('_scheduleMessageListenerRetry'));
      expect(sync, contains('unawaited(_onMessageCoreLeaseLost'));
      expect(android, contains('isAppLocalNotification'));
      expect(android, contains('putString("local", "1")'));
      expect(ios, contains('loadHandledMsgKeys()'));
      expect(ios, contains('clearHandledMsgKeys'));
      expect(ios, contains('isAppLocalNotification(notification'));
    });
  });

  group('IM-07 group ordering', () {
    V2TimMessage message(String id, int seq) {
      return V2TimMessage.fromJson(<String, Object?>{
        'message_msg_id': id,
        'message_sender': 'bob',
        'message_group_id': 'g-7',
        'message_seq': seq,
        'message_conv_type': ConversationType.V2TIM_GROUP,
        'message_conv_id': 'g-7',
        'message_risk_type_identified': 0,
        'message_elem_array': <Object?>[],
      });
    }

    test('detects a protocol gap only for group Seq', () {
      final gap = GapDetector.detectGaps(
        newestFirst: <V2TimMessage>[
          message('m-8', 8),
          message('m-5', 5),
        ],
        isGroup: true,
        fullScan: true,
      );

      expect(gap, hasLength(1));
      expect(gap.single.upperSeq, 8);
      expect(gap.single.lowerSeq, 5);
      expect(
        GapDetector.detectGaps(
          newestFirst: <V2TimMessage>[
            message('m-8', 8),
            message('m-5', 5),
          ],
          isGroup: false,
          fullScan: true,
        ),
        isEmpty,
      );
    });

    test('buffers ahead messages and flushes once the missing Seq arrives', () {
      final flushed = <List<V2TimMessage>>[];
      final gaps = <int>[];
      final buffer = InboundReorderBuffer(
        onFlush: flushed.add,
        onGapTimeout: (anchorSeq, _) => gaps.add(anchorSeq),
      );
      buffer.activate('group_g-7', 5);

      expect(buffer.accept(message('m-7', 7)), isNull);
      final contiguous = buffer.accept(message('m-6', 6));

      expect(contiguous, hasLength(2));
      expect(contiguous!.map((item) => item.seq), <String?>['6', '7']);
      expect(flushed, isEmpty);
      expect(gaps, isEmpty);
    });
  });
}

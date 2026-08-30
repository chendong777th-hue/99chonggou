// IM-09 ADR enforcement: c2c receive message opt 只能通过 C2cReceiveOptService 写入。
//
// 不允许页面/服务直接调 MessageService.setC2CReceiveMessageOpt 或 Tencent SDK。
// 这套测试守住 SessionIdentity fence、owner 校验和参数校验，
// 跨账号晚到回执必须被拒绝。

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/c2c_receive_opt_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/contracts/account_scoped_conversation_key.dart';
import 'package:tencent_cloud_chat_demo/src/services/session_identity.dart';
import 'package:tencent_cloud_chat_sdk/enum/receive_message_opt_enum.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';

class _FakeMessageService implements MessageService {
  final List<List<String>> calls = [];
  V2TimCallback nextResult = V2TimCallback(code: 0, desc: 'ok');
  Object? throwOnNext;

  @override
  Future<V2TimCallback> setC2CReceiveMessageOpt({
    required List<String> userIDList,
    required ReceiveMsgOptEnum opt,
  }) async {
    if (throwOnNext != null) {
      final e = throwOnNext!;
      throwOnNext = null;
      throw e;
    }
    calls.add(List<String>.unmodifiable(userIDList));
    return nextResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IM-09 C2cReceiveOptService.fenceValid', () {
    late SessionIdentityService sessionService;

    setUp(() {
      sessionService = SessionIdentityService.instance;
      // 每次测试前清零 generation（通过 invalidate 直到 generation 足够大）。
      while (sessionService.generation > 1000000) {
        sessionService.invalidate(reason: 'reset_high_gen');
      }
    });

    test('current generation + matching owner passes', () {
      final id = sessionService.capture(ownerUserId: 'alice');
      expect(
        C2cReceiveOptService.fenceValid(
          captured: id,
          currentOwnerUserId: 'alice',
        ),
        isTrue,
      );
    });

    test('stale generation (account switched) is rejected', () {
      final id = sessionService.capture(ownerUserId: 'alice');
      sessionService.invalidate(reason: 'switch_to_bob');
      expect(
        C2cReceiveOptService.fenceValid(
          captured: id,
          currentOwnerUserId: 'bob',
        ),
        isFalse,
        reason: 'late write from previous session must never reach SDK',
      );
    });

    test('owner mismatch (race / UI tearing down) is rejected', () {
      final id = sessionService.capture(ownerUserId: 'alice');
      expect(
        C2cReceiveOptService.fenceValid(
          captured: id,
          currentOwnerUserId: 'bob',
        ),
        isFalse,
        reason: 'owner mismatch even with current generation must be rejected',
      );
    });

    test('empty current owner (test/bootstrap) falls back to generation only', () {
      final id = sessionService.capture(ownerUserId: '');
      expect(
        C2cReceiveOptService.fenceValid(
          captured: id,
          currentOwnerUserId: '',
        ),
        isTrue,
        reason: 'no owner context available; generation fence is the floor',
      );
    });
  });

  group('IM-09 C2cReceiveOptService.setOpt single peer', () {
    late _FakeMessageService svc;
    late SessionIdentityService sessionService;

    setUp(() {
      svc = _FakeMessageService();
      sessionService = SessionIdentityService.instance;
    });

    test('rejects wrong conversation type without invoking SDK', () async {
      final id = sessionService.capture(ownerUserId: 'alice');
      final groupKey = AccountScopedConversationKey(
        ownerUserId: 'alice',
        conversationType: ImConversationType.group,
        conversationId: '@TGS#_abc',
      );
      final res = await C2cReceiveOptService.setOpt(
        messageService: svc,
        key: groupKey,
        opt: ReceiveMsgOptEnum.V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE,
        capturedIdentity: id,
      );
      expect(res.code, -1);
      expect(res.desc, 'key_must_be_c2c');
      expect(svc.calls, isEmpty);
    });

    test('rejects owner mismatch between key and capturedIdentity', () async {
      final id = sessionService.capture(ownerUserId: 'bob');
      final key = AccountScopedConversationKey(
        ownerUserId: 'alice',
        conversationType: ImConversationType.c2c,
        conversationId: 'alice',
      );
      final res = await C2cReceiveOptService.setOpt(
        messageService: svc,
        key: key,
        opt: ReceiveMsgOptEnum.V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE,
        capturedIdentity: id,
      );
      expect(res.code, -1);
      expect(res.desc, 'owner_mismatch');
      expect(svc.calls, isEmpty);
    });

    test('stale generation (account switched away) is rejected', () async {
      final id = sessionService.capture(ownerUserId: 'alice');
      sessionService.invalidate(reason: 'switch_to_bob');
      final key = AccountScopedConversationKey(
        ownerUserId: 'alice',
        conversationType: ImConversationType.c2c,
        conversationId: 'bob',
      );
      final res = await C2cReceiveOptService.setOpt(
        messageService: svc,
        key: key,
        opt: ReceiveMsgOptEnum.V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE,
        capturedIdentity: id,
      );
      expect(res.code, -1);
      expect(res.desc, 'stale_identity');
      expect(svc.calls, isEmpty);
    });

    test('happy path trims canonical conversation id and forwards to SDK',
        () async {
      final id = sessionService.capture(ownerUserId: 'alice');
      final key = AccountScopedConversationKey(
        ownerUserId: 'alice',
        conversationType: ImConversationType.c2c,
        conversationId: 'c2c_bob',
      );
      final res = await C2cReceiveOptService.setOpt(
        messageService: svc,
        key: key,
        opt: ReceiveMsgOptEnum.V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE,
        capturedIdentity: id,
      );
      expect(res.code, 0);
      expect(svc.calls, hasLength(1));
      expect(
        svc.calls.single,
        ['bob'],
        reason: 'SDK must receive exactly one raw user id (no c2c_ prefix)',
      );
    });

    test('propagates SDK failure (network/permission/etc.)', () async {
      final id = sessionService.capture(ownerUserId: 'alice');
      svc.nextResult = V2TimCallback(code: 6014, desc: 'network_unreachable');
      final key = AccountScopedConversationKey(
        ownerUserId: 'alice',
        conversationType: ImConversationType.c2c,
        conversationId: 'bob',
      );
      final res = await C2cReceiveOptService.setOpt(
        messageService: svc,
        key: key,
        opt: ReceiveMsgOptEnum.V2TIM_RECEIVE_MESSAGE,
        capturedIdentity: id,
      );
      expect(res.code, 6014);
      expect(svc.calls, [['bob']]);
    });
  });

  group('IM-09 C2cReceiveOptService.setOptForBatch', () {
    late _FakeMessageService svc;
    late SessionIdentityService sessionService;

    setUp(() {
      svc = _FakeMessageService();
      sessionService = SessionIdentityService.instance;
    });

    test('rejects empty peer list', () async {
      final id = sessionService.capture(ownerUserId: 'alice');
      final res = await C2cReceiveOptService.setOptForBatch(
        messageService: svc,
        ownerUserId: 'alice',
        peerUserIds: const <String>[],
        opt: ReceiveMsgOptEnum.V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE,
        capturedIdentity: id,
      );
      expect(res.code, -1);
      expect(svc.calls, isEmpty);
    });

    test('rejects empty owner userId', () async {
      final id = sessionService.capture(ownerUserId: 'alice');
      final res = await C2cReceiveOptService.setOptForBatch(
        messageService: svc,
        ownerUserId: '   ',
        peerUserIds: const <String>['bob'],
        opt: ReceiveMsgOptEnum.V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE,
        capturedIdentity: id,
      );
      expect(res.code, -1);
      expect(res.desc, 'empty_owner_user_id');
      expect(svc.calls, isEmpty);
    });

    test('rejects owner mismatch between arg and capturedIdentity', () async {
      final id = sessionService.capture(ownerUserId: 'alice');
      final res = await C2cReceiveOptService.setOptForBatch(
        messageService: svc,
        ownerUserId: 'bob',
        peerUserIds: const <String>['carol'],
        opt: ReceiveMsgOptEnum.V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE,
        capturedIdentity: id,
      );
      expect(res.code, -1);
      expect(res.desc, 'owner_mismatch');
      expect(svc.calls, isEmpty);
    });

    test('rejects when any peer id is empty in batch', () async {
      final id = sessionService.capture(ownerUserId: 'alice');
      final res = await C2cReceiveOptService.setOptForBatch(
        messageService: svc,
        ownerUserId: 'alice',
        peerUserIds: const <String>['bob', '   '],
        opt: ReceiveMsgOptEnum.V2TIM_RECEIVE_MESSAGE,
        capturedIdentity: id,
      );
      expect(res.code, -1);
      expect(res.desc, 'empty_peer_user_id_in_batch');
      expect(svc.calls, isEmpty);
    });

    test('stale generation rejects the whole batch', () async {
      final id = sessionService.capture(ownerUserId: 'alice');
      sessionService.invalidate(reason: 'switch_to_bob');
      final res = await C2cReceiveOptService.setOptForBatch(
        messageService: svc,
        ownerUserId: 'alice',
        peerUserIds: const <String>['bob', 'carol'],
        opt: ReceiveMsgOptEnum.V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE,
        capturedIdentity: id,
      );
      expect(res.code, -1);
      expect(res.desc, 'stale_identity');
      expect(svc.calls, isEmpty);
    });

    test('happy path forwards canonicalised peer list to SDK', () async {
      final id = sessionService.capture(ownerUserId: 'alice');
      final res = await C2cReceiveOptService.setOptForBatch(
        messageService: svc,
        ownerUserId: 'alice',
        peerUserIds: const <String>['c2c_bob', 'carol'],
        opt: ReceiveMsgOptEnum.V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE,
        capturedIdentity: id,
      );
      expect(res.code, 0);
      expect(svc.calls, hasLength(1));
      expect(
        svc.calls.single,
        ['bob', 'carol'],
        reason: 'c2c_ prefix stripped by ChatIdFormat.rawUserUid',
      );
    });
  });

  group('IM-09 C2cReceiveOptService.setOptViaSdk fence', () {
    // SDK 原生路径在测试环境难以 mock；只校验 fence / 参数校验，
    // 拒绝路径必须返回失败回调而不是调 SDK（避免静默泄露到真实 SDK）。

    late SessionIdentityService sessionService;

    setUp(() {
      sessionService = SessionIdentityService.instance;
    });

    test('wrong conversation type returns error', () async {
      final id = sessionService.capture(ownerUserId: 'alice');
      final groupKey = AccountScopedConversationKey(
        ownerUserId: 'alice',
        conversationType: ImConversationType.group,
        conversationId: '@TGS#_abc',
      );
      final res = await C2cReceiveOptService.setOptViaSdk(
        key: groupKey,
        opt: ReceiveMsgOptEnum.V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE,
        capturedIdentity: id,
      );
      expect(res.code, -1);
      expect(res.desc, 'key_must_be_c2c');
    });

    test('stale fence returns error', () async {
      final id = sessionService.capture(ownerUserId: 'alice');
      sessionService.invalidate(reason: 'switch_to_bob');
      final key = AccountScopedConversationKey(
        ownerUserId: 'alice',
        conversationType: ImConversationType.c2c,
        conversationId: 'bob',
      );
      final res = await C2cReceiveOptService.setOptViaSdk(
        key: key,
        opt: ReceiveMsgOptEnum.V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE,
        capturedIdentity: id,
      );
      expect(res.code, -1);
      expect(res.desc, 'stale_identity');
    });
  });

  group('IM-09 C2cReceiveOptService.setOptForBatchViaSdk fence', () {
    late SessionIdentityService sessionService;

    setUp(() {
      sessionService = SessionIdentityService.instance;
    });

    test('empty peer list returns error', () async {
      final id = sessionService.capture(ownerUserId: 'alice');
      final res = await C2cReceiveOptService.setOptForBatchViaSdk(
        ownerUserId: 'alice',
        peerUserIds: const <String>[],
        opt: ReceiveMsgOptEnum.V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE,
        capturedIdentity: id,
      );
      expect(res.code, -1);
      expect(res.desc, 'empty_peer_user_ids');
    });

    test('empty peer in batch returns error', () async {
      final id = sessionService.capture(ownerUserId: 'alice');
      final res = await C2cReceiveOptService.setOptForBatchViaSdk(
        ownerUserId: 'alice',
        peerUserIds: const <String>['bob', '   '],
        opt: ReceiveMsgOptEnum.V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE,
        capturedIdentity: id,
      );
      expect(res.code, -1);
      expect(res.desc, 'empty_peer_user_id_in_batch');
    });

    test('owner mismatch returns error', () async {
      final id = sessionService.capture(ownerUserId: 'alice');
      final res = await C2cReceiveOptService.setOptForBatchViaSdk(
        ownerUserId: 'bob',
        peerUserIds: const <String>['carol'],
        opt: ReceiveMsgOptEnum.V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE,
        capturedIdentity: id,
      );
      expect(res.code, -1);
      expect(res.desc, 'owner_mismatch');
    });

    test('stale fence returns error', () async {
      final id = sessionService.capture(ownerUserId: 'alice');
      sessionService.invalidate(reason: 'switch_to_bob');
      final res = await C2cReceiveOptService.setOptForBatchViaSdk(
        ownerUserId: 'alice',
        peerUserIds: const <String>['bob'],
        opt: ReceiveMsgOptEnum.V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE,
        capturedIdentity: id,
      );
      expect(res.code, -1);
      expect(res.desc, 'stale_identity');
    });
  });
}

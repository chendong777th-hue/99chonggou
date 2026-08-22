import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/api/im_snapshot_api.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_snapshot_bootstrap_service.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';

class _TsMsg extends Fake implements V2TimMessage {
  _TsMsg(this._timestamp);

  final int _timestamp;

  @override
  int? get timestamp => _timestamp;
}

void main() {
  group('shouldAttemptImSnapshotOnLoginBootstrap', () {
    test('login bootstrap disables priority C2C snapshot', () {
      expect(
        ConversationSyncService.shouldAttemptImSnapshotOnLoginBootstrap(),
        isFalse,
      );
      expect(
        ConversationSyncService.shouldUseImSnapshotBootstrap(rowCount: 0),
        isFalse,
      );
      expect(
        ConversationSyncService.shouldUseImSnapshotBootstrap(rowCount: 50),
        isFalse,
      );
      expect(
        ConversationPerfFlags.snapshotPriorityC2cLimit,
        20,
      );
    });
  });

  test('only an explicit login bootstrap gate suppresses UIKit persistence',
      () {
    final service = ImSnapshotBootstrapService.instance;
    expect(service.shouldSuppressViewModelPersist, isFalse);
    service.beginLoginBootstrapGate();
    try {
      expect(service.shouldSuppressViewModelPersist, isTrue);
    } finally {
      service.endLoginBootstrapGate();
    }
    expect(service.shouldSuppressViewModelPersist, isFalse);
  });

  group('selectPriorityC2cConversations', () {
    test('keeps response order, excludes groups, and caps at 20', () {
      ImSnapshotConversation row(String id, int time) {
        return ImSnapshotConversation(
          conversationId: id,
          chatType: id.startsWith('group_') ? 'group' : 'c2c',
          peerId: id.contains('_') ? id.substring(id.indexOf('_') + 1) : id,
          lastMessage: ImSnapshotMessage(time: time, msgKey: 'k_$id'),
        );
      }

      final rows = ImSnapshotBootstrapService.selectPriorityC2cConversations(
        <ImSnapshotConversation>[
          row('c2c_first', 50),
          row('group_g1', 40),
          for (var i = 0; i < 24; i++) row('c2c_$i', 30 - i),
        ],
        limit: 20,
      );
      expect(rows, hasLength(20));
      expect(rows.first.conversationId, 'c2c_first');
      expect(rows.every((row) => row.chatType == 'c2c'), isTrue);
      expect(rows.last.conversationId, 'c2c_18');
    });
  });

  group('mergeSnapshotWithSdk', () {
    test('unread prefers SDK including non-zero', () {
      final shell = V2TimConversation(
        conversationID: 'c2c_peer',
        type: 1,
        userID: 'peer',
        unreadCount: 0,
      );
      final sdk = V2TimConversation(
        conversationID: 'c2c_peer',
        type: 1,
        userID: 'peer',
        unreadCount: 5,
        showName: 'Peer',
        faceUrl: 'https://example.com/a.png',
        draftText: 'draft',
      );
      final merged = ImSnapshotBootstrapService.mergeSnapshotWithSdk(
        shell: shell,
        sdk: sdk,
      );
      expect(merged.unreadCount, 5);
      expect(merged.showName, 'Peer');
      expect(merged.faceUrl, 'https://example.com/a.png');
      expect(merged.draftText, 'draft');
    });

    test('without SDK keeps shell unread 0', () {
      final shell = V2TimConversation(
        conversationID: 'c2c_peer',
        type: 1,
        userID: 'peer',
        unreadCount: 0,
        showName: 'peer',
      );
      final merged = ImSnapshotBootstrapService.mergeSnapshotWithSdk(
        shell: shell,
        sdk: null,
      );
      expect(merged.unreadCount, 0);
      expect(merged.showName, 'peer');
    });

    test('without SDK preserves local unread', () {
      final shell = V2TimConversation(
        conversationID: 'c2c_peer',
        type: 1,
        userID: 'peer',
        unreadCount: 0,
        showName: 'peer',
      );
      final local = V2TimConversation(
        conversationID: 'c2c_peer',
        type: 1,
        userID: 'peer',
        unreadCount: 7,
        showName: 'LocalName',
      );
      final merged = ImSnapshotBootstrapService.mergeSnapshotWithSdk(
        shell: shell,
        sdk: null,
        local: local,
      );
      expect(merged.unreadCount, 7);
      expect(merged.showName, 'LocalName');
    });
  });

  group('pickFresherLastMessage', () {
    test('newer SDK wins', () {
      final picked = ImSnapshotBootstrapService.pickFresherLastMessage(
        snapshot: _TsMsg(100),
        sdk: _TsMsg(200),
      );
      expect(picked?.timestamp, 200);
    });

    test('newer snapshot wins', () {
      final picked = ImSnapshotBootstrapService.pickFresherLastMessage(
        snapshot: _TsMsg(300),
        sdk: _TsMsg(200),
      );
      expect(picked?.timestamp, 300);
    });

    test('tie prefers SDK', () {
      final snap = _TsMsg(100);
      final sdk = _TsMsg(100);
      final picked = ImSnapshotBootstrapService.pickFresherLastMessage(
        snapshot: snap,
        sdk: sdk,
      );
      expect(identical(picked, sdk), isTrue);
    });
  });

  group('snapshotMessageToHistoryItem', () {
    test('maps seconds time and synthesizes text body', () {
      final item = ImSnapshotBootstrapService.snapshotMessageToHistoryItem(
        const ImSnapshotMessage(
          msgKey: '1_2_3',
          msgId: 'cloud-id',
          sender: 'u1',
          time: 1710000000,
          type: 'TIMTextElem',
          text: 'Hello',
          status: 1,
        ),
      );
      expect(item['msgKey'], '1_2_3');
      expect(item['msgId'], 'cloud-id');
      expect(item['fromAccount'], 'u1');
      expect(item['msgTimeMs'], 1710000000 * 1000);
      expect(item['previewText'], 'Hello');
      final body = item['msgBody'] as List<dynamic>;
      expect(body, isNotEmpty);
      expect((body.first as Map)['MsgType'], 'TIMTextElem');
    });
  });
}

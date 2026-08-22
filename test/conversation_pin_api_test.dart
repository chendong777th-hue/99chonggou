import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/api/conversation_pin_api.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime/friend_realtime_event.dart';

void main() {
  test('ConversationPinPage parses full items set', () {
    final page = ConversationPinPage.fromJson(<String, dynamic>{
      'items': [
        <String, dynamic>{
          'chatType': 'c2c',
          'peerId': 'user_a',
          'pinnedAt': 100,
          'updatedAt': 110,
        },
        <String, dynamic>{
          'chatType': 'group',
          'peerId': '@TGS#abc',
          'pinnedAt': 120,
          'updatedAt': 130,
        },
      ],
      'serverTime': 200,
      'updatedAt': 130,
    });
    expect(page.items.length, 2);
    expect(page.items.first.chatType, 'c2c');
    expect(page.items.first.peerId, 'user_a');
    expect(page.items.last.chatType, 'group');
    expect(page.updatedAt, 130);
    expect(page.serverTime, 200);
  });

  test('ConversationPinMutationResult keeps full items from put response', () {
    final result = ConversationPinMutationResult.fromJson(<String, dynamic>{
      'ok': true,
      'chatType': 'c2c',
      'peerId': 'u1',
      'pinned': true,
      'pinnedAt': 1,
      'updatedAt': 2,
      'items': [
        <String, dynamic>{
          'chatType': 'c2c',
          'peerId': 'u1',
          'pinnedAt': 1,
          'updatedAt': 2,
        },
      ],
      'serverTime': 3,
    });
    expect(result.ok, isTrue);
    expect(result.pinned, isTrue);
    expect(result.items.length, 1);
    expect(result.items.first.peerId, 'u1');
  });

  test('FriendRealtimeEvent parses conversation_pin_changed items', () {
    final event = FriendRealtimeEvent.fromJson(<String, dynamic>{
      'event': 'conversation_pin_changed',
      'items': [
        <String, dynamic>{
          'chatType': 'c2c',
          'peerId': 'peer1',
          'pinnedAt': 10,
          'updatedAt': 11,
        },
      ],
      'updatedAt': 11,
      'batch': false,
      'pinned': true,
      'chatType': 'c2c',
      'peerId': 'peer1',
    });
    expect(event.event, 'conversation_pin_changed');
    expect(event.pinItems, isNotNull);
    expect(event.pinItems!.length, 1);
    expect(event.pinItems!.first.peerId, 'peer1');
    expect(event.pinUpdatedAt, 11);
    expect(event.pinBatch, isFalse);
  });

  test('FriendRealtimeEvent missing items yields null pinItems', () {
    final event = FriendRealtimeEvent.fromJson(<String, dynamic>{
      'event': 'conversation_pin_changed',
      'updatedAt': 11,
    });
    expect(event.pinItems, isNull);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/utils/dice_play_policy.dart';
import 'package:tencent_cloud_chat_demo/utils/dice_play_store.dart';

void main() {
  group('decideDicePlayKeyUpdate', () {
    test('local id → msgID while animating keeps animation and migrates mark', () {
      final decision = decideDicePlayKeyUpdate(
        oldKey: 'local-1',
        newKey: 'msg-cloud-1',
        oldKeyPlayed: true,
        newKeyPlayed: false,
        isAnimatingOrStarting: true,
      );
      expect(decision.action, DicePlayKeyAction.keepAnimatingAndMigrate);
      expect(decision.markKey, 'msg-cloud-1');
    });

    test('animating before markPlayed still migrates instead of restarting', () {
      final decision = decideDicePlayKeyUpdate(
        oldKey: 'local-1',
        newKey: 'msg-cloud-1',
        oldKeyPlayed: false,
        newKeyPlayed: false,
        isAnimatingOrStarting: true,
      );
      expect(decision.action, DicePlayKeyAction.keepAnimatingAndMigrate);
      expect(decision.markKey, 'msg-cloud-1');
    });

    test('still + old key already played only migrates, does not replay', () {
      final decision = decideDicePlayKeyUpdate(
        oldKey: 'local-1',
        newKey: 'msg-cloud-1',
        oldKeyPlayed: true,
        newKeyPlayed: false,
        isAnimatingOrStarting: false,
      );
      expect(decision.action, DicePlayKeyAction.keepStillAndMigrate);
      expect(decision.markKey, 'msg-cloud-1');
    });

    test('still + empty old key + unplayed new key starts resolve', () {
      final decision = decideDicePlayKeyUpdate(
        oldKey: '',
        newKey: 'local-1',
        oldKeyPlayed: false,
        newKeyPlayed: false,
        isAnimatingOrStarting: false,
      );
      expect(decision.action, DicePlayKeyAction.resolveMode);
      expect(decision.markKey, isNull);
    });

    test('still + new key already played stays still', () {
      final decision = decideDicePlayKeyUpdate(
        oldKey: 'local-1',
        newKey: 'msg-cloud-1',
        oldKeyPlayed: false,
        newKeyPlayed: true,
        isAnimatingOrStarting: false,
      );
      expect(decision.action, DicePlayKeyAction.keepStill);
    });

    test('empty new key stays still', () {
      final decision = decideDicePlayKeyUpdate(
        oldKey: 'local-1',
        newKey: '  ',
        oldKeyPlayed: false,
        newKeyPlayed: false,
        isAnimatingOrStarting: false,
      );
      expect(decision.action, DicePlayKeyAction.keepStill);
    });
  });

  group('DicePlayStore.playKeyForMessage', () {
    test('prefers cloud msgID over local id', () {
      expect(
        DicePlayStore.playKeyForMessage(msgID: 'cloud', localId: 42),
        'cloud',
      );
    });

    test('falls back to local id when msgID is empty', () {
      expect(
        DicePlayStore.playKeyForMessage(msgID: '  ', localId: 42),
        '42',
      );
    });
  });
}

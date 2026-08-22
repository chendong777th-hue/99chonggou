import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/c2c_friend_message_guard.dart';

void main() {
  const peer = 'u_peer_became_friends';

  setUp(C2cFriendMessageGuard.debugReset);
  tearDown(C2cFriendMessageGuard.debugReset);

  group('C2cFriendMessageGuard trust vs lagging false', () {
    test('resolveCanSendWithTrust prefers fresh trust over false relation', () {
      expect(
        C2cFriendMessageGuard.resolveCanSendWithTrust(
          relationCanMessage: false,
          hasFreshTrust: true,
        ),
        isTrue,
      );
      expect(
        C2cFriendMessageGuard.resolveCanSendWithTrust(
          relationCanMessage: false,
          hasFreshTrust: false,
        ),
        isFalse,
      );
      expect(
        C2cFriendMessageGuard.resolveCanSendWithTrust(
          relationCanMessage: true,
          hasFreshTrust: false,
        ),
        isTrue,
      );
    });

    test('invalidate keeps trust by default; clearTrusted drops it', () {
      C2cFriendMessageGuard.trustCanSendHint(
        peer,
        source: C2cFriendMessageGuard.becameFriendsTrustSource,
      );
      expect(C2cFriendMessageGuard.hasFreshTrustedCanSendHint(peer), isTrue);
      expect(C2cFriendMessageGuard.cachedCanSendToSync(peer), isTrue);

      C2cFriendMessageGuard.invalidate(peer);
      expect(C2cFriendMessageGuard.hasFreshTrustedCanSendHint(peer), isTrue);
      // Cache cleared but trust still unlocks via prefer-trust helper on next write;
      // cached sync is null until trust/cache rewritten.
      expect(C2cFriendMessageGuard.cachedCanSendToSync(peer), isNull);

      C2cFriendMessageGuard.invalidate(peer, clearTrusted: true);
      expect(C2cFriendMessageGuard.hasFreshTrustedCanSendHint(peer), isFalse);
    });

    test('clearTrustedHint alone removes became-friends unlock', () {
      C2cFriendMessageGuard.trustCanSendHint(
        peer,
        source: C2cFriendMessageGuard.becameFriendsTrustSource,
      );
      C2cFriendMessageGuard.clearTrustedHint(peer);
      expect(C2cFriendMessageGuard.hasFreshTrustedCanSendHint(peer), isFalse);
    });

    test('trust TTL expiry drops hint', () async {
      C2cFriendMessageGuard.trustCanSendHint(
        peer,
        source: C2cFriendMessageGuard.becameFriendsTrustSource,
        ttl: const Duration(milliseconds: 30),
      );
      expect(C2cFriendMessageGuard.hasFreshTrustedCanSendHint(peer), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(C2cFriendMessageGuard.hasFreshTrustedCanSendHint(peer), isFalse);
    });
  });

  group('C2cFriendMessageGuard three-state decision', () {
    test('unknown lookup does not fail closed for SDK send', () {
      final unknown = C2cFriendMessageGuard.resolveDecision(
        relationCanMessage: null,
        localCanMessage: null,
        hasFreshTrust: false,
        lookupFailed: true,
      );
      expect(unknown, C2cSendPermissionDecision.unknown);
      expect(C2cFriendMessageGuard.sdkAllowsSend(unknown), isTrue);
      expect(C2cFriendMessageGuard.uiCanSend(unknown), isNull);
    });

    test('explicit relation false is blocked', () {
      final blocked = C2cFriendMessageGuard.resolveDecision(
        relationCanMessage: false,
        localCanMessage: true,
        hasFreshTrust: false,
        lookupFailed: false,
      );
      expect(blocked, C2cSendPermissionDecision.blocked);
      expect(C2cFriendMessageGuard.sdkAllowsSend(blocked), isFalse);
      expect(C2cFriendMessageGuard.uiCanSend(blocked), isFalse);
    });

    test('fresh trust wins over relation false', () {
      final allowed = C2cFriendMessageGuard.resolveDecision(
        relationCanMessage: false,
        localCanMessage: false,
        hasFreshTrust: true,
        lookupFailed: false,
      );
      expect(allowed, C2cSendPermissionDecision.allowed);
      expect(C2cFriendMessageGuard.sdkAllowsSend(allowed), isTrue);
      expect(C2cFriendMessageGuard.uiCanSend(allowed), isTrue);
    });

    test('unknown does not write negative cache', () {
      expect(C2cFriendMessageGuard.cachedCanSendToSync(peer), isNull);
    });

    test('local false is UI unknown and does not fail closed for SDK send', () {
      final snapshot = C2cFriendMessageGuard.resolveUiSnapshot(
        relationCanMessage: null,
        localCanMessage: false,
        hasFreshTrust: false,
        lookupFailed: false,
      );
      expect(snapshot.decision, C2cSendPermissionDecision.unknown);
      expect(snapshot.relationConfirmed, isFalse);
      expect(C2cFriendMessageGuard.uiCanSend(snapshot.decision), isNull);

      final sendDecision = C2cFriendMessageGuard.resolveDecision(
        relationCanMessage: null,
        localCanMessage: false,
        hasFreshTrust: false,
        lookupFailed: false,
      );
      expect(sendDecision, C2cSendPermissionDecision.unknown);
      expect(C2cFriendMessageGuard.sdkAllowsSend(sendDecision), isTrue);
    });

    test('relation false is blocked and confirmed', () {
      final snapshot = C2cFriendMessageGuard.resolveUiSnapshot(
        relationCanMessage: false,
        localCanMessage: true,
        hasFreshTrust: false,
        lookupFailed: false,
      );
      expect(snapshot.decision, C2cSendPermissionDecision.blocked);
      expect(snapshot.relationConfirmed, isTrue);
      expect(C2cFriendMessageGuard.uiCanSend(snapshot.decision), isFalse);
    });
  });

  group('C2cFriendMessageGuard peer id canonicalize', () {
    test('c2c_ prefix and mixed case share the same trust slot', () {
      C2cFriendMessageGuard.trustCanSendHint(
        'c2c_Alice',
        source: C2cFriendMessageGuard.becameFriendsTrustSource,
      );
      expect(C2cFriendMessageGuard.hasFreshTrustedCanSendHint('Alice'), isTrue);
      expect(C2cFriendMessageGuard.hasFreshTrustedCanSendHint('alice'), isTrue);
      expect(
        C2cFriendMessageGuard.hasFreshTrustedCanSendHint('c2c_alice'),
        isTrue,
      );
    });

    test('group ids are not treated as C2C peers', () {
      C2cFriendMessageGuard.trustCanSendHint(
        '@TGS#_mc2SX4NMM62CZ',
        source: C2cFriendMessageGuard.becameFriendsTrustSource,
      );
      expect(C2cFriendMessageGuard.debugTrustedHintCount(), 0);
      C2cFriendMessageGuard.trustCanSendHint(
        'group_@TGS#_@TGS#abc',
        source: C2cFriendMessageGuard.becameFriendsTrustSource,
      );
      expect(C2cFriendMessageGuard.debugTrustedHintCount(), 0);
    });
  });
}

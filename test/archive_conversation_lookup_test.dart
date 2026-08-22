import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/archive_conversation_lookup.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

void main() {
  group('archiveLookupTokensForConversationId', () {
    test('group short and full forms share equivalence token', () {
      const shortPeer = 'cCOZ5MMM62CJ';
      final full = ChatIdFormat.communityFullIdFromShort(shortPeer);
      final fromShort = archiveLookupTokensForConversationId('group_$shortPeer');
      final fromFull = archiveLookupTokensForConversationId('group_$full');
      final shared = fromShort.intersection(fromFull);
      expect(shared, isNotEmpty);
      expect(fromShort.contains(shortPeer) || fromFull.contains(shortPeer), isTrue);
    });

    test('c2c peer normalizes to c2c_uid token', () {
      final tokens = archiveLookupTokensForConversationId('c2c_alice_01');
      expect(tokens.contains('c2c_alice_01'), isTrue);
      expect(tokens.contains('alice_01'), isTrue);
    });
  });

  group('conversationIdInArchivedLookup', () {
    test('matches group short vs archived full id', () {
      const shortPeer = 'cCOZ5MMM62CJ';
      final full = ChatIdFormat.communityFullIdFromShort(shortPeer);
      final lookup = buildArchiveLookupTokenSet({'group_$full'});
      expect(
        conversationIdInArchivedLookup(lookup, 'group_$shortPeer'),
        isTrue,
      );
      expect(
        conversationIdInArchivedLookup(lookup, 'group_unrelatedXYZ'),
        isFalse,
      );
    });

    test('matches c2c bare peer against c2c_ prefixed archive', () {
      final lookup = buildArchiveLookupTokenSet({'c2c_bob_user'});
      expect(conversationIdInArchivedLookup(lookup, 'c2c_bob_user'), isTrue);
      expect(conversationIdInArchivedLookup(lookup, 'bob_user'), isTrue);
      expect(conversationIdInArchivedLookup(lookup, 'c2c_other'), isFalse);
    });

    test('empty sets are false', () {
      expect(conversationIdInArchivedLookup(const {}, 'c2c_x'), isFalse);
      expect(
        conversationIdInArchivedLookup(
          buildArchiveLookupTokenSet({'c2c_x'}),
          '',
        ),
        isFalse,
      );
    });
  });

  group('archivedIdMatchedInStoredIds', () {
    test('c2c bare stored matches prefixed archive id', () {
      expect(
        archivedIdMatchedInStoredIds('c2c_bob_user', {'bob_user'}),
        isTrue,
      );
      expect(
        archivedIdMatchedInStoredIds('c2c_bob_user', {'c2c_bob_user'}),
        isTrue,
      );
      expect(
        archivedIdMatchedInStoredIds('c2c_bob_user', {'c2c_other'}),
        isFalse,
      );
    });

    test('join candidates equal lookup tokens', () {
      const id = 'group_cCOZ5MMM62CJ';
      expect(
        archiveJoinCandidatesForConversationId(id),
        archiveLookupTokensForConversationId(id),
      );
    });
  });
}

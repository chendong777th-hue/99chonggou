import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/c2c_peer_id.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/error_message_converter.dart';

void main() {
  test('short id displays with single @', () {
    expect(
      ChatIdFormat.displayGroupAlias('m2BXTRBN5CK'),
      '@m2BXTRBN5CK',
    );
  });

  test('full community id displays as @short', () {
    expect(
      ChatIdFormat.displayGroupAlias('@TGS#_@TGS#m2BXTRBN5CK'),
      '@m2BXTRBN5CK',
    );
  });

  test('single-TGS community displays as @short', () {
    expect(
      ChatIdFormat.displayGroupAlias('@@TGS#c2SX4NMM62CZ'),
      '@c2SX4NMM62CZ',
    );
    expect(
      ChatIdFormat.displayGroupAlias('@TGS#c2SX4NMM62CZ'),
      '@c2SX4NMM62CZ',
    );
  });

  test('backend @TGS#_ form keeps single leading @', () {
    expect(
      ChatIdFormat.displayGroupAlias('@TGS#_mc2SX4NMM62CZ'),
      '@TGS#_mc2SX4NMM62CZ',
    );
  });

  test('displayGroupAlias prefers value then fallback', () {
    expect(
      ChatIdFormat.displayGroupAlias(
        '',
        groupIdFallback: '@TGS#_@TGS#m2O5P4YN5CI',
      ),
      '@m2O5P4YN5CI',
    );
  });

  test('normalizeGroupId keeps business short id (no TGS expand)', () {
    expect(ChatIdFormat.normalizeGroupId('m2MUSSKN5C3'), 'm2MUSSKN5C3');
    expect(ChatIdFormat.normalizeGroupId('@m2MUSSKN5C3'), 'm2MUSSKN5C3');
  });

  test('normalizeGroupId preserves all IM original prefix families', () {
    expect(
      ChatIdFormat.normalizeGroupId('@TGS#_@TGS#c7XWLQIM62C2'),
      '@TGS#_@TGS#c7XWLQIM62C2',
    );
    expect(
      ChatIdFormat.normalizeGroupId('@TGS#c2SX4NMM62CZ'),
      '@TGS#c2SX4NMM62CZ',
    );
    expect(
      ChatIdFormat.normalizeGroupId('@@TGS#c2SX4NMM62CZ'),
      '@TGS#c2SX4NMM62CZ',
    );
    expect(
      ChatIdFormat.normalizeGroupId('group_@TGS#c2SX4NMM62CZ'),
      '@TGS#c2SX4NMM62CZ',
    );
  });

  test('apiGroupId preserves backend IM original forms', () {
    expect(ChatIdFormat.apiGroupId('m2BXTRBN5CK'), 'm2BXTRBN5CK');
    expect(
      ChatIdFormat.apiGroupId('@TGS#_@TGS#c7XWLQIM62C2'),
      '@TGS#_@TGS#c7XWLQIM62C2',
    );
    expect(
      ChatIdFormat.apiGroupId('@TGS#c2SX4NMM62CZ'),
      '@TGS#c2SX4NMM62CZ',
    );
    expect(
      ChatIdFormat.apiGroupId('@TGS#_mc2SX4NMM62CZ'),
      '@TGS#_mc2SX4NMM62CZ',
    );
  });

  test('normalizeGroupId keeps backend @TGS#_ form (no double expand)', () {
    expect(
      ChatIdFormat.normalizeGroupId('@TGS#_mc2SX4NMM62CZ'),
      '@TGS#_mc2SX4NMM62CZ',
    );
    expect(
      ChatIdFormat.apiGroupId('@TGS#_@TGS#_mc2SX4NMM62CZ'),
      '@TGS#_mc2SX4NMM62CZ',
    );
  });

  test('apiGroupIdCandidates prefers original then morph fallbacks', () {
    final fromSingle = ChatIdFormat.apiGroupIdCandidates('@TGS#c2SX4NMM62CZ');
    expect(fromSingle.first, '@TGS#c2SX4NMM62CZ');
    expect(fromSingle, contains('c2SX4NMM62CZ'));
    expect(fromSingle, contains('@TGS#_@TGS#c2SX4NMM62CZ'));

    final fromShort = ChatIdFormat.apiGroupIdCandidates('c7XWLQIM62C2');
    expect(fromShort.first, 'c7XWLQIM62C2');
    expect(fromShort, contains('@TGS#c7XWLQIM62C2'));
    expect(fromShort, contains('@TGS#_@TGS#c7XWLQIM62C2'));
  });

  test('imGroupIdCandidates puts short id first for business token', () {
    final ids = ChatIdFormat.imGroupIdCandidates('m2C2BU2N5CE');
    expect(ids.first, 'm2C2BU2N5CE');
    expect(ids, contains('@TGS#_@TGS#m2C2BU2N5CE'));
    expect(
      ids.indexOf('m2C2BU2N5CE'),
      lessThan(ids.indexOf('@TGS#_@TGS#m2C2BU2N5CE')),
    );
  });

  test('imGroupIdCandidates prefers original IM form', () {
    const full = '@TGS#_@TGS#c7XWLQIM62C2';
    expect(ChatIdFormat.imGroupIdCandidates(full).first, full);

    const single = '@TGS#c2SX4NMM62CZ';
    final singleIds = ChatIdFormat.imGroupIdCandidates(single);
    expect(singleIds.first, single);
    expect(singleIds, contains('c2SX4NMM62CZ'));
    expect(singleIds, contains('@TGS#_@TGS#c2SX4NMM62CZ'));
  });

  test('console custom community @TGS#_mc… stays as-is for IM/REST', () {
    const consoleId = '@TGS#_mc2SX4NMM62CZ';
    expect(ChatIdFormat.isCustomCommunityId(consoleId), isTrue);
    expect(ChatIdFormat.normalizeGroupId(consoleId), consoleId);
    expect(ChatIdFormat.apiGroupId(consoleId), consoleId);
    expect(ChatIdFormat.normalizeGroupId('mc2SX4NMM62CZ'), consoleId);
    expect(ChatIdFormat.normalizeGroupId('group_$consoleId'), consoleId);

    final apiIds = ChatIdFormat.apiGroupIdCandidates(consoleId);
    expect(apiIds.first, consoleId);
    expect(apiIds, isNot(contains('@TGS#_@TGS#mc2SX4NMM62CZ')));

    final imIds = ChatIdFormat.imGroupIdCandidates(consoleId);
    expect(imIds.first, consoleId);
    expect(imIds, isNot(contains('@TGS#_@TGS#mc2SX4NMM62CZ')));
  });

  test('corrupted @TGS#_@TGS#_mc… restores console custom id', () {
    expect(
      ChatIdFormat.normalizeGroupId('@TGS#_@TGS#_mcH2XUNMM62CQ'),
      '@TGS#_mcH2XUNMM62CQ',
    );
  });

  test('console custom community ids are equivalent across forms', () {
    expect(
      ChatIdFormat.groupIdsEquivalent(
        '@TGS#_mc2SX4NMM62CZ',
        'mc2SX4NMM62CZ',
      ),
      isTrue,
    );
  });

  test('short / single-TGS / full forms are equivalent', () {
    expect(
      ChatIdFormat.groupIdsEquivalent(
        'c2SX4NMM62CZ',
        '@TGS#c2SX4NMM62CZ',
      ),
      isTrue,
    );
    expect(
      ChatIdFormat.groupIdsEquivalent(
        '@TGS#c2SX4NMM62CZ',
        '@TGS#_@TGS#c2SX4NMM62CZ',
      ),
      isTrue,
    );
  });

  test('looksLikeCommunityGroupId covers IM community families', () {
    expect(
      ChatIdFormat.looksLikeCommunityGroupId('@TGS#_@TGS#m2MUSSKN5C3'),
      isTrue,
    );
    expect(
      ChatIdFormat.looksLikeCommunityGroupId('@TGS#_mc2SX4NMM62CZ'),
      isTrue,
    );
    expect(
      ChatIdFormat.looksLikeCommunityGroupId('@TGS#c2SX4NMM62CZ'),
      isTrue,
    );
    expect(ChatIdFormat.looksLikeCommunityGroupId('@TGS#2ABCDEF'), isFalse);
    expect(ChatIdFormat.looksLikeCommunityGroupId('m2MUSSKN5C3'), isFalse);
  });

  test('imGroupIdFromRecord preserves IM original forms', () {
    expect(
      ChatIdFormat.imGroupIdFromRecord(
        groupId: '@TGS#_mc2SX4NMM62CZ',
        displayAlias: '@m2MUSSKN5C3',
      ),
      '@TGS#_mc2SX4NMM62CZ',
    );
    expect(
      ChatIdFormat.imGroupIdFromRecord(
        groupId: 'm2MUSSKN5C3',
        displayAlias: '@m2MUSSKN5C3',
      ),
      'm2MUSSKN5C3',
    );
    expect(
      ChatIdFormat.imGroupIdFromRecord(
        groupId: '@TGS#c2SX4NMM62CZ',
        displayAlias: '@c2SX4NMM62CZ',
      ),
      '@TGS#c2SX4NMM62CZ',
    );
    expect(
      ChatIdFormat.imGroupIdFromRecord(
        groupId: '@TGS#_@TGS#c7XWLQIM62C2',
        displayAlias: '@c7XWLQIM62C2',
      ),
      '@TGS#_@TGS#c7XWLQIM62C2',
    );
  });

  test('rawUserUid and canonicalC2cUserId strip c2c prefix', () {
    expect(ChatIdFormat.rawUserUid('c2c_peer_a'), 'peer_a');
    expect(ChatIdFormat.canonicalC2cUserId('c2c_Peer_A@im'), 'peer_a');
  });

  test('canonicalC2cUserId matches UIKit C2cPeerId for c2c_Peer_A', () {
    const raw = 'c2c_Peer_A';
    expect(ChatIdFormat.canonicalC2cUserId(raw), C2cPeerId.normalize(raw));
    expect(
      ErrorMessageConverter.normalizedPeerUserId(raw),
      C2cPeerId.normalize(raw),
    );
  });
}

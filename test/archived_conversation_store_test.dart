import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitConversation/archived_conversation_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    clearArchivedConversationSessionState();
    setArchivedConversationAccountScopeResolverForTest(null);
  });

  tearDown(() {
    clearArchivedConversationSessionState();
    setArchivedConversationAccountScopeResolverForTest(null);
  });

  test('archived conversation ids are isolated per account scope', () async {
    setArchivedConversationAccountScopeResolverForTest(() => 'user_a');
    await saveArchivedConversationIDs(
      ConversationArchiveScope.c2c,
      {'c2c_peer1'},
    );

    setArchivedConversationAccountScopeResolverForTest(() => 'user_b');
    await ensureArchivedConversationIDsLoaded();
    expect(archivedConversationC2cIDsNotifier.value, isEmpty);

    await saveArchivedConversationIDs(
      ConversationArchiveScope.c2c,
      {'c2c_peer2'},
    );

    setArchivedConversationAccountScopeResolverForTest(() => 'user_a');
    await ensureArchivedConversationIDsLoaded();
    expect(archivedConversationC2cIDsNotifier.value, {'c2c_peer1'});

    setArchivedConversationAccountScopeResolverForTest(() => 'user_b');
    await ensureArchivedConversationIDsLoaded();
    expect(archivedConversationC2cIDsNotifier.value, {'c2c_peer2'});
  });

  test('clearArchivedConversationSessionState keeps persisted account data',
      () async {
    setArchivedConversationAccountScopeResolverForTest(() => 'user_a');
    await saveArchivedConversationIDs(
      ConversationArchiveScope.group,
      {'group_g1'},
    );

    clearArchivedConversationSessionState();
    expect(archivedConversationGroupIDsNotifier.value, isEmpty);

    setArchivedConversationAccountScopeResolverForTest(() => 'user_a');
    await ensureArchivedConversationIDsLoaded();
    expect(archivedConversationGroupIDsNotifier.value, {'group_g1'});
  });

  test('formal account never imports ownerless legacy archived ids', () async {
    SharedPreferences.setMockInitialValues({
      archivedConversationIDsC2cStorageKey: ['c2c_legacy'],
      archivedConversationIDsGroupStorageKey: ['group_legacy'],
      archivedConversationIDsMigratedStorageKey: true,
    });
    clearArchivedConversationSessionState();

    setArchivedConversationAccountScopeResolverForTest(() => 'legacy_user');
    await ensureArchivedConversationIDsLoaded();

    expect(archivedConversationC2cIDsNotifier.value, isEmpty);
    expect(archivedConversationGroupIDsNotifier.value, isEmpty);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList(
        'archivedConversationIDs_c2c_v2_legacy_user',
      ),
      isNull,
    );
    expect(
      prefs.getStringList(
        'archivedConversationIDs_group_v2_legacy_user',
      ),
      isNull,
    );
  });

  test('clear removes only the requested account archive cache', () async {
    await saveArchivedConversationIDs(
      ConversationArchiveScope.c2c,
      {'c2c_a'},
      accountScope: 'user_a',
    );
    await saveArchivedConversationIDs(
      ConversationArchiveScope.c2c,
      {'c2c_b'},
      accountScope: 'user_b',
    );

    await clearArchivedConversationDataForAccountScope('user_a');
    clearArchivedConversationSessionState();
    await ensureArchivedConversationIDsLoaded(accountScope: 'user_b');

    expect(archivedConversationC2cIDsNotifier.value, {'c2c_b'});
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList('archivedConversationIDs_c2c_v2_user_a'),
      isNull,
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/archived_conversation_entry_visibility.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitConversation/archived_conversation_store.dart';

void main() {
  final gate = ArchivedConversationEntryVisibility.instance;

  setUp(() {
    gate.resetForTest();
    clearArchivedConversationSessionState();
    archivedConversationC2cIDsNotifier.value = <String>{};
    archivedConversationGroupIDsNotifier.value = <String>{};
  });

  tearDown(() {
    gate.resetForTest();
    clearArchivedConversationSessionState();
  });

  V2TimConversation conv(String id) => V2TimConversation(
        conversationID: id,
        userID: id.startsWith('c2c_') ? id.substring(4) : id,
        type: 1,
      );

  test('empty ids hide entry', () async {
    gate.ensureStarted();
    expect(gate.shouldShow(ConversationArchiveScope.c2c), isFalse);
  });

  test('id add shows optimistically then keeps when local hits', () async {
    gate.localByIdsForTest = (ids) async => [conv(ids.first)];
    gate.sdkGetConversationForTest = (_) async => null;
    gate.saveIdsForTest = (_, __) async {};
    gate.ensureStarted();

    archivedConversationC2cIDsNotifier.value = {'c2c_alice'};
    expect(gate.shouldShow(ConversationArchiveScope.c2c), isTrue);

    await gate.reconcile(ConversationArchiveScope.c2c);
    expect(gate.shouldShow(ConversationArchiveScope.c2c), isTrue);
  });

  test('orphan ids hide entry and prune after sdk null', () async {
    final saved = <String>{};
    gate.localByIdsForTest = (_) async => const <V2TimConversation>[];
    gate.sdkGetConversationForTest = (_) async => null;
    gate.saveIdsForTest = (scope, ids) async {
      expect(scope, ConversationArchiveScope.c2c);
      saved
        ..clear()
        ..addAll(ids);
      archivedConversationC2cIDsNotifier.value = Set<String>.from(ids);
    };
    gate.ensureStarted();

    archivedConversationC2cIDsNotifier.value = {'c2c_ghost'};
    expect(gate.shouldShow(ConversationArchiveScope.c2c), isTrue);

    await gate.reconcile(ConversationArchiveScope.c2c);
    expect(gate.shouldShow(ConversationArchiveScope.c2c), isFalse);
    expect(saved, isEmpty);
  });

  test('sdk hydrate keeps entry visible', () async {
    gate.localByIdsForTest = (_) async => const <V2TimConversation>[];
    gate.sdkGetConversationForTest = (id) async => conv(id);
    gate.saveIdsForTest = (_, __) async {};
    gate.ensureStarted();

    archivedConversationC2cIDsNotifier.value = {'c2c_bob'};
    await gate.reconcile(ConversationArchiveScope.c2c);
    expect(gate.shouldShow(ConversationArchiveScope.c2c), isTrue);
  });
}

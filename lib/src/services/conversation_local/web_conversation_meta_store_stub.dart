import 'web_conversation_meta_snapshot.dart';

/// Non-web stub: conversation meta persistence is handled by SQLite.
class WebConversationMetaStore {
  WebConversationMetaStore._();

  static final WebConversationMetaStore instance = WebConversationMetaStore._();

  Future<WebConversationMetaSnapshot?> load(String ownerUserId) async {
    return null;
  }

  Future<void> save(
    String ownerUserId,
    WebConversationMetaSnapshot snapshot,
  ) async {}
}

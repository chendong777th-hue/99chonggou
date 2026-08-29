import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/models/conversation_preview_item.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/utils/message_conversation_id.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

class ConversationPreviewCache {
  ConversationPreviewCache._();

  static String _prefsKey(String scope, String ownerUserId) =>
      'conversation_preview_cache_v2_${ContactSocialCacheStore.accountScopeForUserId(ownerUserId)}_$scope';

  static Future<List<ConversationPreviewItem>> load(
    String scope, {
    String? ownerUserId,
  }) async {
    final owner = ChatIdFormat.rawUserUid(
      ownerUserId ?? ContactSocialCacheStore.safeLoginUserId(),
    );
    if (owner.isEmpty) {
      return const [];
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey(scope, owner));
    if (raw == null || raw.trim().isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }
      return decoded
          .whereType<Map>()
          .map((e) => ConversationPreviewItem.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .where((e) => e.conversationId.isNotEmpty)
          .where(
            (e) => !MessageConversationId.isSelfC2CConversation(
              e.conversationId,
              owner,
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> save(
    String scope,
    List<ConversationPreviewItem> items, {
    String? ownerUserId,
  }) async {
    final owner = ChatIdFormat.rawUserUid(
      ownerUserId ?? ContactSocialCacheStore.safeLoginUserId(),
    );
    if (owner.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_prefsKey(scope, owner), raw);
  }

  static Future<void> clearLegacyKeys() async {
    final prefs = await SharedPreferences.getInstance();
    for (final scope in const ['c2c', 'group', 'all']) {
      await prefs.remove('conversation_preview_cache_v1_$scope');
    }
  }

  static Future<void> clearForOwner(String? ownerUserId) async {
    final owner = ChatIdFormat.rawUserUid(ownerUserId);
    if (owner.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    for (final scope in const ['c2c', 'group', 'all']) {
      await prefs.remove(_prefsKey(scope, owner));
    }
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_gallery_expand.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_gallery_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_preview_builder.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/chat_media_preview_item.dart';

/// 图集打开期间：本地扩窗一次，之后只把最新媒体增量插进来。
class ChatMediaGalleryLiveSession {
  ChatMediaGalleryLiveSession({
    required this.chatModel,
    required this.tappedMessage,
    required this.types,
    required ChatMediaPreviewBuildResult initialPreview,
    required this.rebuildPreview,
    required this.isMounted,
  }) : preview = initialPreview;

  static const int newestScanCount = 8;
  static const Duration _ingestDebounce = Duration(milliseconds: 400);

  final TUIChatSeparateViewModel chatModel;
  final V2TimMessage tappedMessage;
  final Set<ChatMediaPreviewType> types;
  final ChatMediaPreviewBuildResult Function(List<V2TimMessage> originList)
      rebuildPreview;
  final bool Function() isMounted;

  ChatMediaPreviewBuildResult preview;

  VoidCallback? _onPreviewChanged;
  Timer? _ingestDebounceTimer;
  var _started = false;
  var _disposed = false;
  var _expanding = false;

  bool _isPreviewable(V2TimMessage message) =>
      isChatMediaPreviewable(message, types);

  void ensureStarted(VoidCallback onPreviewChanged) {
    _onPreviewChanged = onPreviewChanged;
    if (_started || _disposed) {
      return;
    }
    _started = true;
    chatModel.addListener(_onChatListChanged);
    chatModel.globalModel.addListener(_onChatListChanged);
    unawaited(_expandLocal());
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _ingestDebounceTimer?.cancel();
    _ingestDebounceTimer = null;
    _onPreviewChanged = null;
    if (_started) {
      chatModel.removeListener(_onChatListChanged);
      chatModel.globalModel.removeListener(_onChatListChanged);
    }
  }

  Future<void> _expandLocal() async {
    _expanding = true;
    try {
      final expanded = await chatModel.expandGalleryOriginMessageList(
        tappedMessage: tappedMessage,
        types: types,
      );
      if (_disposed || !isMounted()) {
        return;
      }
      _applyOriginList(expanded);
      _ingestNewest();
    } catch (_) {
    } finally {
      _expanding = false;
    }
  }

  void _onChatListChanged() {
    if (_disposed || !isMounted() || _expanding) {
      return;
    }
    _ingestDebounceTimer?.cancel();
    _ingestDebounceTimer = Timer(_ingestDebounce, () {
      _ingestDebounceTimer = null;
      if (_disposed || !isMounted() || _expanding) {
        return;
      }
      _ingestNewest();
    });
  }

  void _ingestNewest() {
    final newestFirst = chatModel.getGalleryOriginMessageList();
    final revokedAuthority = chatModel
        .getOriginMessageList()
        .where(isChatMediaMessageRevoked)
        .toList(growable: false);
    final scanCount = newestFirst.length < newestScanCount
        ? newestFirst.length
        : newestScanCount;
    var working = preview.sortedMessages
        .where(
          (message) =>
              _isPreviewable(message) &&
              !revokedAuthority.any(
                (revoked) => isSameChatMediaMessage(revoked, message),
              ),
        )
        .toList(growable: false);
    var changed = working.length != preview.sortedMessages.length;
    for (var i = 0; i < scanCount; i++) {
      final next = appendIncomingChatMediaGalleryMessage(
        currentOldestFirst: working,
        incoming: newestFirst[i],
        isPreviewable: _isPreviewable,
      );
      if (!identical(next, working)) {
        working = next;
        changed = true;
      }
    }
    if (!changed) {
      return;
    }
    _applyOriginList(working);
  }

  void _applyOriginList(List<V2TimMessage> originList) {
    final next = rebuildPreview(originList);
    if (_samePreview(preview, next)) {
      return;
    }
    preview = next;
    ChatMediaGalleryExpandCache.put(
      ChatMediaGalleryExpandCache.keyFor(
        conversationID: chatModel.conversationID,
        types: types,
      ),
      next.sortedMessages,
    );
    _onPreviewChanged?.call();
  }

  static bool _samePreview(
    ChatMediaPreviewBuildResult a,
    ChatMediaPreviewBuildResult b,
  ) {
    if (a.items.length != b.items.length) {
      return false;
    }
    for (var i = 0; i < a.items.length; i++) {
      if (!isSameChatMediaMessage(a.items[i].message, b.items[i].message)) {
        return false;
      }
    }
    return true;
  }
}

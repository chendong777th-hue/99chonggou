import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_peek_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/message_media_metadata_store.dart';
import 'package:tencent_cloud_chat_demo/src/utils/conversation_preview_history_sync.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/constants/history_message_constant.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_gallery_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_send_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';

/// 聊天气泡缩略图 disk/memory cache key（与预览原图区分）。
String chatBubbleImageCacheKey(String? msgID, {String? url}) {
  return chatMediaBubbleImageCacheKey(msgID, urlFallback: url);
}

/// 进入聊天页前的首屏预取结果。
class ChatOpenPrefetchResult {
  const ChatOpenPrefetchResult({
    required this.messages,
    required this.hasMoreOlder,
  });

  final List<V2TimMessage> messages;
  final bool hasMoreOlder;
}

/// 历史消息加载后，预热首屏图片缩略图缓存。
class ChatImageMessagePrefetch {
  ChatImageMessagePrefetch._();

  static const _maxPrefetch = 10;
  static const _maxHistoricalPrefetch = 6;
  static const _maxUrlResolve = 16;
  static const _maxConcurrent = 3;
  static const _maxUrlResolveConcurrent = 8;
  static const _leaveEvictBatchSize = 8;

  /// 气泡预热位图软顶：超出则 evict 最旧 thumb（保留列表可见命中空间）。
  static const int maxWarmedBubbleProviders = 40;

  static final MessageService _messageService =
      serviceLocator<MessageService>();

  static int _inFlight = 0;
  static final List<({String url, String cacheKey})> _pending =
      <({String url, String cacheKey})>[];
  static final List<({String url, String cacheKey})> _warmedBubbleProviders =
      <({String url, String cacheKey})>[];

  static final Map<String, Future<ConversationPeekLoadResult>> _peekInFlight =
      <String, Future<ConversationPeekLoadResult>>{};

  /// 点击会话时尽早预热（与清未读、路由 push 并行）。
  static void prefetchForConversation(V2TimConversation conversation) {
    final key = _conversationKey(conversation);
    if (key != null && key.isNotEmpty) {
      final globalModel = serviceLocator<TUIChatGlobalModel>();
      if (globalModel.hasInitialHistoryLoaded(key) &&
          globalModel.rawMessageCount(key) > 0) {
        final cached = globalModel.getMessageList(key);
        if (cached != null && cached.isNotEmpty) {
          fromMessages(cached);
          return;
        }
      }
    }
    unawaited(_preparePeekMessages(conversation));
  }

  /// 进入聊天页前：先拉历史并立即返回可灌入 globalModel 的消息；
  /// 补 URL / 预热缩略图在后台进行，不阻塞导航。
  static Future<ChatOpenPrefetchResult> prepareBeforeChatOpen(
    V2TimConversation conversation, {
    Duration warmBudget = const Duration(milliseconds: 450),
    Duration? prepareBudget,
    void Function(ChatOpenPrefetchResult result)? onLatePrepared,
  }) async {
    final result = await _loadPeekForConversation(conversation);
    if (result.messages.isEmpty) {
      return const ChatOpenPrefetchResult(
        messages: <V2TimMessage>[],
        hasMoreOlder: false,
      );
    }
    final messages = List<V2TimMessage>.from(result.messages);
    await MessageMediaMetadataStore.instance.hydrateMessages(messages);
    final openResult = ChatOpenPrefetchResult(
      messages: messages,
      hasMoreOlder: result.hasMoreOlder,
    );
    unawaited(
      _enrichOpenPrefetchInBackground(
        messages: messages,
        warmBudget: warmBudget,
        hasMoreOlder: result.hasMoreOlder,
        onLatePrepared: onLatePrepared,
      ),
    );
    return openResult;
  }

  static Future<void> _enrichOpenPrefetchInBackground({
    required List<V2TimMessage> messages,
    required Duration warmBudget,
    required bool hasMoreOlder,
    void Function(ChatOpenPrefetchResult result)? onLatePrepared,
  }) async {
    await resolveOnlineUrlsForMessages(messages);
    unawaited(MessageMediaMetadataStore.instance.persistFromMessages(messages));
    fromMessages(messages);
    if (warmBudget > Duration.zero) {
      await warmWithBudget(messages, warmBudget);
    }
    onLatePrepared?.call(
      ChatOpenPrefetchResult(
        messages: messages,
        hasMoreOlder: hasMoreOlder,
      ),
    );
  }

  static Future<void> _preparePeekMessages(
    V2TimConversation conversation,
  ) async {
    final result = await prepareBeforeChatOpen(
      conversation,
      warmBudget: Duration.zero,
    );
    if (result.messages.isEmpty) {
      return;
    }
    fromMessages(result.messages);
  }

  static Future<ConversationPeekLoadResult> _loadPeekForConversation(
    V2TimConversation conversation,
  ) {
    final key = _conversationKey(conversation);
    if (key == null || key.isEmpty) {
      return Future<ConversationPeekLoadResult>.value(
        const ConversationPeekLoadResult(
          messages: <V2TimMessage>[],
          hasMoreOlder: false,
        ),
      );
    }
    final globalModel = serviceLocator<TUIChatGlobalModel>();
    if (ConversationPreviewHistorySync.isWarmWindowReadyForOpen(
      globalModel: globalModel,
      conversationKey: key,
      preview: conversation.lastMessage,
    )) {
      final cached = globalModel.messageListMap[key] ?? const <V2TimMessage>[];
      return Future<ConversationPeekLoadResult>.value(
        ConversationPeekLoadResult(
          messages: List<V2TimMessage>.from(cached),
          hasMoreOlder: globalModel.mayHaveOlderHistory(key),
        ),
      );
    }
    final inFlight = _peekInFlight[key];
    if (inFlight != null) {
      return inFlight;
    }
    final task = ConversationPeekService.loadForChatEntry(conversation);
    _peekInFlight[key] = task;
    return task.whenComplete(() {
      if (_peekInFlight[key] == task) {
        _peekInFlight.remove(key);
      }
    });
  }

  static String? _conversationKey(V2TimConversation conversation) {
    final userID = conversation.userID?.trim();
    if (userID != null && userID.isNotEmpty) {
      return userID;
    }
    final groupID = conversation.groupID?.trim();
    if (groupID != null && groupID.isNotEmpty) {
      return ChatIdFormat.canonicalGroupStorageId(groupID);
    }
    final conversationID = conversation.conversationID.trim();
    if (conversationID.isEmpty) {
      return null;
    }
    if (conversationID.toLowerCase().startsWith('group_')) {
      return ChatIdFormat.canonicalGroupStorageId(conversationID);
    }
    return conversationID;
  }

  /// 本地历史有图但缺 URL 时，批量向 SDK 补全（首进关键路径）。
  ///
  /// [budget] 超时后后台继续补全，不阻塞导航。
  static Future<void> resolveOnlineUrlsForMessages(
    Iterable<V2TimMessage?> messages, {
    Duration? budget,
    bool includeSelf = false,
  }) async {
    final task = _resolveOnlineUrlsForMessages(
      messages,
      includeSelf: includeSelf,
    );
    if (budget == null) {
      await task;
      return;
    }
    try {
      await task.timeout(budget);
    } on TimeoutException {
      unawaited(task);
    }
  }

  static Future<void> _resolveOnlineUrlsForMessages(
    Iterable<V2TimMessage?> messages, {
    bool includeSelf = false,
  }) async {
    final list = messages.whereType<V2TimMessage>().toList(growable: false);
    await MessageMediaMetadataStore.instance.hydrateMessages(list);
    unawaited(MessageMediaMetadataStore.instance.persistFromMessages(list));
    final pending = <V2TimMessage>[];
    for (var index = list.length - 1; index >= 0; index--) {
      if (pending.length >= _maxUrlResolve) {
        break;
      }
      final message = list[index];
      if (!needsOnlineUrlResolution(message, includeSelf: includeSelf)) {
        continue;
      }
      pending.add(message);
    }
    if (pending.isEmpty) {
      return;
    }

    var cursor = 0;
    Future<void> worker() async {
      while (true) {
        if (cursor >= pending.length) {
          return;
        }
        final index = cursor;
        cursor++;
        await _resolveOnlineUrlForMessage(pending[index]);
      }
    }

    final workers = <Future<void>>[];
    final workerCount = pending.length < _maxUrlResolveConcurrent
        ? pending.length
        : _maxUrlResolveConcurrent;
    for (var i = 0; i < workerCount; i++) {
      workers.add(worker());
    }
    await Future.wait(workers);
  }

  static bool needsOnlineUrlResolution(
    V2TimMessage message, {
    bool includeSelf = false,
  }) {
    // 会话预览需要给「自己发的图」补 URL：本地缓存可能已被清掉。
    if (message.isSelf == true && !includeSelf) {
      return false;
    }
    final msgID = message.msgID?.trim() ?? '';
    if (msgID.isEmpty) {
      return false;
    }
    if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE ||
        message.imageElem != null) {
      if (_hasLocalThumbFile(message)) {
        return false;
      }
      return resolveBubbleThumbUrl(message) == null;
    }
    if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_VIDEO ||
        message.videoElem != null) {
      if (_hasLocalVideoSnapshotFile(message)) {
        return false;
      }
      return resolveVideoSnapshotUrl(message) == null ||
          resolveVideoPlayUrl(message) == null;
    }
    return false;
  }

  static bool _hasLocalThumbFile(V2TimMessage message) {
    final imageList = message.imageElem?.imageList;
    if (imageList == null) {
      return false;
    }
    for (final image in imageList) {
      final type = image?.type;
      if (type != 1 && type != 2) {
        continue;
      }
      final local = image?.localUrl?.trim() ?? '';
      if (local.isNotEmpty && !kIsWeb && File(local).existsSync()) {
        return true;
      }
    }
    return false;
  }

  static bool _hasLocalVideoSnapshotFile(V2TimMessage message) {
    if (kIsWeb) {
      return false;
    }
    for (final path in <String?>[
      message.videoElem?.localSnapshotUrl,
      message.videoElem?.snapshotPath,
      message.videoElem?.localVideoUrl,
      message.videoElem?.videoPath,
    ]) {
      final value = path?.trim() ?? '';
      if (value.isNotEmpty && File(value).existsSync()) {
        return true;
      }
    }
    return false;
  }

  static String? resolveBubbleThumbUrl(V2TimMessage message) {
    final imageList = message.imageElem?.imageList;
    if (imageList == null || imageList.isEmpty) {
      return null;
    }
    // 预热只用缩略图，避免大图进全局 imageCache 挤掉头像。
    final thumb = MessageUtils.getImageFromImgList(
      imageList,
      HistoryMessageDartConstant.smallImgPrior,
    );
    final url = thumb?.url?.trim() ?? '';
    if (url.startsWith('http')) {
      return url;
    }
    for (final image in imageList) {
      if (image?.type != 1) {
        continue;
      }
      final candidate = image?.url?.trim() ?? '';
      if (candidate.startsWith('http')) {
        return candidate;
      }
    }
    for (final image in imageList) {
      final candidate = image?.url?.trim() ?? '';
      if (candidate.startsWith('http')) {
        return candidate;
      }
    }
    return null;
  }

  static String? resolveVideoSnapshotUrl(V2TimMessage message) {
    for (final candidate in <String?>[
      message.videoElem?.snapshotUrl,
      message.videoElem?.videoUrl,
    ]) {
      final value = candidate?.trim() ?? '';
      if (value.startsWith('http')) {
        return value;
      }
    }
    return null;
  }

  static String? resolveVideoPlayUrl(V2TimMessage message) {
    final value = message.videoElem?.videoUrl?.trim() ?? '';
    return value.startsWith('http') ? value : null;
  }

  static Future<void> _resolveOnlineUrlForMessage(V2TimMessage message) async {
    final msgID = message.msgID?.trim() ?? '';
    if (msgID.isEmpty) {
      return;
    }
    try {
      final response = await _messageService.getMessageOnlineUrl(
        msgID: msgID,
        reportError: false,
      );
      final imageElem = response.data?.imageElem;
      if (imageElem != null) {
        message.imageElem = imageElem;
      }
      final videoElem = response.data?.videoElem;
      if (videoElem != null) {
        message.videoElem = videoElem;
      }
      if (imageElem != null || videoElem != null) {
        await MessageMediaMetadataStore.instance.upsertFromMessage(message);
      }
    } catch (_) {}
  }

  static void fromMessages(Iterable<V2TimMessage?> messages) {
    _prefetchFromMessages(messages, maxCount: _maxPrefetch);
  }

  /// 上拉加载更早历史时，仅预热少量靠近当前视口的图片。
  static void fromHistoricalBatch(Iterable<V2TimMessage?> messages) {
    _prefetchFromMessages(messages, maxCount: _maxHistoricalPrefetch);
  }

  /// 退出聊天页时取消尚未开始的预取队列。
  static void cancelPending() {
    _pending.clear();
  }

  /// 退出聊天页：释放本会话气泡缩略图内存位图，把头像缓存让出来。
  /// 只驱逐已知气泡 provider，不清空整库。
  static void evictBubbleCacheForMessages(Iterable<V2TimMessage?> messages) {
    if (kIsWeb) {
      return;
    }
    cancelPending();
    _evictBubbleProvidersNow(_collectBubbleProvidersForEviction(messages));
  }

  /// 聊天路由退出后分帧释放图片气泡缓存，避免 pop 动画与 ImageCache 驱逐抢主线程。
  static void evictBubbleCacheForMessagesAfterFrame(
    Iterable<V2TimMessage?> messages,
  ) {
    if (kIsWeb) {
      return;
    }
    cancelPending();
    final snapshot =
        List<V2TimMessage>.from(messages.whereType<V2TimMessage>());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final providers = _collectBubbleProvidersForEviction(snapshot);
      _evictBubbleProvidersInBatches(providers);
    });
  }

  static List<({String url, String cacheKey})>
      _collectBubbleProvidersForEviction(Iterable<V2TimMessage?> messages) {
    final pendingEvict = <({String url, String cacheKey})>[
      ..._warmedBubbleProviders,
    ];
    _warmedBubbleProviders.clear();
    for (final message in messages.whereType<V2TimMessage>()) {
      if (message.elemType != MessageElemType.V2TIM_ELEM_TYPE_IMAGE) {
        continue;
      }
      final url = resolveBubbleThumbUrl(message);
      if (url == null || url.isEmpty) {
        continue;
      }
      pendingEvict.add((
        url: url,
        cacheKey: chatBubbleImageCacheKey(message.msgID, url: url),
      ));
    }
    final seen = <String>{};
    return pendingEvict
        .where((item) => seen.add(item.cacheKey))
        .toList(growable: false);
  }

  static void _evictBubbleProvidersNow(
    Iterable<({String url, String cacheKey})> providers,
  ) {
    for (final item in providers) {
      try {
        _evictBubbleProviders(item.url, item.cacheKey);
      } catch (_) {}
    }
  }

  static void _evictBubbleProvidersInBatches(
    List<({String url, String cacheKey})> providers, [
    int offset = 0,
  ]) {
    if (offset >= providers.length) {
      return;
    }
    final end =
        (offset + _leaveEvictBatchSize).clamp(0, providers.length).toInt();
    _evictBubbleProvidersNow(providers.sublist(offset, end));
    if (end >= providers.length) {
      return;
    }
    WidgetsBinding.instance.scheduleFrame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _evictBubbleProvidersInBatches(providers, end);
    });
  }

  static void _prefetchFromMessages(
    Iterable<V2TimMessage?> messages, {
    required int maxCount,
  }) {
    final list = messages.whereType<V2TimMessage>().toList(growable: false);
    if (list.isEmpty) {
      return;
    }

    var warmed = 0;
    for (var index = list.length - 1; index >= 0; index--) {
      if (warmed >= maxCount) {
        break;
      }
      final message = list[index];
      if (message.elemType != MessageElemType.V2TIM_ELEM_TYPE_IMAGE) {
        continue;
      }
      if (_hasLocalThumbFile(message)) {
        continue;
      }

      final url = resolveBubbleThumbUrl(message);
      if (url == null) {
        continue;
      }

      warmed++;
      _scheduleWarmNetworkImage(
        url,
        chatBubbleImageCacheKey(message.msgID, url: url),
      );
    }
  }

  static Future<void> warmWithBudget(
    Iterable<V2TimMessage?> messages,
    Duration budget,
  ) async {
    final jobs = <Future<void>>[];
    final list = messages.whereType<V2TimMessage>().toList(growable: false);
    for (var index = list.length - 1; index >= 0; index--) {
      if (jobs.length >= 4) {
        break;
      }
      final message = list[index];
      if (message.elemType != MessageElemType.V2TIM_ELEM_TYPE_IMAGE) {
        continue;
      }
      if (_hasLocalThumbFile(message)) {
        continue;
      }
      final url = resolveBubbleThumbUrl(message);
      if (url == null) {
        continue;
      }
      jobs.add(
        _warmNetworkImage(
          url,
          chatBubbleImageCacheKey(message.msgID, url: url),
        ),
      );
    }
    if (jobs.isEmpty) {
      return;
    }
    try {
      await Future.wait(jobs).timeout(budget);
    } catch (_) {}
  }

  static void _scheduleWarmNetworkImage(String url, String cacheKey) {
    if (_inFlight >= _maxConcurrent) {
      _pending.add((url: url, cacheKey: cacheKey));
      return;
    }
    _inFlight++;
    unawaited(
      _warmNetworkImage(url, cacheKey).whenComplete(_onWarmComplete),
    );
  }

  static void _onWarmComplete() {
    if (_inFlight > 0) {
      _inFlight--;
    }
    while (_inFlight < _maxConcurrent && _pending.isNotEmpty) {
      final job = _pending.removeAt(0);
      _scheduleWarmNetworkImage(job.url, job.cacheKey);
    }
  }

  static void _trackWarmedBubbleProvider({
    required String url,
    required String cacheKey,
  }) {
    _warmedBubbleProviders.removeWhere((e) => e.cacheKey == cacheKey);
    _warmedBubbleProviders.add((url: url, cacheKey: cacheKey));
    while (_warmedBubbleProviders.length > maxWarmedBubbleProviders) {
      final oldest = _warmedBubbleProviders.removeAt(0);
      _evictBubbleProviders(oldest.url, oldest.cacheKey);
    }
  }

  static Iterable<ImageProvider> _bubbleProviders(
    String url,
    String cacheKey,
  ) sync* {
    final base = CachedNetworkImageProvider(url, cacheKey: cacheKey);
    yield base;
    // 兼容旧预热写入的 720 ResizeImage，离开会话时一并 evict。
    yield ResizeImage(
      base,
      width: kChatBubbleImageDecodeScrollDeferMaxPx,
    );
    yield ResizeImage(
      base,
      height: kChatBubbleImageDecodeScrollDeferMaxPx,
    );
  }

  static void _evictBubbleProviders(String url, String cacheKey) {
    final cache = PaintingBinding.instance.imageCache;
    for (final provider in _bubbleProviders(url, cacheKey)) {
      try {
        cache.evict(provider);
      } catch (_) {}
    }
  }

  static Future<void> _warmNetworkImage(String url, String cacheKey) async {
    if (kIsWeb) {
      return;
    }
    try {
      _trackWarmedBubbleProvider(url: url, cacheKey: cacheKey);
      await _warmProvider(
        CachedNetworkImageProvider(url, cacheKey: cacheKey),
      );
    } catch (_) {}
  }

  static Future<void> _warmProvider(ImageProvider provider) async {
    final stream = provider.resolve(const ImageConfiguration());
    final completer = Completer<void>();
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (_, __) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      onError: (_, __) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
    );
    stream.addListener(listener);
    await completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {},
    );
    stream.removeListener(listener);
  }
}

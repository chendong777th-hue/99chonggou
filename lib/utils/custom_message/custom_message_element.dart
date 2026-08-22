import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/calling_message/call_message_bubble_style.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/calling_message/calling_message_data_provider.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/calling_message/group_call_message_builder.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/calling_message/single_call_message_builder.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/contact_card_message.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/friend_became_friends_message.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/group_live_message.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/group_live/group_live_message_card.dart';
import 'package:tencent_cloud_chat_demo/src/pages/group_live/group_live_navigator.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/red_packet_claim_notice_message.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/contact_card_message_item.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_tip_custom_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/controller/tim_uikit_chat_controller.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_message_width.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_bubble_text_color.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_jump_highlight.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/link_preview/common/extensions.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/link_preview/common/utils.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/link_message.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/official_account_article_card.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/official_account_article_message.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/platform_wallet_notice_message.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/platform_wallet_notice_message_item.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/web_link_message.dart';
import 'package:tencent_cloud_chat_demo/src/api/wallet_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/wallet_amount.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/chat_cards/chat_wallet_card_metrics.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/chat_cards/red_packet_card.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/red_packet/red_packet_models.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/red_packet/red_packet_detail_pop_result.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/red_packet/red_packet_flow_launcher.dart';
import 'package:tencent_cloud_chat_demo/src/services/red_packet_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/red_packet_sender_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/transfer_detail_screen.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/transfer_party_name_resolver.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/chat_cards/transfer_card.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/wallet_repository.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/order/wallet_card_integrity.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/order/wallet_card_send_service.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/wallet_repository_provider.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/wallet_store.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';

/// 专属红包收款人头像内存缓存，避免进入会话时重复解析引发抖动。
final Map<String, String> _exclusiveReceiverFaceMemoryCache = {};

class CustomMessageElem extends StatefulWidget {
  final TextStyle? messageFontStyle;
  final BorderRadius? messageBorderRadius;
  final Color? messageBackgroundColor;
  final EdgeInsetsGeometry? textPadding;
  final V2TimMessage message;
  final bool isShowJump;
  final VoidCallback? clearJump;
  final TIMUIKitChatController chatController;

  const CustomMessageElem({
    Key? key,
    required this.message,
    required this.isShowJump,
    required this.chatController,
    this.clearJump,
    this.messageFontStyle,
    this.messageBorderRadius,
    this.messageBackgroundColor,
    this.textPadding,
  }) : super(key: key);

  static bool? isC2CCallOutgoing(V2TimMessage message) {
    try {
      final callingMessageDataProvider = CallingMessageDataProvider(message);
      if (callingMessageDataProvider.shouldDisplayInHistory &&
          callingMessageDataProvider.participantType ==
              CallParticipantType.c2c) {
        return callingMessageDataProvider.direction ==
            CallMessageDirection.outcoming;
      }
    } catch (e) {
      return null;
    }

    return null;
  }

  static bool isWalletOrderMessage(V2TimMessage message) =>
      isWalletCardMessage(message);

  static String? stableWalletWidgetKey(V2TimMessage message) {
    try {
      final raw = message.customElem?.data;
      if (raw == null || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final data = Map<String, dynamic>.from(decoded);
      final clientOrderId = data['clientOrderId']?.toString().trim() ?? '';
      final orderId = data['orderId']?.toString().trim() ?? '';
      final fallback =
          message.msgID?.trim() ?? message.id?.toString().trim() ?? '';
      final stableId = clientOrderId.isNotEmpty
          ? clientOrderId
          : (orderId.isNotEmpty ? orderId : fallback);
      if (stableId.isEmpty) return null;
      return 'wallet_$stableId';
    } catch (_) {
      return null;
    }
  }

  static String walletMessageWidgetKey(V2TimMessage message) {
    final orderKey = stableWalletWidgetKey(message);
    if (orderKey != null && orderKey.isNotEmpty) {
      return orderKey;
    }
    final msgKey = message.msgID?.trim() ??
        message.id?.toString().trim() ??
        '${message.timestamp ?? 0}_${message.seq ?? 0}_${message.random ?? 0}';
    return 'wallet_$msgKey';
  }

  static bool isContactCardMessage(V2TimMessage message) {
    return getContactCardMessage(message.customElem) != null;
  }

  static bool isWalletCardMessage(V2TimMessage message) {
    try {
      final raw = message.customElem?.data;
      if (raw == null || raw.trim().isEmpty) return false;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return false;
      final data = Map<String, dynamic>.from(decoded);
      if (isPlatformWalletNoticePayload(data)) return false;
      if (data['businessID']?.toString() == kRedPacketClaimNoticeBusinessID) {
        return false;
      }
      final customType = data['customType']?.toString() ?? '';
      final legacyType = data['type']?.toString() ?? '';
      final businessID = data['businessID']?.toString() ?? '';
      return customType == 'wallet_transfer' ||
          legacyType == 'wallet_transfer' ||
          customType == 'wallet_group_transfer' ||
          legacyType == 'wallet_group_transfer' ||
          customType == 'wallet_red_packet' ||
          legacyType == 'wallet_red_packet' ||
          businessID == 'wallet_order';
    } catch (_) {
      return false;
    }
  }

  static bool isPlatformWalletNoticeMessage(V2TimMessage message) {
    try {
      final raw = message.customElem?.data;
      if (raw == null || raw.trim().isEmpty) return false;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return false;
      return isPlatformWalletNoticePayload(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      return false;
    }
  }

  static Future<void> launchWebURL(BuildContext context, String url) async {
    try {
      await launchUrl(
        Uri.parse(url).withScheme,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      ToastUtils.toast(TIM_t("无法打开URL"));
    }
  }

  @override
  State<CustomMessageElem> createState() => _CustomMessageElemState();
}

class _CustomMessageElemState extends State<CustomMessageElem> {
  bool isShowJumpState = false;
  bool isShining = false;
  bool isShowBorder = false;
  Timer? _jumpHighlightTimer;

  /// 红包/转账卡片：避免列表 rebuild 时 FutureBuilder 重新走 loading。
  String? _walletCacheKey;
  Map<String, dynamic>? _walletData;
  WalletOrderCardDto? _walletCard;
  bool _walletLoading = false;
  String? _exclusiveMetaKey;
  _ExclusiveRedPacketMeta? _exclusiveMeta;
  String? _exclusiveReceiverUserIdOverride;
  String? _exclusiveReceiverFaceUrl;
  String? _exclusiveReceiverFaceResolveKey;
  bool _exclusiveFaceResolveInFlight = false;
  bool _walletQuietRefreshInFlight = false;
  Timer? _walletInvalidRetryTimer;
  Timer? _walletQuietRefreshFallbackTimer;
  int _walletQuietRefreshGeneration = 0;
  int _walletInvalidRetryAttempt = 0;
  String? _packetTypeResolveKey;
  bool _redPacketSenderRefreshListening = false;
  bool _redPacketOverlayOpening = false;
  bool _redPacketOpenedLocally = false;
  bool _redPacketClaimedLocally = false;
  String? _redPacketOpenedCheckKey;
  bool _redPacketOpenedCheckInFlight = false;

  String _walletOverlayConversationID() {
    final groupID = widget.message.groupID?.trim() ?? '';
    if (groupID.isNotEmpty) {
      return 'group_$groupID';
    }
    final userID = widget.message.userID?.trim() ?? '';
    if (userID.isNotEmpty) {
      return 'c2c_$userID';
    }
    return '';
  }

  bool _shouldIgnoreWalletCardTap() {
    if (!mounted) {
      return true;
    }
    try {
      return Provider.of<TUIChatGlobalModel>(context, listen: false)
          .isMessageContextMenuOverlayOpen;
    } catch (_) {
      return false;
    }
  }

  String _walletOverlayAnchorMessageID() {
    return widget.message.msgID?.trim().isNotEmpty == true
        ? widget.message.msgID!.trim()
        : (widget.message.id?.toString().trim() ?? '');
  }

  Future<T?> _pushWalletOverlay<T>(Route<T> route) async {
    final globalModel = Provider.of<TUIChatGlobalModel>(context, listen: false);
    final convId = _walletOverlayConversationID();
    globalModel.beginWalletOverlay(
      conversationID: convId,
      anchorMessageID: _walletOverlayAnchorMessageID(),
    );
    try {
      return await Navigator.of(context).push<T>(route);
    } finally {
      globalModel.endWalletOverlay(conversationID: convId);
    }
  }

  AppMaterialPageRoute<T> _walletOverlayRoute<T>(Widget page) {
    return AppMaterialPageRoute<T>(
      settings: const RouteSettings(name: AppRoutes.walletOverlay),
      enableFullScreenBackGesture: true,
      edgeStartWidthPx: 96.0,
      builder: (_) => page,
    );
  }

  WalletOrderCardDto _walletCardWithStatus(
    WalletOrderCardDto card,
    String status,
  ) {
    return WalletOrderCardDto(
      ok: card.ok,
      type: card.type,
      status: status,
      amount: card.amount,
      coin: card.coin,
      title: card.title,
      msg: card.msg,
    );
  }

  @override
  void initState() {
    super.initState();
    final data = _walletPayload(widget.message.customElem?.data);
    if (data != null) {
      _scheduleWalletCardLoad(data);
      _syncRedPacketSenderRefreshListener(data);
    }
  }

  @override
  void didUpdateWidget(CustomMessageElem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isShowJump && !oldWidget.isShowJump && !isShining) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showJumpColor();
        }
      });
    }
    if (!widget.isShowJump && oldWidget.isShowJump) {
      isShowJumpState = false;
      widget.clearJump?.call();
    }
    final data = _walletPayload(widget.message.customElem?.data);
    if (data == null) {
      _clearWalletState();
      _syncRedPacketSenderRefreshListener(null);
      return;
    }
    final oldMessageKey =
        CustomMessageElem.walletMessageWidgetKey(oldWidget.message);
    final newMessageKey =
        CustomMessageElem.walletMessageWidgetKey(widget.message);
    if (oldMessageKey != newMessageKey) {
      _scheduleWalletCardLoad(data);
      _syncRedPacketSenderRefreshListener(data);
      return;
    }
    final key = _walletCacheKeyFromData(data);
    if (key != _walletCacheKey) {
      _scheduleWalletCardLoad(data);
    } else {
      _applyWalletPayloadInPlace(data);
    }
    _syncRedPacketSenderRefreshListener(data);
  }

  @override
  void dispose() {
    _jumpHighlightTimer?.cancel();
    _walletInvalidRetryTimer?.cancel();
    _cancelWalletQuietRefresh();
    _setRedPacketSenderRefreshListening(false);
    super.dispose();
  }

  void _clearWalletState() {
    _walletCacheKey = null;
    _walletData = null;
    _walletCard = null;
    _walletLoading = false;
    _walletInvalidRetryTimer?.cancel();
    _walletInvalidRetryTimer = null;
    _walletInvalidRetryAttempt = 0;
    _cancelWalletQuietRefresh();
    _exclusiveMetaKey = null;
    _exclusiveMeta = null;
    _exclusiveReceiverUserIdOverride = null;
    _exclusiveReceiverFaceUrl = null;
    _exclusiveReceiverFaceResolveKey = null;
    _exclusiveFaceResolveInFlight = false;
    _packetTypeResolveKey = null;
    _redPacketOpenedLocally = false;
    _redPacketClaimedLocally = false;
    _redPacketOpenedCheckKey = null;
    _redPacketOpenedCheckInFlight = false;
  }

  String _walletIdentityKey(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    final orderId = data['orderId']?.toString() ?? '';
    final clientOrderId = data['clientOrderId']?.toString() ?? '';
    final currency = data['currency']?.toString() ?? '';
    final amountRaw = data['amount'];
    final amount = amountRaw is int
        ? amountRaw
        : int.tryParse(amountRaw?.toString() ?? '');
    return '$type|$orderId|$clientOrderId|$currency|${amount ?? ''}';
  }

  String _walletCacheKeyFromData(Map<String, dynamic> data) {
    return _walletIdentityKey(data);
  }

  void _applyWalletPayloadInPlace(Map<String, dynamic> data) {
    final prevData = _walletData;
    _walletData = data;
    final card = _walletCard;
    if (card == null || !card.ok || card.invalid) {
      return;
    }
    final local = _walletLocalCardFromData(data);
    final next = local == null
        ? card
        : retainWalletCardDisplayAmount(
            next: card.copyWith(
              status: local.status,
              amount: local.amount.isNotEmpty ? local.amount : card.amount,
              coin: local.coin.isNotEmpty ? local.coin : card.coin,
              msg: local.msg.isNotEmpty ? local.msg : card.msg,
            ),
            previous: card,
          );
    final cardChanged = next.status != card.status ||
        next.amount != card.amount ||
        next.coin != card.coin ||
        next.msg != card.msg;
    final metaChanged = prevData == null ||
        '${prevData['packetCount']}' != '${data['packetCount']}' ||
        '${prevData['packetType']}' != '${data['packetType']}' ||
        '${prevData['status']}' != '${data['status']}';
    if (!cardChanged && !metaChanged) {
      return;
    }
    if (mounted) {
      setState(() {
        _walletCard = next;
      });
    }
  }

  void _cancelWalletQuietRefresh() {
    _walletQuietRefreshFallbackTimer?.cancel();
    _walletQuietRefreshFallbackTimer = null;
    _walletQuietRefreshGeneration++;
  }

  /// 本地/缓存卡已上屏后，把 order-card 网络刷新挪到首帧之后（≤1s 兜底）。
  void _scheduleWalletQuietRefresh(Map<String, dynamic> data) {
    _cancelWalletQuietRefresh();
    final generation = _walletQuietRefreshGeneration;
    final cacheKey = _walletCacheKey;
    void run() {
      if (!mounted || generation != _walletQuietRefreshGeneration) {
        return;
      }
      if (cacheKey != null && _walletCacheKey != cacheKey) {
        return;
      }
      _walletQuietRefreshFallbackTimer?.cancel();
      _walletQuietRefreshFallbackTimer = null;
      _maybeResolvePacketType(data);
      unawaited(_fetchAndMergeWalletCard(data));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _walletQuietRefreshGeneration) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != _walletQuietRefreshGeneration) {
          return;
        }
        run();
      });
    });
    _walletQuietRefreshFallbackTimer = Timer(const Duration(seconds: 1), run);
  }

  void _scheduleWalletCardLoad(Map<String, dynamic> data) {
    final cacheKey = _walletCacheKeyFromData(data);
    _walletCacheKey = cacheKey;
    _walletData = data;
    _walletInvalidRetryTimer?.cancel();
    _walletInvalidRetryTimer = null;
    _walletInvalidRetryAttempt = 0;
    _cancelWalletQuietRefresh();

    final args = _walletLoadArgs(data);
    Future<void> presentImmediateCard(WalletOrderCardDto card) async {
      _walletLoading = false;
      _walletCard = retainWalletCardDisplayAmount(
        next: card,
        previous: _walletCard,
      );
      _seedExclusiveMetaFromPayload(data);
      _primeExclusiveReceiverFaceFromCache(data);
      _scheduleExclusiveReceiverFaceResolve(data, _exclusiveMeta);
      _maybeLoadExclusiveMeta(data, card);
      await _hydrateRedPacketOpenedBeforeFirstPaint(data);
      _scheduleRedPacketOpenedCheck(data);
      if (mounted) {
        setState(() {});
      }
      // 本地/缓存壳已可首帧绘制：把 order-card 网络刷新推到首帧之后，
      // 避免与 list→chat 历史落地、DB reopen 抢主线程。
      if (!kIsWeb) {
        _scheduleWalletQuietRefresh(data);
      }
    }

    final cached = WalletStore.instance.peekOrderCard(
      type: args.type,
      orderId: args.orderId,
      clientOrderId: args.clientOrderId,
      currency: args.currency,
      amount: args.amount,
      status: args.status,
      greeting: args.greeting,
    );
    if (cached != null) {
      unawaited(
        presentImmediateCard(_walletImmediateDisplayCard(cached, data)),
      );
      return;
    }

    final local = _walletLocalCardFromData(data);
    if (local != null) {
      unawaited(presentImmediateCard(local));
      return;
    }

    if (kIsWeb) {
      _walletLoading = false;
      _walletCard = WalletOrderCardDto(
        ok: false,
        type: args.type,
        status: args.status ?? 'failed',
        amount: '',
        coin: '',
        title: TIM_t('钱包消息'),
        msg: TIM_t('请在移动端查看'),
      );
      _seedExclusiveMetaFromPayload(data);
      if (mounted) {
        setState(() {});
      }
      return;
    }

    final existing = _walletCard;
    if (existing != null && existing.ok && !existing.invalid) {
      _walletLoading = false;
      _scheduleWalletQuietRefresh(data);
      return;
    }

    // Last resort: unknown wallet type without a local shell. Prefer keeping
    // whatever card we already painted over flashing the gray spinner.
    _walletLoading = _walletCard == null;
    if (_walletCard == null && mounted) {
      setState(() {});
    }

    _loadWalletCardFromData(data).then((card) {
      _mergeWalletCardFromNetwork(
        card: card,
        cacheKey: cacheKey,
        data: data,
        isFirstPaint: true,
      );
    });
  }

  void _mergeWalletCardFromNetwork({
    required WalletOrderCardDto card,
    required String cacheKey,
    required Map<String, dynamic> data,
    required bool isFirstPaint,
    int attempt = 0,
  }) {
    if (!mounted || _walletCacheKey != cacheKey) return;
    final globalModel = Provider.of<TUIChatGlobalModel>(context, listen: false);
    if (!isFirstPaint && globalModel.isChatListUserScrolling && attempt < 12) {
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        _mergeWalletCardFromNetwork(
          card: card,
          cacheKey: cacheKey,
          data: data,
          isFirstPaint: isFirstPaint,
          attempt: attempt + 1,
        );
      });
      return;
    }
    if (isFirstPaint) {
      final secured = _securedWalletCard(card);
      final visible = retainWalletCardDisplayAmount(
        next: _walletVisibleCardForInvalid(
              secured: secured,
              data: data,
            ) ??
            secured,
        previous: _walletCard,
      );
      setState(() {
        _walletLoading = false;
        _walletCard = visible;
      });
      if (secured.invalid && !visible.invalid) {
        _scheduleWalletInvalidRetry(data);
      }
      if (visible.invalid) {
        return;
      }
      _seedExclusiveMetaFromPayload(data);
      _primeExclusiveReceiverFaceFromCache(data);
      _scheduleExclusiveReceiverFaceResolve(data, _exclusiveMeta);
      _maybeLoadExclusiveMeta(data, visible);
      _maybeResolvePacketType(data);
      _scheduleRedPacketOpenedCheck(data);
      return;
    }
    final secured = _securedWalletCard(card);
    final visible = retainWalletCardDisplayAmount(
      next: _walletVisibleCardForInvalid(
            secured: secured,
            data: data,
            previous: _walletCard,
          ) ??
          secured,
      previous: _walletCard,
    );
    final prev = _walletCard;
    final needsRebuild = walletCardQuietMergeNeedsRebuild(
      previous: prev,
      next: visible,
    );
    // Always keep the latest DTO in memory (amount fill / status), but avoid
    // setState for title/msg-only API churn that flashes the card on enter.
    _walletLoading = false;
    _walletCard = visible;
    if (needsRebuild && mounted) {
      setState(() {});
    }
    if (secured.invalid && !visible.invalid) {
      _scheduleWalletInvalidRetry(data);
    } else if (!secured.invalid) {
      _walletInvalidRetryTimer?.cancel();
      _walletInvalidRetryTimer = null;
      _walletInvalidRetryAttempt = 0;
    }
    if (!visible.invalid) {
      _maybeLoadExclusiveMeta(data, visible);
    }
  }

  Future<void> _fetchAndMergeWalletCard(Map<String, dynamic> data) async {
    if (_walletQuietRefreshInFlight) return;
    _walletQuietRefreshInFlight = true;
    final cacheKey = _walletCacheKeyFromData(data);
    try {
      final card = await _loadWalletCardFromData(data);
      if (!mounted || _walletCacheKey != cacheKey) return;
      _mergeWalletCardFromNetwork(
        card: card,
        cacheKey: cacheKey,
        data: data,
        isFirstPaint: false,
      );
    } finally {
      _walletQuietRefreshInFlight = false;
    }
  }

  _WalletLoadArgs _walletLoadArgs(Map<String, dynamic> data) {
    final currency = data['currency']?.toString() ?? '';
    final amountRaw = data['amount'];
    final status = data['status']?.toString() ?? '';
    final greeting = data['greeting']?.toString() ?? '';
    return _WalletLoadArgs(
      type: data['type']?.toString() ?? '',
      orderId: resolveRedPacketServerId(data),
      clientOrderId: resolveRedPacketClientOrderId(data),
      currency: currency.isNotEmpty ? currency : null,
      amount: amountRaw is int
          ? amountRaw
          : int.tryParse(amountRaw?.toString() ?? ''),
      status: status.isNotEmpty ? status : null,
      greeting: greeting.isNotEmpty ? greeting : null,
    );
  }

  WalletOrderCardDto? _walletLocalCardFromData(Map<String, dynamic> data) {
    final args = _walletLoadArgs(data);
    return WalletStore.buildLocalOrderCard(
      type: args.type,
      currency: args.currency,
      amount: args.amount,
      status: args.status,
      greeting: args.greeting,
    );
  }

  WalletOrderCardDto _walletImmediateDisplayCard(
    WalletOrderCardDto card,
    Map<String, dynamic> data,
  ) {
    final secured = _securedWalletCard(card);
    if (!secured.invalid) return secured;
    return _walletVisibleCardForInvalid(
          secured: secured,
          data: data,
          previous: null,
        ) ??
        secured;
  }

  WalletOrderCardDto? _walletVisibleCardForInvalid({
    required WalletOrderCardDto secured,
    required Map<String, dynamic> data,
    WalletOrderCardDto? previous,
  }) {
    if (!secured.invalid) return secured;
    if (previous != null && previous.ok && !previous.invalid) {
      return previous;
    }
    if (!(widget.message.isSelf ?? false)) {
      return null;
    }
    return _walletLocalCardFromData(data);
  }

  void _scheduleWalletInvalidRetry(Map<String, dynamic> data) {
    if (kIsWeb) return;
    if (_walletInvalidRetryAttempt >= 3) return;
    if (_walletInvalidRetryTimer?.isActive ?? false) return;
    final cacheKey = _walletCacheKeyFromData(data);
    final delays = const [
      Duration(milliseconds: 700),
      Duration(milliseconds: 1400),
      Duration(milliseconds: 2600),
    ];
    final delay = delays[_walletInvalidRetryAttempt];
    _walletInvalidRetryAttempt += 1;
    _walletInvalidRetryTimer = Timer(delay, () {
      if (!mounted || _walletCacheKey != cacheKey) return;
      _invalidateWalletCardCache(data);
      unawaited(_fetchAndMergeWalletCard(data));
    });
  }

  void _invalidateWalletCardCache(Map<String, dynamic> data) {
    final args = _walletLoadArgs(data);
    WalletStore.instance.invalidateOrderCard(
      type: args.type,
      orderId: args.orderId,
      clientOrderId: args.clientOrderId,
      currency: args.currency,
      amount: args.amount,
      status: args.status,
      greeting: args.greeting,
    );
  }

  Future<WalletOrderCardDto> _loadWalletCardFromData(
    Map<String, dynamic> data,
  ) {
    final args = _walletLoadArgs(data);
    return _loadWalletCard(
      type: args.type,
      orderId: args.orderId,
      clientOrderId: args.clientOrderId,
      currency: args.currency,
      amount: args.amount,
      status: args.status,
      greeting: args.greeting,
    );
  }

  Future<void> _refreshWalletCardQuietly(
    Map<String, dynamic> data, {
    Duration delay = const Duration(milliseconds: 320),
  }) async {
    if (_walletQuietRefreshInFlight) return;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (!mounted) return;
    await _fetchAndMergeWalletCard(data);
  }

  bool _shouldListenRedPacketSenderRefresh(Map<String, dynamic>? data) {
    if (kIsWeb || data == null) return false;
    if (!(widget.message.isSelf ?? false)) return false;
    if (data['type']?.toString() != 'wallet_red_packet') return false;
    final groupId = widget.message.groupID?.trim() ?? '';
    return groupId.isNotEmpty;
  }

  List<String> _redPacketStorageKeys(Map<String, dynamic> data) {
    final keys = <String>{};
    final orderId = data['orderId']?.toString().trim() ?? '';
    final clientOrderId = data['clientOrderId']?.toString().trim() ?? '';
    if (orderId.isNotEmpty) keys.add(orderId);
    if (clientOrderId.isNotEmpty) keys.add(clientOrderId);
    return keys.toList(growable: false);
  }

  RedPacketOpenedRecord? _peekRedPacketOpenedRecord(Map<String, dynamic> data) {
    for (final key in _redPacketStorageKeys(data)) {
      final record = RedPacketLocalStore.instance.peekOpened(orderId: key);
      if (record != null) return record;
    }
    return null;
  }

  void _applyRedPacketOpenedRecord(
    RedPacketOpenedRecord? record, {
    bool notify = true,
  }) {
    final opened = record != null;
    final claimed = record?.claimed ?? false;
    if (_redPacketOpenedLocally == opened &&
        _redPacketClaimedLocally == claimed) {
      return;
    }
    if (!notify) {
      _redPacketOpenedLocally = opened;
      _redPacketClaimedLocally = claimed;
      return;
    }
    setState(() {
      _redPacketOpenedLocally = opened;
      _redPacketClaimedLocally = claimed;
    });
  }

  /// Fill opened/claimed from disk before the first paint when possible, so
  /// entering a chat does not flash bright → dimmed for already-opened packets.
  Future<void> _hydrateRedPacketOpenedBeforeFirstPaint(
    Map<String, dynamic> data,
  ) async {
    if (kIsWeb) return;
    if (data['type']?.toString() != 'wallet_red_packet') return;
    final keys = _redPacketStorageKeys(data);
    if (keys.isEmpty) return;

    final peek = _peekRedPacketOpenedRecord(data);
    if (peek != null) {
      _applyRedPacketOpenedRecord(peek, notify: false);
      return;
    }

    try {
      RedPacketOpenedRecord? record;
      for (final key in keys) {
        record = await RedPacketLocalStore.instance
            .getOpened(orderId: key)
            .timeout(const Duration(milliseconds: 80));
        if (record != null) break;
      }
      if (record != null) {
        _applyRedPacketOpenedRecord(record, notify: false);
      }
    } on TimeoutException {
      // Disk still loading — [_scheduleRedPacketOpenedCheck] finishes after paint.
    } catch (_) {}
  }

  void _scheduleRedPacketOpenedCheck(Map<String, dynamic> data) {
    if (kIsWeb) return;
    if (data['type']?.toString() != 'wallet_red_packet') return;
    final keys = _redPacketStorageKeys(data);
    if (keys.isEmpty) return;

    final peek = _peekRedPacketOpenedRecord(data);
    if (peek != null) {
      _applyRedPacketOpenedRecord(peek);
    }

    final checkKey = keys.join('|');
    if (_redPacketOpenedCheckKey == checkKey && _redPacketOpenedCheckInFlight) {
      return;
    }
    // Memory already hydrated — skip another disk round-trip this mount.
    if (peek != null && _redPacketOpenedLocally) {
      _redPacketOpenedCheckKey = checkKey;
      return;
    }
    _redPacketOpenedCheckKey = checkKey;
    _redPacketOpenedCheckInFlight = true;
    unawaited(_loadRedPacketOpenedState(keys));
  }

  Future<void> _loadRedPacketOpenedState(
    List<String> keys, {
    bool notify = true,
  }) async {
    final checkKey = keys.join('|');
    try {
      RedPacketOpenedRecord? record;
      for (final key in keys) {
        record = await RedPacketLocalStore.instance.getOpened(orderId: key);
        if (record != null) break;
      }
      if (!mounted || _redPacketOpenedCheckKey != checkKey) return;
      if (record != null || !_redPacketOpenedLocally) {
        _applyRedPacketOpenedRecord(record, notify: notify);
      }
    } finally {
      if (mounted && _redPacketOpenedCheckKey == checkKey) {
        _redPacketOpenedCheckInFlight = false;
      }
    }
  }

  Future<void> _markRedPacketOpenedLocally({
    required Map<String, dynamic> data,
    required String orderId,
    bool claimed = false,
  }) async {
    final keys = _redPacketStorageKeys(data);
    if (keys.isEmpty && orderId.trim().isEmpty) return;

    await RedPacketLocalStore.instance.markOpened(
      orderId: orderId.trim().isNotEmpty ? orderId.trim() : keys.first,
      claimed: claimed,
      aliasOrderIds: keys,
    );
    if (!mounted) return;
    setState(() {
      _redPacketOpenedLocally = true;
      _redPacketClaimedLocally = claimed || _redPacketClaimedLocally;
      _redPacketOpenedCheckKey = keys.join('|');
    });
  }

  void _syncRedPacketSenderRefreshListener(Map<String, dynamic>? data) {
    _setRedPacketSenderRefreshListening(
      _shouldListenRedPacketSenderRefresh(data),
    );
  }

  void _setRedPacketSenderRefreshListening(bool listening) {
    if (_redPacketSenderRefreshListening == listening) {
      return;
    }
    if (listening) {
      RedPacketSenderRefreshBus.instance.revision
          .addListener(_onRedPacketSenderRefresh);
    } else {
      RedPacketSenderRefreshBus.instance.revision
          .removeListener(_onRedPacketSenderRefresh);
    }
    _redPacketSenderRefreshListening = listening;
  }

  void _onRedPacketSenderRefresh() {
    final event = RedPacketSenderRefreshBus.instance.lastRefresh.value;
    final data = _walletData;
    if (event == null || data == null || !mounted) return;
    if (!_matchesRedPacketSenderRefresh(event, data)) return;

    final next = Map<String, dynamic>.from(data);
    if (event.remainingCount != null) {
      next['remainingCount'] = event.remainingCount;
      final total = _packetCountText(next);
      final remaining = event.remainingCount!;
      if (total != null) {
        final totalCount = int.tryParse(total) ?? 0;
        if (totalCount > 0) {
          final claimed = math.max(0, totalCount - remaining);
          next['claimedCount'] = claimed;
        }
      }
    }
    final packetStatus = event.packetStatus?.trim().toUpperCase() ?? '';
    if (event.action == 'expired' || packetStatus == 'REFUNDED') {
      next['status'] = 'expired';
    } else if (packetStatus == 'COMPLETED' ||
        (event.remainingCount != null && event.remainingCount! <= 0)) {
      next['status'] = 'empty';
    } else if (packetStatus == 'ACTIVE') {
      final currentStatus =
          next['status']?.toString().trim().toLowerCase() ?? '';
      if (currentStatus.isEmpty || currentStatus == 'active') {
        next['status'] = 'active';
      }
    }

    setState(() {
      _walletData = next;
      if (_walletCard != null) {
        final status = next['status']?.toString().trim() ?? '';
        if (status.isNotEmpty) {
          _walletCard = _walletCardWithStatus(_walletCard!, status);
        }
      }
    });
    unawaited(_refreshWalletCardQuietly(next, delay: Duration.zero));
  }

  bool _matchesRedPacketSenderRefresh(
    RedPacketSenderRefreshEvent event,
    Map<String, dynamic> data,
  ) {
    if (!matchesRedPacketPacketKey(data, packetId: event.packetId)) {
      return false;
    }
    final groupId = widget.message.groupID?.trim() ?? '';
    final eventGroupId = event.groupId?.trim() ?? '';
    if (groupId.isNotEmpty &&
        eventGroupId.isNotEmpty &&
        groupId != eventGroupId) {
      return false;
    }
    return true;
  }

  Future<String> _resolveRedPacketApiId(Map<String, dynamic> data) async {
    final serverId = resolveRedPacketServerId(data);
    if (serverId.isNotEmpty) return serverId;

    final clientId = resolveRedPacketClientOrderId(data);
    if (clientId.isEmpty) return '';

    final draft =
        await WalletCardSendService().pendingCardForOrderKeys([clientId]);
    final recovered = draft?.serverOrderId.trim() ?? '';
    if (isRedPacketServerId(recovered)) {
      if (mounted) {
        setState(() {
          _walletData = Map<String, dynamic>.from(_walletData ?? data)
            ..['orderId'] = recovered;
        });
      }
      return recovered;
    }
    return '';
  }

  void _maybeResolvePacketType(Map<String, dynamic> data) {
    if (kIsWeb) return;
    if (data['type']?.toString() != 'wallet_red_packet') return;
    final existing = data['packetType']?.toString().trim() ?? '';
    if (existing.isNotEmpty) return;

    final serverOrderId = resolveRedPacketServerId(data);
    if (serverOrderId.isEmpty) return;

    final key = 'ptype|$serverOrderId';
    if (_packetTypeResolveKey == key) return;
    _packetTypeResolveKey = key;
    unawaited(_fetchPacketType(serverOrderId, data));
  }

  Future<void> _fetchPacketType(
    String orderId,
    Map<String, dynamic> data,
  ) async {
    try {
      final order = await WalletApi.instance.getRedPacketOrder(orderId);
      final packetType = order.data['packetType']?.toString().trim() ?? '';
      if (!mounted || packetType.isEmpty) return;
      setState(() {
        _walletData = Map<String, dynamic>.from(_walletData ?? data)
          ..['packetType'] = packetType;
      });
      if (packetType == 'EXCLUSIVE') {
        final merged = Map<String, dynamic>.from(_walletData ?? data);
        _seedExclusiveMetaFromPayload(merged);
        final card = _walletCard;
        if (card != null) {
          _maybeLoadExclusiveMeta(merged, card);
        }
      }
    } catch (_) {}
  }

  String _resolveRedPacketPacketType(
    Map<String, dynamic> data,
    _ExclusiveRedPacketMeta? meta,
  ) {
    final packetType = data['packetType']?.toString().trim() ?? '';
    if (packetType.isNotEmpty) {
      return packetType;
    }
    if (_isExclusiveRedPacket(data, meta)) {
      return 'EXCLUSIVE';
    }
    final isGroup = widget.message.groupID?.trim().isNotEmpty ?? false;
    return isGroup ? 'NORMAL_GROUP' : 'NORMAL_C2C';
  }

  String _resolveRedPacketTypeLabel(Map<String, dynamic> data) {
    final packetType = data['packetType']?.toString().trim() ?? '';
    if (packetType.isNotEmpty) {
      return redPacketTypeLabel(packetType);
    }
    if (_exclusiveMeta != null) {
      return redPacketTypeLabel('EXCLUSIVE');
    }
    final isGroup = widget.message.groupID?.trim().isNotEmpty ?? false;
    if (!isGroup) {
      return redPacketTypeLabel('NORMAL_C2C');
    }
    return redPacketTypeLabel(null);
  }

  void _seedExclusiveMetaFromPayload(Map<String, dynamic> data) {
    final packetType =
        data['packetType']?.toString().trim().toUpperCase() ?? '';
    final receiverName = _firstNonEmpty([
      data['receiverName'],
      data['toUserName'],
      data['receiveUserName'],
    ]);
    if (packetType != 'EXCLUSIVE' && receiverName.isEmpty) {
      return;
    }

    final serverOrderId = resolveRedPacketServerId(data);
    if (serverOrderId.isEmpty) return;

    _exclusiveMetaKey = 'exclusive|$serverOrderId';
    final avatar = _firstUsableAvatar([
      data['receiverAvatar'],
      data['toUserAvatar'],
      data['receiveUserAvatar'],
    ]);
    final title = receiverName.isNotEmpty
        ? '$receiverName的专属红包'
        : (packetType == 'EXCLUSIVE' ? '专属红包' : receiverName);
    if (title.isEmpty) {
      return;
    }
    _exclusiveMeta = _ExclusiveRedPacketMeta(
      title: title,
      avatar: avatar,
    );
  }

  bool _isExclusiveRedPacket(
    Map<String, dynamic> data,
    _ExclusiveRedPacketMeta? meta,
  ) {
    final packetType =
        data['packetType']?.toString().trim().toUpperCase() ?? '';
    if (packetType == 'EXCLUSIVE') {
      return true;
    }
    return meta != null;
  }

  String _exclusiveReceiverUserId(Map<String, dynamic> data) {
    return _firstNonEmpty([
      _exclusiveReceiverUserIdOverride,
      data['toUserId'],
      data['exclusiveUserId'],
      data['receiverId'],
      data['receiveUserId'],
    ]);
  }

  _ExclusiveRedPacketMeta _mergeExclusiveMetaStable(
    _ExclusiveRedPacketMeta? current,
    _ExclusiveRedPacketMeta incoming,
  ) {
    final currentTitle = current?.title.trim() ?? '';
    if (currentTitle.endsWith('的专属红包') && currentTitle.length > 5) {
      final avatar = incoming.avatar.isNotEmpty
          ? incoming.avatar
          : (current?.avatar ?? '');
      return _ExclusiveRedPacketMeta(
        title: currentTitle,
        avatar: avatar,
      );
    }
    return incoming;
  }

  void _primeExclusiveReceiverFaceFromCache(Map<String, dynamic> data) {
    final userId = _exclusiveReceiverUserId(data);
    if (userId.isEmpty) {
      return;
    }
    final cached = _exclusiveReceiverFaceMemoryCache[userId];
    if (cached != null && cached.isNotEmpty) {
      _exclusiveReceiverFaceUrl = cached;
    }
  }

  void _storeExclusiveReceiverFace(String userId, String faceUrl) {
    final id = userId.trim();
    final face = UserAvatarHelper.usableAvatarOrEmpty(faceUrl);
    if (id.isNotEmpty && face.isNotEmpty) {
      _exclusiveReceiverFaceMemoryCache[id] = face;
    }
  }

  void _publishExclusiveReceiverFace(String faceUrl, String resolveKey) {
    if (!mounted || _exclusiveReceiverFaceResolveKey != resolveKey) {
      return;
    }
    final next = UserAvatarHelper.usableAvatarOrEmpty(faceUrl);
    if (next.isEmpty || next == _exclusiveReceiverFaceUrl) {
      return;
    }
    _exclusiveReceiverFaceUrl = next;
    final userId = resolveKey.split('|').elementAtOrNull(1)?.trim() ?? '';
    if (userId.isNotEmpty) {
      _storeExclusiveReceiverFace(userId, next);
    }

    final globalModel = Provider.of<TUIChatGlobalModel>(context, listen: false);
    void repaint() {
      if (!mounted || _exclusiveReceiverFaceUrl != next) return;
      setState(() {});
    }

    if (globalModel.isChatListUserScrolling) {
      Future<void>.delayed(const Duration(milliseconds: 160), () {
        if (!mounted) return;
        if (globalModel.isChatListUserScrolling) {
          Future<void>.delayed(const Duration(milliseconds: 240), repaint);
          return;
        }
        repaint();
      });
      return;
    }
    repaint();
  }

  void _scheduleExclusiveReceiverFaceResolve(
    Map<String, dynamic> data,
    _ExclusiveRedPacketMeta? meta,
  ) {
    if (!_isExclusiveRedPacket(data, meta)) {
      return;
    }
    _scheduleReceiverFaceResolve(
      data,
      iconHint: _exclusiveRedPacketIconUrl(data, meta),
    );
  }

  void _scheduleGroupTransferReceiverFaceResolve(Map<String, dynamic> data) {
    _scheduleReceiverFaceResolve(
      data,
      iconHint: _firstUsableAvatar([
        data['receiverAvatar'],
        data['toUserAvatar'],
        data['receiveUserAvatar'],
      ]),
    );
  }

  void _scheduleReceiverFaceResolve(
    Map<String, dynamic> data, {
    required String iconHint,
  }) {
    final userId = _exclusiveReceiverUserId(data);
    if (userId.isEmpty) {
      return;
    }

    final resolveKey =
        '${widget.message.msgID ?? widget.message.id ?? ''}|$userId|$iconHint';
    if (_exclusiveReceiverFaceResolveKey == resolveKey) {
      if (_exclusiveReceiverFaceUrl?.trim().isNotEmpty ?? false) {
        return;
      }
      if (_exclusiveFaceResolveInFlight) {
        return;
      }
    }
    _exclusiveReceiverFaceResolveKey = resolveKey;

    final cached = _exclusiveReceiverFaceMemoryCache[userId];
    if (cached != null && cached.isNotEmpty) {
      _publishExclusiveReceiverFace(cached, resolveKey);
      return;
    }

    final syncFace = UserAvatarHelper.usableAvatarOrEmpty(iconHint);
    if (syncFace.isNotEmpty) {
      _storeExclusiveReceiverFace(userId, syncFace);
      _publishExclusiveReceiverFace(syncFace, resolveKey);
      return;
    }

    final groupFace = UserAvatarHelper.groupMemberFaceUrl(
      widget.message.groupID,
      userId,
    );
    if (groupFace.isNotEmpty) {
      _storeExclusiveReceiverFace(userId, groupFace);
      _publishExclusiveReceiverFace(groupFace, resolveKey);
      return;
    }

    if (_exclusiveFaceResolveInFlight) {
      return;
    }
    _exclusiveFaceResolveInFlight = true;
    UserAvatarHelper.resolveChatPeerFaceUrl(
      peerUserId: userId,
      messageFaceUrl: iconHint,
      groupId: widget.message.groupID,
    ).then((resolved) {
      _exclusiveFaceResolveInFlight = false;
      if (!mounted || _exclusiveReceiverFaceResolveKey != resolveKey) {
        return;
      }
      final next = UserAvatarHelper.usableAvatarOrEmpty(resolved);
      if (next.isEmpty) {
        return;
      }
      _storeExclusiveReceiverFace(userId, next);
      _publishExclusiveReceiverFace(next, resolveKey);
    });
  }

  String _exclusiveCardTitle(
    Map<String, dynamic> data,
    _ExclusiveRedPacketMeta? meta,
  ) {
    final name = _exclusiveReceiverName(data, meta);
    if (name.isNotEmpty) {
      return '$name的专属红包';
    }
    final title = meta?.title.trim() ?? '';
    if (title.isNotEmpty) {
      return title;
    }
    return TIM_t('专属红包');
  }

  String _exclusiveReceiverName(
    Map<String, dynamic> data,
    _ExclusiveRedPacketMeta? meta,
  ) {
    final direct = _firstNonEmpty([
      data['receiverName'],
      data['toUserName'],
      data['receiveUserName'],
    ]);
    if (direct.isNotEmpty) {
      return direct;
    }
    final title = meta?.title.trim() ?? '';
    if (title.endsWith('的专属红包') && title.length > 5) {
      return title.substring(0, title.length - 5);
    }
    return '';
  }

  String _firstUsableAvatar(List<Object?> values) {
    for (final value in values) {
      final text = UserAvatarHelper.usableAvatarOrEmpty(value?.toString());
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  String _exclusiveRedPacketIconUrl(
    Map<String, dynamic> data,
    _ExclusiveRedPacketMeta? meta,
  ) {
    if (!_isExclusiveRedPacket(data, meta)) {
      return '';
    }
    return _firstUsableAvatar([
      meta?.avatar,
      data['receiverAvatar'],
      data['toUserAvatar'],
      data['receiveUserAvatar'],
    ]);
  }

  void _maybeLoadExclusiveMeta(
    Map<String, dynamic> data,
    WalletOrderCardDto card,
  ) {
    if (kIsWeb) return;
    if (card.type != 'wallet_red_packet') return;
    if (!_isExclusiveRedPacket(data, _exclusiveMeta)) {
      final packetType =
          data['packetType']?.toString().trim().toUpperCase() ?? '';
      if (packetType.isNotEmpty && packetType != 'EXCLUSIVE') {
        return;
      }
      final hasReceiver = _firstNonEmpty([
        data['toUserId'],
        data['exclusiveUserId'],
        data['receiverId'],
        data['receiverName'],
        data['toUserName'],
      ]).isNotEmpty;
      if (!hasReceiver) {
        return;
      }
    }

    final serverOrderId = resolveRedPacketServerId(data);
    if (serverOrderId.isEmpty) return;

    final metaKey = 'exclusive|$serverOrderId';
    final cachedAvatar = _exclusiveRedPacketIconUrl(data, _exclusiveMeta);
    if (_exclusiveMetaKey == metaKey &&
        _exclusiveMeta != null &&
        cachedAvatar.isNotEmpty) {
      return;
    }
    _exclusiveMetaKey = metaKey;

    _loadExclusiveMeta(serverOrderId, data).then((meta) {
      if (!mounted || _exclusiveMetaKey != metaKey) return;
      if (meta == null) return;

      final mergedMeta = _mergeExclusiveMetaStable(_exclusiveMeta, meta);

      var face =
          UserAvatarHelper.usableAvatarOrEmpty(_exclusiveReceiverFaceUrl);
      final uid = _exclusiveReceiverUserId(data);
      if (face.isEmpty && uid.isNotEmpty) {
        face = UserAvatarHelper.usableAvatarOrEmpty(
          _exclusiveReceiverFaceMemoryCache[uid],
        );
      }
      if (face.isEmpty) {
        face = UserAvatarHelper.usableAvatarOrEmpty(
          _firstUsableAvatar([mergedMeta.avatar]),
        );
      }
      if (face.isEmpty) {
        face = UserAvatarHelper.groupMemberFaceUrl(
          widget.message.groupID,
          uid,
        );
      }

      setState(() {
        _exclusiveMeta = mergedMeta;
        if (face.isNotEmpty) {
          _exclusiveReceiverFaceUrl = face;
          if (uid.isNotEmpty) {
            _storeExclusiveReceiverFace(uid, face);
          }
        }
      });

      if (face.isEmpty && uid.isNotEmpty) {
        _scheduleExclusiveReceiverFaceResolve(data, mergedMeta);
      }
    });
  }

  void _showJumpColor() {
    _jumpHighlightTimer = MessageJumpHighlight.play(
      mounted: () => mounted,
      getIsShining: () => isShining,
      setIsShining: (value) => isShining = value,
      setState: setState,
      applyHighlight: (highlighted, {border}) {
        isShowJumpState = highlighted;
        if (border != null) {
          isShowBorder = border;
        }
      },
      clearJump: () => widget.clearJump?.call(),
      previousTimer: _jumpHighlightTimer,
    );
  }

  Map<String, dynamic>? _walletPayload(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final data = Map<String, dynamic>.from(decoded);

      final customType = data['customType']?.toString() ?? '';
      final legacyType = data['type']?.toString() ?? '';
      final businessID = data['businessID']?.toString() ?? '';

      String? cardType;
      if (customType == 'wallet_transfer' || legacyType == 'wallet_transfer') {
        cardType = 'wallet_transfer';
      } else if (customType == 'wallet_group_transfer' ||
          legacyType == 'wallet_group_transfer') {
        cardType = 'wallet_group_transfer';
      } else if (customType == 'wallet_red_packet' ||
          legacyType == 'wallet_red_packet') {
        cardType = 'wallet_red_packet';
      } else if (businessID == 'wallet_order') {
        cardType = legacyType;
      }
      if (cardType == null || cardType.isEmpty) return null;

      final serverOrderId = resolveRedPacketServerId(data);
      final clientOrderId = resolveRedPacketClientOrderId(data);
      if (serverOrderId.isEmpty && clientOrderId.isEmpty) return null;

      final payload = <String, dynamic>{
        'type': cardType,
        'orderId': serverOrderId,
        'clientOrderId': clientOrderId,
        'currency': data['currency']?.toString() ?? '',
        'amount': data['amount'],
        'status': data['status']?.toString() ?? '',
        'greeting': data['greeting']?.toString() ??
            data['memo']?.toString() ??
            data['msg']?.toString() ??
            '',
        'memo': data['memo']?.toString() ??
            data['greeting']?.toString() ??
            data['msg']?.toString() ??
            '',
      };
      for (final key in const [
        'packetCount',
        'count',
        'cnt',
        'totalCount',
        'claimedCount',
        'progress',
        'senderId',
        'senderUserId',
        'senderName',
        'senderNick',
        'senderAvatar',
        'fromUserId',
        'fromUserName',
        'fromUserAvatar',
        'receiverId',
        'receiverName',
        'receiverAvatar',
        'toUserId',
        'exclusiveUserId',
        'toUserName',
        'toUserAvatar',
        'receiveUserId',
        'receiveUserName',
        'receiveUserAvatar',
        'createdAt',
        'createTime',
        'transferTime',
        'receivedAt',
        'receiveTime',
        'completedAt',
        'updatedAt',
        'packetType',
      ]) {
        final value = data[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          payload[key] = value;
        }
      }
      return payload;
    } catch (_) {}
    return null;
  }

  Widget _buildWalletCardWidget() {
    return _buildWalletCardBody();
  }

  Widget _buildWalletCardBody() {
    final data = _walletData;
    if (data == null) {
      return _walletLoadingCard();
    }
    final card = _walletCard;
    if (card == null && _walletLoading) {
      return _walletLoadingCard();
    }
    if (card == null) {
      return _walletLoadingCard();
    }
    if (!card.ok) {
      return _walletErrorCard(card.msg);
    }
    return _buildWalletCardContent(card, data);
  }

  Widget _buildWalletCardContent(
    WalletOrderCardDto card,
    Map<String, dynamic> data,
  ) {
    if (card.type == 'wallet_red_packet') {
      final meta = _exclusiveMeta;
      final exclusiveIcon = _exclusiveRedPacketIconUrl(data, meta);
      final isExclusive = _isExclusiveRedPacket(data, meta);
      final receiverFaceUrl = isExclusive
          ? UserAvatarHelper.usableAvatarOrEmpty(
              _exclusiveReceiverFaceUrl ?? exclusiveIcon,
            )
          : '';
      final redPacketStatus = _resolveRedPacketCardStatus(card.status, data);
      return RedPacketCard(
        msg: card.msg.isNotEmpty ? card.msg : TIM_t('恭喜发财，大吉大利'),
        title: isExclusive ? _exclusiveCardTitle(data, meta) : meta?.title,
        typeLabel: _resolveRedPacketTypeLabel(data),
        iconUrl: exclusiveIcon.isNotEmpty ? exclusiveIcon : null,
        useReceiverAvatar: isExclusive,
        receiverUserId: isExclusive ? _exclusiveReceiverUserId(data) : null,
        receiverName: isExclusive ? _exclusiveReceiverName(data, meta) : null,
        groupId: widget.message.groupID,
        receiverFaceUrl: receiverFaceUrl.isNotEmpty ? receiverFaceUrl : null,
        packetType: _resolveRedPacketPacketType(data, meta),
        status: redPacketStatus,
        amountText: card.amount.isNotEmpty
            ? '${card.amount}${card.coin.isNotEmpty ? card.coin : ''}'
            : null,
        packetCountText: _packetCountText(data),
        progressText: _progressText(data),
        timeText: _messageTimeText(),
        isSelf: widget.message.isSelf ?? false,
        onTap: () {
          if (_shouldIgnoreWalletCardTap()) return;
          unawaited(_openRedPacketDetail(data: data, card: card));
        },
      );
    }

    if (card.type == 'wallet_transfer' ||
        card.type == 'wallet_group_transfer') {
      final isOutgoing = _isOutgoingTransfer(data);
      final memo = _transferMemo(data, card);
      final isGroupTransfer = card.type == 'wallet_group_transfer';
      if (isGroupTransfer) {
        _primeExclusiveReceiverFaceFromCache(data);
        _scheduleGroupTransferReceiverFaceResolve(data);
      }
      final receiverName =
          isGroupTransfer ? _transferReceiverName(data, isOutgoing) : '';
      final receiverUserId =
          isGroupTransfer ? _exclusiveReceiverUserId(data) : '';
      final receiverFaceUrl = isGroupTransfer
          ? UserAvatarHelper.usableAvatarOrEmpty(
              _exclusiveReceiverFaceUrl ??
                  _firstUsableAvatar([
                    data['receiverAvatar'],
                    data['toUserAvatar'],
                    data['receiveUserAvatar'],
                  ]),
            )
          : '';
      return TransferCard(
        amount: card.amount,
        coin: card.coin,
        status: isGroupTransfer ? 'success' : _walletStatusText(card.status),
        memo: (!isGroupTransfer && memo.isNotEmpty) ? memo : null,
        isSelf: isOutgoing,
        timeText: _messageTimeText(),
        isGroupTransfer: isGroupTransfer,
        receiverUserId: receiverUserId.isNotEmpty ? receiverUserId : null,
        receiverName: receiverName.isNotEmpty ? receiverName : null,
        receiverFaceUrl: receiverFaceUrl.isNotEmpty ? receiverFaceUrl : null,
        groupId: widget.message.groupID,
        onTap: () {
          if (_shouldIgnoreWalletCardTap()) return;
          unawaited(_openGroupOrC2cTransferDetail(card));
        },
      );
    }

    return _walletErrorCard(TIM_t('订单状态异常'));
  }

  Map<String, dynamic> _redPacketSeedPacket(
    Map<String, dynamic> data,
    WalletOrderCardDto card,
  ) {
    final seed = <String, dynamic>{};
    for (final key in const [
      'packetType',
      'greeting',
      'msg',
      'currency',
      'amount',
      'totalAmount',
      'packetCount',
      'count',
      'cnt',
      'totalCount',
      'claimedCount',
      'remainingCount',
      'status',
      'senderId',
      'senderName',
      'senderAvatar',
      'fromUserId',
      'fromUserName',
      'fromUserAvatar',
      'receiverId',
      'receiverName',
      'receiverAvatar',
      'toUserId',
      'exclusiveUserId',
      'toUserName',
      'toUserAvatar',
      'receiveUserId',
      'receiveUserName',
      'receiveUserAvatar',
    ]) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        seed[key] = value;
      }
    }
    if ((seed['greeting']?.toString().trim().isEmpty ?? true) &&
        card.msg.trim().isNotEmpty) {
      seed['greeting'] = card.msg.trim();
    }
    if ((seed['currency']?.toString().trim().isEmpty ?? true) &&
        card.coin.trim().isNotEmpty) {
      seed['currency'] = card.coin.trim();
    }
    if ((seed['status']?.toString().trim().isEmpty ?? true) &&
        card.status.trim().isNotEmpty) {
      seed['status'] = card.status.trim();
    }
    final groupId = widget.message.groupID?.trim() ?? '';
    if (groupId.isNotEmpty) {
      seed['chatGroupId'] = groupId;
    } else {
      final peer = (widget.message.userID ?? widget.message.sender ?? '')
          .toString()
          .trim();
      if (peer.isNotEmpty) {
        seed['chatPeerUserId'] = peer;
      }
    }
    return seed;
  }

  Future<void> _openRedPacketDetail({
    required Map<String, dynamic> data,
    required WalletOrderCardDto card,
  }) async {
    if (_shouldIgnoreWalletCardTap()) {
      return;
    }
    if (card.invalid || !card.ok) {
      ToastUtils.toast(TIM_t('无效卡片'));
      return;
    }
    final serverOrderId = await _resolveRedPacketApiId(data);
    if (serverOrderId.isEmpty) {
      ToastUtils.toast(TIM_t('红包信息异常'));
      return;
    }
    await _claimRedPacket(orderId: serverOrderId, card: card);
  }

  Future<void> _claimRedPacket({
    required String orderId,
    required WalletOrderCardDto card,
  }) async {
    if (_redPacketOverlayOpening) {
      return;
    }
    if (kIsWeb) {
      ToastUtils.toast(TIM_t('Web 端暂不支持钱包操作，请在移动端查看'));
      return;
    }
    if (orderId.trim().isEmpty) {
      ToastUtils.toast(TIM_t('订单状态异常'));
      return;
    }

    final walletData = _walletData ?? const <String, dynamic>{};
    unawaited(
      _markRedPacketOpenedLocally(
        data: walletData,
        orderId: orderId,
      ),
    );

    final meta = _exclusiveMeta;
    final packetType = _resolveRedPacketPacketType(walletData, meta);
    final senderName = _redPacketSenderName();
    final senderAvatar = widget.message.faceUrl ?? '';
    final greeting = card.msg.isNotEmpty ? card.msg : TIM_t('恭喜发财，大吉大利');
    final autoClaim = _isRedPacketClaimableStatus(card.status);

    var showOpenAnimation = false;
    var shouldAutoClaim = autoClaim;
    _redPacketOverlayOpening = true;
    try {
      final claimState =
          await WalletApi.instance.getRedPacketClaimState(orderId);
      showOpenAnimation = autoClaim && claimState.canOpen;
      if (!claimState.canOpen) {
        shouldAutoClaim = false;
      }
    } catch (_) {
      showOpenAnimation = false;
    }

    RedPacketDetailPopResult? result;
    try {
      result = await _pushWalletOverlay<RedPacketDetailPopResult>(
        _walletOverlayRoute(
          RedPacketFlowLauncher.buildOverlayPage(
            orderId: orderId,
            packetType: packetType,
            senderName: senderName,
            senderAvatar: senderAvatar,
            greeting: greeting,
            autoClaim: shouldAutoClaim,
            showOpenAnimation: showOpenAnimation,
            seedPacket: _redPacketSeedPacket(walletData, card),
          ),
        ),
      );
    } finally {
      _redPacketOverlayOpening = false;
    }
    if (!mounted) return;

    await _markRedPacketOpenedLocally(
      data: walletData,
      orderId: orderId,
      claimed: result?.claimed ?? false,
    );

    if (result != null && result.status.isNotEmpty && _walletCard != null) {
      final nextCard = _walletCardWithStatus(_walletCard!, result.status);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _walletCard == null) return;
        setState(() {
          _walletCard = nextCard;
        });
      });
      return;
    }
    if (_isRedPacketUnopenedStatus(_walletStatusCode(card.status))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          _refreshWalletCardQuietly(
            walletData,
            delay: const Duration(milliseconds: 800),
          ),
        );
      });
    }
  }

  String _transferMemo(Map<String, dynamic> data, WalletOrderCardDto card) {
    return _firstNonEmpty([
      data['memo'],
      data['greeting'],
      data['msg'],
      card.msg,
    ]);
  }

  String _imSenderDisplayName() {
    final fromUtils = MessageUtils.getDisplayName(widget.message).trim();
    if (fromUtils.isNotEmpty) {
      return fromUtils;
    }
    return _firstNonEmpty([
      widget.message.nameCard,
      widget.message.friendRemark,
      widget.message.nickName,
    ]);
  }

  bool _sameUserId(String a, String b) {
    final left = a.trim();
    final right = b.trim();
    if (left.isEmpty || right.isEmpty) {
      return false;
    }
    if (left == right) {
      return true;
    }
    final rawLeft = ChatIdFormat.rawUserUid(left);
    final rawRight = ChatIdFormat.rawUserUid(right);
    return rawLeft.isNotEmpty && rawLeft == rawRight;
  }

  String _transferSenderName(Map<String, dynamic> data, bool isOutgoing) {
    return TransferPartyNameResolver.pickPreferredName(
      userId: _transferSenderUserId(data, isOutgoing),
      groupId: widget.message.groupID,
      candidates: [
        _imSenderDisplayName(),
        widget.message.nameCard,
        widget.message.friendRemark,
        widget.message.nickName,
        data['senderNick'],
        data['senderName'],
        data['fromUserName'],
        if (isOutgoing) TIM_t('我'),
      ],
    );
  }

  String _transferReceiverName(Map<String, dynamic> data, bool isOutgoing) {
    return TransferPartyNameResolver.pickPreferredName(
      userId: _transferReceiverUserId(data, isOutgoing),
      groupId: widget.message.groupID,
      candidates: [
        data['receiverName'],
        data['toUserName'],
        data['receiveUserName'],
        if (!isOutgoing) TIM_t('我'),
      ],
    );
  }

  String _transferSenderUserId(Map<String, dynamic> data, bool isOutgoing) {
    final fromPayload = _firstNonEmpty([
      data['senderUserId'],
      data['fromUserId'],
      data['senderId'],
    ]);
    if (fromPayload.isNotEmpty) {
      return fromPayload;
    }
    final fromMessage = _firstNonEmpty([
      widget.message.sender,
      widget.message.userID,
    ]);
    if (fromMessage.isNotEmpty) {
      return fromMessage;
    }
    if (isOutgoing) {
      return TIMUIKitCore.getInstance().loginInfo.userID.trim();
    }
    return '';
  }

  String _transferReceiverUserId(Map<String, dynamic> data, bool isOutgoing) {
    final fromPayload = _firstNonEmpty([
      data['toUserId'],
      data['exclusiveUserId'],
      data['receiverId'],
      data['receiveUserId'],
    ]);
    if (fromPayload.isNotEmpty) {
      return fromPayload;
    }
    if (!isOutgoing) {
      return TIMUIKitCore.getInstance().loginInfo.userID.trim();
    }
    return '';
  }

  String _transferTimeFromPayload(
    Map<String, dynamic> data,
    List<String> keys,
    String fallback,
  ) {
    for (final key in keys) {
      final raw = data[key];
      if (raw == null) continue;
      DateTime? date;
      if (raw is num) {
        final value = raw.toInt();
        date = DateTime.fromMillisecondsSinceEpoch(
          value >= 1000000000000 ? value : value * 1000,
        );
      } else {
        final text = raw.toString().trim();
        if (text.isEmpty) continue;
        final numeric = int.tryParse(text);
        if (numeric != null) {
          date = DateTime.fromMillisecondsSinceEpoch(
            numeric >= 1000000000000 ? numeric : numeric * 1000,
          );
        } else {
          date = DateTime.tryParse(text)?.toLocal();
        }
      }
      if (date != null) return _formatWalletDetailTime(date);
    }
    return fallback;
  }

  bool _isOutgoingTransfer(Map<String, dynamic> data) {
    final currentUserId = TIMUIKitCore.getInstance().loginInfo.userID.trim();
    final senderId = _firstNonEmpty([
      data['senderUserId'],
      data['fromUserId'],
      data['senderId'],
      widget.message.sender,
      widget.message.userID,
    ]);
    if (currentUserId.isNotEmpty && senderId.isNotEmpty) {
      return _sameUserId(senderId, currentUserId);
    }
    return widget.message.isSelf ?? false;
  }

  Future<void> _openGroupOrC2cTransferDetail(WalletOrderCardDto card) async {
    if (_shouldIgnoreWalletCardTap()) {
      return;
    }
    if (card.invalid || !card.ok) {
      ToastUtils.toast(TIM_t('无效卡片'));
      return;
    }
    if (card.type != 'wallet_group_transfer') {
      await _openTransferDetail(card);
      return;
    }
    if (kIsWeb) {
      ToastUtils.toast(TIM_t('Web 端暂不支持钱包操作，请在移动端查看'));
      return;
    }
    if (!mounted) return;
    final data = _walletData;
    final timeText = _messageFullTimeText();
    var currency = data?['currency']?.toString();
    var amount = card.amount;
    var coin = card.coin;
    final isOutgoing = data != null
        ? _isOutgoingTransfer(data)
        : (widget.message.isSelf ?? false);
    var transferTime = data == null
        ? timeText
        : _transferTimeFromPayload(
            data,
            const ['transferTime', 'createdAt', 'createTime'],
            timeText,
          );
    var receiveTime = data == null
        ? timeText
        : _transferTimeFromPayload(
            data,
            const ['receivedAt', 'receiveTime', 'completedAt', 'updatedAt'],
            timeText,
          );
    var senderName = data == null
        ? _imSenderDisplayName()
        : _transferSenderName(data, isOutgoing);
    var receiverName =
        data == null ? '' : _transferReceiverName(data, isOutgoing);
    var senderUserId = data == null
        ? _firstNonEmpty([widget.message.sender, widget.message.userID])
        : _transferSenderUserId(data, isOutgoing);
    var receiverUserId =
        data == null ? '' : _transferReceiverUserId(data, isOutgoing);

    final orderId = resolveRedPacketServerId(data ?? const <String, dynamic>{});
    if (orderId.isNotEmpty) {
      try {
        final order = await WalletApi.instance.getRedPacketOrder(orderId);
        final packet = Map<String, dynamic>.from(order.data);
        final packetCurrency = packet['currency']?.toString().trim() ?? '';
        if (packetCurrency.isNotEmpty) {
          currency = packetCurrency;
        }
        final totalRaw = packet['totalAmount'];
        final totalAmount = totalRaw is int
            ? totalRaw
            : int.tryParse(totalRaw?.toString() ?? '') ?? 0;
        final resolvedCurrency = currency?.trim() ?? '';
        if (totalAmount > 0 && resolvedCurrency.isNotEmpty) {
          amount = formatWalletAmount(resolvedCurrency, totalAmount);
          coin = walletDisplayCoin(resolvedCurrency);
        }
        transferTime = _transferTimeFromPayload(
          packet,
          const ['createdAt', 'createTime', 'transferTime'],
          transferTime,
        );
        receiveTime = _transferTimeFromPayload(
          packet,
          const ['completedAt', 'updatedAt', 'receivedAt', 'receiveTime'],
          receiveTime,
        );
        final groupId = widget.message.groupID;
        final enrichedReceiverId = _firstNonEmpty([
          packet['toUserId'],
          packet['exclusiveUserId'],
          packet['receiverId'],
          packet['receiveUserId'],
          receiverUserId,
        ]);
        if (enrichedReceiverId.isNotEmpty) {
          receiverUserId = enrichedReceiverId;
        }
        final enrichedReceiver = TransferPartyNameResolver.pickPreferredName(
          userId: receiverUserId,
          groupId: groupId,
          candidates: [
            receiverName,
            packet['receiverName'],
            packet['toUserName'],
            packet['receiveUserName'],
          ],
        );
        if (enrichedReceiver.isNotEmpty) {
          receiverName = enrichedReceiver;
        }
        final enrichedSenderId = _firstNonEmpty([
          packet['senderUserId'],
          packet['fromUserId'],
          packet['senderId'],
          senderUserId,
        ]);
        if (enrichedSenderId.isNotEmpty) {
          senderUserId = enrichedSenderId;
        }
        final enrichedSender = TransferPartyNameResolver.pickPreferredName(
          userId: senderUserId,
          groupId: groupId,
          candidates: [
            senderName,
            packet['senderNick'],
            packet['senderName'],
            packet['fromUserName'],
          ],
        );
        if (enrichedSender.isNotEmpty) {
          senderName = enrichedSender;
        }
      } catch (_) {}
    }

    final resolvedNames = await TransferPartyNameResolver.resolvePair(
      senderName: senderName,
      receiverName: receiverName,
      senderUserId: senderUserId,
      receiverUserId: receiverUserId,
      groupId: widget.message.groupID,
    );
    senderName = resolvedNames.$1;
    receiverName = resolvedNames.$2;

    if (!mounted) return;
    await _pushWalletOverlay(
      _walletOverlayRoute(
        TransferDetailScreen(
          isOutgoing: isOutgoing,
          isGroupTransfer: true,
          amount: amount,
          coin: coin,
          currency: currency,
          memo: null,
          senderName: senderName,
          receiverName: receiverName,
          senderUserId: senderUserId,
          receiverUserId: receiverUserId,
          groupId: widget.message.groupID,
          transferTime: transferTime,
          receiveTime: receiveTime,
        ),
      ),
    );
  }

  Future<void> _openTransferDetail(WalletOrderCardDto card) async {
    if (kIsWeb) {
      ToastUtils.toast(TIM_t('Web 端暂不支持钱包操作，请在移动端查看'));
      return;
    }
    if (!mounted) return;
    final data = _walletData;
    final timeText = _messageFullTimeText();
    final memo = data != null ? _transferMemo(data, card) : card.msg;
    final currency = data?['currency']?.toString();
    final isOutgoing = data != null
        ? _isOutgoingTransfer(data)
        : (widget.message.isSelf ?? false);
    final transferTime = data == null
        ? timeText
        : _transferTimeFromPayload(
            data,
            const ['transferTime', 'createdAt', 'createTime'],
            timeText,
          );
    final receiveTime = data == null
        ? timeText
        : _transferTimeFromPayload(
            data,
            const ['receivedAt', 'receiveTime', 'completedAt', 'updatedAt'],
            timeText,
          );
    final senderName = data == null
        ? _imSenderDisplayName()
        : _transferSenderName(data, isOutgoing);
    final receiverName =
        data == null ? '' : _transferReceiverName(data, isOutgoing);
    final senderUserId = data == null
        ? _firstNonEmpty([widget.message.sender, widget.message.userID])
        : _transferSenderUserId(data, isOutgoing);
    final receiverUserId =
        data == null ? '' : _transferReceiverUserId(data, isOutgoing);
    final resolvedNames = await TransferPartyNameResolver.resolvePair(
      senderName: senderName,
      receiverName: receiverName,
      senderUserId: senderUserId,
      receiverUserId: receiverUserId,
      groupId: widget.message.groupID,
    );
    if (!mounted) return;
    await _pushWalletOverlay(
      _walletOverlayRoute(
        TransferDetailScreen(
          isOutgoing: isOutgoing,
          amount: card.amount,
          coin: card.coin,
          currency: currency,
          memo: memo.trim().isNotEmpty ? memo.trim() : null,
          senderName: resolvedNames.$1,
          receiverName: resolvedNames.$2,
          senderUserId: senderUserId,
          receiverUserId: receiverUserId,
          groupId: widget.message.groupID,
          transferTime: transferTime,
          receiveTime: receiveTime,
        ),
      ),
    );
  }

  String _redPacketSenderName() {
    final candidates = [
      widget.message.nickName,
      widget.message.sender,
      widget.message.userID,
    ];
    for (final value in candidates) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return TIM_t('好友');
  }

  Future<WalletOrderCardDto> _loadWalletCard({
    required String type,
    required String orderId,
    required String clientOrderId,
    String? currency,
    int? amount,
    String? status,
    String? greeting,
  }) async {
    try {
      return await WalletStore.instance.getOrderCard(
        repo: createWalletRepository(),
        type: type,
        orderId: orderId,
        clientOrderId: clientOrderId,
        currency: currency,
        amount: amount,
        status: status,
        greeting: greeting,
      );
    } catch (_) {
      return WalletOrderCardDto(
        ok: false,
        type: '',
        status: 'failed',
        amount: '',
        coin: '',
        title: TIM_t('订单异常'),
        msg: TIM_t('无法加载订单状态'),
      );
    }
  }

  Future<_ExclusiveRedPacketMeta?> _loadExclusiveMeta(
    String orderId,
    Map<String, dynamic> payload,
  ) async {
    final id = orderId.trim();
    if (id.isEmpty) return null;
    try {
      final order = await WalletApi.instance.getRedPacketOrder(id);
      final packet = Map<String, dynamic>.from(order.data);
      final packetType =
          packet['packetType']?.toString().trim().toUpperCase() ?? '';
      if (packetType != 'EXCLUSIVE') return null;

      final receiverUserId = _firstNonEmpty([
        packet['toUserId'],
        packet['exclusiveUserId'],
        packet['receiverId'],
        packet['receiveUserId'],
        payload['toUserId'],
        payload['exclusiveUserId'],
        payload['receiverId'],
      ]);
      if (receiverUserId.isNotEmpty) {
        _exclusiveReceiverUserIdOverride = receiverUserId;
      }
      var receiverName = _firstNonEmpty([
        packet['receiverName'],
        packet['toUserName'],
        packet['receiveUserName'],
        payload['receiverName'],
      ]);

      String avatar = _firstUsableAvatar([
        packet['receiverAvatar'],
        packet['toUserAvatar'],
        packet['receiveUserAvatar'],
        payload['receiverAvatar'],
        payload['toUserAvatar'],
        payload['receiveUserAvatar'],
      ]);

      // 专属红包的 xxx 统一使用领取人/接收人；如果详情里没给人，就从 claims 里补。
      var titleSeed = receiverName.isNotEmpty ? receiverName : receiverUserId;
      if (titleSeed.isEmpty) {
        try {
          final claims = await WalletApi.instance.getRedPacketClaims(id);
          if (claims.isNotEmpty) {
            final firstClaim = claims.first;
            receiverName = _firstNonEmpty([
              firstClaim['userName'],
              firstClaim['nickName'],
            ]);
            final claimedUserId = _firstNonEmpty([
              firstClaim['userId'],
              firstClaim['receiverId'],
            ]);
            titleSeed = receiverName.isNotEmpty ? receiverName : claimedUserId;
            if (receiverUserId.isEmpty && claimedUserId.isNotEmpty) {
              // use claimer as designated receiver fallback
              avatar = avatar;
            }
            if (avatar.isEmpty) {
              avatar = _firstUsableAvatar([
                firstClaim['avatar'],
                firstClaim['faceUrl'],
              ]);
            }
            if (receiverName.isEmpty && claimedUserId.isNotEmpty) {
              receiverName = claimedUserId;
            }
            if (titleSeed.isEmpty && claimedUserId.isNotEmpty) {
              titleSeed = claimedUserId;
            }
          }
        } catch (_) {}
      }

      if (titleSeed.isEmpty) {
        return const _ExclusiveRedPacketMeta(title: '专属红包', avatar: '');
      }

      var title = '$titleSeed的专属红包';
      final infoLookupUserId =
          receiverUserId.isNotEmpty ? receiverUserId : receiverName;
      if (infoLookupUserId.isNotEmpty) {
        try {
          final res = await TencentImSDKPlugin.v2TIMManager.getUsersInfo(
            userIDList: [infoLookupUserId],
          );
          final user = (res.data?.isNotEmpty ?? false) ? res.data!.first : null;
          final nick = user?.nickName?.trim() ?? '';
          if (nick.isNotEmpty) {
            title = '$nick的专属红包';
          }
          final fetchedAvatar =
              UserAvatarHelper.usableAvatarOrEmpty(user?.faceUrl);
          if (fetchedAvatar.isNotEmpty) {
            avatar = fetchedAvatar;
          }
        } catch (_) {}
      }

      return _ExclusiveRedPacketMeta(title: title, avatar: avatar);
    } catch (_) {
      final fallbackReceiver = _firstNonEmpty([
        payload['receiverName'],
        payload['toUserId'],
        payload['exclusiveUserId'],
        payload['receiverId'],
      ]);
      if (fallbackReceiver.isNotEmpty) {
        return _ExclusiveRedPacketMeta(
          title: '$fallbackReceiver的专属红包',
          avatar: _firstUsableAvatar([payload['receiverAvatar']]),
        );
      }
      return null;
    }
  }

  String _firstNonEmpty(List<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != 'null') {
        return text;
      }
    }
    return '';
  }

  WalletOrderCardDto _securedWalletCard(WalletOrderCardDto card) {
    if (card.invalid) {
      return WalletOrderCardDto.invalidCard();
    }
    final groupId = widget.message.groupID?.trim() ?? '';
    final reason = WalletCardIntegrity.evaluate(
      restSenderUserId: card.senderUserId,
      messageSender: widget.message.sender ?? '',
      restGroupId: card.groupId,
      messageGroupId: groupId,
      isGroupMessage: groupId.isNotEmpty,
    );
    if (reason == WalletCardInvalidReason.none) {
      return card;
    }
    return WalletOrderCardDto.invalidCard();
  }

  Widget _walletLoadingCard() {
    return Container(
      width: double.infinity,
      constraints:
          BoxConstraints(minHeight: ChatWalletCardMetrics.minCardHeight),
      padding: EdgeInsets.symmetric(
        horizontal: ChatWalletCardMetrics.w(16),
        vertical: ChatWalletCardMetrics.h(14),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(TIM_t('正在确认订单')),
        ],
      ),
    );
  }

  Widget _walletErrorCard(String text) {
    return Container(
      width: double.infinity,
      constraints:
          BoxConstraints(minHeight: ChatWalletCardMetrics.minCardHeight),
      padding: EdgeInsets.symmetric(
        horizontal: ChatWalletCardMetrics.w(16),
        vertical: ChatWalletCardMetrics.h(14),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFFE53935),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _walletStatusCode(String status) {
    switch (status.trim().toLowerCase()) {
      case 'success':
      case 'completed':
      case 'credited':
        return 'success';
      case 'failed':
      case 'failure':
      case 'error':
        return 'failed';
      case 'expired':
        return 'expired';
      case 'refunded':
        return 'refunded';
      case 'claimed':
      case 'received':
        return 'claimed';
      case 'empty':
      case 'finished':
      case 'fully_claimed':
      case 'claimed_all':
        return 'finished';
      case 'pending':
      case 'active':
      case 'accepted':
      case 'confirming':
      case 'broadcasting':
      case 'unknown':
      case '':
        return 'pending';
      default:
        return 'pending';
    }
  }

  String _resolveRedPacketCardStatus(
    String serverStatus,
    Map<String, dynamic> data,
  ) {
    final code = _walletStatusCode(serverStatus);
    if (!_isRedPacketUnopenedStatus(code)) {
      return code;
    }

    final local = _peekRedPacketOpenedRecord(data);
    final opened = _redPacketOpenedLocally || local != null;
    final claimed = _redPacketClaimedLocally || (local?.claimed ?? false);
    if (!opened) {
      return code;
    }
    return claimed ? 'claimed' : 'viewed';
  }

  bool _isRedPacketUnopenedStatus(String code) {
    return code == 'pending' || code == 'success';
  }

  bool _isRedPacketClaimableStatus(String status) {
    return _isRedPacketUnopenedStatus(_walletStatusCode(status));
  }

  String _walletStatusText(String status) {
    switch (_walletStatusCode(status)) {
      case 'success':
        return TIM_t('成功');
      case 'failed':
        return TIM_t('失败');
      case 'expired':
        return TIM_t('已过期');
      case 'refunded':
        return TIM_t('已退款');
      case 'claimed':
        return TIM_t('已领取');
      case 'finished':
        return TIM_t('已抢完');
      case 'pending':
      default:
        return TIM_t('处理中');
    }
  }

  String? _packetCountText(Map<String, dynamic> data) {
    final candidates = [
      data['packetCount'],
      data['count'],
      data['cnt'],
      data['rpCnt'],
      data['totalCount'],
    ];
    for (final value in candidates) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != '0') return text;
    }
    return null;
  }

  String? _progressText(Map<String, dynamic> data) {
    final direct = data['progress']?.toString().trim() ?? '';
    if (direct.isNotEmpty) return direct;
    final claimed = data['claimedCount']?.toString().trim() ?? '';
    final total = _packetCountText(data) ?? '';
    if (claimed.isNotEmpty && total.isNotEmpty) return '$claimed/$total';
    return null;
  }

  String _messageTimeText() {
    final timestamp = widget.message.timestamp;
    if (timestamp == null || timestamp <= 0) return '--:--';
    final ms = timestamp >= 1000000000000 ? timestamp : timestamp * 1000;
    final date = DateTime.fromMillisecondsSinceEpoch(ms);
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _messageFullTimeText() {
    final timestamp = widget.message.timestamp;
    if (timestamp == null || timestamp <= 0) return '--';
    final ms = timestamp >= 1000000000000 ? timestamp : timestamp * 1000;
    final date = DateTime.fromMillisecondsSinceEpoch(ms);
    return _formatWalletDetailTime(date);
  }

  String _formatWalletDetailTime(DateTime date) {
    final yyyy = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    final ss = date.second.toString().padLeft(2, '0');
    return '$yyyy-$month-$day $hh:$mm:$ss';
  }

  Widget _callElemBuilder(BuildContext context, TUITheme theme) {
    final customElem = widget.message.customElem;
    final platformNotice =
        tryBuildPlatformWalletNoticeMessageItem(widget.message);
    if (platformNotice != null) {
      return renderMessageItem(
        platformNotice,
        theme,
        false,
        maxWidth: 300,
        skipBubbleDecoration: true,
      );
    }

    final groupLivePayload = parseGroupLivePayload(widget.message);
    if (groupLivePayload != null && groupLivePayload.isCard) {
      return renderMessageItem(
        GroupLiveMessageCard(
          payload: groupLivePayload,
          onTap: () => unawaited(
            GroupLiveNavigator.openFromPayload(
              context,
              payload: groupLivePayload,
            ),
          ),
        ),
        theme,
        false,
        maxWidth: 300,
        skipBubbleDecoration: true,
      );
    }

    final walletData = _walletPayload(customElem?.data);
    if (walletData != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final cardCap = ChatWalletCardMetrics.desktopMaxWidthForChat();
          final rowWidth =
              constraints.maxWidth.isFinite && constraints.maxWidth > 0
                  ? constraints.maxWidth
                  : chatMessageMaxWidth(
                      context,
                      desktopMaxWidth: cardCap,
                      desktopFactor: 0.40,
                      mobileFactor: 0.70,
                    );
          final availableWidth = math.max(
            ChatWalletCardMetrics.minWidth,
            rowWidth - 48.0,
          );
          final walletMessageMaxWidth = math.min(availableWidth, cardCap);
          return renderMessageItem(
            ClipRect(
              clipBehavior: Clip.hardEdge,
              child: _buildWalletCardWidget(),
            ),
            theme,
            false,
            maxWidth: walletMessageMaxWidth,
            skipBubbleDecoration: true,
          );
        },
      );
    }

    final callingMessageDataProvider =
        CallingMessageDataProvider(widget.message);

    final articleMessage =
        parseOfficialAccountArticleFromMessage(widget.message);
    final linkMessage = getLinkMessage(customElem);
    final webLinkMessage = getWebLinkMessage(customElem);
    final contactCardMessage = getContactCardMessage(customElem);

    final friendBecameFriendsText =
        getFriendBecameFriendsDisplayText(customElem);
    final claimNoticePayload = parseRedPacketClaimNoticePayload(customElem);
    final claimNoticeText = claimNoticePayload == null
        ? ''
        : redPacketClaimNoticeDisplayText(claimNoticePayload);

    if (customElem?.data == "group_create") {
      return renderMessageItem(
        Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(TIM_t(("群聊创建成功！"))),
          ],
        ),
        theme,
        false,
      );
    }

    final groupTipPayload = parseGroupTipPayload(customElem);
    if (groupTipPayload != null) {
      final tipText = groupTipDisplayText(groupTipPayload);
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        child: Text(
          tipText,
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.weakTextColor, fontSize: 12),
        ),
      );
    } else if (claimNoticeText.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        child: Text(
          claimNoticeText,
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.weakTextColor, fontSize: 12),
        ),
      );
    } else if (friendBecameFriendsText.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        child: Text(
          friendBecameFriendsText,
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.weakTextColor, fontSize: 12),
        ),
      );
    } else if (MessageUtils.getCustomGroupCreatedOrDismissedString(
            widget.message)
        .isNotEmpty) {
      return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          child: Text.rich(TextSpan(children: [
            TextSpan(
              text: MessageUtils.getCustomGroupCreatedOrDismissedString(
                  widget.message),
              style: TextStyle(color: theme.weakTextColor),
            ),
          ], style: const TextStyle(fontSize: 12))));
    } else if (contactCardMessage != null) {
      final isFromSelf = widget.message.isSelf ?? false;
      return LayoutBuilder(
        builder: (context, constraints) {
          final cardCap = ChatWalletCardMetrics.desktopMaxWidthForChat();
          final rowWidth =
              constraints.maxWidth.isFinite && constraints.maxWidth > 0
                  ? constraints.maxWidth
                  : chatMessageMaxWidth(
                      context,
                      desktopMaxWidth: cardCap,
                      desktopFactor: 0.40,
                      mobileFactor: 0.70,
                    );
          final cardMaxWidth = math.min(
            math.max(ChatWalletCardMetrics.minWidth, rowWidth - 48.0),
            cardCap,
          );
          return renderMessageItem(
            Material(
              color: Colors.transparent,
              child: ClipRect(
                clipBehavior: Clip.hardEdge,
                child: ContactCardMessageItem(
                  message: contactCardMessage,
                  theme: theme,
                  isSelf: isFromSelf,
                  timeText: _messageTimeText(),
                  groupId: widget.message.groupID,
                ),
              ),
            ),
            theme,
            false,
            maxWidth: cardMaxWidth,
            skipBubbleDecoration: true,
          );
        },
      );
    } else if (articleMessage != null &&
        articleMessage.shouldRenderAsArticleCard) {
      return renderMessageItem(
        OfficialAccountArticleCard(
          article: articleMessage,
          theme: theme,
        ),
        theme,
        false,
        maxWidth: 300,
      );
    } else if (linkMessage != null) {
      final fallbackArticle = OfficialAccountArticleMessage(
        businessID: linkMessage.businessID ?? articleMessage?.businessID,
        title: linkMessage.text?.trim() ??
            articleMessage?.title ??
            customElem?.desc?.trim() ??
            '',
        description: articleMessage?.description ?? '',
        imageUrl: articleMessage?.imageUrl,
        link: linkMessage.link ?? articleMessage?.link,
      );
      if (fallbackArticle.shouldRenderAsArticleCard) {
        return renderMessageItem(
          OfficialAccountArticleCard(
            article: fallbackArticle,
            theme: theme,
          ),
          theme,
          false,
          maxWidth: 300,
        );
      }
      final String option1 = linkMessage.link ?? "";
      return renderMessageItem(
        Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((linkMessage.text ?? '').trim().isNotEmpty)
              Text(linkMessage.text!.trim()),
            MarkdownBody(
              data: TIM_t_para(
                "[查看详情 >>]({{option1}})",
                "[查看详情 >>]($option1)",
              )(option1: option1),
              styleSheet: MarkdownStyleSheet.fromTheme(
                ThemeData(
                  textTheme: const TextTheme(
                    bodyMedium: TextStyle(fontSize: 16.0),
                  ),
                ),
              ).copyWith(
                a: TextStyle(color: LinkUtils.hexToColor("015fff")),
              ),
              onTapLink: (String link, String? href, String title) {
                LinkUtils.launchURL(context, linkMessage.link ?? "");
              },
            ),
          ],
        ),
        theme,
        false,
      );
    } else if (webLinkMessage != null) {
      final article = OfficialAccountArticleMessage(
        businessID: articleMessage?.businessID,
        title: webLinkMessage.title?.trim() ?? articleMessage?.title ?? '',
        description: webLinkMessage.description?.trim() ??
            articleMessage?.description ??
            '',
        imageUrl: articleMessage?.imageUrl,
        link: webLinkMessage.hyperlinks_text?["value"]?.toString() ??
            articleMessage?.link,
      );
      return renderMessageItem(
        OfficialAccountArticleCard(
          article: article,
          theme: theme,
        ),
        theme,
        false,
        maxWidth: 300,
      );
    } else if (callingMessageDataProvider.shouldDisplayInHistory) {
      if (callingMessageDataProvider.participantType ==
          CallParticipantType.group) {
        // Group Call message
        return GroupCallMessageItem(
            callingMessageDataProvider: callingMessageDataProvider);
      } else {
        // One-to-one Call message
        bool isFromSelf = callingMessageDataProvider.direction ==
            CallMessageDirection.outcoming;
        final bubbleStyle = CallMessageBubbleStyle.resolve(
          theme,
          isFromSelf: isFromSelf,
        );
        final bodyTextStyle = MessageBubbleTextColor.bodyTextStyle(
          theme: theme,
          backgroundColor: bubbleStyle.background,
          fontStyle: widget.messageFontStyle,
          fontSize: widget.messageFontStyle?.fontSize ?? 16,
          lineHeight: widget.messageFontStyle?.height ??
              MessageBubbleTextColor.messageBodyLineHeight,
        );
        final timeTextStyle = TextStyle(
          fontSize: 11,
          height: 1,
          color: MessageBubbleTextColor.metaText(
            theme: theme,
            backgroundColor: bubbleStyle.background,
            overrideColor: widget.messageFontStyle?.color,
          ),
        );
        return renderMessageItem(
          CallMessageItem(
            callingMessageDataProvider: callingMessageDataProvider,
            timeText: _messageTimeText(),
            textStyle: bodyTextStyle,
            timeTextStyle: timeTextStyle,
            backgroundColor: bubbleStyle.background,
            borderRadius: CallMessageBubbleStyle.bubbleBorderRadius(
              isFromSelf: isFromSelf,
            ),
            border: bubbleStyle.border,
          ),
          theme,
          false,
          isSelf: isFromSelf,
          skipBubbleDecoration: true,
          maxWidth: chatMessageMaxWidth(
            context,
            desktopMaxWidth: 340,
            desktopFactor: 0.40,
            mobileFactor: 0.70,
          ),
        );
      }
    } else {
      // Mid-state / non-history call signals (invite/accept/lk_call ring):
      // hide instead of falling through to "[自定义]".
      if (callingMessageDataProvider.isCallingSignal ||
          CallingMessageDataProvider.looksLikeCallMessage(widget.message)) {
        return const SizedBox.shrink();
      }
      return renderMessageItem(const Text("[自定义]"), theme, false);
    }
  }

  Widget renderMessageItem(
    Widget child,
    TUITheme theme,
    bool isVoteMessage, {
    bool? isSelf,
    double maxWidth = 240,
    bool skipBubbleDecoration = false,
    Color? messageBackgroundColorOverride,
    Border? messageBorderOverride,
    EdgeInsetsGeometry? messagePaddingOverride,
  }) {
    bool isFromSelf = widget.message.isSelf ?? true;
    if (isSelf != null) {
      isFromSelf = isSelf;
    }

    final borderRadius = isFromSelf
        ? const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(2),
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10))
        : const BorderRadius.only(
            topLeft: Radius.circular(2),
            topRight: Radius.circular(10),
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10));

    final defaultStyle = isFromSelf
        ? (theme.chatMessageItemFromSelfBgColor ??
            theme.lightPrimaryMaterialColor.shade50)
        : (theme.chatMessageItemFromOthersBgColor ??
            theme.weakBackgroundColor ??
            Colors.white);
    final Color? resolvedBackgroundColor;
    if (isShowJumpState) {
      resolvedBackgroundColor = kMessageJumpHighlightColor;
    } else if (messageBackgroundColorOverride != null) {
      resolvedBackgroundColor = messageBackgroundColorOverride;
    } else {
      resolvedBackgroundColor = defaultStyle;
    }

    final double resolvedMaxWidth = (kIsWeb
            ? math.min(
                isVoteMessage ? 298 : maxWidth,
                chatMessageMaxWidth(
                  context,
                  desktopMaxWidth: isVoteMessage ? 298 : maxWidth,
                  desktopMinWidth:
                      math.min(220, isVoteMessage ? 298 : maxWidth),
                  desktopFactor: 0.40,
                  mobileFactor: 0.70,
                ),
              )
            : (isVoteMessage ? 298 : maxWidth))
        .toDouble();

    if (skipBubbleDecoration) {
      return ClipRect(
        clipBehavior: Clip.hardEdge,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: resolvedMaxWidth),
          child: child,
        ),
      );
    }

    return Container(
      padding: isVoteMessage
          ? null
          : (messagePaddingOverride ??
              widget.textPadding ??
              MessageBubbleTextColor.messageBubblePadding),
      decoration: isVoteMessage
          ? BoxDecoration(
              border: Border.all(
                width: 1,
                color: theme.weakDividerColor ?? Colors.grey,
              ),
            )
          : BoxDecoration(
              color: widget.messageBackgroundColor ?? resolvedBackgroundColor,
              borderRadius: widget.messageBorderRadius ?? borderRadius,
              border: messageBorderOverride ??
                  MessageBubbleTextColor.othersBubbleBorder(
                    isFromSelf: isFromSelf,
                    bubbleBackground:
                        widget.messageBackgroundColor ?? resolvedBackgroundColor,
                  ),
            ),
      constraints: BoxConstraints(maxWidth: resolvedMaxWidth),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context, listen: false).theme;
    return _callElemBuilder(context, theme);
  }
}

class _WalletLoadArgs {
  final String type;
  final String orderId;
  final String clientOrderId;
  final String? currency;
  final int? amount;
  final String? status;
  final String? greeting;

  const _WalletLoadArgs({
    required this.type,
    required this.orderId,
    required this.clientOrderId,
    this.currency,
    this.amount,
    this.status,
    this.greeting,
  });
}

class _ExclusiveRedPacketMeta {
  final String title;
  final String avatar;

  const _ExclusiveRedPacketMeta({
    required this.title,
    required this.avatar,
  });
}

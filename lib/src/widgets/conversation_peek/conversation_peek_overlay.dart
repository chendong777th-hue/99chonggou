import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/provider/presence_provider.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/services/platform_official_account_service.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/presence_subtitle.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_mutual_utils.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_status.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_status.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_peek_service.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_peek/conversation_peek_actions.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_peek/conversation_peek_message_summary.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_image_message_prefetch.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_message_prefetch.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_peek/conversation_peek_message_item.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/chat_ui_state_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/controller/tim_uikit_chat_controller.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/time_ago.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/history_pagination_scroll_physics.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/tim_uikit_chat_config.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_chat_group_tips_elem.dart';

class ConversationPeekOverlay {
  ConversationPeekOverlay._();

  static bool _isShowing = false;

  static Future<void> show({
    required BuildContext context,
    required V2TimConversation conversation,
    required String displayName,
    required ConversationPeekActions actions,
  }) async {
    if (_isShowing) {
      return;
    }
    _isShowing = true;
    final i18n = AppI18n.of(context);

    try {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: i18n.t(
          zhHans: '关闭预览',
          zhHant: '關閉預覽',
          en: 'Dismiss preview',
          ja: 'プレビューを閉じる',
          ko: '미리보기 닫기',
        ),
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          return _ConversationPeekDialog(
            conversation: conversation,
            displayName: displayName,
            actions: actions,
            onDismiss: () => Navigator.of(dialogContext).pop(),
            onOpenChat: () {
              Navigator.of(dialogContext).pop();
              actions.onOpenChat();
            },
          );
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(opacity: curved, child: child);
        },
      );
    } finally {
      _isShowing = false;
    }
  }
}

enum _PeekListItemType { loadingOlder, date, message }

/// 预览弹窗按屏幕百分比布局（基于 SafeArea 内可用高度/宽度）。
class _ConversationPeekLayout {
  _ConversationPeekLayout._();

  static const double horizontalInsetFactor = 0.037;
  static const double topInsetFactor = 0.008;
  static const double bottomInsetFactor = 0.016;
  static const double previewHeightFactor = 0.60;
  static const double previewMenuGapFactor = 0.012;
  static const double menuWidthFactor = 0.48;
  static const double cardRadiusFactor = 0.058;
  static const double menuItemVerticalPaddingFactor = 0.012;
  static const double menuRowContentHeight = 22;
  static const double menuDividerHeight = 1;
  static const double menuLayoutSlack = 12;

  static int _menuItemCount(ConversationPeekActions actions) {
    if (actions.isOfficialAccount) {
      return 1;
    }
    if (actions.variant == ConversationPeekMenuVariant.contact) {
      var count = 1;
      if (actions.onViewProfile != null) count++;
      if (actions.onToggleStar != null) count++;
      if (actions.onDeleteFriend != null) count++;
      return count;
    }
    var count = 0;
    if (actions.onArchive != null) count++;
    if (actions.onAddToFolder != null) count++;
    if (actions.onMarkUnread != null) count++;
    if (actions.onTogglePin != null) count++;
    if (actions.onToggleMute != null) count++;
    if (actions.onDelete != null) count++;
    return count;
  }

  static int _menuDividerCount(ConversationPeekActions actions) {
    if (actions.isOfficialAccount) {
      return 0;
    }
    if (actions.variant == ConversationPeekMenuVariant.contact) {
      return actions.onDeleteFriend != null ? 1 : 0;
    }
    return (actions.onArchive != null || actions.onAddToFolder != null)
        ? 1
        : 0;
  }

  static double _estimateMenuHeight(
    ConversationPeekActions actions,
    double itemVerticalPadding,
  ) {
    final rowHeight = itemVerticalPadding * 2 + menuRowContentHeight;
    return _menuItemCount(actions) * rowHeight +
        _menuDividerCount(actions) * menuDividerHeight +
        menuLayoutSlack;
  }

  static _ConversationPeekMetrics resolve({
    required BoxConstraints constraints,
    required double screenWidth,
    required ConversationPeekActions actions,
  }) {
    final availableHeight = constraints.maxHeight;
    final horizontalPadding = screenWidth * horizontalInsetFactor;
    final topPadding = availableHeight * topInsetFactor;
    final bottomPadding = availableHeight * bottomInsetFactor;
    final gap = availableHeight * previewMenuGapFactor;
    final usableHeight = availableHeight - topPadding - bottomPadding;
    final menuItemVerticalPadding =
        availableHeight * menuItemVerticalPaddingFactor;
    final menuNaturalHeight =
        _estimateMenuHeight(actions, menuItemVerticalPadding);

    final preferredPreview = usableHeight * previewHeightFactor;
    final maxPreviewHeight = usableHeight - gap - menuNaturalHeight;
    final previewHeight = preferredPreview.clamp(
      120.0,
      maxPreviewHeight > 120.0 ? maxPreviewHeight : 120.0,
    );

    final menuViewportHeight =
        (usableHeight - previewHeight - gap).clamp(0.0, menuNaturalHeight);

    return _ConversationPeekMetrics(
      horizontalPadding: horizontalPadding,
      topPadding: topPadding,
      bottomPadding: bottomPadding,
      gap: gap,
      previewHeight: previewHeight,
      menuWidth: screenWidth * menuWidthFactor,
      menuNaturalHeight: menuNaturalHeight,
      menuViewportHeight: menuViewportHeight,
      menuNeedsScroll: menuNaturalHeight > menuViewportHeight + 0.5,
      cardWidth: screenWidth - horizontalPadding * 2,
      cardRadius: screenWidth * cardRadiusFactor,
      menuItemVerticalPadding: menuItemVerticalPadding,
    );
  }
}

class _ConversationPeekMetrics {
  const _ConversationPeekMetrics({
    required this.horizontalPadding,
    required this.topPadding,
    required this.bottomPadding,
    required this.gap,
    required this.previewHeight,
    required this.menuWidth,
    required this.menuNaturalHeight,
    required this.menuViewportHeight,
    required this.menuNeedsScroll,
    required this.cardWidth,
    required this.cardRadius,
    required this.menuItemVerticalPadding,
  });

  final double horizontalPadding;
  final double topPadding;
  final double bottomPadding;
  final double gap;
  final double previewHeight;
  final double menuWidth;
  final double menuNaturalHeight;
  final double menuViewportHeight;
  final bool menuNeedsScroll;
  final double cardWidth;
  final double cardRadius;
  final double menuItemVerticalPadding;
}

class _PeekListItem {
  const _PeekListItem.loadingOlder()
      : type = _PeekListItemType.loadingOlder,
        dateLabel = null,
        message = null;

  const _PeekListItem.date(this.dateLabel)
      : type = _PeekListItemType.date,
        message = null;

  const _PeekListItem.message(this.message)
      : type = _PeekListItemType.message,
        dateLabel = null;

  final _PeekListItemType type;
  final String? dateLabel;
  final V2TimMessage? message;
}

class _ConversationPeekDialog extends StatefulWidget {
  const _ConversationPeekDialog({
    required this.conversation,
    required this.displayName,
    required this.actions,
    required this.onDismiss,
    required this.onOpenChat,
  });

  final V2TimConversation conversation;
  final String displayName;
  final ConversationPeekActions actions;
  final VoidCallback onDismiss;
  final VoidCallback onOpenChat;

  @override
  State<_ConversationPeekDialog> createState() =>
      _ConversationPeekDialogState();
}

class _ConversationPeekDialogState extends State<_ConversationPeekDialog> {
  static const _scrollPaginationCompensationMs = 1200;
  static const _loadOlderTopThresholdPx = 72.0;

  final ScrollController _scrollController = ScrollController();
  final List<V2TimMessage> _messages = [];
  bool _loading = true;
  bool _loadingOlder = false;
  bool _hasMoreOlder = true;
  String? _errorMessage;
  bool _isGroup = false;
  int? _groupMemberCount;
  int _scrollPaginationCompensationUntilMs = 0;
  int _scrollPaginationCompensationGeneration = 0;
  String? _presenceScheduledUserId;
  late final TUIChatSeparateViewModel _peekChatModel;
  late final TIMUIKitChatController _peekChatController;

  static const Color _telegramBlue = Color(0xFF3390EC);

  void _initPeekChatModel() {
    _peekChatModel = TUIChatSeparateViewModel();
    final convKey = _isGroup
        ? widget.conversation.groupID?.trim()
        : widget.conversation.userID?.trim();
    _peekChatModel.conversationID = (convKey != null && convKey.isNotEmpty)
        ? convKey
        : widget.conversation.conversationID;
    _peekChatModel.conversationType =
        _isGroup ? ConvType.group : ConvType.c2c;
    _peekChatModel
      ..suppressReadReporting = true
      ..chatConfig = const TIMUIKitChatConfig(
        isShowReadingStatus: true,
        isUseMessageReaction: false,
        isUseDraft: false,
      );
    _peekChatController = TIMUIKitChatController(viewModel: _peekChatModel);
  }

  @override
  void initState() {
    super.initState();
    _isGroup = widget.conversation.type == 2 ||
        (widget.conversation.groupID?.trim().isNotEmpty ?? false);
    _initPeekChatModel();
    _scrollController.addListener(_onScroll);
    unawaited(_loadInitial());
    if (_isGroup) {
      unawaited(_loadGroupMemberCount());
    } else {
      _schedulePresenceLoad();
    }
  }

  void _schedulePresenceLoad() {
    final userId = widget.conversation.userID?.trim() ?? '';
    if (userId.isEmpty || _presenceScheduledUserId == userId) {
      return;
    }
    _presenceScheduledUserId = userId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final id = widget.conversation.userID?.trim() ?? '';
      if (id.isEmpty || id != userId) {
        return;
      }
      final localSetting = Provider.of<LocalSetting>(context, listen: false);
      if (!localSetting.isShowOnlineStatus) {
        return;
      }
      if (PlatformOfficialAccountService.showsVerifiedBadge(id)) {
        return;
      }
      final presence = Provider.of<PresenceProvider>(context, listen: false);
      presence.ensure([id]);
      presence.refresh([id], urgent: true);
    });
  }

  @override
  void dispose() {
    _peekChatModel.dispose();
    _clearScrollPaginationCompensation();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  bool _shouldCompensateScrollForPagination() {
    if (_loadingOlder) {
      return true;
    }
    final until = _scrollPaginationCompensationUntilMs;
    return until > 0 &&
        DateTime.now().millisecondsSinceEpoch < until;
  }

  void _beginScrollPaginationCompensation() {
    _extendScrollPaginationCompensation();
  }

  void _extendScrollPaginationCompensation({int? milliseconds}) {
    final extendMs = milliseconds ?? _scrollPaginationCompensationMs;
    final until = DateTime.now().millisecondsSinceEpoch + extendMs;
    if (until > _scrollPaginationCompensationUntilMs) {
      _scrollPaginationCompensationUntilMs = until;
    }
  }

  void _clearScrollPaginationCompensation() {
    _scrollPaginationCompensationUntilMs = 0;
  }

  void _scheduleScrollPaginationCompensationEnd({
    required int generation,
  }) {
    Future<void>.delayed(
      const Duration(milliseconds: _scrollPaginationCompensationMs),
      () {
        if (!mounted || _scrollPaginationCompensationGeneration != generation) {
          return;
        }
        _clearScrollPaginationCompensation();
      },
    );
  }

  /// 与聊天页消息列表一致：HistoryPaginationScrollPhysics + 平台默认惯性
  /// （iOS 弹性 / Android clamping），不再强制 Clamping 或自定义减速。
  ScrollPhysics _peekListScrollPhysics() {
    return HistoryPaginationScrollPhysics(
      shouldCompensate: _shouldCompensateScrollForPagination,
    );
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final result =
          await ConversationPeekService.loadInitial(widget.conversation);
      if (!mounted) {
        return;
      }
      final messages = List<V2TimMessage>.from(result.messages);
      // 预览里图片/视频常缺 URL；先补全再渲染，避免灰块占位。
      await ChatImageMessagePrefetch.resolveOnlineUrlsForMessages(
        messages,
        budget: const Duration(milliseconds: 600),
        includeSelf: true,
      );
      await StickerMessagePrefetch.resolveForMessages(messages);
      ChatImageMessagePrefetch.fromMessages(messages);
      if (!mounted) {
        return;
      }
      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
        _hasMoreOlder = result.hasMoreOlder;
        _loading = false;
      });
      _anchorToLatest();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage = AppI18n.of(context).t(
          zhHans: '加载失败，请重试',
          zhHant: '載入失敗，請重試',
          en: 'Failed to load. Please try again.',
          ja: '読み込みに失敗しました。再試行してください。',
          ko: '불러오지 못했습니다. 다시 시도해 주세요.',
        );
      });
    }
  }

  void _anchorToLatest({int attempt = 0, double? previousMax}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final position = _scrollController.position;
      final maxExtent = position.maxScrollExtent;
      position.jumpTo(0);
      final extentChanged =
          previousMax == null || (maxExtent - previousMax).abs() > 0.5;
      if (attempt < 10 && extentChanged) {
        _anchorToLatest(attempt: attempt + 1, previousMax: maxExtent);
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _loading ||
        _loadingOlder ||
        !_hasMoreOlder ||
        _messages.isEmpty) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - _loadOlderTopThresholdPx) {
      return;
    }
    unawaited(_loadOlder());
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasMoreOlder || _messages.isEmpty) {
      return;
    }
    _beginScrollPaginationCompensation();
    final compensationGeneration = ++_scrollPaginationCompensationGeneration;
    setState(() {
      _loadingOlder = true;
    });

    try {
      final result = await ConversationPeekService.loadOlder(
        conversation: widget.conversation,
        anchor: _messages.first,
      );
      if (!mounted) {
        return;
      }
      final existingIds = _messages.map((m) => m.msgID).toSet();
      final older = result.messages
          .where((message) => !existingIds.contains(message.msgID))
          .toList();
      if (older.isNotEmpty) {
        await ChatImageMessagePrefetch.resolveOnlineUrlsForMessages(
          older,
          budget: const Duration(milliseconds: 400),
          includeSelf: true,
        );
        await StickerMessagePrefetch.resolveForMessages(
          older,
          budget: const Duration(milliseconds: 500),
        );
        ChatImageMessagePrefetch.fromMessages(older);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.insertAll(0, older);
        _messages.sort((a, b) {
          final timeCompare =
              (a.timestamp ?? 0).compareTo(b.timestamp ?? 0);
          if (timeCompare != 0) {
            return timeCompare;
          }
          final seqA = int.tryParse(a.seq?.toString() ?? '') ?? 0;
          final seqB = int.tryParse(b.seq?.toString() ?? '') ?? 0;
          return seqA.compareTo(seqB);
        });
        _hasMoreOlder = older.isNotEmpty && result.hasMoreOlder;
        _loadingOlder = false;
      });
      _extendScrollPaginationCompensation();
      _scheduleScrollPaginationCompensationEnd(
        generation: compensationGeneration,
      );
    } catch (_) {
      _clearScrollPaginationCompensation();
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingOlder = false;
      });
    }
  }

  List<_PeekListItem> _buildListItems(AppI18n i18n) {
    final items = <_PeekListItem>[];
    if (_loadingOlder) {
      items.add(const _PeekListItem.loadingOlder());
    }
    String? lastDateKey;
    for (final message in _messages) {
      final dateKey = _messageDateKey(message);
      if (dateKey != null && dateKey != lastDateKey) {
        items.add(_PeekListItem.date(_formatDateLabel(message)));
        lastDateKey = dateKey;
      }
      items.add(_PeekListItem.message(message));
    }
    return items;
  }

  String? _messageDateKey(V2TimMessage message) {
    final timestamp = message.timestamp ?? 0;
    if (timestamp <= 0) {
      return null;
    }
    final ms = timestamp >= 1000000000000 ? timestamp : timestamp * 1000;
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.year}-${dt.month}-${dt.day}';
  }

  String _formatDateLabel(V2TimMessage message) {
    final timestamp = message.timestamp ?? 0;
    if (timestamp <= 0) {
      return '';
    }
    final seconds =
        timestamp >= 1000000000000 ? timestamp ~/ 1000 : timestamp;
    return TimeAgo().getTimeForMessage(seconds);
  }

  Future<void> _loadGroupMemberCount() async {
    final groupID = widget.conversation.groupID?.trim() ?? '';
    if (groupID.isEmpty) {
      return;
    }
    try {
      final res = await TencentImSDKPlugin.v2TIMManager
          .getGroupManager()
          .getGroupsInfo(groupIDList: [groupID]);
      final count = res.data != null && res.data!.isNotEmpty
          ? res.data!.first.groupInfo?.memberCount
          : null;
      if (!mounted) {
        return;
      }
      setState(() {
        _groupMemberCount = count;
      });
    } catch (_) {}
  }

  Widget? _buildPillSubtitle(TUITheme theme) {
    if (_isGroup) {
      final count = _groupMemberCount;
      if (count == null) {
        return null;
      }
      return Text(
        TIM_t_para('{{option1}}人', '$count人')(option1: '$count'),
        style: TextStyle(
          fontSize: 11,
          color: theme.weakTextColor ?? const Color(0xFF8E8E93),
          height: 1.1,
        ),
      );
    }

    final localSetting = Provider.of<LocalSetting>(context, listen: false);
    if (!localSetting.isShowOnlineStatus) {
      return null;
    }
    final userId = widget.conversation.userID?.trim() ?? '';
    if (userId.isEmpty ||
        PlatformOfficialAccountService.showsVerifiedBadge(userId)) {
      return null;
    }

    final friendship = serviceLocator<TUIFriendShipViewModel>();
    return Consumer<PresenceProvider>(
      builder: (context, presence, _) {
        V2TimUserStatus? onlineStatus;
        for (final status in friendship.userStatusList) {
          if (status.userID == userId) {
            onlineStatus = status;
            break;
          }
        }
        final imOnline = onlineStatus?.statusType == 1;
        final loading = presence.isLastSeenLoading(
          userId: userId,
          imOnline: imOnline,
        );
        final label = loading
            ? ''
            : presence.listLabelFor(
                userId: userId,
                imOnline: presence.resolveOnline(
                  userId: userId,
                  imOnline: imOnline,
                ),
                isMutualFriend: friendCanMessage(friendship, userId),
              );
        return PresenceSubtitle(
          label: label,
          loading: loading,
          imOnline: presence.resolveOnline(userId: userId, imOnline: imOnline),
          fontSize: 11,
          height: 1.1,
          lineHeight: 12.1,
          onlineColor: theme.primaryColor ?? const Color(0xFF1E90FF),
          offlineColor: theme.primaryColor ?? const Color(0xFF1E90FF),
          skeletonColor: theme.weakTextColor,
          skeletonWidth: 48,
          skeletonHeight: 8,
        );
      },
    );
  }

  Future<void> _runAction(Future<void> Function()? action) async {
    if (action == null) {
      return;
    }
    widget.onDismiss();
    await action();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onDismiss,
              child: defaultTargetPlatform == TargetPlatform.android
                  ? Container(
                      color: Colors.black.withValues(alpha: 0.35),
                    )
                  : BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.35),
                      ),
                    ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final layout = _ConversationPeekLayout.resolve(
                  constraints: constraints,
                  screenWidth: screenWidth,
                  actions: widget.actions,
                );
                final menu = _buildActionMenu(
                  i18n,
                  menuWidth: layout.menuWidth,
                  itemVerticalPadding: layout.menuItemVerticalPadding,
                );
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    layout.horizontalPadding,
                    layout.topPadding,
                    layout.horizontalPadding,
                    layout.bottomPadding,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: layout.previewHeight,
                        child: _buildPreviewCard(
                          context,
                          i18n,
                          layout: layout,
                        ),
                      ),
                      SizedBox(height: layout.gap),
                      Align(
                        alignment: Alignment.centerRight,
                        child: layout.menuNeedsScroll
                            ? SizedBox(
                                width: layout.menuWidth,
                                height: layout.menuViewportHeight,
                                child: SingleChildScrollView(
                                  physics: const ClampingScrollPhysics(),
                                  child: menu,
                                ),
                              )
                            : SizedBox(
                                width: layout.menuWidth,
                                child: menu,
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(
    BuildContext context,
    AppI18n i18n, {
    required _ConversationPeekMetrics layout,
  }) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final surfaceColor = theme.appbarBgColor ?? Colors.white;
    final titleColor = theme.darkTextColor ?? const Color(0xFF111111);
    final subtitleColor = theme.weakTextColor ?? const Color(0xFF8E8E93);

    return GestureDetector(
      onTap: widget.onOpenChat,
      child: Container(
        width: layout.cardWidth,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(layout.cardRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const SizedBox(height: 10),
            _buildPillHeader(titleColor, theme),
            const SizedBox(height: 6),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: layout.cardRadius * 0.35),
                child: _buildBody(i18n, subtitleColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillHeader(Color titleColor, TUITheme theme) {
    final subtitle = _buildPillSubtitle(theme);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                  height: 1.15,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                subtitle,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AppI18n i18n, Color subtitleColor) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _errorMessage!,
              style: TextStyle(color: subtitleColor, fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loadInitial,
              child: Text(
                i18n.t(
                  zhHans: '重试',
                  zhHant: '重試',
                  en: 'Retry',
                  ja: '再試行',
                  ko: '다시 시도',
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (_messages.isEmpty) {
      return Center(
        child: Text(
          i18n.t(
            zhHans: '暂无消息',
            zhHant: '暫無訊息',
            en: 'No messages yet',
            ja: 'メッセージはありません',
            ko: '메시지가 없습니다',
          ),
          style: TextStyle(color: subtitleColor, fontSize: 14),
        ),
      );
    }

    final listItems = _buildListItems(i18n);
    final theme = Provider.of<DefaultThemeData>(context, listen: false).theme;

    // 强制打开 TickerMode：图片/视频气泡在 TickerMode=false 时会永久灰块占位。
    // ChatUiStateStore 供 TIMUIKitSoundElem 等与聊天页共用的气泡读取行级刷新。
    return TickerMode(
      enabled: true,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<TUIChatGlobalModel>.value(
            value: serviceLocator<TUIChatGlobalModel>(),
          ),
          ChangeNotifierProvider<ChatUiStateStore>.value(
            value: serviceLocator<ChatUiStateStore>(),
          ),
        ],
        child: ListView.builder(
          controller: _scrollController,
          reverse: true,
          physics: _peekListScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 28, 12, 4),
          itemCount: listItems.length,
          itemBuilder: (context, index) {
            final item = listItems[listItems.length - 1 - index];
            switch (item.type) {
              case _PeekListItemType.loadingOlder:
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.primaryColor ?? _telegramBlue,
                      ),
                    ),
                  ),
                );
              case _PeekListItemType.date:
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Text(
                      item.dateLabel ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.chatTimeDividerTextColor ?? subtitleColor,
                      ),
                    ),
                  ),
                );
              case _PeekListItemType.message:
                return _buildMessageBubble(
                  item.message!,
                  subtitleColor: subtitleColor,
                );
            }
          },
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    V2TimMessage message, {
    required Color subtitleColor,
  }) {
    if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS &&
        message.groupTipsElem != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: TIMUIKitGroupTipsElem(
            groupTipsElem: message.groupTipsElem!,
            groupMemberList: const [],
          ),
        ),
      );
    }

    final systemText = ConversationPeekMessageSummary.centerSystemText(message);
    if (systemText != null) {
      return _buildCenterSystemMessage(systemText, subtitleColor);
    }

    return ConversationPeekMessageItem(
      message: message,
      chatModel: _peekChatModel,
      chatController: _peekChatController,
      isGroup: _isGroup,
      subtitleColor: subtitleColor,
      peerFaceUrl: widget.conversation.faceUrl,
      peerShowName: widget.conversation.showName,
      peerUserId: widget.conversation.userID,
      groupId: widget.conversation.groupID,
    );
  }

  Widget _buildCenterSystemMessage(String text, Color subtitleColor) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: subtitleColor,
          fontSize: 12,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _buildActionMenu(
    AppI18n i18n, {
    required double menuWidth,
    required double itemVerticalPadding,
  }) {
    final actions = widget.actions;
    if (actions.isOfficialAccount) {
      return _ActionMenuCard(
        width: menuWidth,
        children: [
          _ActionMenuItem(
            icon: Icons.delete_outline_rounded,
            label: i18n.t(
              zhHans: '删除',
              zhHant: '刪除',
              en: 'Delete',
              ja: '削除',
              ko: '삭제',
            ),
            isDestructive: true,
            verticalPadding: itemVerticalPadding,
            onTap: () => _runAction(actions.onDelete),
          ),
        ],
      );
    }

    if (actions.variant == ConversationPeekMenuVariant.contact) {
      return _ActionMenuCard(
        width: menuWidth,
        children: [
          _ActionMenuItem(
            icon: Icons.chat_bubble_outline_rounded,
            label: i18n.t(
              zhHans: '发消息',
              zhHant: '發訊息',
              en: 'Send Message',
              ja: 'メッセージを送信',
              ko: '메시지 보내기',
            ),
            verticalPadding: itemVerticalPadding,
            onTap: () {
              widget.onDismiss();
              actions.onOpenChat();
            },
          ),
          if (actions.onViewProfile != null)
            _ActionMenuItem(
              icon: Icons.person_outline_rounded,
              label: i18n.t(
                zhHans: '查看资料',
                zhHant: '查看資料',
                en: 'View Profile',
                ja: 'プロフィールを見る',
                ko: '프로필 보기',
              ),
              verticalPadding: itemVerticalPadding,
              onTap: () => _runAction(actions.onViewProfile),
            ),
          if (actions.onToggleStar != null)
            _ActionMenuItem(
              icon: actions.isStarred
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              label: actions.isStarred
                  ? i18n.t(
                      zhHans: '取消星标',
                      zhHant: '取消星標',
                      en: 'Unstar',
                      ja: 'スターを外す',
                      ko: '즐겨찾기 해제',
                    )
                  : i18n.t(
                      zhHans: '设为星标',
                      zhHant: '設為星標',
                      en: 'Star',
                      ja: 'スターを付ける',
                      ko: '즐겨찾기',
                    ),
              verticalPadding: itemVerticalPadding,
              onTap: () => _runAction(actions.onToggleStar),
            ),
          if (actions.onDeleteFriend != null) ...[
            const _ActionMenuDivider(),
            _ActionMenuItem(
              icon: Icons.person_remove_outlined,
              label: i18n.t(
                zhHans: '删除好友',
                zhHant: '刪除好友',
                en: 'Delete Friend',
                ja: '友達を削除',
                ko: '친구 삭제',
              ),
              isDestructive: true,
              verticalPadding: itemVerticalPadding,
              onTap: () => _runAction(actions.onDeleteFriend),
            ),
          ],
        ],
      );
    }

    return _ActionMenuCard(
      width: menuWidth,
      children: [
        if (actions.onArchive != null)
          _ActionMenuItem(
            icon: Icons.archive_outlined,
            label: actions.isArchived
                ? i18n.t(
                    zhHans: '取消归档',
                    zhHant: '取消封存',
                    en: 'Unarchive',
                    ja: 'アーカイブ解除',
                    ko: '보관 해제',
                  )
                : i18n.t(
                    zhHans: '归档',
                    zhHant: '封存',
                    en: 'Archive',
                    ja: 'アーカイブ',
                    ko: '보관',
                  ),
            verticalPadding: itemVerticalPadding,
            onTap: () => _runAction(actions.onArchive),
          ),
        if (actions.onAddToFolder != null)
          _ActionMenuItem(
            icon: Icons.create_new_folder_outlined,
            label: i18n.t(
              zhHans: '添加至分组',
              zhHant: '添加至分組',
              en: 'Add to folder',
              ja: 'フォルダに追加',
              ko: '폴더에 추가',
            ),
            verticalPadding: itemVerticalPadding,
            onTap: () => _runAction(actions.onAddToFolder),
          ),
        if (actions.onArchive != null || actions.onAddToFolder != null)
          const _ActionMenuDivider(),
        if (actions.onMarkUnread != null)
          _ActionMenuItem(
            icon: Icons.mark_chat_unread_outlined,
            label: i18n.t(
              zhHans: '标记为未读',
              zhHant: '標記為未讀',
              en: 'Mark as unread',
              ja: '未読にする',
              ko: '읽지 않음으로 표시',
            ),
            verticalPadding: itemVerticalPadding,
            onTap: () => _runAction(actions.onMarkUnread),
          ),
        if (actions.onTogglePin != null)
          _ActionMenuItem(
            icon: actions.isPinned
                ? Icons.push_pin_outlined
                : Icons.push_pin_outlined,
            label: actions.isPinned
                ? i18n.t(
                    zhHans: '取消置顶',
                    zhHant: '取消置頂',
                    en: 'Unpin',
                    ja: 'ピン留め解除',
                    ko: '고정 해제',
                  )
                : i18n.t(
                    zhHans: '置顶',
                    zhHant: '置頂',
                    en: 'Pin',
                    ja: 'ピン留め',
                    ko: '고정',
                  ),
            verticalPadding: itemVerticalPadding,
            onTap: () => _runAction(actions.onTogglePin),
          ),
        if (actions.onToggleMute != null)
          _ActionMenuItem(
            icon: actions.isMuted
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
            label: actions.isMuted
                ? i18n.t(
                    zhHans: '取消免打扰',
                    zhHant: '取消免打擾',
                    en: 'Unmute',
                    ja: 'ミュート解除',
                    ko: '알림 켜기',
                  )
                : i18n.t(
                    zhHans: '静音',
                    zhHant: '靜音',
                    en: 'Mute',
                    ja: 'ミュート',
                    ko: '알림 끄기',
                  ),
            verticalPadding: itemVerticalPadding,
            onTap: () => _runAction(actions.onToggleMute),
          ),
        if (actions.onDelete != null)
          _ActionMenuItem(
            icon: Icons.delete_outline_rounded,
            label: i18n.t(
              zhHans: '删除',
              zhHant: '刪除',
              en: 'Delete',
              ja: '削除',
              ko: '삭제',
            ),
            isDestructive: true,
            verticalPadding: itemVerticalPadding,
            onTap: () => _runAction(actions.onDelete),
          ),
      ],
    );
  }
}

class _ActionMenuCard extends StatelessWidget {
  const _ActionMenuCard({
    required this.width,
    required this.children,
  });

  final double width;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: theme.appbarBgColor ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

class _ActionMenuDivider extends StatelessWidget {
  const _ActionMenuDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: Colors.black.withValues(alpha: 0.08),
    );
  }
}

class _ActionMenuItem extends StatelessWidget {
  const _ActionMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.verticalPadding,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double verticalPadding;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final color = isDestructive
        ? const Color(0xFFFF3B30)
        : (theme.darkTextColor ?? const Color(0xFF111111));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: verticalPadding,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

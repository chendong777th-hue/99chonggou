import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_peek_service.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_peek/conversation_peek_message_item.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_network_image.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/message_notification_banner.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/chat_ui_state_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/controller/tim_uikit_chat_controller.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/tim_uikit_chat_config.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_mem_cache_utils.dart';

/// iOS 风格应用内消息横幅（前台提示，不依赖系统通知权限）。
class InAppMessageNotificationBanner {
  InAppMessageNotificationBanner._();

  static const String appIconAsset = 'assets/im_new_logo.jpg';

  static OverlayEntry? _entry;
  static GlobalKey<_InAppMessageBannerOverlayState>? _entryKey;
  static Timer? _dismissTimer;
  static DateTime? _lastShownAt;
  static bool _lastShowRateLimited = false;

  static const Duration defaultVisibleDuration = Duration(seconds: 2);
  static const Duration minShowInterval = Duration(seconds: 2);

  /// 上一次 [show] 是否因限流未展示（overlay 不可用时不算限流）。
  static bool get lastShowRateLimited => _lastShowRateLimited;

  /// 横幅是否处于展开（全屏半透明底）状态。
  static bool get isExpanded => _entryKey?.currentState?.isExpanded ?? false;

  static bool show({
    required String title,
    required String body,
    String? avatarUrl,
    bool preferAppIcon = false,
    DateTime? receivedAt,
    V2TimConversation? conversation,
    V2TimMessage? message,
    FutureOr<void> Function()? onTap,
    Duration duration = defaultVisibleDuration,
  }) {
    _lastShowRateLimited = false;

    final trimmedTitle = title.trim();
    final trimmedBody = body.trim();
    if (trimmedTitle.isEmpty && trimmedBody.isEmpty) {
      return false;
    }

    final now = DateTime.now();
    final activeState = _entryKey?.currentState;
    if (activeState != null) {
      if (activeState.matchesConversation(conversation)) {
        activeState.updateIncoming(
          title: trimmedTitle,
          body: trimmedBody,
          avatarUrl: avatarUrl,
          receivedAt: receivedAt ?? now,
          message: message,
        );
        _restartDismissTimer(duration);
        _lastShownAt = now;
        return true;
      }
      if (activeState.isExpanded) {
        // 展开的迷你聊天不能被另一会话的横幅强行替换。
        return true;
      }
    }
    if (_lastShownAt != null &&
        now.difference(_lastShownAt!) < minShowInterval) {
      _lastShowRateLimited = true;
      return false;
    }

    final overlay = _resolveOverlay();
    if (overlay == null) {
      if (Platform.isAndroid) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final retryNow = DateTime.now();
          if (_lastShownAt != null &&
              retryNow.difference(_lastShownAt!) < minShowInterval) {
            _lastShowRateLimited = true;
            return;
          }
          final retryOverlay = _resolveOverlay();
          if (retryOverlay == null) {
            // ignore: avoid_print
            print('MSG_BANNER_TRACE overlay_null_after_frame');
            return;
          }
          _insertOnOverlay(
            overlay: retryOverlay,
            title: trimmedTitle,
            body: trimmedBody,
            avatarUrl: avatarUrl,
            preferAppIcon: preferAppIcon,
            receivedAt: receivedAt,
            conversation: conversation,
            message: message,
            onTap: onTap,
            duration: duration,
            now: retryNow,
          );
        });
        return true;
      }
      return false;
    }

    return _insertOnOverlay(
      overlay: overlay,
      title: trimmedTitle,
      body: trimmedBody,
      avatarUrl: avatarUrl,
      preferAppIcon: preferAppIcon,
      receivedAt: receivedAt,
      conversation: conversation,
      message: message,
      onTap: onTap,
      duration: duration,
      now: now,
    );
  }

  static OverlayState? _resolveOverlay() {
    final direct = AppNavigator.overlay;
    if (direct != null && direct.mounted) {
      return direct;
    }
    final context = AppNavigator.context;
    if (context != null) {
      final fromContext = Overlay.maybeOf(context, rootOverlay: true);
      if (fromContext != null && fromContext.mounted) {
        return fromContext;
      }
    }
    return null;
  }

  static bool _insertOnOverlay({
    required OverlayState overlay,
    required String title,
    required String body,
    String? avatarUrl,
    bool preferAppIcon = false,
    DateTime? receivedAt,
    V2TimConversation? conversation,
    V2TimMessage? message,
    FutureOr<void> Function()? onTap,
    Duration duration = defaultVisibleDuration,
    required DateTime now,
  }) {
    hide();
    _lastShownAt = now;

    final entryKey = GlobalKey<_InAppMessageBannerOverlayState>();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _InAppMessageBannerOverlay(
        key: entryKey,
        title: title,
        body: body,
        avatarUrl: avatarUrl?.trim(),
        preferAppIcon: preferAppIcon,
        receivedAt: receivedAt ?? DateTime.now(),
        conversation: conversation,
        message: message,
        onTap: onTap,
        onDismiss: hide,
        onExpandedChanged: (expanded) {
          if (expanded) {
            _dismissTimer?.cancel();
            _dismissTimer = null;
          } else {
            _restartDismissTimer(duration);
          }
        },
      ),
    );
    _entryKey = entryKey;
    _entry = entry;
    overlay.insert(entry);
    _restartDismissTimer(duration);
    return true;
  }

  static void _restartDismissTimer(Duration duration) {
    _dismissTimer?.cancel();
    _dismissTimer = Timer(duration, () {
      if (_entryKey?.currentState?.isExpanded ?? false) {
        return;
      }
      hide();
    });
  }

  static void hide() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _entry?.remove();
    _entry = null;
    _entryKey = null;
  }

  static void resetRateLimit() {
    _lastShownAt = null;
    _lastShowRateLimited = false;
  }
}

class _InAppMessageBannerOverlay extends StatefulWidget {
  const _InAppMessageBannerOverlay({
    super.key,
    required this.title,
    required this.body,
    required this.receivedAt,
    required this.onDismiss,
    required this.onExpandedChanged,
    this.avatarUrl,
    this.preferAppIcon = false,
    this.conversation,
    this.message,
    this.onTap,
  });

  final String title;
  final String body;
  final String? avatarUrl;
  final bool preferAppIcon;
  final DateTime receivedAt;
  final V2TimConversation? conversation;
  final V2TimMessage? message;
  final FutureOr<void> Function()? onTap;
  final VoidCallback onDismiss;
  final ValueChanged<bool> onExpandedChanged;

  @override
  State<_InAppMessageBannerOverlay> createState() =>
      _InAppMessageBannerOverlayState();
}

class _InAppMessageBannerOverlayState extends State<_InAppMessageBannerOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  AnimationController? _dragSettleController;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final List<V2TimMessage> _messages = <V2TimMessage>[];
  bool _handlingTap = false;
  bool _expanded = false;
  bool _dragging = false;
  bool _loadingMessages = false;
  bool _loadingOlder = false;
  bool _hasMoreOlder = true;
  bool _sending = false;
  double _dragOffsetY = 0;
  String? _loadError;
  late String _title;
  late String _body;
  late String? _avatarUrl;
  late DateTime _receivedAt;
  TUIChatSeparateViewModel? _chatModel;
  TIMUIKitChatController? _chatController;

  static const double _dismissDragThreshold = 36;
  static const double _expandDragThreshold = 48;
  static const double _loadOlderThreshold = 72;
  static const double _dismissOffscreenY = -220;

  bool get isExpanded => _expanded;

  // iOS 风格双主题配色；次要文字用 systemGray(0xFF8E8E93)，两种主题下通用。
  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _panelColor => _dark ? const Color(0xFF1C1C1E) : Colors.white;
  Color get _primaryTextColor =>
      _dark ? const Color(0xFFF2F2F7) : const Color(0xFF111111);
  Color get _bodyTextColor =>
      _dark ? const Color(0xFFD1D1D6) : const Color(0xFF3C3C43);
  Color get _composerBorderColor =>
      _dark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);
  Color get _inputFillColor =>
      _dark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
  Color get _sendDisabledColor =>
      _dark ? const Color(0xFF1F4A73) : const Color(0xFFB8D7F3);

  bool matchesConversation(V2TimConversation? conversation) {
    final currentId = widget.conversation?.conversationID.trim() ?? '';
    final incomingId = conversation?.conversationID.trim() ?? '';
    return currentId.isNotEmpty && currentId == incomingId;
  }

  @override
  void initState() {
    super.initState();
    _title = widget.title;
    _body = widget.body;
    _avatarUrl = widget.avatarUrl;
    _receivedAt = widget.receivedAt;
    _scrollController.addListener(_handleMessageScroll);
    // ChatModel 延后到展开时再建，避免入场抢主线程。
    if (widget.message != null) {
      _messages.add(widget.message!);
    }
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 270),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _dragSettleController?.dispose();
    _chatModel?.dispose();
    _scrollController
      ..removeListener(_handleMessageScroll)
      ..dispose();
    _textController.dispose();
    _inputFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _stopDragSettleAnimation() {
    final controller = _dragSettleController;
    if (controller == null) {
      return;
    }
    controller.stop();
    controller.dispose();
    _dragSettleController = null;
  }

  Future<void> _animateDragOffsetTo(
    double end, {
    required Duration duration,
    Curve curve = Curves.easeOutCubic,
  }) async {
    _stopDragSettleAnimation();
    if (!mounted) {
      return;
    }
    final start = _dragOffsetY;
    if ((end - start).abs() < 0.5) {
      setState(() {
        _dragOffsetY = end;
      });
      return;
    }
    final controller = AnimationController(vsync: this, duration: duration);
    _dragSettleController = controller;
    final animation = Tween<double>(begin: start, end: end).animate(
      CurvedAnimation(parent: controller, curve: curve),
    );
    void listener() {
      if (!mounted) {
        return;
      }
      setState(() {
        _dragOffsetY = animation.value;
      });
    }

    animation.addListener(listener);
    try {
      await controller.forward();
    } finally {
      animation.removeListener(listener);
      if (identical(_dragSettleController, controller)) {
        controller.dispose();
        _dragSettleController = null;
      } else {
        controller.dispose();
      }
    }
  }

  void _initChatModel() {
    final conversation = widget.conversation;
    if (conversation == null) {
      return;
    }
    final isGroup = _isGroupConversation(conversation);
    final conversationKey =
        (isGroup ? conversation.groupID : conversation.userID)?.trim() ?? '';
    if (conversationKey.isEmpty) {
      return;
    }
    final model = TUIChatSeparateViewModel()
      ..conversationID = conversationKey
      ..conversationType = isGroup ? ConvType.group : ConvType.c2c
      ..suppressReadReporting = true
      ..chatConfig = const TIMUIKitChatConfig(
        isShowReadingStatus: true,
        isUseMessageReaction: false,
        isUseDraft: false,
      );
    _chatModel = model;
    _chatController = TIMUIKitChatController(viewModel: model);
  }

  void updateIncoming({
    required String title,
    required String body,
    required String? avatarUrl,
    required DateTime receivedAt,
    required V2TimMessage? message,
  }) {
    if (!mounted) {
      return;
    }
    setState(() {
      _title = title;
      _body = body;
      _avatarUrl = avatarUrl;
      _receivedAt = receivedAt;
      if (message != null) {
        _upsertMessage(message);
      }
    });
    if (_expanded) {
      _scrollToLatest();
    }
  }

  void _upsertMessage(V2TimMessage message) {
    final messageId = message.msgID?.trim() ?? '';
    final localId = message.id?.trim() ?? '';
    final index = _messages.indexWhere((candidate) {
      if (messageId.isNotEmpty && candidate.msgID == messageId) {
        return true;
      }
      return localId.isNotEmpty && candidate.id == localId;
    });
    if (index >= 0) {
      _messages[index] = message;
    } else {
      _messages.add(message);
    }
    _messages.sort(_compareMessages);
  }

  int _compareMessages(V2TimMessage a, V2TimMessage b) {
    final timeCompare = (a.timestamp ?? 0).compareTo(b.timestamp ?? 0);
    if (timeCompare != 0) {
      return timeCompare;
    }
    final aSeq = int.tryParse(a.seq?.toString() ?? '') ?? 0;
    final bSeq = int.tryParse(b.seq?.toString() ?? '') ?? 0;
    return aSeq.compareTo(bSeq);
  }

  bool _isGroupConversation(V2TimConversation conversation) {
    return conversation.type == 2 ||
        (conversation.groupID?.trim().isNotEmpty ?? false);
  }

  bool get _canExpand => widget.conversation != null;

  Future<void> _expand() async {
    if (_expanded || !_canExpand) {
      return;
    }
    _stopDragSettleAnimation();
    if (_chatModel == null || _chatController == null) {
      _initChatModel();
    }
    if (_chatModel == null || _chatController == null) {
      return;
    }
    setState(() {
      _expanded = true;
      _dragging = false;
      _dragOffsetY = 0;
    });
    widget.onExpandedChanged(true);
    await _loadInitialMessages();
  }

  void _collapse() {
    if (!_expanded) {
      return;
    }
    _stopDragSettleAnimation();
    _inputFocusNode.unfocus();
    setState(() {
      _expanded = false;
      _dragging = false;
      _dragOffsetY = 0;
    });
    widget.onExpandedChanged(false);
  }

  Future<void> _loadInitialMessages() async {
    final conversation = widget.conversation;
    if (conversation == null || _loadingMessages) {
      return;
    }
    setState(() {
      _loadingMessages = true;
      _loadError = null;
    });
    try {
      final result = await ConversationPeekService.loadInitial(conversation);
      if (!mounted) {
        return;
      }
      setState(() {
        for (final message in result.messages) {
          _upsertMessage(message);
        }
        _hasMoreOlder = result.hasMoreOlder;
        _loadingMessages = false;
      });
      _scrollToLatest();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingMessages = false;
        _loadError = '加载消息失败';
      });
    }
  }

  void _handleMessageScroll() {
    if (!_expanded ||
        !_scrollController.hasClients ||
        _loadingMessages ||
        _loadingOlder ||
        !_hasMoreOlder ||
        _messages.isEmpty) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - _loadOlderThreshold) {
      return;
    }
    unawaited(_loadOlderMessages());
  }

  Future<void> _loadOlderMessages() async {
    final conversation = widget.conversation;
    if (conversation == null ||
        _loadingOlder ||
        !_hasMoreOlder ||
        _messages.isEmpty) {
      return;
    }
    setState(() {
      _loadingOlder = true;
    });
    try {
      final result = await ConversationPeekService.loadOlder(
        conversation: conversation,
        anchor: _messages.first,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        for (final message in result.messages) {
          _upsertMessage(message);
        }
        _hasMoreOlder = result.hasMoreOlder && result.messages.isNotEmpty;
        _loadingOlder = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingOlder = false;
      });
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _sendText() async {
    final model = _chatModel;
    final conversation = widget.conversation;
    final text = _textController.text.trim();
    if (model == null || conversation == null || text.isEmpty || _sending) {
      return;
    }
    final isGroup = _isGroupConversation(conversation);
    final conversationKey =
        (isGroup ? conversation.groupID : conversation.userID)?.trim() ?? '';
    if (conversationKey.isEmpty) {
      return;
    }
    setState(() {
      _sending = true;
    });
    try {
      final result = await model.sendTextMessage(
        text: text,
        convID: conversationKey,
        convType: isGroup ? ConvType.group : ConvType.c2c,
      );
      if (!mounted) {
        return;
      }
      if (result?.code == 0 && result?.data != null) {
        setState(() {
          _textController.clear();
          _upsertMessage(result!.data!);
        });
        _scrollToLatest();
      } else {
        _showSendFailure(result);
      }
    } catch (_) {
      if (mounted) {
        _showSendFailure(null);
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  void _showSendFailure(V2TimValueCallback<V2TimMessage>? result) {
    final message = result?.desc.trim();
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          message != null && message.isNotEmpty ? message : '发送失败',
        ),
      ),
    );
  }

  Future<void> _handleTap() async {
    if (_handlingTap) {
      return;
    }
    _handlingTap = true;
    try {
      final handler = widget.onTap;
      if (handler != null) {
        await Future<void>.sync(handler).timeout(
          const Duration(seconds: 3),
          onTimeout: () {},
        );
      }
    } catch (_) {}
    _handlingTap = false;
    await _dismiss();
  }

  Future<void> _dismiss({
    bool continueFromDrag = false,
    double velocity = 0,
  }) async {
    if (!mounted) {
      widget.onDismiss();
      return;
    }
    if (continueFromDrag) {
      // 从当前手指位置惯性飞出，避免再叠一层 SlideTransition reverse 打架。
      if (mounted) {
        setState(() {
          _dragging = true;
        });
      }
      final speed = (-velocity).clamp(0, 2500);
      final ms = (200 - speed / 20).clamp(110, 200).round();
      await _animateDragOffsetTo(
        _dismissOffscreenY,
        duration: Duration(milliseconds: ms),
        curve: Curves.easeOutCubic,
      );
      if (mounted) {
        widget.onDismiss();
      }
      return;
    }
    _stopDragSettleAnimation();
    if (_dragOffsetY != 0 || _dragging) {
      setState(() {
        _dragging = false;
        _dragOffsetY = 0;
      });
    }
    await _controller.reverse();
    if (mounted) {
      widget.onDismiss();
    }
  }

  Future<void> _snapDragBack() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _dragging = true;
    });
    await _animateDragOffsetTo(
      0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _dragging = false;
      _dragOffsetY = 0;
    });
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (!_canExpand && details.delta.dy > 0) {
      return;
    }
    _stopDragSettleAnimation();
    setState(() {
      _dragging = true;
      _dragOffsetY = (_dragOffsetY + details.delta.dy).clamp(-140, 180);
    });
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_expanded) {
      if (_dragOffsetY <= -_expandDragThreshold || velocity < -700) {
        _collapse();
        return;
      }
      unawaited(_snapDragBack());
      return;
    }
    if (_canExpand &&
        (_dragOffsetY >= _expandDragThreshold || velocity > 700)) {
      unawaited(_expand());
      return;
    }
    if (_dragOffsetY <= -_dismissDragThreshold || velocity < -700) {
      unawaited(_dismiss(continueFromDrag: true, velocity: velocity));
      return;
    }
    unawaited(_snapDragBack());
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final availableHeight = mediaQuery.size.height -
        mediaQuery.padding.top -
        mediaQuery.viewInsets.bottom;
    final keyboardVisible = mediaQuery.viewInsets.bottom > 0;
    final expandedHeight = (availableHeight * (keyboardVisible ? 0.88 : 0.72))
        .clamp(220.0, 650.0)
        .clamp(0.0, availableHeight - 6)
        .toDouble();
    final dragExpansion = _expanded ? 0.0 : _dragOffsetY.clamp(0, 180);
    final panelHeight =
        _expanded ? expandedHeight : 84.0 + dragExpansion * 0.45;
    // 上滑关闭动画可飞到屏幕外，不再卡在 -120。
    final upwardOffset = _dragOffsetY.clamp(_dismissOffscreenY, 0).toDouble();
    final dragOpacity =
        (1 + (upwardOffset / 140)).clamp(0.0, 1.0).toDouble();
    const keyboardPanelGap = 8.0;
    const panelOuterTopPadding = 6.0;
    final panelTop = _expanded && keyboardVisible
        ? (availableHeight -
                panelHeight -
                keyboardPanelGap -
                panelOuterTopPadding)
            .clamp(0.0, double.infinity)
            .toDouble()
        : 0.0;

    return Stack(
      children: [
        if (_expanded)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _collapse,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                color: Colors.black.withValues(alpha: 0.22),
              ),
            ),
          ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          top: panelTop,
          left: 0,
          right: 0,
          child: SlideTransition(
            position: _slide,
            child: Material(
              color: Colors.transparent,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                  child: Transform.translate(
                    offset: Offset(0, upwardOffset),
                    child: Opacity(
                      opacity: dragOpacity,
                      child: _buildPanelShell(
                        height: panelHeight,
                        child: Material(
                          color: _panelColor,
                          child: Column(
                            children: [
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _handleTap,
                                onVerticalDragUpdate: _handleVerticalDragUpdate,
                                onVerticalDragEnd: _handleVerticalDragEnd,
                                child: SizedBox(
                                  // 展开成迷你聊天后头部只剩单行标题+副标题，压矮一些。
                                  height: _expanded ? 64 : 84,
                                  child: _buildBannerHeader(),
                                ),
                              ),
                              if (_expanded) ...[
                                Divider(height: 1, color: _composerBorderColor),
                                Expanded(child: _buildExpandedConversation()),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPanelShell({
    required double height,
    required Widget child,
  }) {
    final decoration = BoxDecoration(
      color: _panelColor,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: _dark ? 0.32 : 0.10),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
    // 拖动中瞬时跟手；展开/收起再用短动画。
    if (_dragging) {
      return Container(
        height: height,
        decoration: decoration,
        clipBehavior: Clip.antiAlias,
        child: child,
      );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      height: height,
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _buildBannerHeader() {
    final verticalPadding = _expanded ? 6.0 : 10.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, verticalPadding, 12, verticalPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _BannerAvatar(
            title: _title,
            avatarUrl: _avatarUrl,
            preferAppIcon: widget.preferAppIcon,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _primaryTextColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_expanded)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _collapse,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                      )
                    else
                      Text(
                        _formatTimeAgo(_receivedAt),
                        style: const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
                if (!_expanded && _body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _bodyTextColor,
                      fontSize: 15,
                      height: 1.2,
                    ),
                  ),
                ] else if (_expanded)
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Text(
                      '迷你聊天',
                      style: TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedConversation() {
    return Column(
      children: [
        Expanded(child: _buildMessageList()),
        _buildComposer(),
      ],
    );
  }

  Widget _buildMessageList() {
    if (_loadingMessages && _messages.length <= 1) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_loadError != null && _messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _loadError!,
              style: const TextStyle(color: Color(0xFF8E8E93)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadInitialMessages,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_messages.isEmpty) {
      return const Center(
        child: Text(
          '暂无消息',
          style: TextStyle(color: Color(0xFF8E8E93)),
        ),
      );
    }

    final model = _chatModel!;
    final controller = _chatController!;
    final conversation = widget.conversation!;
    final isGroup = _isGroupConversation(conversation);
    final extraLoader = _loadingOlder ? 1 : 0;
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
          ChangeNotifierProvider<TUIChatSeparateViewModel>.value(value: model),
        ],
        child: ListView.builder(
          controller: _scrollController,
          reverse: true,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          itemCount: _messages.length + extraLoader,
          itemBuilder: (context, index) {
            if (index >= _messages.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            final message = _messages[_messages.length - 1 - index];
            return ConversationPeekMessageItem(
              message: message,
              chatModel: model,
              chatController: controller,
              isGroup: isGroup,
              subtitleColor: const Color(0xFF8E8E93),
              peerFaceUrl: conversation.faceUrl,
              peerShowName: conversation.showName,
              peerUserId: conversation.userID,
              groupId: conversation.groupID,
            );
          },
        ),
      ),
    );
  }

  Widget _buildComposer() {
    // 面板悬浮在屏幕上部、不贴屏幕底边，不需要 SafeArea 的 home 指示条
    // 底部留白（键盘收起时那 ~34pt 全是空隙）。
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: _panelColor,
        border: Border(top: BorderSide(color: _composerBorderColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _inputFocusNode,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => unawaited(_sendText()),
              style: TextStyle(color: _primaryTextColor),
              decoration: InputDecoration(
                hintText: '输入消息',
                hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
                isDense: true,
                filled: true,
                fillColor: _inputFillColor,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _sending ? null : () => unawaited(_sendText()),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF3390EC),
              disabledBackgroundColor: _sendDisabledColor,
            ),
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.arrow_upward_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _BannerAvatar extends StatelessWidget {
  const _BannerAvatar({
    required this.title,
    this.avatarUrl,
    this.preferAppIcon = false,
  });

  final String title;
  final String? avatarUrl;
  final bool preferAppIcon;

  static const double _size = 44;

  Widget _buildPlaceholderAvatar() {
    return SizedBox(
      width: _size,
      height: _size,
      child: ClipOval(
        child: Image.asset(
          UserAvatarHelper.defaultC2CAvatarAsset,
          width: _size,
          height: _size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Image.asset(
            UserAvatarHelper.appDefaultAvatarAsset,
            width: _size,
            height: _size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(
              color: Color(0xFFE5E5EA),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkAvatar(String url, BuildContext context) {
    final headers = UserAvatarHelper.httpHeadersFor(url);
    final cacheSize = ImageMemCacheSize.forLogicalSize(_size, context);
    return SizedBox(
      width: _size,
      height: _size,
      child: ClipOval(
        child: AppNetworkImage(
          url: url,
          width: _size,
          height: _size,
          fit: BoxFit.cover,
          headers: headers,
          memCacheWidth: cacheSize,
          memCacheHeight: cacheSize,
          errorWidget: (_, __, ___) => _buildPlaceholderAvatar(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (preferAppIcon) {
      return SizedBox(
        width: _size,
        height: _size,
        child: ClipOval(
          child: Image.asset(
            InAppMessageNotificationBanner.appIconAsset,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(
              color: Color(0xFF007AFF),
            ),
          ),
        ),
      );
    }

    final networkUrl = UserAvatarHelper.resolveBannerAvatarUrl(avatarUrl);
    final avatar = networkUrl != null
        ? _buildNetworkAvatar(networkUrl, context)
        : _buildPlaceholderAvatar();
    final dark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: avatar),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dark ? const Color(0xFF1C1C1E) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(1.5),
              child: ClipOval(
                child: Image.asset(
                  InAppMessageNotificationBanner.appIconAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: Color(0xFF007AFF),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTimeAgo(DateTime receivedAt) {
  final now = DateTime.now();
  final diff = now.difference(receivedAt);
  if (diff.inSeconds < 10) {
    return '刚刚';
  }
  if (diff.inMinutes < 1) {
    return '${diff.inSeconds}秒前';
  }
  if (diff.inHours < 1) {
    return '${diff.inMinutes}分钟前';
  }
  if (diff.inDays < 1) {
    return '${diff.inHours}小时前';
  }
  if (diff.inDays < 7) {
    return '${diff.inDays}天前';
  }
  return '${receivedAt.month}/${receivedAt.day}';
}

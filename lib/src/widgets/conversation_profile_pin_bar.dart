import 'package:flutter/material.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/api/conversation_pin_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_pin_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_pin_sync_service.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitProfile/widget/tim_uikit_operation_item.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitProfile/widget/tim_uikit_profile_widget.dart';

/// UIKit 资料弹窗里的置顶开关，与列表共用 [ConversationPinService]。
class ConversationProfilePinBar extends StatefulWidget {
  const ConversationProfilePinBar({
    super.key,
    required this.conversation,
    required this.source,
    this.smallCardMode = true,
  });

  final V2TimConversation conversation;
  final String source;
  final bool smallCardMode;

  @override
  State<ConversationProfilePinBar> createState() =>
      _ConversationProfilePinBarState();
}

class _ConversationProfilePinBarState extends State<ConversationProfilePinBar> {
  late bool _pinned;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _pinned = ConversationPinSyncService.instance
        .isPinnedConversationId(widget.conversation.conversationID);
  }

  @override
  void didUpdateWidget(covariant ConversationProfilePinBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversation.conversationID !=
        widget.conversation.conversationID) {
      _pinned = ConversationPinSyncService.instance
          .isPinnedConversationId(widget.conversation.conversationID);
    }
  }

  Future<void> _onChanged(bool value) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _pinned = value;
    });
    try {
      final result = await ConversationPinService.instance.setPinned(
        conversation: widget.conversation,
        isPinned: value,
        source: widget.source,
      );
      if (!mounted) {
        return;
      }
      if (!result.applied) {
        setState(() {
          _pinned = !value;
          _busy = false;
        });
        _showConversationPinFailedToast(context);
        return;
      }
      setState(() => _busy = false);
    } on ConversationPinLimitExceededException {
      if (!mounted) {
        return;
      }
      setState(() {
        _pinned = !value;
        _busy = false;
      });
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '置顶已达上限（最多 100 个）',
        zhHant: '置頂已達上限（最多 100 個）',
        en: 'Pin limit reached (max 100)',
        ja: 'ピン留め上限です（最大100）',
        ko: '고정 한도에 도달했습니다(최대 100)',
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return TIMUIKitProfileWidget.pinConversationBar(
      _pinned,
      context,
      _busy ? null : _onChanged,
      widget.smallCardMode,
    );
  }
}

void _showConversationPinFailedToast(BuildContext context) {
  ToastUtils.toast(AppI18n.of(context).t(
    zhHans: '设置失败',
    zhHant: '設置失敗',
    en: 'Failed to update',
    ja: '設定に失敗しました',
    ko: '설정에 실패했습니다',
  ));
}

/// 群资料侧栏 / 弹层里的置顶开关。
class ConversationGroupProfilePinBar extends StatefulWidget {
  const ConversationGroupProfilePinBar({
    super.key,
    required this.groupID,
    required this.source,
    this.conversation,
    this.onApplied,
    this.isUseCheckedBoxOnWide = true,
  });

  final String groupID;
  final String source;
  final V2TimConversation? conversation;
  final void Function(bool isPinned)? onApplied;
  final bool isUseCheckedBoxOnWide;

  @override
  State<ConversationGroupProfilePinBar> createState() =>
      _ConversationGroupProfilePinBarState();
}

class _ConversationGroupProfilePinBarState
    extends State<ConversationGroupProfilePinBar> {
  late bool _pinned;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _pinned = ConversationPinSyncService.instance
        .isPinnedConversationId('group_${widget.groupID.trim()}');
  }

  @override
  void didUpdateWidget(covariant ConversationGroupProfilePinBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupID != widget.groupID) {
      _pinned = ConversationPinSyncService.instance
          .isPinnedConversationId('group_${widget.groupID.trim()}');
    }
  }

  Future<void> _onChanged(bool value) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _pinned = value;
    });
    final conversation = ConversationPinService.groupConversationSnapshot(
      groupID: widget.groupID,
      existing: widget.conversation,
    );
    try {
      final result = await ConversationPinService.instance.setPinned(
        conversation: conversation,
        isPinned: value,
        source: widget.source,
      );
      if (!mounted) {
        return;
      }
      if (!result.applied) {
        setState(() {
          _pinned = !value;
          _busy = false;
        });
        _showConversationPinFailedToast(context);
        return;
      }
      widget.onApplied?.call(result.isPinned);
      setState(() => _busy = false);
    } on ConversationPinLimitExceededException {
      if (!mounted) {
        return;
      }
      setState(() {
        _pinned = !value;
        _busy = false;
      });
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '置顶已达上限（最多 100 个）',
        zhHant: '置頂已達上限（最多 100 個）',
        en: 'Pin limit reached (max 100)',
        ja: 'ピン留め上限です（最大100）',
        ko: '고정 한도에 도달했습니다(최대 100)',
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return TIMUIKitOperationItem(
      isEmpty: false,
      operationName: TIM_t("置顶聊天"),
      type: "switch",
      isUseCheckedBoxOnWide: widget.isUseCheckedBoxOnWide,
      operationValue: _pinned,
      onSwitchChange: _busy ? null : _onChanged,
    );
  }
}

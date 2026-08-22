import 'package:flutter/material.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';

class ForwardSinglePreviewItem {
  const ForwardSinglePreviewItem({
    required this.senderName,
    required this.summary,
    this.faceUrl = '',
  });

  final String senderName;
  final String summary;
  final String faceUrl;
}

/// 全屏「正在发送中」遮罩（走 rootNavigator，避免被 bottomSheet 挡住或布局挤掉）。
Future<T> runWithForwardSendingOverlay<T>({
  required BuildContext context,
  required Future<T> Function() action,
  String? statusText,
  Color? indicatorColor,
  Color? cardColor,
  Color? textColor,
}) async {
  final label = statusText ?? TIM_t("正在发送中");
  final primary = indicatorColor ?? const Color(0xFF2196F3);
  final bg = cardColor ?? Colors.white;
  final fg = textColor ?? const Color(0xFF111111);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    builder: (dialogContext) {
      return PopScope(
        canPop: false,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  // 先让遮罩完成一帧绘制，再跑可能很重的转发循环。
  await WidgetsBinding.instance.endOfFrame;
  await Future<void>.delayed(Duration.zero);

  try {
    return await action();
  } finally {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }
}

/// 确认转发底部弹层。
///
/// [onConfirmSend] 在用户点「发送」后执行；期间展示全屏「正在发送中」。
Future<bool?> showForwardConfirmBottomSheet({
  required BuildContext context,
  required TUITheme theme,
  required bool isMergerForward,
  required List<V2TimConversation> receivers,
  required Future<void> Function() onConfirmSend,
  List<ForwardSinglePreviewItem> singleItems = const [],
  String mergeTitle = '',
  List<String> mergeAbstracts = const [],
}) {
  final sheetColor =
      theme.conversationItemBgColor ?? theme.weakBackgroundColor ?? Colors.white;
  final previewBg =
      theme.selectPanelBgColor ?? theme.inputFillColor ?? const Color(0xFFF5F5F5);
  final isDark = sheetColor.computeLuminance() < 0.5;
  final titleColor = isDark ? Colors.white : const Color(0xFF111111);
  final secondaryText = theme.weakTextColor ?? const Color(0xFF999999);
  final cancelBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F1F5);
  final primary = theme.primaryColor ?? const Color(0xFF2196F3);

  Widget buildSheet(BuildContext sheetContext) {
    return _ForwardConfirmSheet(
      theme: theme,
      sheetColor: sheetColor,
      previewBg: previewBg,
      titleColor: titleColor,
      secondaryText: secondaryText,
      cancelBg: cancelBg,
      primary: primary,
      isMergerForward: isMergerForward,
      receivers: receivers,
      singleItems: singleItems,
      mergeTitle: mergeTitle,
      mergeAbstracts: mergeAbstracts,
      onConfirmSend: onConfirmSend,
    );
  }

  final isDesktop =
      TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
  if (isDesktop) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Material(
                color: Colors.transparent,
                child: buildSheet(dialogContext),
              ),
            ),
          ),
        );
      },
    );
  }

  return showModalBottomSheet<bool>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    useSafeArea: true,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    backgroundColor: Colors.transparent,
    builder: buildSheet,
  );
}

class _ForwardConfirmSheet extends StatefulWidget {
  const _ForwardConfirmSheet({
    required this.theme,
    required this.sheetColor,
    required this.previewBg,
    required this.titleColor,
    required this.secondaryText,
    required this.cancelBg,
    required this.primary,
    required this.isMergerForward,
    required this.receivers,
    required this.singleItems,
    required this.mergeTitle,
    required this.mergeAbstracts,
    required this.onConfirmSend,
  });

  final TUITheme theme;
  final Color sheetColor;
  final Color previewBg;
  final Color titleColor;
  final Color secondaryText;
  final Color cancelBg;
  final Color primary;
  final bool isMergerForward;
  final List<V2TimConversation> receivers;
  final List<ForwardSinglePreviewItem> singleItems;
  final String mergeTitle;
  final List<String> mergeAbstracts;
  final Future<void> Function() onConfirmSend;

  @override
  State<_ForwardConfirmSheet> createState() => _ForwardConfirmSheetState();
}

class _ForwardConfirmSheetState extends State<_ForwardConfirmSheet> {
  bool _sending = false;

  Future<void> _handleSend() async {
    if (_sending) {
      return;
    }
    setState(() => _sending = true);
    try {
      await runWithForwardSendingOverlay(
        context: context,
        indicatorColor: widget.primary,
        cardColor: widget.sheetColor,
        textColor: widget.titleColor,
        action: widget.onConfirmSend,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenWidth = mq.size.width;
    final bottomSafe = mq.padding.bottom;
    final isWide = TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop ||
        screenWidth >= 600;
    final horizontalPadding = isWide ? 28.0 : 24.0;
    final previewHeight = widget.isMergerForward
        ? (isWide ? 168.0 : 148.0)
        : (isWide ? 128.0 : 112.0);

    final receiver = widget.receivers.isNotEmpty ? widget.receivers.first : null;
    final receiverName = _receiverDisplayName(widget.receivers);
    final receiverFaceUrl = receiver?.faceUrl ?? '';
    final receiverType = (receiver?.type == 2) ? 2 : 1;

    final mergeVisible = widget.mergeAbstracts.take(3).toList();
    final mergeTotal = widget.mergeAbstracts.length;
    final singleCount = widget.singleItems.length;
    final singlePreview =
        widget.singleItems.isNotEmpty ? widget.singleItems.first : null;

    // 不用 Align + 无界 Stack：多会话时容易只剩 barrier、白底确认卡高度塌掉。
    final sheetBody = Material(
      color: Colors.transparent,
      child: Container(
        width: isWide ? screenWidth.clamp(360.0, 480.0) : screenWidth,
        decoration: BoxDecoration(
          color: widget.sheetColor,
          borderRadius: isWide
              ? BorderRadius.circular(16)
              : const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            24,
            horizontalPadding,
                  bottomSafe + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TIM_t("发送给"),
                      style: TextStyle(
                        color: widget.secondaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: Avatar(
                            faceUrl: receiverFaceUrl,
                            showName: receiverName,
                            type: receiverType,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            receiverName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: widget.titleColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: previewHeight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: widget.previewBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          child: widget.isMergerForward
                              ? _buildMergePreview(
                                  title: widget.mergeTitle,
                                  lines: mergeVisible,
                                  total: mergeTotal,
                                  primaryText: widget.titleColor,
                                  secondaryText: widget.secondaryText,
                                )
                              : _buildSinglePreview(
                                  count: singleCount,
                                  item: singlePreview,
                                  primaryText: widget.titleColor,
                                  secondaryText: widget.secondaryText,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 38,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: widget.cancelBg,
                                foregroundColor: widget.titleColor,
                                disabledBackgroundColor:
                                    widget.cancelBg.withValues(alpha: 0.6),
                                disabledForegroundColor:
                                    widget.titleColor.withValues(alpha: 0.45),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              onPressed: _sending
                                  ? null
                                  : () => Navigator.of(context).pop(false),
                              child: Text(
                                TIM_t("取消"),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 38,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: widget.primary,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    widget.primary.withValues(alpha: 0.45),
                                disabledForegroundColor:
                                    Colors.white.withValues(alpha: 0.85),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              onPressed: _sending ? null : _handleSend,
                              child: Text(
                                _sending ? TIM_t("发送中") : TIM_t("发送"),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );

    return PopScope(
      canPop: !_sending,
      child: Padding(
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        child: isWide
            ? sheetBody
            : Align(
                alignment: Alignment.bottomCenter,
                child: sheetBody,
              ),
      ),
    );
  }
}

String _receiverDisplayName(List<V2TimConversation> receivers) {
  if (receivers.isEmpty) {
    return '';
  }
  final first = (receivers.first.showName ?? '').trim();
  final display = first.isNotEmpty
      ? first
      : (receivers.first.userID ?? receivers.first.groupID ?? '');
  if (receivers.length <= 1) {
    return display;
  }
  return TIM_t_para("{{option1}}等{{option2}}人", "$display等${receivers.length}人")(
    option1: display,
    option2: receivers.length.toString(),
  );
}

Widget _buildSinglePreview({
  required int count,
  required ForwardSinglePreviewItem? item,
  required Color primaryText,
  required Color secondaryText,
}) {
  if (item == null) {
    return Align(
      alignment: Alignment.topLeft,
      child: Text(
        TIM_t("转发消息"),
        style: TextStyle(color: secondaryText, fontSize: 13),
      ),
    );
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        count <= 1
            ? TIM_t("逐条转发 · 1 条消息")
            : TIM_t_para("逐条转发 · {{option1}} 条消息", "逐条转发 · $count 条消息")(
                option1: count.toString(),
              ),
        style: TextStyle(color: secondaryText, fontSize: 13),
      ),
      const SizedBox(height: 10),
      Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: Avatar(
                faceUrl: item.faceUrl,
                showName: item.senderName,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.senderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      item.summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (count > 1)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            TIM_t_para("… 还有 {{option1}} 条", "… 还有 ${count - 1} 条")(
              option1: (count - 1).toString(),
            ),
            style: TextStyle(color: secondaryText, fontSize: 12),
          ),
        ),
    ],
  );
}

Widget _buildMergePreview({
  required String title,
  required List<String> lines,
  required int total,
  required Color primaryText,
  required Color secondaryText,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: primaryText,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),
          ],
        ),
      ),
      if (total > lines.length)
        Text(
          TIM_t_para("… 共 {{option1}} 条", "… 共 $total 条")(
            option1: total.toString(),
          ),
          style: TextStyle(color: secondaryText, fontSize: 12),
        ),
    ],
  );
}

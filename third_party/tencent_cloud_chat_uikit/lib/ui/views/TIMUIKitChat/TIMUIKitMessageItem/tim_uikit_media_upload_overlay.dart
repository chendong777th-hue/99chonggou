import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/chat_ui_state_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';

/// 图片/视频消息发送中的进度遮罩（读取 [TUIChatGlobalModel.getMessageProgress]）。
class TimUIKitMediaUploadOverlay {
  TimUIKitMediaUploadOverlay._();

  static int resolveUploadProgress(
    TUIChatGlobalModel model,
    V2TimMessage message,
  ) {
    final byMsgId = message.msgID != null && message.msgID!.isNotEmpty
        ? model.getMessageProgress(message.msgID)
        : 0;
    final byId = message.id != null && message.id!.isNotEmpty
        ? model.getMessageProgress(message.id)
        : 0;
    return max(byMsgId, byId);
  }

  static bool shouldShowUploadOverlay(
    V2TimMessage message,
    int progress, {
    int? statusOverride,
  }) {
    if (message.isSelf != true) {
      return false;
    }
    final status = statusOverride ??
        message.status ??
        MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
    if (status == MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL) {
      return false;
    }
    if (status == MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC) {
      return false;
    }
    if (progress >= 100) {
      return false;
    }
    return status == MessageStatus.V2TIM_MSG_STATUS_SENDING ||
        (progress > 0 && progress < 100);
  }

  static bool supportsInlineUploadOverlay(int? elemType) {
    return elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE ||
        elemType == MessageElemType.V2TIM_ELEM_TYPE_VIDEO;
  }

  static int effectiveMessageStatus({
    required TUIChatGlobalModel model,
    required String conversationID,
    required V2TimMessage message,
  }) {
    final fallback = message.status ?? MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
    if (message.isSelf != true) {
      return fallback;
    }
    model.messageListRevisionFor(conversationID);
    return model.messageStatusInConversation(
      conversationID,
      clientId: message.id,
      msgID: message.msgID,
      fallback: fallback,
      elemType: message.elemType,
    );
  }

  static Widget build({
    required int progress,
    required bool visible,
    VoidCallback? onCancel,
  }) {
    if (!visible) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: GestureDetector(
        onTap: onCancel,
        behavior: HitTestBehavior.opaque,
        child: ColoredBox(
          color: const Color(0x99000000),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: progress.clamp(0, 100) / 100),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            builder: (context, displayProgress, _) {
              final showPercent = displayProgress > 0 && displayProgress < 1;
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: showPercent ? displayProgress : null,
                            strokeWidth: 3,
                            color: Colors.white,
                            backgroundColor: Colors.white24,
                          ),
                          Icon(
                            onCancel != null
                                ? Icons.stop_rounded
                                : Icons.cloud_upload_outlined,
                            color: Colors.white,
                            size: onCancel != null ? 28 : 24,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      onCancel != null
                          ? TIM_t('点击停止发送')
                          : (showPercent
                              ? '${(displayProgress * 100).round()}%'
                              : TIM_t('发送中')),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 仅重建上传遮罩，避免进度更新牵动整张图片气泡。
class TimUIKitMessageUploadOverlayLayer extends StatefulWidget {
  const TimUIKitMessageUploadOverlayLayer({
    super.key,
    required this.message,
    required this.conversationID,
    required this.globalModel,
  });

  final V2TimMessage message;
  final String conversationID;
  final TUIChatGlobalModel globalModel;

  @override
  State<TimUIKitMessageUploadOverlayLayer> createState() =>
      _TimUIKitMessageUploadOverlayLayerState();
}

class _TimUIKitMessageUploadOverlayLayerState
    extends State<TimUIKitMessageUploadOverlayLayer> {
  @override
  Widget build(BuildContext context) {
    final msgKey = ChatUiStateStore.messageKeyOf(widget.message);
    context.select<ChatUiStateStore, int>(
      (store) => store.rowRevision(widget.conversationID, msgKey),
    );
    final progress = TimUIKitMediaUploadOverlay.resolveUploadProgress(
      widget.globalModel,
      widget.message,
    );
    final status = TimUIKitMediaUploadOverlay.effectiveMessageStatus(
      model: widget.globalModel,
      conversationID: widget.conversationID,
      message: widget.message,
    );
    final visible = TimUIKitMediaUploadOverlay.shouldShowUploadOverlay(
      widget.message,
      progress,
      statusOverride: status,
    );
    return TimUIKitMediaUploadOverlay.build(
      progress: progress,
      visible: visible,
    );
  }
}

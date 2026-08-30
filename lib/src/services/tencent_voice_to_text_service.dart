import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_sound_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_sound_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/contracts/account_scoped_conversation_key.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/outgoing_send_coordinator.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';

class TencentVoiceToTextResult {
  const TencentVoiceToTextResult({
    this.text,
    this.errorMessage,
  });

  final String? text;
  final String? errorMessage;

  bool get isSuccess => text != null && text!.trim().isNotEmpty;
}

class _PendingVoiceUpload {
  _PendingVoiceUpload({
    required this.msgID,
    required this.message,
  });

  final String msgID;
  final V2TimMessage message;
}

/// 腾讯 IM [convertVoiceToText](https://trtc.io/zh/document/60751?product=chat)
/// 实例区域与当前 init 的 sdkAppId（后端 UserSig）绑定，无需额外区域配置。
class TencentVoiceToTextService {
  TencentVoiceToTextService._();

  static String? lastErrorMessage;
  static _PendingVoiceUpload? _pendingUpload;

  static bool get hasPendingUpload => _pendingUpload != null;

  static void acknowledgePendingUpload() {
    _pendingUpload = null;
  }

  static _PendingVoiceUpload? takePendingUpload() {
    final pending = _pendingUpload;
    _pendingUpload = null;
    return pending;
  }

  static Future<TencentVoiceToTextResult> convertMessage({
    required V2TimMessage message,
    String? msgID,
    Future<String?> Function(V2TimMessage message, String msgID)? resolveUrl,
  }) async {
    lastErrorMessage = null;
    if (kIsWeb) {
      return const TencentVoiceToTextResult(
        errorMessage: '当前平台暂不支持语音转文字',
      );
    }

    final resolvedMsgID = msgID?.trim();
    String? audioUrl = message.soundElem?.url?.trim();
    if ((audioUrl == null || audioUrl.isEmpty) &&
        resolveUrl != null &&
        resolvedMsgID != null &&
        resolvedMsgID.isNotEmpty) {
      audioUrl = await resolveUrl(message, resolvedMsgID);
    }
    if (audioUrl == null || audioUrl.isEmpty) {
      lastErrorMessage = '语音文件不可用';
      return TencentVoiceToTextResult(errorMessage: lastErrorMessage);
    }
    message.soundElem ??= V2TimSoundElem();
    message.soundElem!.url = audioUrl;

    final result = await TencentImSDKPlugin.v2TIMManager
        .getMessageManager()
        .convertVoiceToText(
          message: message,
          msgID: resolvedMsgID,
          language: IMDemoConfig.voiceToTextLanguage,
        );
    return _mapSdkResult(result);
  }

  /// 本地录音需先上传拿到 URL，再调用 convertVoiceToText。
  static Future<TencentVoiceToTextResult> convertLocalFile({
    required String soundPath,
    required int duration,
    required String convID,
    required ConvType convType,
    required MessageService messageService,
    Future<String?> Function(V2TimMessage message, String msgID)? resolveUrl,
  }) async {
    lastErrorMessage = null;
    if (kIsWeb) {
      return const TencentVoiceToTextResult(
        errorMessage: '当前平台暂不支持语音转文字',
      );
    }

    final path = soundPath.trim();
    final targetConvID = convID.trim();
    if (path.isEmpty || targetConvID.isEmpty || convType == ConvType.none) {
      lastErrorMessage = '语音文件不可用';
      return TencentVoiceToTextResult(errorMessage: lastErrorMessage);
    }

    final effectiveDuration = duration > 0 ? duration : _estimateWavDurationSec(path);
    if (effectiveDuration <= 0) {
      lastErrorMessage = '说话时间太短';
      return TencentVoiceToTextResult(errorMessage: lastErrorMessage);
    }

    final createResult = await messageService.createSoundMessage(
      soundPath: path,
      duration: effectiveDuration,
    );
    final message = createResult?.messageInfo;
    final messageID = createResult?.id;
    if (message == null || messageID == null || messageID.isEmpty) {
      lastErrorMessage = '语音消息创建失败';
      return TencentVoiceToTextResult(errorMessage: lastErrorMessage);
    }

    message.soundElem ??= V2TimSoundElem();
    message.soundElem!.path = path;
    message.soundElem!.localUrl ??= path;

    final receiver = convType == ConvType.c2c ? targetConvID : '';
    final groupID = convType == ConvType.group ? targetConvID : '';
    final coordinatorConvType = convType == ConvType.c2c
        ? ImConversationType.c2c
        : ImConversationType.group;
    final coordinated = await ImOutgoingSendCoordinator.instance.send(
      messageService: messageService,
      sdkLocalId: messageID,
      conversationId: targetConvID,
      conversationType: coordinatorConvType,
      receiver: receiver,
      groupID: groupID,
      fallbackMessage: message,
      isExcludedFromUnreadCount: true,
      persistOutbox: false,
    );
    if (coordinated.sdkResult.code != 0) {
      final desc = coordinated.sdkResult.desc.trim();
      lastErrorMessage = desc.isNotEmpty ? desc : '语音上传失败';
      return TencentVoiceToTextResult(errorMessage: lastErrorMessage);
    }

    final sentMessage = coordinated.sdkResult.data ?? message;
    final sentMsgID = sentMessage.msgID?.trim();
    if (sentMsgID == null || sentMsgID.isEmpty) {
      lastErrorMessage = '语音上传失败';
      return TencentVoiceToTextResult(errorMessage: lastErrorMessage);
    }

    _pendingUpload = _PendingVoiceUpload(
      msgID: sentMsgID,
      message: sentMessage,
    );

    return convertMessage(
      message: sentMessage,
      msgID: sentMsgID,
      resolveUrl: resolveUrl,
    );
  }

  static TencentVoiceToTextResult _mapSdkResult(
    V2TimValueCallback<String> result,
  ) {
    final text = result.data?.trim();
    if (result.code == 0 && text != null && text.isNotEmpty) {
      return TencentVoiceToTextResult(text: text);
    }

    final desc = result.desc.trim();
    if (desc.isNotEmpty) {
      lastErrorMessage = desc;
      return TencentVoiceToTextResult(errorMessage: desc);
    }
    lastErrorMessage = '转文字失败，请重试';
    return TencentVoiceToTextResult(errorMessage: lastErrorMessage);
  }

  static int _estimateWavDurationSec(String path) {
    try {
      final file = File(path);
      if (!file.existsSync()) {
        return 0;
      }
      final bytes = file.lengthSync();
      if (bytes <= 44) {
        return 0;
      }
      // flutter_plugin_record_plus iOS 默认 8kHz/16bit/mono。
      return max(1, ((bytes - 44) / 16000).ceil());
    } catch (_) {
      return 0;
    }
  }
}

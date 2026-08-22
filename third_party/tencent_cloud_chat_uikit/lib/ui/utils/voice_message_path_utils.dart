import 'dart:async';
import 'dart:io';

import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/common_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';

class VoiceMessagePathUtils {
  VoiceMessagePathUtils._();

  static String? resolveLocalSoundPath({
    required V2TimMessage message,
    required TUIChatGlobalModel globalModel,
  }) {
    if (PlatformUtils().isWeb) {
      return null;
    }
    final msgID = TencentUtils.checkString(message.msgID);
    final candidates = <String?>[
      if (msgID != null) globalModel.getFileMessageLocation(msgID),
      globalModel.getFileMessageLocation(message.id),
      message.soundElem?.path,
      message.soundElem?.localUrl,
    ];
    for (final raw in candidates) {
      final path = TencentUtils.checkString(raw);
      if (path != null && File(path).existsSync()) {
        return path;
      }
    }
    return null;
  }

  static Future<String?> resolveLocalSoundPathWithDownload({
    required V2TimMessage message,
    required TUIChatGlobalModel globalModel,
    required MessageService messageService,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final existing = resolveLocalSoundPath(
      message: message,
      globalModel: globalModel,
    );
    if (existing != null) {
      return existing;
    }
    if (PlatformUtils().isWeb) {
      return null;
    }

    final msgID = TencentUtils.checkString(message.msgID);
    if (msgID == null) {
      return null;
    }

    unawaited(messageService.downloadMessage(
      msgID: msgID,
      messageType: MessageElemType.V2TIM_ELEM_TYPE_SOUND,
      imageType: 0,
      isSnapshot: false,
      reportError: false,
    ));

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final path = resolveLocalSoundPath(
        message: message,
        globalModel: globalModel,
      );
      if (path != null) {
        return path;
      }
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }

    final messages = await messageService.findMessages(messageIDList: [msgID]);
    final sound = (messages != null && messages.isNotEmpty)
        ? messages.first.soundElem
        : null;
    if (sound != null) {
      message.soundElem = sound;
    }
    return resolveLocalSoundPath(message: message, globalModel: globalModel);
  }
}

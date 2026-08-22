import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/calling_message/calling_message_data_provider.dart';

enum CallMessageOutcome {
  answered,
  missed,
  rejected,
  cancelled,
  noAnswer,
}

class CallMessageVisual {
  CallMessageVisual._();

  static const Color negativeAccentColor = Color(0xFFE64340);

  static CallMessageOutcome outcomeFor({
    required CallProtocolType protocolType,
    required CallParticipantRole participantRole,
  }) {
    switch (protocolType) {
      case CallProtocolType.hangup:
        return CallMessageOutcome.answered;
      case CallProtocolType.reject:
        return CallMessageOutcome.rejected;
      case CallProtocolType.cancel:
        return CallMessageOutcome.cancelled;
      case CallProtocolType.timeout:
      case CallProtocolType.lineBusy:
        return participantRole == CallParticipantRole.caller
            ? CallMessageOutcome.noAnswer
            : CallMessageOutcome.missed;
      default:
        return CallMessageOutcome.answered;
    }
  }

  static bool isNegativeOutcome(CallMessageOutcome outcome) {
    switch (outcome) {
      case CallMessageOutcome.missed:
      case CallMessageOutcome.rejected:
      case CallMessageOutcome.cancelled:
        return true;
      case CallMessageOutcome.answered:
      case CallMessageOutcome.noAnswer:
        return false;
    }
  }

  static String iconAsset({
    required CallStreamMediaType mediaType,
    required bool isOutgoing,
  }) {
    if (mediaType == CallStreamMediaType.video) {
      return isOutgoing
          ? 'assets/calling_message/video_call_self.png'
          : 'assets/calling_message/video_call.png';
    }
    return 'assets/calling_message/voice_call.png';
  }

  static Color? accentColor(CallMessageOutcome outcome) {
    switch (outcome) {
      case CallMessageOutcome.missed:
      case CallMessageOutcome.rejected:
        return negativeAccentColor;
      case CallMessageOutcome.cancelled:
        return const Color(0xFF888888);
      case CallMessageOutcome.answered:
      case CallMessageOutcome.noAnswer:
        return null;
    }
  }

  static Color resolveTextColor({
    required Color baseTextColor,
    required CallMessageOutcome outcome,
  }) {
    if (isNegativeOutcome(outcome)) {
      return negativeAccentColor;
    }
    return baseTextColor;
  }
}

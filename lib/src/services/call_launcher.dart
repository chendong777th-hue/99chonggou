import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/api/livekit_call_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/platform/permission_guard.dart';
import 'package:tencent_cloud_chat_demo/src/services/desktop_call_float_service.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_demo/src/services/desktop_call_float_service_web.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_navigator.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_ringtone.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_session.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_types.dart';
import 'package:tencent_cloud_chat_demo/src/utils/call_user_id.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';

class CallLauncher {
  CallLauncher._();

  static String _unsupportedText(BuildContext context) {
    if (PlatformUtils().isWeb) {
      return AppI18n.of(context).t(
        zhHans: 'Web 端暂未接入音视频通话 SDK，请在移动端使用',
        zhHant: 'Web 端暫未接入音視訊通話 SDK，請在移動端使用',
        en: 'Web audio/video call SDK is not connected yet. Please use mobile.',
        ja: 'Web版の音声/ビデオ通話は対応中です。',
        ko: '웹 음성/영상 통화는 지원 준비 중입니다.',
      );
    }
    return AppI18n.of(context).t(
      zhHans: '当前设备暂不支持通话',
      zhHant: '目前裝置暫不支援通話',
      en: 'Calls are not supported on this device.',
      ja: 'この端末では通話を利用できません。',
      ko: '현재 기기에서는 통화를 지원하지 않습니다.',
    );
  }

  static String _emptyUserText(BuildContext context) {
    return AppI18n.of(context).t(
      zhHans: '无法识别通话对象',
      zhHant: '無法識別通話對象',
      en: 'Unable to identify the call recipient.',
      ja: '通話相手を識別できません。',
      ko: '통화 상대를 확인할 수 없습니다.',
    );
  }

  static String normalizeC2CUserId(String? value) {
    return CallUserId.normalizeCallUserId(value?.trim() ?? '');
  }

  static String normalizeGroupId(String? value) {
    final text = value?.trim() ?? '';
    if (text.startsWith('group_')) {
      return text.substring(6).trim();
    }
    return text;
  }

  static String c2cConversationId(String userId) {
    final target = normalizeC2CUserId(userId);
    return target.isEmpty ? '' : 'c2c_$target';
  }

  static String groupConversationId(String groupId) {
    final target = normalizeGroupId(groupId);
    return target.isEmpty ? '' : 'group_$target';
  }

  static bool _deviceReady(BuildContext context) {
    if (PlatformUtils().isWeb || PlatformUtils().isDesktop) {
      ToastUtils.toast(_unsupportedText(context));
      return false;
    }
    return true;
  }

  static Future<bool> _permissionReady(
    BuildContext context, {
    required bool video,
  }) {
    return PermissionGuard.call(context, video: video);
  }

  static bool _loginReady(BuildContext context) {
    try {
      final userId = TIMUIKitCore.getInstance().loginInfo.userID.trim();
      if (userId.isNotEmpty) return true;
    } catch (_) {}
    ToastUtils.toast(AppI18n.of(context).t(
      zhHans: '通话服务未登录',
      zhHant: '通話服務未登入',
      en: 'Call service is not signed in.',
      ja: '通話サービスにログインしていません。',
      ko: '통화 서비스에 로그인되어 있지 않습니다.',
    ));
    return false;
  }

  static Future<bool> startC2C(
    BuildContext context, {
    required String userId,
    required bool video,
    String? conversationId,
  }) {
    return startBridgeC2C(
      context,
      userId: userId,
      video: video,
      conversationId: conversationId,
    );
  }

  static Future<bool> startBridgeC2C(
    BuildContext context, {
    required String userId,
    required bool video,
    String? conversationId,
  }) async {
    final target = normalizeC2CUserId(userId);
    if (target.isEmpty) {
      ToastUtils.toast(_emptyUserText(context));
      return false;
    }
    if (!_deviceReady(context) || !_loginReady(context)) return false;
    final failFallback = AppI18n.of(context).t(
      zhHans: '发起通话失败',
      zhHant: '發起通話失敗',
      en: 'Failed to start the call.',
      ja: '通話を開始できませんでした。',
      ko: '통화를 시작하지 못했습니다.',
    );

    try {
      DesktopCallFloatService.instance.hide();
      // Show ringing UI immediately — do not await permissions / invite first.
      await LiveKitCallSession.instance.prepareOutgoingPending(
        calleeUserId: target,
        video: video,
      );
      final pageFuture = LiveKitCallNavigator.openCallPage(
        context: context.mounted ? context : null,
      );
      // Attach after push so AudioSession work does not block first frame.
      // ensureAttached() re-reads current phase and starts dial tone.
      unawaited(LiveKitCallRingtone.instance.ensureAttached());

      if (!context.mounted) {
        await _abortOutgoingBeforeInvite();
        return false;
      }
      if (!await _permissionReady(context, video: video)) {
        // PermissionGuard already toasted / prompted settings.
        await _abortOutgoingBeforeInvite();
        return false;
      }

      final creds = await LiveKitCallApi.instance.invite(
        calleeUserId: target,
        video: video,
      );
      final bound = LiveKitCallSession.instance.bindOutgoingCredentials(creds);
      if (!bound) {
        // User canceled while invite was in flight — tear down remote call.
        unawaited(
          LiveKitCallApi.instance.cancel(callId: creds.callId).catchError((_) {}),
        );
        await pageFuture;
        return false;
      }
      // Let the enter fade settle before Room.connect / camera / textures.
      await LiveKitCallNavigator.waitForEnterSettled();
      try {
        await LiveKitCallSession.instance.connectMedia();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('CallLauncher: connectMedia failed: $e');
        }
        final text = e.toString();
        ToastUtils.toast(
          text.trim().isNotEmpty && !text.contains('Instance of')
              ? text
              : failFallback,
        );
      }
      await pageFuture;
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CallLauncher: startBridgeC2C failed: $e');
      }
      // Invite / prepare failed after UI may already be open — close local session.
      if (LiveKitCallSession.instance.isBusy &&
          LiveKitCallSession.instance.role == AppCallRole.caller) {
        unawaited(LiveKitCallSession.instance.cancelOutgoing());
      }
      final text = e.toString();
      ToastUtils.toast(
        text.trim().isNotEmpty && !text.contains('Instance of')
            ? text
            : failFallback,
      );
      return false;
    }
  }

  /// Permission denied / context lost before invite — end local pending UI only.
  static Future<void> _abortOutgoingBeforeInvite() async {
    if (LiveKitCallSession.instance.isBusy &&
        LiveKitCallSession.instance.role == AppCallRole.caller) {
      await LiveKitCallSession.instance.cancelOutgoing();
    }
    await LiveKitCallNavigator.closeCallPage();
  }

  /// Group calls are not productized in the LiveKit cutover.
  static Future<bool> startGroup(
    BuildContext context, {
    required String groupId,
    required List<String?> userIds,
    required bool video,
  }) async {
    ToastUtils.toast(AppI18n.of(context).t(
      zhHans: '暂不支持群通话',
      zhHant: '暫不支援群通話',
      en: 'Group calls are not supported yet.',
      ja: 'グループ通話は未対応です。',
      ko: '그룹 통화는 아직 지원되지 않습니다.',
    ));
    return false;
  }

  static Future<bool> startCore(
    BuildContext context, {
    required List<String> userIds,
    required bool video,
    String? groupId,
  }) {
    if ((groupId ?? '').trim().isNotEmpty) {
      return startGroup(
        context,
        groupId: groupId!,
        userIds: userIds,
        video: video,
      );
    }
    if (userIds.isEmpty) {
      ToastUtils.toast(_emptyUserText(context));
      return Future.value(false);
    }
    return startBridgeC2C(
      context,
      userId: userIds.first,
      video: video,
    );
  }
}

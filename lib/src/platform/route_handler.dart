import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_chat_route.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/services/external_chat_entry_service.dart';
import 'package:tencent_cloud_chat_demo/src/all_group_application_list.dart';
import 'package:tencent_cloud_chat_demo/src/newContact.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/desktop_group_notice_host.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/wallet_screen.dart';
import 'package:tencent_cloud_chat_demo/src/services/device_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/ui/utils/desktop_modal_layout.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/message_notification_banner.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';

class RouteHandler {
  RouteHandler._();

  static final Set<String> _openingConversationIds = <String>{};
  static final Map<String, int> _lastOpenAtMs = <String, int>{};
  static bool _openingNewContact = false;
  static int _lastOpenNewContactAtMs = 0;

  static bool _tooSoon(String conversationID) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastOpenAtMs[conversationID];
    if (last != null && now - last < 700) {
      return true;
    }
    _lastOpenAtMs[conversationID] = now;
    return false;
  }

  static Future<void> openConversation(
    String conversationID, {
    String source = 'route_handler_open_conversation',
  }) async {
    final id = conversationID.trim();
    if (id.isEmpty) return;
    if (_tooSoon(id)) {
      ExternalChatEntryService.instance.logFlow(
        'skip_duplicate_open',
        source: source,
        conversationID: id,
      );
      return;
    }
    if (ExternalChatEntryService.instance.isVisibleChat(id)) {
      final context = AppNavigator.context;
      if (context != null && context.mounted) {
        _popToChatPreservingWalletOverlays(context);
      }
      ExternalChatEntryService.instance.logFlow(
        'reuse_visible_chat',
        source: source,
        conversationID: id,
        extras: <String, Object?>{
          'ready': ExternalChatEntryService.instance.isVisibleChatReady(id),
        },
      );
      ExternalChatEntryService.instance.requestActivation(
        conversationID: id,
        source: source,
        reason: ExternalChatEntryService.instance.isVisibleChatReady(id)
            ? 'visible_chat_ready'
            : 'visible_chat_needs_activation',
        delay: const Duration(milliseconds: 120),
      );
      return;
    }

    try {
      final res = await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .getConversation(conversationID: id)
          .timeout(const Duration(seconds: 3));
      final conversation = res.data;
      if (conversation == null) {
        ExternalChatEntryService.instance.logFlow(
          'conversation_not_found',
          source: source,
          conversationID: id,
        );
        return;
      }

      openChat(conversationID: id, conversation: conversation, source: source);
    } catch (e) {
      ExternalChatEntryService.instance.logFlow(
        'open_conversation_failed',
        source: source,
        conversationID: id,
        extras: <String, Object?>{'error': e.toString()},
      );
    }
  }

  static void openHome({String source = 'route_handler_open_home'}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = AppNavigator.context;
      if (context == null || !context.mounted) {
        return;
      }
      try {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ExternalChatEntryService.instance.logFlow('open_home', source: source);
      } catch (_) {}
    });
  }

  static void openWallet({String source = 'route_handler_open_wallet'}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = AppNavigator.context;
      if (context == null || !context.mounted) {
        return;
      }
      try {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } catch (_) {}

      scheduleMicrotask(() async {
        final ctx = AppNavigator.context;
        if (ctx == null || !ctx.mounted) {
          return;
        }
        try {
          await Navigator.of(ctx).push(
            AppMaterialPageRoute(
              settings: const RouteSettings(name: AppRoutes.walletOverlay),
              builder: (_) => const WalletScreen(),
            ),
          );
          ExternalChatEntryService.instance.logFlow(
            'open_wallet',
            source: source,
          );
        } catch (e) {
          ExternalChatEntryService.instance.logFlow(
            'open_wallet_failed',
            source: source,
            extras: <String, Object?>{'error': e.toString()},
          );
        }
      });
    });
  }

  static bool _openingGroupNotices = false;
  static int _lastOpenGroupNoticesAtMs = 0;

  static Future<void> openGroupNotices() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_openingGroupNotices || now - _lastOpenGroupNoticesAtMs < 700) {
      return;
    }
    _openingGroupNotices = true;
    _lastOpenGroupNoticesAtMs = now;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = AppNavigator.context;
      if (context == null || !context.mounted) {
        _openingGroupNotices = false;
        return;
      }
      try {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } catch (_) {}

      scheduleMicrotask(() async {
        try {
          final ctx = AppNavigator.context;
          if (ctx == null || !ctx.mounted) {
            return;
          }
          if (TUIKitScreenUtils.getFormFactor(ctx) == DeviceType.Desktop ||
              DesktopModalLayout.isDesktop(ctx)) {
            DesktopGroupNoticeHost.open();
            return;
          }
          await Navigator.of(ctx).push(
            AppMaterialPageRoute(
              builder: (_) => const AllGroupApplicationListPage(),
            ),
          );
        } catch (_) {
        } finally {
          _openingGroupNotices = false;
        }
      });
    });
  }

  static Future<void> openNewContact() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_openingNewContact || now - _lastOpenNewContactAtMs < 700) {
      return;
    }
    _openingNewContact = true;
    _lastOpenNewContactAtMs = now;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = AppNavigator.context;
      if (context == null || !context.mounted) {
        _openingNewContact = false;
        return;
      }
      try {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } catch (_) {}

      scheduleMicrotask(() async {
        try {
          final ctx = AppNavigator.context;
          if (ctx == null || !ctx.mounted) {
            return;
          }
          await Navigator.of(
            ctx,
          ).push(AppMaterialPageRoute(builder: (_) => const NewContact()));
        } catch (_) {
        } finally {
          _openingNewContact = false;
        }
      });
    });
  }

  static Future<bool> openChat({
    required String conversationID,
    required dynamic conversation,
    String source = 'route_handler_open_chat',
    int navigationAttempt = 0,
  }) async {
    if (!_openingConversationIds.add(conversationID)) {
      ExternalChatEntryService.instance.logFlow(
        'skip_parallel_navigation',
        source: source,
        conversationID: conversationID,
      );
      return ExternalChatEntryService.instance.isVisibleChat(conversationID);
    }
    DeviceSyncService.instance.prepareForChatNavigation();

    try {
      BuildContext? context;
      var attempt = navigationAttempt;
      while (attempt <= 20) {
        WidgetsBinding.instance.scheduleFrame();
        await WidgetsBinding.instance.endOfFrame;
        context = AppNavigator.context;
        if (context != null && context.mounted) {
          break;
        }
        if (attempt >= 20) {
          ExternalChatEntryService.instance.logFlow(
            'chat_route_navigator_unavailable',
            source: source,
            conversationID: conversationID,
          );
          return false;
        }
        final delayMs = 120 + attempt * 80;
        await Future<void>.delayed(Duration(milliseconds: delayMs));
        attempt += 1;
      }

      if (context == null || !context.mounted) {
        return false;
      }

      if (ExternalChatEntryService.instance.isVisibleChat(conversationID)) {
        _popToChatPreservingWalletOverlays(context);
        ExternalChatEntryService.instance.logFlow(
          'reuse_visible_chat',
          source: source,
          conversationID: conversationID,
          extras: <String, Object?>{
            'ready': ExternalChatEntryService.instance.isVisibleChatReady(
              conversationID,
            ),
          },
        );
        ExternalChatEntryService.instance.requestActivation(
          conversationID: conversationID,
          source: source,
          reason: ExternalChatEntryService.instance.isVisibleChatReady(
            conversationID,
          )
              ? 'visible_chat_ready'
              : 'visible_chat_needs_activation',
          delay: const Duration(milliseconds: 120),
        );
        return true;
      }

      try {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } catch (_) {}
      await Future<void>.delayed(Duration.zero);

      final ctx = AppNavigator.context;
      if (ctx == null || !ctx.mounted) {
        return false;
      }
      if (ExternalChatEntryService.instance.isVisibleChat(conversationID)) {
        ExternalChatEntryService.instance.logFlow(
          'skip_push_visible_chat',
          source: source,
          conversationID: conversationID,
        );
        ExternalChatEntryService.instance.requestActivation(
          conversationID: conversationID,
          source: source,
          reason: 'visible_chat_after_pop',
          delay: const Duration(milliseconds: 120),
        );
        return true;
      }

      try {
        final pushCtx = AppNavigator.context;
        if (pushCtx == null || !pushCtx.mounted) {
          return false;
        }
        unawaited(
          openOrReuseAppChat(
            pushCtx,
            conversation,
            entryUnreadCount: conversation.unreadCount ?? 0,
          ),
        );
        ExternalChatEntryService.instance.logFlow(
          'chat_route_pushed',
          source: source,
          conversationID: conversationID,
        );
        ExternalChatEntryService.instance.requestActivation(
          conversationID: conversationID,
          source: source,
          reason: 'post_navigation',
          delay: const Duration(milliseconds: 900),
        );
        return true;
      } catch (e) {
        ExternalChatEntryService.instance.logFlow(
          'chat_route_push_failed',
          source: source,
          conversationID: conversationID,
          extras: <String, Object?>{'error': e.toString()},
        );
        return false;
      }
    } finally {
      _openingConversationIds.remove(conversationID);
    }
  }

  static bool _isWalletOverlayRoute(Route<dynamic> route) {
    return route.settings.name == AppRoutes.walletOverlay;
  }

  static bool _isChatRoute(Route<dynamic> route) {
    return route.settings.name == AppRoutes.chat;
  }

  static void _popToChatPreservingWalletOverlays(BuildContext context) {
    try {
      Navigator.of(context).popUntil((route) {
        if (route.isFirst) return true;
        if (_isChatRoute(route) || _isWalletOverlayRoute(route)) {
          return true;
        }
        return false;
      });
    } catch (_) {}
  }
}

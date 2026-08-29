import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/api/auth_api.dart';
import 'package:tencent_cloud_chat_demo/src/platform/listener_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/archived_conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/auth_bootstrap_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_folder_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/native_bootstrap_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_notify_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_pin_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/device_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/session_identity.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_local/friend_contact_incremental_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_local/friend_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_entity_incremental_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_member_incremental_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_membership_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_live/group_live_index_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_bootstrap.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_incremental_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_snapshot_bootstrap_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_settings_service.dart';
import 'package:tencent_cloud_chat_demo/src/utils/push_identity_cache.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/init_step.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';
import 'package:tencent_cloud_chat_demo/src/provider/user_sticker_provider.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/message_notification_banner.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

/// 原生登录：IM 就绪进首页后，串行限流补会话/好友/群/副作用，避免并行读写风暴。
class NativePostHomeBootstrapQueue {
  NativePostHomeBootstrapQueue._();

  static final NativePostHomeBootstrapQueue instance =
      NativePostHomeBootstrapQueue._();

  int _generation = 0;
  bool _inFlight = false;
  String? _pendingReason;
  final Map<int, SessionIdentity> _identityByGeneration =
      <int, SessionIdentity>{};

  void schedule({required String reason}) {
    if (kIsWeb) {
      return;
    }
    if (_inFlight) {
      _pendingReason = reason;
      _log('schedule ignored inFlight pending=$reason');
      return;
    }
    final identity = SessionIdentityService.instance.capture();
    if (identity.ownerUserId.isEmpty) return;
    _inFlight = true;
    final gen = _generation;
    _identityByGeneration[gen] = identity;
    _log('schedule start reason=$reason gen=$gen');
    unawaited(_run(generation: gen, reason: reason));
  }

  void reset({String reason = 'reset'}) {
    _generation++;
    _identityByGeneration.removeWhere(
      (generation, _) => generation < _generation,
    );
    _pendingReason = null;
    _inFlight = false;
    AuthBootstrapService.instance.bumpBootstrapGeneration(
      reason: 'native_post_home_reset:$reason',
    );
    _log('reset reason=$reason gen=$_generation');
  }

  Future<void> _run({
    required int generation,
    required String reason,
  }) async {
    try {
      DeviceSyncService.instance.suspendPhotoSync(
        reason: 'native_post_home',
        duration: const Duration(seconds: 25),
      );
      await Future<void>.delayed(NativeBootstrapPerfFlags.postHomeStartDelay);
      if (!_stillCurrent(generation)) {
        return;
      }
      await _waitWhileFeedScrollingIfNeeded();
      if (!_stillCurrent(generation)) {
        return;
      }
      await _stage1ConversationFirstPage();
      if (!_stillCurrent(generation)) {
        return;
      }
      // paced sync 页内只 patch：收尾再灌一次热窗，避免「库已更新 UI 仍缺条」。
      await _waitWhileFeedScrollingIfNeeded();
      if (!_stillCurrent(generation)) {
        return;
      }
      await _runCatching('conversation_hot_window_reload', () async {
        await ConversationListNotifier.instance.restoreStoreProjection(
          reason: ConversationStoreProjectionReason.authBootstrap,
        );
      });
      if (!_stillCurrent(generation)) {
        return;
      }
      AuthBootstrapService.instance.applyNativePostHomeStage1Finished();

      await _yieldIfCurrent(generation);
      if (!_stillCurrent(generation)) {
        return;
      }
      await _waitWhileFeedScrollingIfNeeded();
      if (!_stillCurrent(generation)) {
        return;
      }
      await _waitWhileChatOpenIfNeeded();
      if (!_stillCurrent(generation)) {
        return;
      }

      final auth = AuthBootstrapService.instance;
      if (!auth.friendSyncBootstrapDone) {
        await _runCatching('friend_sync', () async {
          await FriendSyncService.instance.syncFull(reason: 'native_post_home');
          auth.friendSyncBootstrapDone = true;
        });
      } else {
        _log('friend_sync skipped bootstrapDone=true');
      }
      await _runCatching('friend_contact_incremental', () async {
        await FriendContactIncrementalSyncService.instance.sync(
          reason: 'native_post_home',
        );
      });
      await _yieldIfCurrent(generation);
      if (!_stillCurrent(generation)) {
        return;
      }
      await _waitWhileFeedScrollingIfNeeded();
      if (!_stillCurrent(generation)) {
        return;
      }
      await _waitWhileResumeQuietIfNeeded();
      if (!_stillCurrent(generation)) {
        return;
      }
      await _waitWhileChatOpenIfNeeded();
      if (!_stillCurrent(generation)) {
        return;
      }

      if (!auth.groupSyncBootstrapDone) {
        await _runCatching('group_sync', () async {
          await GroupMembershipSyncService.instance
              .syncFull(reason: 'native_post_home');
          auth.groupSyncBootstrapDone = true;
        });
      } else {
        _log('group_sync skipped bootstrapDone=true');
      }
      await _runCatching('group_entity_incremental', () async {
        await GroupEntityIncrementalSyncService.instance.sync(
          reason: 'native_post_home',
        );
      });
      await _runCatching('group_notice_incremental', () async {
        await GroupNoticeIncrementalSyncService.instance.sync(
          reason: 'native_post_home',
        );
      });
      await _runCatching('group_member_incremental', () async {
        await GroupMemberIncrementalSyncService.instance.syncAllJoined(
          reason: 'native_post_home',
        );
      });
      await _runCatching('group_live_index', () async {
        await GroupLiveIndexSyncService.instance.fetchIndex(
          reason: 'native_post_home',
        );
      });
      await _yieldIfCurrent(generation);
      if (!_stillCurrent(generation)) {
        return;
      }
      await _waitWhileFeedScrollingIfNeeded();
      if (!_stillCurrent(generation)) {
        return;
      }
      await _waitWhileChatOpenIfNeeded();
      if (!_stillCurrent(generation)) {
        return;
      }

      await _runCatching('friendship_uikit', () async {
        final friendship = serviceLocator<TUIFriendShipViewModel>();
        await friendship.loadContactListData();
        await FriendSyncService.instance
            .reseedC2cDisplayNamesFromLocalFriends();
        await friendship.loadContactApplicationData();
        if ((friendship.friendList?.isNotEmpty ?? false)) {
          await friendship.loadUserStatus();
        }
      });
      await _yieldIfCurrent(generation);
      if (!_stillCurrent(generation)) {
        return;
      }
      await _waitWhileFeedScrollingIfNeeded();
      if (!_stillCurrent(generation)) {
        return;
      }
      await _waitWhileChatOpenIfNeeded();
      if (!_stillCurrent(generation)) {
        return;
      }

      await _runSideEffects(generation);
      if (!_stillCurrent(generation)) {
        return;
      }
      _log('done reason=$reason');
    } catch (e, st) {
      _log('failed reason=$reason error=$e\n$st');
      if (_stillCurrent(generation)) {
        AuthBootstrapService.instance.applyNativePostHomeStage1Finished();
      }
    } finally {
      if (_generation == generation) {
        _inFlight = false;
        final pending = _pendingReason;
        _pendingReason = null;
        if (pending != null) {
          schedule(reason: pending);
        }
      }
    }
  }

  Future<void> _waitWhileFeedScrollingIfNeeded() async {
    if (!ConversationPerfFlags.postHomePauseWhileFeedScrolling) {
      return;
    }
    final scrolling = ConversationListNotifier.instance.isFeedScrolling;
    if (scrolling == null) {
      return;
    }
    if (!scrolling()) {
      return;
    }
    final deadline = DateTime.now().add(
      ConversationPerfFlags.postHomeScrollPauseMaxWait,
    );
    while (DateTime.now().isBefore(deadline)) {
      final fn = ConversationListNotifier.instance.isFeedScrolling;
      if (fn == null || !fn()) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> _waitWhileChatOpenIfNeeded() async {
    if (!ConversationPerfFlags.postHomePauseWhileChatOpen) {
      return;
    }
    if (!DeviceSyncService.instance.isChatRouteOpen) {
      return;
    }
    _log('wait chat_open before heavy stage');
    final deadline = DateTime.now().add(
      ConversationPerfFlags.postHomeChatPauseMaxWait,
    );
    while (DateTime.now().isBefore(deadline)) {
      if (!DeviceSyncService.instance.isChatRouteOpen) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
  }

  Future<void> _waitWhileResumeQuietIfNeeded() async {
    if (!ConversationPerfFlags.postHomeWaitResumeQuiet) {
      return;
    }
    if (!ConversationSyncService.instance.isInResumeQuietWindow) {
      return;
    }
    _log('wait resume_quiet before group_sync');
    await ConversationSyncService.instance.waitUntilResumeQuietEnds();
  }

  Future<void> _stage1ConversationFirstPage() async {
    await _runCatching('conversation_s1', () async {
      final auth = AuthBootstrapService.instance;
      if (ConversationSyncService.shouldSkipPostHomeConversationReset(
        conversationListBootstrapDone: auth.conversationListBootstrapDone,
      )) {
        _log(
          'native_post_home_s1 skipped reset bootstrapDone=true',
        );
        // 热窗优先：不再因 haveMore 自动 idle drain。
        if (ConversationPerfFlags.idleBackgroundDrainEnabled) {
          final meta = await ConversationLocalStore.instance.readSyncMeta();
          if (meta.haveMore) {
            ConversationSyncService.instance.scheduleIdleBackgroundDrain(
              reason: 'native_post_home',
            );
          }
        }
        return;
      }

      ImSnapshotBootstrapService.instance.beginLoginBootstrapGate();
      try {
        await ConversationSyncService.instance.healC2cCursorIfNeeded(
          reason: 'native_post_home_heal',
        );
        final meta = await ConversationLocalStore.instance.readSyncMeta();
        final rowCount = await ConversationLocalStore.instance.countRows();
        final owner = ChatIdFormat.rawUserUid(
          ContactSocialCacheStore.safeLoginUserId(),
        );
        if (ConversationSyncService.shouldAttemptImSnapshotOnLoginBootstrap() &&
            owner.isNotEmpty) {
          _log(
            'native_post_home_s1 Snapshot try owner=$owner rows=$rowCount',
          );
          final snapOk = await ImSnapshotBootstrapService.instance
              .tryBootstrapOnLogin(ownerUserId: owner);
          if (snapOk) {
            auth.conversationListBootstrapDone = true;
            _log(
              'native_post_home_s1 Snapshot C2C priority ready; '
              'SDK follow-up scheduled',
            );
            return;
          }
          _log('native_post_home_s1 Snapshot miss → SDK fallback');
          await ConversationSyncService.instance.syncFromSdk(
            reason: 'bootstrap_snapshot_fallback',
            reset: !(meta.hasSyncedOnce && rowCount > 0),
            drainMode: ConversationSdkDrainMode.foregroundLimited,
            reloadUiEachPage: false,
          );
          auth.conversationListBootstrapDone = true;
          if (ConversationPerfFlags.idleBackgroundDrainEnabled &&
              await ConversationSyncService.instance.haveMoreData) {
            ConversationSyncService.instance.scheduleIdleBackgroundDrain(
              reason: 'native_post_home',
            );
          }
          return;
        }

        final shouldReset = !(meta.hasSyncedOnce && rowCount > 0);
        await ConversationSyncService.instance.syncFromSdk(
          reason: 'native_post_home_s1',
          reset: shouldReset,
          drainMode: ConversationSdkDrainMode.foregroundLimited,
          reloadUiEachPage: false,
        );
        auth.conversationListBootstrapDone = true;
        if (ConversationPerfFlags.idleBackgroundDrainEnabled &&
            await ConversationSyncService.instance.haveMoreData) {
          ConversationSyncService.instance.scheduleIdleBackgroundDrain(
            reason: 'native_post_home',
          );
        }
      } finally {
        ImSnapshotBootstrapService.instance.endLoginBootstrapGate();
      }
    });
  }

  Future<void> _runSideEffects(int generation) async {
    final identity = _identityByGeneration[generation];
    if (identity == null || !_stillCurrent(generation)) return;
    await _runCatching('listener_after_login', () async {
      await ListenerStore.afterLogin(expectedIdentity: identity)
          .timeout(const Duration(seconds: 8));
    });
    await _yieldIfCurrent(generation);
    if (!_stillCurrent(generation)) {
      return;
    }

    await _runCatching('notify_sync', () async {
      await ConversationNotifySyncService.instance.syncAllOnLogin();
    });
    await _yieldIfCurrent(generation);
    if (!_stillCurrent(generation)) {
      return;
    }

    await _runCatching('archived_sync', () async {
      await ArchivedConversationSyncService.instance.syncOnLogin();
    });
    await _yieldIfCurrent(generation);
    if (!_stillCurrent(generation)) {
      return;
    }

    await _runCatching('folder_sync', () async {
      await ConversationFolderSyncService.instance.syncOnLogin();
    });
    await _yieldIfCurrent(generation);
    if (!_stillCurrent(generation)) {
      return;
    }

    await _runCatching('pin_sync', () async {
      await ConversationPinSyncService.instance.syncOnLogin();
    });
    await _yieldIfCurrent(generation);
    if (!_stillCurrent(generation)) {
      return;
    }

    await _runCatching('avatar_push', () async {
      final me = await AuthApi.instance.fetchMe();
      await UserAvatarHelper.syncSelfAvatarFromBackend(me.avatarUrl);
      await PushIdentityCache.instance.refreshSelf();
    });
    await _yieldIfCurrent(generation);
    if (!_stillCurrent(generation)) {
      return;
    }

    await _runCatching('stickers', () async {
      await UserStickerProvider.shared.refresh(force: true);
      final navContext = AppNavigator.context;
      if (navContext != null && navContext.mounted) {
        await InitStep.publishStickerPackages(navContext);
      }
    });
    await _yieldIfCurrent(generation);
    if (!_stillCurrent(generation)) {
      return;
    }

    await _runCatching('group_notice', () async {
      await GroupNoticeBootstrap.install();
    });
    await _yieldIfCurrent(generation);
    if (!_stillCurrent(generation)) {
      return;
    }

    await _runCatching('moments_cover_cache', () async {
      await MomentsSettingsService.instance.hydrateFromLocal();
    });
  }

  Future<void> _yieldIfCurrent(int generation) async {
    if (!_stillCurrent(generation)) {
      return;
    }
    await Future<void>.delayed(NativeBootstrapPerfFlags.stageYield);
  }

  bool _stillCurrent(int generation) {
    if (_generation != generation) return false;
    final identity = _identityByGeneration[generation];
    return identity == null ||
        SessionIdentityService.instance.isCurrent(identity);
  }

  Future<void> _runCatching(
    String label,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      _log('stage $label failed: $e');
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('NativePostHomeBootstrap: $message');
    }
  }
}

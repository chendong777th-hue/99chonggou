import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:tencent_cloud_chat_demo/src/pages/livekit_call_page.dart';
import 'package:tencent_cloud_chat_demo/src/services/desktop_call_float_service.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_demo/src/services/desktop_call_float_service_web.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_session.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_ui_log.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/message_notification_banner.dart';

class LiveKitCallNavigator {
  LiveKitCallNavigator._();

  static const String routeName = 'livekit_call_page';

  /// Fade-in only — avoid sliding a full-screen video/avatar layer.
  static const Duration enterTransitionDuration = Duration(milliseconds: 180);

  /// Instant pop — never drag LiveKit textures / network bg through reverse.
  static const Duration exitTransitionDuration = Duration.zero;

  static bool _open = false;
  static bool _routeInStack = false;
  static bool _routeIsCurrent = false;
  static int _mountedPages = 0;

  static bool get isCallPageOpen => _open;

  /// True while at least one [LiveKitCallPage] State is mounted.
  static bool get isCallPageMounted => _mountedPages > 0;

  /// Whether the call route is the topmost route (not minimized / covered).
  @visibleForTesting
  static bool get isCallPageCurrent => _routeIsCurrent;

  static String get _diag =>
      'open=$_open mounted=$_mountedPages inStack=$_routeInStack '
      'current=$_routeIsCurrent phase=${LiveKitCallSession.instance.phase} '
      'inCall=${LiveKitCallSession.instance.isInCall} '
      'float=${DesktopCallFloatService.instance.visible}';

  @visibleForTesting
  static void notifyCallRoutePushed() {
    _routeInStack = true;
    _routeIsCurrent = true;
    liveKitCallUiLog('routePushed $_diag');
  }

  @visibleForTesting
  static void notifyCallRoutePopped() {
    _routeInStack = false;
    _routeIsCurrent = false;
    liveKitCallUiLog('routePopped $_diag');
  }

  @visibleForTesting
  static void notifyCallRouteCovered() {
    _routeIsCurrent = false;
    liveKitCallUiLog('routeCovered $_diag');
  }

  @visibleForTesting
  static void notifyCallRouteUncovered() {
    if (_routeInStack) {
      _routeIsCurrent = true;
    }
    liveKitCallUiLog('routeUncovered $_diag');
  }

  /// Called from [LiveKitCallPage] init/dispose — heals RouteAware missed didPush.
  static void notifyCallPageMounted() {
    _mountedPages++;
    _routeInStack = true;
    _routeIsCurrent = true;
    liveKitCallUiLog('pageMounted $_diag');
  }

  static void notifyCallPageDisposed() {
    if (_mountedPages > 0) {
      _mountedPages--;
    }
    if (_mountedPages == 0) {
      _routeInStack = false;
      _routeIsCurrent = false;
    }
    liveKitCallUiLog('pageDisposed $_diag');
  }

  @visibleForTesting
  static void resetRouteTrackingForTest() {
    _routeInStack = false;
    _routeIsCurrent = false;
    _open = false;
    _mountedPages = 0;
  }

  /// Push the fullscreen call page.
  ///
  /// The returned future completes when the page is **popped**. The route is
  /// inserted synchronously before the first await, so callers can start media
  /// connect after [waitForEnterSettled] (without waiting for the future).
  static Future<void> openCallPage({
    String? peerDisplayName,
    String? peerFaceUrl,
    BuildContext? context,
  }) async {
    final nav = AppNavigator.key.currentState ??
        (context != null
            ? Navigator.of(context, rootNavigator: true)
            : null);
    if (nav == null) {
      liveKitCallUiLog('openCallPage aborted — no Navigator ($_diag)');
      return;
    }

    // Heal desync: flag says open but no widget is mounted → allow re-push.
    if (_open && !isCallPageMounted) {
      liveKitCallUiLog(
        'openCallPage heal desync — _open without mounted page ($_diag)',
      );
      _open = false;
      _routeInStack = false;
      _routeIsCurrent = false;
    }

    if (_open || isCallPageMounted) {
      if (_routeIsCurrent && isCallPageMounted) {
        liveKitCallUiLog('openCallPage skipped — already on top ($_diag)');
        return;
      }
      if (_routeInStack || isCallPageMounted) {
        liveKitCallUiLog(
          'openCallPage — call page exists but not current, bring front ($_diag)',
        );
        await bringCallPageToFront();
        if (_routeIsCurrent && isCallPageMounted) {
          return;
        }
      }
      // Still blocked by _open latch with no recoverable page — reset & push.
      if (_open && !isCallPageMounted) {
        _open = false;
      } else if (_open && isCallPageMounted) {
        liveKitCallUiLog(
          'openCallPage — mounted but still not current after bringFront ($_diag)',
        );
        return;
      }
    }

    _open = true;
    liveKitCallUiLog('openCallPage pushing ($_diag)');
    try {
      await nav.push(
        _LiveKitCallPageRoute(
          peerDisplayName: peerDisplayName,
          peerFaceUrl: peerFaceUrl,
        ),
      );
    } catch (e, st) {
      liveKitCallUiLog('openCallPage push error: $e\n$st');
      rethrow;
    } finally {
      _open = false;
      liveKitCallUiLog('openCallPage route future completed ($_diag)');
    }
  }

  /// Pop routes above the call page until it is current again.
  static Future<void> bringCallPageToFront() async {
    final nav = AppNavigator.key.currentState;
    if (nav == null) {
      liveKitCallUiLog('bringCallPageToFront aborted — no Navigator');
      return;
    }
    if (!isCallPageMounted && !_routeInStack) {
      liveKitCallUiLog('bringCallPageToFront aborted — no call page ($_diag)');
      return;
    }
    if (_routeIsCurrent && isCallPageMounted) {
      liveKitCallUiLog('bringCallPageToFront noop — already current');
      return;
    }
    liveKitCallUiLog('bringCallPageToFront start ($_diag)');
    for (var safety = 0;
        safety < 25 &&
            isCallPageMounted &&
            !_routeIsCurrent &&
            nav.canPop();
        safety++) {
      liveKitCallUiLog('bringCallPageToFront pop#$safety');
      nav.pop();
      await WidgetsBinding.instance.endOfFrame;
    }
    liveKitCallUiLog('bringCallPageToFront done ($_diag)');
  }

  /// Retry pushing the call page while a session is active (CallKit wake may
  /// beat Navigator readiness; voipAlreadyPresent skips invite-time push).
  static Future<void> ensureCallPageVisible({
    String? peerDisplayName,
    String? peerFaceUrl,
    BuildContext? context,
    int maxAttempts = 20,
    String reason = 'unspecified',
  }) async {
    liveKitCallUiLog('ensureCallPageVisible begin reason=$reason ($_diag)');
    if (!LiveKitCallSession.instance.isInCall) {
      liveKitCallUiLog('ensureCallPageVisible skip — not in call');
      return;
    }

    if (DesktopCallFloatService.instance.visible) {
      liveKitCallUiLog('ensureCallPageVisible restore float');
      await DesktopCallFloatService.instance.restoreCallPage();
      await _waitForCallPageCurrent(maxFrames: 30);
      liveKitCallUiLog('ensureCallPageVisible after float ($_diag)');
      return;
    }

    if (_routeIsCurrent && isCallPageMounted) {
      liveKitCallUiLog('ensureCallPageVisible already current');
      return;
    }

    if (isCallPageMounted || _routeInStack) {
      await bringCallPageToFront();
      if (_routeIsCurrent && isCallPageMounted) {
        liveKitCallUiLog('ensureCallPageVisible recovered via bringFront');
        return;
      }
    }

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (!LiveKitCallSession.instance.isInCall) {
        liveKitCallUiLog('ensureCallPageVisible stop — left call');
        return;
      }
      if (_routeIsCurrent && isCallPageMounted) {
        liveKitCallUiLog('ensureCallPageVisible ok attempt=$attempt');
        return;
      }
      liveKitCallUiLog('ensureCallPageVisible attempt=$attempt ($_diag)');
      // Fire-and-forget push: awaiting openCallPage blocks until page pops.
      unawaited(
        openCallPage(
          peerDisplayName: peerDisplayName,
          peerFaceUrl: peerFaceUrl,
          context: context,
        ),
      );
      await _waitForCallPageCurrent(maxFrames: 20);
      if (_routeIsCurrent && isCallPageMounted) {
        liveKitCallUiLog('ensureCallPageVisible pushed ok attempt=$attempt');
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    liveKitCallUiLog(
      'ensureCallPageVisible GAVE UP reason=$reason ($_diag)',
    );
  }

  static Future<void> _waitForCallPageCurrent({required int maxFrames}) async {
    for (var i = 0;
        i < maxFrames && !(_routeIsCurrent && isCallPageMounted);
        i++) {
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  /// Yields until the enter fade has finished + one frame painted.
  ///
  /// Call after [openCallPage] (fire-and-forget) and **before**
  /// `connectMedia` / heavy WebRTC work so camera + textures do not compete
  /// with the route transition.
  static Future<void> waitForEnterSettled() async {
    final ms = enterTransitionDuration.inMilliseconds;
    if (ms > 0) {
      await Future<void>.delayed(enterTransitionDuration);
    }
    final binding = SchedulerBinding.instance;
    await binding.endOfFrame;
    await binding.endOfFrame;
  }

  /// Pop the fullscreen call route without ending the LiveKit session.
  static Future<void> closeCallPage() async {
    final nav = AppNavigator.key.currentState;
    if (nav == null) return;
    // Only pop when we actually own the call route. Never pop chat/profile.
    if (!_open && !isCallPageMounted) {
      liveKitCallUiLog('closeCallPage ignored — not open ($_diag)');
      return;
    }
    liveKitCallUiLog('closeCallPage popping ($_diag)');
    if (nav.canPop()) {
      nav.pop();
    }
  }
}

/// Fullscreen call route: fade enter, instant exit.
class _LiveKitCallPageRoute extends PageRouteBuilder<void> {
  _LiveKitCallPageRoute({
    String? peerDisplayName,
    String? peerFaceUrl,
  }) : super(
          fullscreenDialog: true,
          opaque: true,
          barrierDismissible: false,
          settings: const RouteSettings(name: LiveKitCallNavigator.routeName),
          transitionDuration: LiveKitCallNavigator.enterTransitionDuration,
          reverseTransitionDuration: LiveKitCallNavigator.exitTransitionDuration,
          pageBuilder: (context, animation, secondaryAnimation) {
            return LiveKitCallPage(
              peerDisplayName: peerDisplayName,
              peerFaceUrl: peerFaceUrl,
            );
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: child,
            );
          },
        );

  @override
  TickerFuture didPush() {
    LiveKitCallNavigator.notifyCallRoutePushed();
    return super.didPush();
  }

  @override
  bool didPop(dynamic result) {
    LiveKitCallNavigator.notifyCallRoutePopped();
    return super.didPop(result);
  }
}

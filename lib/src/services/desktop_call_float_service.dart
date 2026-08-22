import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_navigator.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_session.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_types.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';

/// In-app minimize float for LiveKit calls (mobile + desktop).
///
/// Placement/sizes match TUICallKit float window (top-right, edge snap).
class DesktopCallFloatService extends ChangeNotifier {
  DesktopCallFloatService._();

  static final DesktopCallFloatService instance = DesktopCallFloatService._();

  bool visible = false;
  /// TUICallKit default: top-right (applied on first minimize via [ensureDefaultPosition]).
  Offset position = const Offset(-1, -1);
  String peerDisplayName = '';
  String peerFaceUrl = '';
  bool _attached = false;
  bool _hasUserMoved = false;

  bool get isVisible => visible;

  bool get isVideoCall => LiveKitCallSession.instance.isVideo;

  Future<void> ensureAttached() async {
    if (_attached) return;
    LiveKitCallSession.instance.addListener(_onSessionChanged);
    _attached = true;
  }

  Future<void> ensureInstalled() => ensureAttached();

  void _onSessionChanged() {
    final session = LiveKitCallSession.instance;
    if (!session.isInCall && visible) {
      hide();
      return;
    }
    if (visible) {
      notifyListeners();
    }
  }

  void ensureDefaultPosition(Size screen, Size panelSize) {
    if (_hasUserMoved && position.dx >= 0 && position.dy >= 0) return;
    // TUICallKit: right edge, top ≈ 75.
    position = Offset(
      (screen.width - panelSize.width - 10).clamp(0.0, screen.width),
      75,
    );
  }

  /// Minimize fullscreen call page into a floating pill / video window.
  Future<void> minimize({
    String? peerDisplayName,
    String? peerFaceUrl,
  }) async {
    await ensureAttached();
    final session = LiveKitCallSession.instance;
    if (!session.isInCall) return;

    final peerId = session.peerUserId;
    final name = (peerDisplayName ?? '').trim().isNotEmpty
        ? peerDisplayName!.trim()
        : (DisplayNameStore.instance.c2c(peerId)?.trim().isNotEmpty == true
            ? DisplayNameStore.instance.c2c(peerId)!.trim()
            : peerId);
    this.peerDisplayName = name;
    this.peerFaceUrl = peerFaceUrl?.trim() ?? this.peerFaceUrl;
    if (name.isNotEmpty && peerId.isNotEmpty) {
      DisplayNameStore.instance.setC2C(peerId, name);
    }

    visible = true;
    notifyListeners();
    await LiveKitCallNavigator.closeCallPage();
  }

  void hide() {
    if (!visible && peerDisplayName.isEmpty) return;
    visible = false;
    peerDisplayName = '';
    peerFaceUrl = '';
    _hasUserMoved = false;
    position = const Offset(-1, -1);
    notifyListeners();
  }

  void updatePosition(Offset delta, Size screen, Size panelSize) {
    ensureDefaultPosition(screen, panelSize);
    _hasUserMoved = true;
    final next = Offset(
      (position.dx + delta.dx).clamp(0.0, screen.width - panelSize.width),
      (position.dy + delta.dy).clamp(0.0, screen.height - panelSize.height),
    );
    if (next == position) return;
    position = next;
    notifyListeners();
  }

  /// Snap to left/right edge like TUICallKit WindowManger.
  void snapToEdge(Size screen, Size panelSize) {
    ensureDefaultPosition(screen, panelSize);
    final mid = position.dx + panelSize.width / 2;
    final x = mid < screen.width / 2
        ? 10.0
        : (screen.width - panelSize.width - 10)
            .clamp(0.0, screen.width - panelSize.width);
    final y = position.dy.clamp(0.0, screen.height - panelSize.height);
    final next = Offset(x, y);
    if (next == position) return;
    position = next;
    notifyListeners();
  }

  Future<void> restoreCallPage() async {
    if (!LiveKitCallSession.instance.isInCall) {
      hide();
      return;
    }
    final name = peerDisplayName;
    final face = peerFaceUrl;
    visible = false;
    notifyListeners();
    // openCallPage's future completes only when the route is popped — do not
    // await it here (PiP / restore callers need to continue after push).
    final openFuture = LiveKitCallNavigator.openCallPage(
      peerDisplayName: name,
      peerFaceUrl: face,
    );
    for (var i = 0; i < 30 && !LiveKitCallNavigator.isCallPageOpen; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    // Keep the route future alive so errors still surface in debug.
    unawaited(openFuture);
  }

  String peerLabel() {
    if (peerDisplayName.trim().isNotEmpty) return peerDisplayName.trim();
    final peerId = LiveKitCallSession.instance.peerUserId;
    final fromStore = DisplayNameStore.instance.c2c(peerId)?.trim() ?? '';
    if (fromStore.isNotEmpty) return fromStore;
    return peerId;
  }

  String durationLabel() {
    final session = LiveKitCallSession.instance;
    if (session.phase == LiveKitCallPhase.ringingOut ||
        session.phase == LiveKitCallPhase.ringingIn ||
        session.phase == LiveKitCallPhase.connecting) {
      return '';
    }
    final started = session.connectedAt;
    if (started == null) return '';
    final sec = DateTime.now().difference(started).inSeconds;
    if (sec < 0) return '';
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    if (_attached) {
      LiveKitCallSession.instance.removeListener(_onSessionChanged);
      _attached = false;
    }
    super.dispose();
  }
}

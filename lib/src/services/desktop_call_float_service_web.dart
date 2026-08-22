import 'package:flutter/material.dart';

/// Web stub — call float is not productized on web.
class DesktopCallFloatService extends ChangeNotifier {
  DesktopCallFloatService._();

  static final DesktopCallFloatService instance = DesktopCallFloatService._();

  bool visible = false;
  Offset position = const Offset(24, 96);
  String peerDisplayName = '';
  String peerFaceUrl = '';

  bool get isVisible => visible;
  bool get isVideoCall => false;

  Future<void> ensureAttached() async {}

  Future<void> ensureInstalled() async {}

  Future<void> minimize({
    String? peerDisplayName,
    String? peerFaceUrl,
  }) async {}

  void hide() {}

  void updatePosition(Offset delta, Size screen, Size panelSize) {}

  void ensureDefaultPosition(Size screen, Size panelSize) {}

  void snapToEdge(Size screen, Size panelSize) {}

  Future<void> restoreCallPage() async {}

  String peerLabel() => '';

  String durationLabel() => '';
}

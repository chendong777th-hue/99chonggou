import 'package:flutter/material.dart';

/// Root navigator for deep links and global overlays.
class AppNavigator {
  AppNavigator._();

  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  static OverlayState? get overlay => key.currentState?.overlay;

  static BuildContext? get context => key.currentState?.context;
}

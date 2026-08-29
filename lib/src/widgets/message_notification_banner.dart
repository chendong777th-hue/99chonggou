import 'package:flutter/material.dart';

/// Root navigator for deep links and global overlays.
class AppNavigator {
  AppNavigator._();

  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  static OverlayState? get overlay => key.currentState?.overlay;

  static BuildContext? get context => key.currentState?.context;

  static String? get currentRouteName {
    final context = key.currentState?.context;
    return context == null ? null : ModalRoute.of(context)?.settings.name;
  }
}

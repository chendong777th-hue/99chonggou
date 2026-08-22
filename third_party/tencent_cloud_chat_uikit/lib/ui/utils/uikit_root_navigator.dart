import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

/// Resolves a [NavigatorState] for modal routes from chat overlays/menus.
///
/// Overlay context menus may not inherit the app root [Navigator]; apps can
/// register [TUIChatGlobalModel.appRootNavigator] as a last-resort fallback.
NavigatorState? resolveUIKitRootNavigator(BuildContext? context) {
  if (context != null) {
    final mountedContext = context.mounted ? context : null;
    if (mountedContext != null) {
      final root = Navigator.maybeOf(mountedContext, rootNavigator: true);
      if (root != null) {
        return root;
      }
      final local = Navigator.maybeOf(mountedContext);
      if (local != null) {
        return local;
      }
    }
  }

  try {
    return serviceLocator<TUIChatGlobalModel>().appRootNavigator?.call();
  } catch (_) {
    return null;
  }
}

/// Shows a confirm dialog on the same [Overlay] that hosts the message menu.
///
/// Message menus are inserted into the root Overlay, above Navigator routes.
/// `showCupertinoDialog` therefore appears *behind* the menu and looks like a
/// dead tap. Inserting another OverlayEntry on top avoids that.
Future<bool> showUIKitOverlayConfirmDialog({
  required OverlayState overlay,
  required String title,
  required String message,
  required String cancelLabel,
  required String confirmLabel,
}) async {
  final completer = Completer<bool>();
  late OverlayEntry entry;
  void finish(bool value) {
    if (completer.isCompleted) {
      return;
    }
    completer.complete(value);
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (ctx) {
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => finish(false),
              child: const ColoredBox(color: Color(0x66000000)),
            ),
          ),
          Center(
            child: CupertinoAlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => finish(false),
                  child: Text(cancelLabel),
                ),
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  onPressed: () => finish(true),
                  child: Text(confirmLabel),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
  overlay.insert(entry);
  return completer.future;
}

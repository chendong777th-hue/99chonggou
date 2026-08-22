import 'package:flutter/widgets.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';

class NavigationRoutes {
  NavigationRoutes._();

  static PageRoute<T> cupertino<T>({
    required WidgetBuilder builder,
    RouteSettings? settings,
    bool maintainState = true,
    bool fullscreenDialog = false,
    bool allowSnapshotting = false,
  }) {
    if (fullscreenDialog) {
      return AppFullscreenDialogRoute<T>(
        builder: builder,
        settings: settings,
        maintainState: maintainState,
        allowSnapshotting: allowSnapshotting,
      );
    }
    return AppMaterialPageRoute<T>(
      builder: builder,
      settings: settings,
      maintainState: maintainState,
    );
  }
}

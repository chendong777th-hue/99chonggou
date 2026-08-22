import 'package:flutter/cupertino.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/ios_back_gesture.dart';

class FadeRoute extends PageRoute<void>
    with CupertinoRouteTransitionMixin<void>, IosBackGestureRouteMixin<void> {
  FadeRoute({required this.page});

  final Widget page;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildContent(BuildContext context) => page;

  @override
  String? get title => null;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return wrapWithIosBackGesture(
      FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }
}

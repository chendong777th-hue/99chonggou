import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';

class AppPrivacyCover extends StatefulWidget {
  const AppPrivacyCover({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<AppPrivacyCover> createState() => _AppPrivacyCoverState();
}

class _AppPrivacyCoverState extends State<AppPrivacyCover>
    with WidgetsBindingObserver {
  bool _covered = false;

  bool get _enabled => !PlatformUtils().isWeb;

  @override
  void initState() {
    super.initState();
    if (_enabled) {
      WidgetsBinding.instance.addObserver(this);
    }
  }

  @override
  void dispose() {
    if (_enabled) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_enabled) return;
    final next = state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden;

    if (_covered == next) return;

    setState(() {
      _covered = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) {
      return widget.child;
    }
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        alignment: Alignment.topLeft,
        children: [
          widget.child,
          if (_covered)
            Positioned.fill(
              child: IgnorePointer(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    color: Colors.black.withOpacity(0.28),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
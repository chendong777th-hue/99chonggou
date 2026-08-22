import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class CallLifecycleService {
  CallLifecycleService._();

  static final CallLifecycleService instance = CallLifecycleService._();

  final ValueNotifier<int> chatHistoryRefreshRevision = ValueNotifier<int>(0);

  bool get isInActiveCall => false;
  bool get isActiveCall => false;

  Future<void> ensureObserversAttached() async {}
  Future<void> ensureFloatWindowEnabled() async {}
  Future<void> teardown() async {}
  void onLifecycleChanged(AppLifecycleState state) {}
}

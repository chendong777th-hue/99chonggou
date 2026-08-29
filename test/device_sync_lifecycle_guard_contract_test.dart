import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('device sync invalidates background work and gates sync starts', () {
    final source = File('lib/src/services/device_sync_service.dart').readAsStringSync();
    expect(source, contains('MobileAsyncCommitGuard'));
    expect(source, contains('_lifecycleGuard.advancePage();'));
    expect(source, contains("'device-contacts-sync'"));
    expect(source, contains("'device-photos-sync'"));
    expect(source, contains('_lifecycleGuard.canCommit(token)'));
  });
}

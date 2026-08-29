import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/session_identity.dart';

void main() {
  test('session generation invalidates work from the previous account', () {
    final service = SessionIdentityService.instance;
    final accountA = service.capture(ownerUserId: 'account_a');

    service.invalidate(reason: 'test_switch_account');
    final accountB = service.capture(ownerUserId: 'account_b');

    expect(
      service.isCurrent(accountA, currentOwnerUserId: 'account_a'),
      isFalse,
    );
    expect(
      service.isCurrent(accountB, currentOwnerUserId: 'account_b'),
      isTrue,
    );
  });
}

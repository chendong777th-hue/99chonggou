import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String chatSource;

  setUpAll(() {
    chatSource = File('lib/src/chat.dart').readAsStringSync();
  });

  test('activate gates media overlay before route_reactivated recover', () {
    final activateAt = chatSource.indexOf('void activate()');
    expect(activateAt, greaterThanOrEqualTo(0));
    final activateBody = chatSource.substring(activateAt, activateAt + 900);

    expect(activateBody.contains('isMediaPreviewOverlayOpen'), isTrue);
    expect(
      activateBody.contains('isRestoringScrollAfterMediaPreview'),
      isTrue,
    );
    expect(activateBody.contains('isMediaPickerOverlayOpen'), isTrue);
    expect(activateBody.contains('isWalletOverlayOpen'), isTrue);

    final mediaGate = activateBody.indexOf('isMediaPreviewOverlayOpen');
    final recoverCall =
        activateBody.indexOf("_recoverChatHistoryAfterOverlayReturn");
    expect(mediaGate, greaterThanOrEqualTo(0));
    expect(recoverCall, greaterThan(mediaGate));
    expect(activateBody.contains("reason: 'route_reactivated'"), isTrue);
  });

  test('recover skips aggressive jumpTo for media route_reactivated', () {
    final recoverAt = chatSource.indexOf(
      'Future<void> _recoverChatHistoryAfterOverlayReturn',
    );
    expect(recoverAt, greaterThanOrEqualTo(0));
    final recoverBody = chatSource.substring(recoverAt, recoverAt + 2800);

    expect(recoverBody.contains('overlay_return_skip_aggressive'), isTrue);
    expect(recoverBody.contains("reason == 'route_reactivated'"), isTrue);
    expect(recoverBody.contains('isMediaPreviewOverlayOpen'), isTrue);
    expect(
      recoverBody.contains('isRestoringScrollAfterMediaPreview'),
      isTrue,
    );
    // Profile/settings path still pins to bottom.
    expect(
      recoverBody.contains('jumpTo(scroll.position.minScrollExtent)'),
      isTrue,
    );
  });

  test('explicit profile recover reasons remain in chat.dart', () {
    expect(chatSource.contains("reason: 'return_from_profile'"), isTrue);
    expect(chatSource.contains("reason: 'return_from_settings'"), isTrue);
  });
}

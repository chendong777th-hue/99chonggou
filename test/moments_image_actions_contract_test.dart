import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('moments image preview exposes download and forward per gallery item',
      () {
    final source = File(
      'lib/src/pages/moments/moments_image_preview.dart',
    ).readAsStringSync();
    expect(source, contains('downloadFn: () => _saveMomentImage(item)'));
    expect(source,
        contains('forwardFn: () => _forwardMomentImage(context, item)'));
    expect(source, isNot(contains('downloadOnly: true')));
  });

  test('forward creates a real image message and uses external sender', () {
    final source = File(
      'lib/src/pages/moments/moments_image_preview.dart',
    ).readAsStringSync();
    expect(source, contains('.createImageMessage('));
    expect(source, contains('ChatExternalMessageSender.sendCreatedMessage('));
  });
}

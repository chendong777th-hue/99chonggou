import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Dart application console output is silenced at the root zone', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main.contains('debugPrint = _discardDebugPrint;'), isTrue);
    expect(main.contains('ZoneSpecification('), isTrue);
    expect(main.contains('print: (self, parent, zone, line) {}'), isTrue);

    final logger = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/utils/logger.dart',
    ).readAsStringSync();
    expect(logger.contains('void i(String text) {}'), isTrue);
    expect(logger.contains('uikitTrace'), isFalse);
  });

  test('native project-owned output routes use no-op loggers', () {
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(appDelegate.contains('func print('), isTrue);

    final kotlinFiles = Directory('android/app/src/main/kotlin')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.kt'));
    for (final file in kotlinFiles) {
      final source = file.readAsStringSync();
      expect(
        source.contains('import android.util.Log'),
        isFalse,
        reason: file.path,
      );
    }
  });
}

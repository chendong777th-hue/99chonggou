import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('file_picker iOS utility class is namespaced and locally overridden',
      () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final header = File(
      'third_party/file_picker/ios/file_picker/Sources/file_picker/include/'
      'file_picker/FileUtils.h',
    ).readAsStringSync();
    final implementation = File(
      'third_party/file_picker/ios/file_picker/Sources/file_picker/FileUtils.m',
    ).readAsStringSync();
    final plugin = File(
      'third_party/file_picker/ios/file_picker/Sources/file_picker/'
      'FilePickerPlugin.m',
    ).readAsStringSync();

    expect(
        pubspec, contains('file_picker:\n    path: third_party/file_picker'));
    expect(header, contains('@interface FLTFilePickerUtils : NSObject'));
    expect(implementation, contains('@implementation FLTFilePickerUtils'));
    expect(header, isNot(contains('@interface FileUtils : NSObject')));
    expect(implementation, isNot(contains('@implementation FileUtils')));
    expect(plugin, isNot(contains('[FileUtils ')));
    expect(plugin, contains('[FLTFilePickerUtils '));
  });
}

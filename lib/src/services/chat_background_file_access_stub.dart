import 'package:flutter/widgets.dart';

Future<bool> chatBackgroundFileExists(String path) async => false;

Future<void> chatBackgroundDeleteFile(String path) async {}

Future<void> chatBackgroundEnsureDir(String path) async {}

Future<void> chatBackgroundDeleteDirIfExists(String path) async {}

Future<String> chatBackgroundCopyFile(String sourcePath, String targetPath) async {
  return targetPath;
}

Widget buildChatBackgroundPreviewImage(String path) {
  return const SizedBox.shrink();
}

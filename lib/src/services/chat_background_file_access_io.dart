import 'dart:io';

import 'package:flutter/widgets.dart';

Future<bool> chatBackgroundFileExists(String path) async {
  return File(path).exists();
}

Future<void> chatBackgroundDeleteFile(String path) async {
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}

Future<void> chatBackgroundEnsureDir(String path) async {
  final dir = Directory(path);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
}

Future<void> chatBackgroundDeleteDirIfExists(String path) async {
  final dir = Directory(path);
  if (await dir.exists()) {
    await dir.delete(recursive: true);
  }
}

Future<String> chatBackgroundCopyFile(String sourcePath, String targetPath) async {
  final copied = await File(sourcePath).copy(targetPath);
  return copied.path;
}

Widget buildChatBackgroundPreviewImage(String path) {
  return Image.file(
    File(path),
    fit: BoxFit.cover,
  );
}

import 'dart:io';

import 'package:flutter/painting.dart';

ImageProvider<Object>? timUIKitLocalImageProvider(String path) {
  final normalized = path.trim();
  if (normalized.isEmpty) {
    return null;
  }
  return FileImage(File(normalized));
}

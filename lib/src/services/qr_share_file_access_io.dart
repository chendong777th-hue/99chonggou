import 'dart:io';
import 'dart:typed_data';

Future<String?> writeQrShareImageFile({
  required String dirPath,
  required String fileName,
  required Uint8List bytes,
}) async {
  final dir = Directory(dirPath);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  final file = File('$dirPath/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

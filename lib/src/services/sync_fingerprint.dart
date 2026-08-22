import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:tencent_cloud_chat_demo/utils/phone_format.dart';

class SyncFingerprint {
  static String contactFingerprint({
    required String displayName,
    required List<String> phones,
  }) {
    final normalizedPhones = PhoneFormat.normalizeContactPhoneList(phones)..sort();
    final payload = '${displayName.trim()}|${normalizedPhones.join(',')}';
    return sha256.convert(utf8.encode(payload)).toString();
  }

  static Future<String> fileContentHash(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  static List<String> normalizePhoneList(List<String> raw) {
    return PhoneFormat.normalizeContactPhoneList(raw);
  }
}

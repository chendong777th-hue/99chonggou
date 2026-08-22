import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:tencent_cloud_chat_demo/src/platform/permission_guard.dart';
import 'package:tencent_cloud_chat_demo/utils/phone_format.dart';

import '../api/sync_api.dart';
import 'sync_fingerprint.dart';

class LocalContactRecord {
  LocalContactRecord({
    required this.localContactId,
    required this.displayName,
    required this.phones,
    required this.fingerprint,
    this.takenAt,
  });

  final String localContactId;
  final String displayName;
  final List<String> phones;
  final String fingerprint;
  final DateTime? takenAt;

  ContactSyncItemPayload toPayload() => ContactSyncItemPayload(
        localContactId: localContactId,
        fingerprint: fingerprint,
        displayName: displayName,
        phones: phones,
        takenAt: takenAt,
      );
}

class ContactSyncCollector {
  static Future<List<LocalContactRecord>> collectAll() async {
    if (!await PermissionGuard.hasContactsForDeviceSync()) {
      return [];
    }
    List<Contact> contacts;
    try {
      contacts = await FlutterContacts.getContacts(withProperties: true);
    } catch (e) {
      debugPrint('ContactSyncCollector: read contacts failed: $e');
      return [];
    }
    final records = <LocalContactRecord>[];
    for (final c in contacts) {
      final rawPhones = <String>[];
      for (final phone in c.phones) {
        final systemNormalized = phone.normalizedNumber.trim();
        if (systemNormalized.isNotEmpty) {
          rawPhones.add(systemNormalized);
        } else {
          rawPhones.add(phone.number);
        }
      }
      final normalized = SyncFingerprint.normalizePhoneList(rawPhones);
      final phones = normalized.isNotEmpty
          ? normalized
          : rawPhones
              .map(PhoneFormat.cleanContactPhoneRaw)
              .where((phone) => phone.isNotEmpty)
              .toList();
      if (phones.isEmpty) {
        continue;
      }
      final displayName = c.displayName.trim().isNotEmpty
          ? c.displayName.trim()
          : (c.name.first.isNotEmpty ? c.name.first : phones.first);
      final fingerprint = SyncFingerprint.contactFingerprint(
        displayName: displayName,
        phones: phones,
      );
      records.add(LocalContactRecord(
        localContactId: c.id,
        displayName: displayName,
        phones: phones,
        fingerprint: fingerprint,
      ));
    }
    return records;
  }
}

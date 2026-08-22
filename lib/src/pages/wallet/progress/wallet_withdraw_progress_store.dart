import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'wallet_withdraw_progress_models.dart';

class WalletWithdrawProgressStore {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _key = 'wallet_withdraw_progress_v1';

  static WalletWithdrawProgressSnapshot? _memory;

  Future<WalletWithdrawProgressSnapshot?> loadActive() async {
    if (_memory != null) return _memory;
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final snapshot = WalletWithdrawProgressSnapshot.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (snapshot.orderId.isEmpty && snapshot.clientOrderId.isEmpty) {
        return null;
      }
      _memory = snapshot;
      return snapshot;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(WalletWithdrawProgressSnapshot snapshot) async {
    _memory = snapshot;
    await _storage.write(
      key: _key,
      value: jsonEncode(snapshot.toJson()),
    );
  }

  Future<void> clear() async {
    _memory = null;
    await _storage.delete(key: _key);
  }
}

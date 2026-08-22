import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 磁盘持久化的钱包 IM 卡片发送记录，按 `orderId` / `clientOrderId` 去重。
abstract class WalletCardSentStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class SecureWalletCardSentStorage implements WalletCardSentStorage {
  const SecureWalletCardSentStorage();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _key = 'wallet_card_sent_v1';

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
}

class MemoryWalletCardSentStorage implements WalletCardSentStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String next) async {
    value = next;
  }
}

class WalletCardSentStore {
  WalletCardSentStore({WalletCardSentStorage? storage})
      : _storage = storage ?? const SecureWalletCardSentStorage();

  static final WalletCardSentStore instance = WalletCardSentStore();

  static const int _maxIds = 400;

  final WalletCardSentStorage _storage;
  final Set<String> _sent = <String>{};
  final Set<String> _rest = <String>{};
  bool _loaded = false;
  Future<void> _writeChain = Future<void>.value();
  Completer<void>? _pendingSave;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await _storage.read();
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _sent
            ..clear()
            ..addAll(_stringSet(decoded['sent']));
          _rest
            ..clear()
            ..addAll(_stringSet(decoded['rest']));
        }
      }
    } catch (_) {
      _sent.clear();
      _rest.clear();
    }
    _loaded = true;
  }

  Future<bool> isSent(Iterable<String> keys) async {
    await load();
    return _contains(_sent, keys);
  }

  Future<bool> isRestCommitted(Iterable<String> keys) async {
    await load();
    return _contains(_rest, keys);
  }

  Future<void> markRestCommitted(Iterable<String> keys) async {
    await load();
    final next = _normalized(keys);
    if (next.isEmpty) return;
    _rest.addAll(next);
    _trim(_rest);
    await _queueSave();
  }

  Future<void> markSent(Iterable<String> keys) async {
    await load();
    final next = _normalized(keys);
    if (next.isEmpty) return;
    _sent.addAll(next);
    _rest.addAll(next);
    _trim(_sent);
    _trim(_rest);
    await _queueSave();
  }

  Future<void> clear() async {
    await load();
    _sent.clear();
    _rest.clear();
    await _queueSave();
  }

  static bool _contains(Set<String> target, Iterable<String> keys) {
    for (final key in _normalized(keys)) {
      if (target.contains(key)) return true;
    }
    return false;
  }

  static Set<String> _normalized(Iterable<String> keys) {
    return keys
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e != '--')
        .toSet();
  }

  static Set<String> _stringSet(Object? raw) {
    if (raw is! List) return <String>{};
    return raw
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  static void _trim(Set<String> ids) {
    if (ids.length <= _maxIds) return;
    final extra = ids.length - _maxIds;
    final drop = ids.take(extra).toList(growable: false);
    ids.removeAll(drop);
  }

  Future<void> _queueSave() {
    final existing = _pendingSave;
    if (existing != null) return existing.future;

    final completer = Completer<void>();
    _pendingSave = completer;
    _writeChain = _writeChain.catchError((_) {}).then((_) async {
      final pending = _pendingSave;
      _pendingSave = null;
      try {
        await _storage.write(
          jsonEncode(<String, List<String>>{
            'sent': _sent.toList(growable: false),
            'rest': _rest.toList(growable: false),
          }),
        );
        pending?.complete();
      } catch (e, st) {
        pending?.completeError(e, st);
      }
    });
    return completer.future;
  }
}

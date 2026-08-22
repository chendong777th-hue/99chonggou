import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'wallet_order.dart';

class WalletPendingStore {
  static final Map<String, WalletOrderDraft> _items = {};
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _key = 'wallet_pending_orders_v2';
  static const int _maxItems = 50;
  static bool _loaded = false;
  static Future<void> _writeChain = Future<void>.value();
  static Completer<void>? _pendingSave;

  List<WalletOrderDraft> get all => _items.values.toList(growable: false);

  Future<List<WalletOrderDraft>> load() async {
    if (_loaded) return all;

    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.trim().isEmpty) {
        _loaded = true;
        return all;
      }

      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _items
          ..clear()
          ..addEntries(
            decoded
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .map(WalletOrderDraft.fromJson)
                .where((e) => e.clientOrderId.isNotEmpty)
                .map((e) => MapEntry(e.clientOrderId, e)),
          );
        _trimIfNeeded();
      }
    } catch (_) {
      _items.clear();
    }

    _loaded = true;
    return all;
  }

  Future<void> put(WalletOrderDraft item) async {
    if (item.clientOrderId.trim().isEmpty) return;
    await load();
    _items[item.clientOrderId] = item;
    _trimIfNeeded();
    await _queueSave();
  }

  Future<void> remove(String clientOrderId) async {
    if (clientOrderId.trim().isEmpty) return;
    await load();
    _items.remove(clientOrderId);
    await _queueSave();
  }

  Future<void> clear() async {
    await load();
    _items.clear();
    await _queueSave();
  }

  Future<void> _queueSave() {
    final existing = _pendingSave;
    if (existing != null) return existing.future;

    final completer = Completer<void>();
    _pendingSave = completer;

    _writeChain = _writeChain.catchError((_) {}).then((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final c = _pendingSave;
      _pendingSave = null;
      try {
        await _saveNow();
        c?.complete();
      } catch (e, st) {
        c?.completeError(e, st);
      }
    });

    return completer.future;
  }

  Future<void> _saveNow() async {
    final raw = jsonEncode(_items.values.map((e) => e.toJson()).toList());
    await _storage.write(key: _key, value: raw);
  }

  static void _trimIfNeeded() {
    if (_items.length <= _maxItems) return;

    final values = _items.values.toList()
      ..sort((a, b) {
        final pa = _keepPriority(a);
        final pb = _keepPriority(b);
        if (pa != pb) return pb.compareTo(pa);
        return _timeOf(b).compareTo(_timeOf(a));
      });

    final keep = values.take(_maxItems).map((e) => e.clientOrderId).toSet();
    _items.removeWhere((key, _) => !keep.contains(key));
  }

  static int _keepPriority(WalletOrderDraft item) {
    if (item.needsChatCard && !item.cardSent && !item.cardIgnored) return 3;
    if (!item.isDoneOrder) return 2;
    if (item.needsChatCard && item.cardSent) return 1;
    return 0;
  }

  static DateTime _timeOf(WalletOrderDraft item) {
    final raw = item.updatedAt.isNotEmpty ? item.updatedAt : item.createdAt;
    return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
}

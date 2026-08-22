import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/api/call_record_api.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_result_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_result_repository.dart';

/// Fills [CallResultRepository] from server (`GET /calls/{callId}` / recent TCP).
///
/// Chat bubbles prefer server `result` + `direction` + `operatorUserId` over
/// raw `lk_call` action inference.
class CallResultEnrichmentService {
  CallResultEnrichmentService._();

  static final CallResultEnrichmentService instance =
      CallResultEnrichmentService._();

  final Map<String, Future<CallResultRecord?>> _inflight =
      <String, Future<CallResultRecord?>>{};

  /// Persist a server-authored record (TCP / recent list).
  void ingestServerItem(CallRecordItem item) {
    final record = item.toCallResultRecord();
    if (record == null) {
      return;
    }
    CallResultRepository.instance.save(record);
  }

  /// Ensure we have a server result for [callId]. No-ops if already `server`.
  Future<CallResultRecord?> ensureServerResult(
    String callId, {
    bool force = false,
  }) {
    final id = callId.trim();
    if (id.isEmpty) {
      return Future<CallResultRecord?>.value(null);
    }
    final existing = CallResultRepository.instance.get(id);
    if (!force && existing?.source == CallResultSource.server) {
      return Future<CallResultRecord?>.value(existing);
    }
    final pending = _inflight[id];
    if (pending != null) {
      return pending;
    }
    final future = _fetchAndSave(id);
    _inflight[id] = future;
    return future.whenComplete(() {
      _inflight.remove(id);
    });
  }

  Future<void> ensureServerResults(
    Iterable<String> callIds, {
    int max = 12,
  }) async {
    final unique = <String>{};
    for (final raw in callIds) {
      final id = raw.trim();
      if (id.isEmpty) continue;
      unique.add(id);
      if (unique.length >= max) break;
    }
    if (unique.isEmpty) return;
    await Future.wait(
      unique.map((id) => ensureServerResult(id)),
      eagerError: false,
    );
  }

  Future<CallResultRecord?> _fetchAndSave(String callId) async {
    try {
      await CallResultRepository.instance.ensureLoaded();
      final item = await CallRecordApi.instance.fetchOne(callId);
      if (item == null) {
        return CallResultRepository.instance.get(callId);
      }
      ingestServerItem(item);
      if (kDebugMode) {
        debugPrint(
          'CallResultEnrichment: fetched callId=$callId '
          'result=${item.result} direction=${item.direction} '
          'duration=${item.durationSec}',
        );
      }
      return CallResultRepository.instance.get(callId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CallResultEnrichment: fetchOne failed callId=$callId err=$e');
      }
      return CallResultRepository.instance.get(callId);
    }
  }
}

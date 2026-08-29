import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/api/call_record_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/livekit_call_api.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_result_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_result_repository.dart';
import 'package:tencent_cloud_chat_demo/src/services/session_identity.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/calling_message/calling_message_data_provider.dart';

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
  final Map<String, Future<CallResultRecord?>> _statusInflight =
      <String, Future<CallResultRecord?>>{};

  /// Persist a server-authored record (TCP / recent list).
  void ingestServerItem(
    CallRecordItem item, {
    SessionIdentity? identity,
  }) {
    final record = item.toCallResultRecord();
    if (record == null) {
      return;
    }
    CallResultRepository.instance.save(record, identity: identity);
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
    final identity = SessionIdentityService.instance.capture();
    if (identity.ownerUserId.isEmpty) {
      return Future<CallResultRecord?>.value(null);
    }
    final existing = CallResultRepository.instance.get(id);
    if (!force && existing?.source == CallResultSource.server) {
      return Future<CallResultRecord?>.value(existing);
    }
    final key = _requestKey(id, identity);
    final pending = _inflight[key];
    if (pending != null) {
      return pending;
    }
    final future = _fetchAndSave(id, identity);
    _inflight[key] = future;
    return future.whenComplete(() {
      if (identical(_inflight[key], future)) {
        _inflight.remove(key);
      }
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

  Future<CallResultRecord?> _fetchAndSave(
    String callId,
    SessionIdentity identity,
  ) async {
    try {
      await CallResultRepository.instance.ensureLoaded(identity: identity);
      if (!_isCurrent(identity)) return null;
      final item = await CallRecordApi.instance.fetchOne(callId);
      if (!_isCurrent(identity)) return null;
      if (item == null) {
        return CallResultRepository.instance.get(callId);
      }
      ingestServerItem(item, identity: identity);
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
        debugPrint(
            'CallResultEnrichment: fetchOne failed callId=$callId err=$e');
      }
      return CallResultRepository.instance.get(callId);
    }
  }

  /// Reconcile from GET /calls/livekit/status/{callId}. This is the source used
  /// while a call is still ringing/answered and after 409/disconnect recovery.
  Future<CallResultRecord?> reconcileStatus(
    String callId, {
    String conversationId = '',
    String peerUserId = '',
    bool? isOutgoing,
  }) {
    final id = callId.trim();
    if (id.isEmpty) return Future<CallResultRecord?>.value(null);
    final identity = SessionIdentityService.instance.capture();
    if (identity.ownerUserId.isEmpty) {
      return Future<CallResultRecord?>.value(null);
    }
    final key = _requestKey(id, identity);
    final pending = _statusInflight[key];
    if (pending != null) return pending;
    final future = _fetchStatusAndSave(
      id,
      conversationId: conversationId,
      peerUserId: peerUserId,
      isOutgoing: isOutgoing,
      identity: identity,
    );
    _statusInflight[key] = future;
    return future.whenComplete(() {
      if (identical(_statusInflight[key], future)) {
        _statusInflight.remove(key);
      }
    });
  }

  Future<CallResultRecord?> _fetchStatusAndSave(
    String callId, {
    required String conversationId,
    required String peerUserId,
    required bool? isOutgoing,
    required SessionIdentity identity,
  }) async {
    try {
      await CallResultRepository.instance.ensureLoaded(identity: identity);
      final snapshot =
          await LiveKitCallApi.instance.fetchStatus(callId: callId);
      if (!_isCurrent(identity)) return null;
      if (snapshot == null || snapshot.callId.isEmpty) {
        return CallResultRepository.instance.get(callId);
      }
      final current = CallResultRepository.instance.get(callId);
      final protocol = _protocolForStatus(snapshot.status);
      final record = CallResultRecord(
        callId: snapshot.callId,
        conversationId: conversationId.isNotEmpty
            ? conversationId
            : (current?.conversationId ?? ''),
        callerUserId: snapshot.callerUserId,
        operatorUserId: current?.operatorUserId ?? '',
        peerUserId:
            peerUserId.isNotEmpty ? peerUserId : (current?.peerUserId ?? ''),
        protocolType: protocol,
        durationSec: snapshot.durationSec,
        endedAtMs: snapshot.endedAtMs,
        isOutgoing: isOutgoing ?? current?.isOutgoing,
        source: CallResultSource.server,
        mediaType: snapshot.mediaType,
        status: snapshot.status,
        roomName: snapshot.roomName,
        startedAtMs: snapshot.startedAtMs,
        acceptedAtMs: snapshot.acceptedAtMs,
      );
      CallResultRepository.instance.save(record, identity: identity);
      if (kDebugMode) {
        debugPrint(
            '[CallStore] status callId=$callId status=${snapshot.status.wireName}');
      }
      return CallResultRepository.instance.get(callId);
    } catch (e) {
      if (kDebugMode)
        debugPrint('[CallStore] status failed callId=$callId err=$e');
      return CallResultRepository.instance.get(callId);
    }
  }

  static CallProtocolType _protocolForStatus(CallSessionStatus status) {
    switch (status) {
      case CallSessionStatus.ringing:
        return CallProtocolType.send;
      case CallSessionStatus.answered:
        return CallProtocolType.accept;
      case CallSessionStatus.rejected:
        return CallProtocolType.reject;
      case CallSessionStatus.canceled:
        return CallProtocolType.cancel;
      case CallSessionStatus.missed:
        return CallProtocolType.timeout;
      case CallSessionStatus.ended:
        return CallProtocolType.hangup;
    }
  }

  String _requestKey(String callId, SessionIdentity identity) {
    return '${identity.ownerUserId}|${identity.generation}|$callId';
  }

  bool _isCurrent(SessionIdentity identity) {
    return identity.ownerUserId.isNotEmpty &&
        SessionIdentityService.instance.isCurrent(identity);
  }
}

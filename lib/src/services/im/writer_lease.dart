import 'package:tencent_cloud_chat_demo/src/services/im/im_ingress_store.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

class ImWriterLease {
  const ImWriterLease({
    required this.ownerUserId,
    required this.leaseOwnerId,
    required this.fencingToken,
    required this.acquiredAtMs,
    required this.expiresAtMs,
    required this.heartbeatAtMs,
  });

  final String ownerUserId;
  final String leaseOwnerId;
  final int fencingToken;
  final int acquiredAtMs;
  final int expiresAtMs;
  final int heartbeatAtMs;

  bool isExpiredAt(int nowMs) => expiresAtMs <= nowMs;

  ImWriterLeaseRecord toRecord() => ImWriterLeaseRecord(
        ownerUserId: ownerUserId,
        leaseOwnerId: leaseOwnerId,
        fencingToken: fencingToken,
        acquiredAtMs: acquiredAtMs,
        expiresAtMs: expiresAtMs,
        heartbeatAtMs: heartbeatAtMs,
      );

  static ImWriterLease fromRecord(ImWriterLeaseRecord record) => ImWriterLease(
        ownerUserId: record.ownerUserId,
        leaseOwnerId: record.leaseOwnerId,
        fencingToken: record.fencingToken,
        acquiredAtMs: record.acquiredAtMs,
        expiresAtMs: record.expiresAtMs,
        heartbeatAtMs: record.heartbeatAtMs,
      );
}

class ImMessageCoreLeaseContext {
  const ImMessageCoreLeaseContext({
    required this.store,
    required this.lease,
    required this.ownerUserId,
    required this.accountGeneration,
    required this.domainGeneration,
  });

  final ImIngressStore store;
  final ImWriterLease lease;
  final String ownerUserId;
  final int accountGeneration;
  final int domainGeneration;
}

/// Transactional owner election and fencing-token validation for MessageCore.
class ImWriterLeaseService {
  ImWriterLeaseService({required ImIngressStore store}) : _store = store;

  final ImIngressStore _store;

  Future<ImWriterLease?> acquire({
    required String ownerUserId,
    required String leaseOwnerId,
    required int nowMs,
    int ttlMs = 15000,
  }) async {
    final owner = _required(ownerUserId, 'ownerUserId');
    final leaseOwner = _requiredOpaque(leaseOwnerId, 'leaseOwnerId');
    _validateTimes(nowMs: nowMs, ttlMs: ttlMs);
    return _store.transaction<ImWriterLease?>((transaction) async {
      final current = await transaction.findWriterLease(owner);
      if (current != null &&
          !current.isExpiredAt(nowMs) &&
          current.leaseOwnerId != leaseOwner) {
        return null;
      }

      final isSameActiveOwner = current != null &&
          current.leaseOwnerId == leaseOwner &&
          !current.isExpiredAt(nowMs);
      final nextToken = isSameActiveOwner
          ? current.fencingToken
          : (current?.fencingToken ?? 0) + 1;
      final replacement = ImWriterLeaseRecord(
        ownerUserId: owner,
        leaseOwnerId: leaseOwner,
        fencingToken: nextToken,
        acquiredAtMs: isSameActiveOwner ? current.acquiredAtMs : nowMs,
        expiresAtMs: nowMs + ttlMs,
        heartbeatAtMs: nowMs,
      );
      final replaced = current == null
          ? await transaction.insertWriterLeaseIfAbsent(replacement)
          : await transaction.replaceWriterLeaseIfCurrent(
              ownerUserId: owner,
              expectedLeaseOwnerId: current.leaseOwnerId,
              expectedFencingToken: current.fencingToken,
              replacement: replacement,
            );
      return replaced ? ImWriterLease.fromRecord(replacement) : null;
    });
  }

  Future<ImWriterLease?> renew({
    required ImWriterLease lease,
    required int nowMs,
    int ttlMs = 15000,
  }) async {
    _validateTimes(nowMs: nowMs, ttlMs: ttlMs);
    if (lease.isExpiredAt(nowMs)) return null;
    return _store.transaction<ImWriterLease?>((transaction) async {
      final current = await transaction.findWriterLease(lease.ownerUserId);
      if (current == null ||
          current.leaseOwnerId != lease.leaseOwnerId ||
          current.fencingToken != lease.fencingToken ||
          current.isExpiredAt(nowMs)) {
        return null;
      }
      final replacement = ImWriterLeaseRecord(
        ownerUserId: current.ownerUserId,
        leaseOwnerId: current.leaseOwnerId,
        fencingToken: current.fencingToken,
        acquiredAtMs: current.acquiredAtMs,
        expiresAtMs: nowMs + ttlMs,
        heartbeatAtMs: nowMs,
      );
      final replaced = await transaction.replaceWriterLeaseIfCurrent(
        ownerUserId: current.ownerUserId,
        expectedLeaseOwnerId: current.leaseOwnerId,
        expectedFencingToken: current.fencingToken,
        replacement: replacement,
      );
      return replaced ? ImWriterLease.fromRecord(replacement) : null;
    });
  }

  Future<bool> isCurrent({
    required ImWriterLease lease,
    required int nowMs,
  }) async {
    final owner = _required(lease.ownerUserId, 'ownerUserId');
    return _store.transaction<bool>((transaction) async {
      final current = await transaction.findWriterLease(owner);
      return current != null &&
          current.leaseOwnerId == lease.leaseOwnerId &&
          current.fencingToken == lease.fencingToken &&
          !current.isExpiredAt(nowMs);
    });
  }

  Future<bool> release(ImWriterLease lease) {
    return _store.transaction<bool>((transaction) {
      return transaction.deleteWriterLeaseIfCurrent(
        ownerUserId: lease.ownerUserId,
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
      );
    });
  }
}

String _required(String value, String name) {
  final normalized = ChatIdFormat.rawUserUid(value);
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, name, 'must not be empty');
  }
  return normalized;
}

String _requiredOpaque(String value, String name) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, name, 'must not be empty');
  }
  return normalized;
}

void _validateTimes({required int nowMs, required int ttlMs}) {
  if (nowMs < 0) throw ArgumentError.value(nowMs, 'nowMs');
  if (ttlMs <= 0) throw ArgumentError.value(ttlMs, 'ttlMs');
}

import 'package:tencent_cloud_chat_demo/src/services/im/read_receipt_outbox_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/session_identity.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

class ReadReceiptOutboxRecoveryService {
  ReadReceiptOutboxRecoveryService._();

  static final ReadReceiptOutboxRecoveryService instance =
      ReadReceiptOutboxRecoveryService._();

  Future<void>? _inFlight;

  Future<void> recoverPending() {
    final running = _inFlight;
    if (running != null) return running;
    late final Future<void> task;
    task = _recover().whenComplete(() {
      if (identical(_inFlight, task)) _inFlight = null;
    });
    _inFlight = task;
    return task;
  }

  Future<void> _recover() async {
    final identity = SessionIdentityService.instance.capture();
    if (identity.ownerUserId.isEmpty) return;
    for (var page = 0; page < 10; page++) {
      final rows = await ReadReceiptOutboxStore.instance.listDue(
        ownerUserId: identity.ownerUserId,
        limit: 100,
      );
      if (rows.isEmpty || !SessionIdentityService.instance.isCurrent(identity)) {
        return;
      }
      await _deliverBatch(identity, rows);
      if (rows.length < 100) return;
    }
  }

  Future<void> _deliverBatch(
    SessionIdentity identity,
    List<ReadReceiptOutboxRecord> rows,
  ) async {
    if (rows.isEmpty || !SessionIdentityService.instance.isCurrent(identity)) {
      return;
    }
    dynamic result;
    try {
      result = await serviceLocator<MessageService>().sendMessageReadReceipts(
        messageIDList:
            rows.map((row) => row.messageId).toList(growable: false),
      );
    } catch (_) {
      result = null;
    }
    if (!SessionIdentityService.instance.isCurrent(identity)) return;
    if (result?.code == 0) {
      await ReadReceiptOutboxStore.instance.acknowledge(
        ownerUserId: identity.ownerUserId,
        messageIds: rows.map((row) => row.messageId),
      );
      return;
    }

    // One expired/invalid message ID must not poison every receipt behind it.
    // Split a rejected batch until only the bad rows receive backoff.
    if (rows.length > 1) {
      final middle = rows.length ~/ 2;
      await _deliverBatch(identity, rows.sublist(0, middle));
      await _deliverBatch(identity, rows.sublist(middle));
      return;
    }
    await ReadReceiptOutboxStore.instance.markRetry(
      ownerUserId: identity.ownerUserId,
      records: rows,
    );
  }
}

import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html)
      'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

class GapInfo {
  const GapInfo({
    required this.upperMsgID,
    required this.lowerMsgID,
    required this.upperSeq,
    required this.lowerSeq,
  });

  final String upperMsgID;
  final String lowerMsgID;
  final int? upperSeq;
  final int? lowerSeq;

  String get gapId => 'gap_${upperMsgID}_$lowerMsgID';
}

/// Detects protocol-proven group gaps from Tencent server Seq values.
///
/// C2C Seq is per sender and timestamp spacing is not proof of a missing
/// message, so C2C conversations deliberately return no gaps here.
class GapDetector {
  GapDetector._();

  static const int _seamScanRadius = 5;

  /// Detects gaps in the merged list. Only scans the seam region
  /// (±[_seamScanRadius] around the join point) for paginated loads.
  /// Full scan is used for replace-style commits (first screen / search
  /// jump / full reset).
  static List<GapInfo> detectGaps({
    required List<V2TimMessage> newestFirst,
    required bool isGroup,
    bool fullScan = false,
    int? seamIndex,
  }) {
    if (!isGroup || newestFirst.length < 2) return const [];

    final candidates = <_GapCandidate>[];
    for (var index = 0; index < newestFirst.length; index++) {
      final message = newestFirst[index];
      if (_isLocalInjected(message)) continue;
      final seq = int.tryParse(message.seq?.trim() ?? '') ?? 0;
      if (seq <= 0) continue;
      candidates.add(_GapCandidate(message: message, index: index, seq: seq));
    }
    if (candidates.length < 2) return const [];

    final gaps = <GapInfo>[];
    for (var index = 0; index < candidates.length - 1; index++) {
      final upper = candidates[index];
      final lower = candidates[index + 1];
      if (!fullScan && seamIndex != null) {
        final scanStart = seamIndex - _seamScanRadius;
        final scanEnd = seamIndex + _seamScanRadius;
        if (lower.index < scanStart || upper.index > scanEnd) continue;
      }
      if (upper.seq - lower.seq <= 1) continue;
      gaps.add(GapInfo(
        upperMsgID: (upper.message.msgID ?? '').trim(),
        lowerMsgID: (lower.message.msgID ?? '').trim(),
        upperSeq: upper.seq,
        lowerSeq: lower.seq,
      ));
    }
    return List<GapInfo>.unmodifiable(gaps);
  }

  static bool _isLocalInjected(V2TimMessage msg) {
    final msgID = msg.msgID?.trim() ?? '';
    return msgID.startsWith('ce_') ||
        msgID.startsWith('local_gt_') ||
        msgID.startsWith('local_') ||
        msgID.startsWith('gap_');
  }
}

class _GapCandidate {
  const _GapCandidate({
    required this.message,
    required this.index,
    required this.seq,
  });

  final V2TimMessage message;
  final int index;
  final int seq;
}

import 'package:flutter/foundation.dart';

/// 入站消息分片揭示：按待揭示队列长度给出 maxChunk / intervalMs。
///
/// iOS / 桌面规则（与 docs/frontend-mobile-perf-realtime-todo.md 一致）：
/// - queueLen ≤ 2 → chunk 1 / 160ms
/// - 3–8 → chunk 3 / 160ms
/// - ≥ 9 → chunk 6 / 80ms
///
/// Android 更快揭示，减少积压 rebuild。
({int maxChunk, int intervalMs}) inboundRevealParams(int queueLen) {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return androidInboundRevealParams(queueLen);
  }
  return defaultInboundRevealParams(queueLen);
}

({int maxChunk, int intervalMs}) defaultInboundRevealParams(int queueLen) {
  final n = queueLen < 0 ? 0 : queueLen;
  if (n <= 2) {
    return (maxChunk: 1, intervalMs: 160);
  }
  if (n <= 8) {
    return (maxChunk: 3, intervalMs: 160);
  }
  return (maxChunk: 6, intervalMs: 80);
}

({int maxChunk, int intervalMs}) androidInboundRevealParams(int queueLen) {
  final n = queueLen < 0 ? 0 : queueLen;
  if (n <= 4) {
    return (maxChunk: 3, intervalMs: 60);
  }
  if (n <= 12) {
    return (maxChunk: 6, intervalMs: 50);
  }
  return (maxChunk: 10, intervalMs: 40);
}

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/inbound_chunk_reveal_params.dart';

void main() {
  final originalTargetPlatform = debugDefaultTargetPlatformOverride;

  tearDown(() {
    debugDefaultTargetPlatformOverride = originalTargetPlatform;
  });

  group('defaultInboundRevealParams', () {
    test('queueLen <= 2 uses chunk 1 / 160ms', () {
      for (final n in [0, 1, 2]) {
        final p = defaultInboundRevealParams(n);
        expect(p.maxChunk, 1, reason: 'n=$n');
        expect(p.intervalMs, 160, reason: 'n=$n');
      }
    });

    test('queueLen 3–8 uses chunk 3 / 160ms', () {
      for (final n in [3, 5, 8]) {
        final p = defaultInboundRevealParams(n);
        expect(p.maxChunk, 3, reason: 'n=$n');
        expect(p.intervalMs, 160, reason: 'n=$n');
      }
    });

    test('queueLen >= 9 uses chunk 6 / 80ms', () {
      for (final n in [9, 10, 20]) {
        final p = defaultInboundRevealParams(n);
        expect(p.maxChunk, 6, reason: 'n=$n');
        expect(p.intervalMs, 80, reason: 'n=$n');
      }
    });

    test('negative queueLen treated as empty', () {
      final p = defaultInboundRevealParams(-1);
      expect(p.maxChunk, 1);
      expect(p.intervalMs, 160);
    });
  });

  group('androidInboundRevealParams', () {
    test('queueLen <= 4 uses chunk 3 / 60ms', () {
      for (final n in [0, 2, 4]) {
        final p = androidInboundRevealParams(n);
        expect(p.maxChunk, 3, reason: 'n=$n');
        expect(p.intervalMs, 60, reason: 'n=$n');
      }
    });

    test('queueLen 5–12 uses chunk 6 / 50ms', () {
      for (final n in [5, 8, 12]) {
        final p = androidInboundRevealParams(n);
        expect(p.maxChunk, 6, reason: 'n=$n');
        expect(p.intervalMs, 50, reason: 'n=$n');
      }
    });

    test('queueLen >= 13 uses chunk 10 / 40ms', () {
      for (final n in [13, 20]) {
        final p = androidInboundRevealParams(n);
        expect(p.maxChunk, 10, reason: 'n=$n');
        expect(p.intervalMs, 40, reason: 'n=$n');
      }
    });
  });

  test('inboundRevealParams routes Android platform to android table', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final p = inboundRevealParams(20);
    expect(p.maxChunk, 10);
    expect(p.intervalMs, 40);
  });
}

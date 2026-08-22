import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/api_node_service.dart';

void main() {
  test('catalog has only CN node', () {
    expect(ApiNodeService.catalog.length, 1);
    expect(ApiNodeService.catalog.single.id, 'cn');
    expect(ApiNodeService.defaultNodeId, 'cn');
  });

  test('nodeById falls back to default', () {
    final node = ApiNodeService.instance.nodeById('os');
    expect(node.id, ApiNodeService.defaultNodeId);
  });

  test('pickFastestNormal returns the only normal node', () {
    final best = ApiNodeService.pickFastestNormal(
      probes: {
        'cn': const ApiNodeProbeResult(
          status: ApiNodeProbeStatus.normal,
          latencyMs: 80,
        ),
      },
    );
    expect(best?.id, 'cn');
  });

  test('pickFastestNormal returns null when excluding the only node', () {
    final best = ApiNodeService.pickFastestNormal(
      probes: {
        'cn': const ApiNodeProbeResult(
          status: ApiNodeProbeStatus.normal,
          latencyMs: 120,
        ),
      },
      excludeId: 'cn',
    );
    expect(best, isNull);
  });

  test('failureSwitchThreshold is 3', () {
    expect(ApiNodeService.failureSwitchThreshold, 3);
  });
}

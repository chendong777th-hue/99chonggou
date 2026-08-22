import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/models/sangong_admin_realtime_state.dart';
import 'package:tencent_cloud_chat_demo/src/utils/sangong_sse_parser.dart';

void main() {
  group('SangongSseParser', () {
    test('parses state event blocks', () {
      final parser = SangongSseParser();
      final events = <String, String>{};
      parser.feed(
        'event: state\n'
        'data: {"state":{"version":2,"status":"running"}}\n\n',
        (event, data) => events[event] = data,
      );
      expect(events['state'], contains('"version":2'));
    });

    test('buffers partial chunks', () {
      final parser = SangongSseParser();
      final events = <String, String>{};
      parser.feed('event: state\n', (event, data) => events[event] = data);
      expect(events, isEmpty);
      parser.feed(
        'data: {"state":{"version":3}}\n\n',
        (event, data) => events[event] = data,
      );
      expect(events['state'], contains('"version":3'));
    });
  });

  group('SangongAdminRealtimeState', () {
    test('parses pending door totals and banner mapping', () {
      final state = SangongAdminRealtimeState.fromJson({
        'version': 12,
        'status': 'running',
        'settings': {'doorCount': 6, 'minBet': 0, 'maxBet': 0},
        'round': {
          'id': 18,
          'bankerNickname': '用户666',
          'bankerDoor': 1,
          'betWindowOpenAt': '2026-06-23T00:05:00+08:00',
        },
        'pending': {
          'open': true,
          'messageCount': 3,
          'doorTotals': {'1': 0, '2': 400, '3': 200},
          'grandTotal': 600,
        },
        'placed': {
          'doorTotals': {'2': 100},
          'grandTotal': 100,
          'betCount': 1,
        },
      });

      final banner = state.toGroupGameRoundStatus();
      expect(banner.bankerName, '用户666');
      expect(banner.bankerDoor, 1);
      expect(banner.totalBetCount, 600);
      expect(banner.doorBetTotals[1], 400);
      expect(banner.doorBetTotals[2], 200);
    });

    test('ignores stale pending when bet window is not open', () {
      final state = SangongAdminRealtimeState.fromJson({
        'settings': {'doorCount': 6},
        'round': {
          'id': 19,
          'bankerNickname': '用户666',
          'bankerDoor': 6,
        },
        'pending': {
          'open': false,
          'messageCount': 3,
          'doorTotals': {'1': 22, '3': 55, '5': 222},
          'grandTotal': 299,
        },
        'placed': {
          'doorTotals': {'2': 100},
          'betCount': 1,
        },
      });

      final banner = state.toGroupGameRoundStatus();
      expect(banner.doorBetTotals, List<int>.filled(6, 0));
      expect(banner.totalBetCount, 0);
    });

    test('uses placed totals after bet window closes', () {
      final state = SangongAdminRealtimeState.fromJson({
        'settings': {'doorCount': 6},
        'round': {
          'id': 18,
          'betWindowOpenAt': '2026-06-23T00:05:00+08:00',
          'betWindowCloseAt': '2026-06-23T00:08:03+08:00',
        },
        'pending': {
          'messageCount': 5,
          'doorTotals': {'2': 400},
        },
        'placed': {
          'betCount': 2,
          'doorTotals': {'2': 100, '3': 50},
        },
      });

      final banner = state.toGroupGameRoundStatus();
      expect(banner.totalBetCount, 150);
      expect(banner.doorBetTotals[1], 100);
      expect(banner.doorBetTotals[2], 50);
    });

    test('tryParseEventData accepts wrapped state payload', () {
      final state = SangongAdminRealtimeState.tryParseEventData(
        '{"state":{"version":9,"status":"running"}}',
      );
      expect(state?.version, 9);
      expect(state?.status, 'running');
    });
  });
}

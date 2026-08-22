import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/agent_rebate_date_range.dart';

void main() {
  final today = DateTime(2026, 7, 13);

  test('same day is a valid one-day range', () {
    final range = AgentRebateDateRange(start: today, end: today, today: today);

    expect(range.inclusiveDays, 1);
    expect(range.startApiValue, '2026-07-13');
    expect(range.endApiValue, '2026-07-13');
  });

  test('exactly 93 inclusive days is valid', () {
    final start = today.subtract(const Duration(days: 92));
    final range = AgentRebateDateRange(start: start, end: today, today: today);

    expect(range.inclusiveDays, 93);
  });

  test('94 inclusive days is rejected', () {
    expect(
      AgentRebateDateRange.validate(
        start: today.subtract(const Duration(days: 93)),
        end: today,
        today: today,
      ),
      AgentRebateDateRangeError.exceedsMaximum,
    );
  });

  test('end before start is rejected', () {
    expect(
      AgentRebateDateRange.validate(
        start: today,
        end: today.subtract(const Duration(days: 1)),
        today: today,
      ),
      AgentRebateDateRangeError.endBeforeStart,
    );
  });

  test('future end date is rejected', () {
    expect(
      AgentRebateDateRange.validate(
        start: today,
        end: today.add(const Duration(days: 1)),
        today: today,
      ),
      AgentRebateDateRangeError.endAfterToday,
    );
  });

  group('China 07:00 business day', () {
    test('before 07:00 China stays on previous business date', () {
      final instant = agentRebateInstantFromChinaWall(2026, 7, 13, 6, 59, 59);
      expect(
        formatAgentRebateApiDate(agentRebateBusinessDate(instant)),
        '2026-07-12',
      );
    });

    test('at 07:00 China rolls to new business date', () {
      final instant = agentRebateInstantFromChinaWall(2026, 7, 13, 7);
      expect(
        formatAgentRebateApiDate(agentRebateBusinessDate(instant)),
        '2026-07-13',
      );
    });

    test('preset ranges follow business date not calendar midnight', () {
      // 中国 7/13 06:59 → 业务「今天」= 7/12
      final beforeCutover =
          agentRebateInstantFromChinaWall(2026, 7, 13, 6, 59);
      final yesterday = AgentRebateDateRange.yesterday(beforeCutover);
      expect(yesterday.startApiValue, '2026-07-11');
      expect(yesterday.endApiValue, '2026-07-11');

      final todayRange = AgentRebateDateRange.today(beforeCutover);
      expect(todayRange.startApiValue, '2026-07-12');
      expect(todayRange.endApiValue, '2026-07-12');

      // 中国 7/13 12:00 → 业务「今天」= 7/13
      final afterCutover =
          agentRebateInstantFromChinaWall(2026, 7, 13, 12);
      expect(
        AgentRebateDateRange.today(afterCutover).startApiValue,
        '2026-07-13',
      );
      expect(
        AgentRebateDateRange.yesterday(afterCutover).startApiValue,
        '2026-07-12',
      );

      for (final days in const <int>[1, 7, 30, 90]) {
        final range = AgentRebateDateRange.recentDays(days, afterCutover);
        expect(range.endApiValue, '2026-07-13');
        expect(range.inclusiveDays, days);
      }
    });
  });
}

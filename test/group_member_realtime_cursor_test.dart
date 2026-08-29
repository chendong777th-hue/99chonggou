import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_member_realtime_cursor_policy.dart';

void main() {
  test('realtime member seq at or behind cursor is already applied', () {
    expect(
      GroupMemberRealtimeCursorPolicy.shouldApply(
        cursor: 50,
        seq: 50,
      ),
      isFalse,
    );
    expect(
      GroupMemberRealtimeCursorPolicy.shouldApply(
        cursor: 50,
        seq: 49,
      ),
      isFalse,
    );
    expect(
      GroupMemberRealtimeCursorPolicy.shouldApply(
        cursor: 50,
        seq: 51,
      ),
      isTrue,
    );
  });

  test('realtime member cursor advances only without a gap', () {
    expect(
      GroupMemberRealtimeCursorPolicy.shouldAdvance(
        cursor: 50,
        seq: 51,
      ),
      isTrue,
    );
    expect(
      GroupMemberRealtimeCursorPolicy.shouldAdvance(
        cursor: 50,
        seq: 52,
      ),
      isFalse,
    );
  });
}

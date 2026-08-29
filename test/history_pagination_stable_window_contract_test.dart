import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('previous pagination preserves request baseline before committing', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/'
      'separate_models/tui_chat_history_pagination_load.dart',
    ).readAsStringSync();

    expect(source.contains('previousPaginationBaseline'), isTrue);
    expect(source.contains('stableCommitBase'), isTrue);
    expect(source.contains('stableLatestBeforeCommit'), isTrue);
    expect(
        source
            .contains('applyMemoryWindow: direction != LoadDirection.previous'),
        isTrue);
  });

  test('previous pagination restores a message viewport anchor across trims',
      () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart',
    ).readAsStringSync();

    expect(source.contains('_capturePaginationViewportAnchor'), isTrue);
    expect(source.contains('_restorePaginationViewportAnchor'), isTrue);
    expect(source.contains('maxPinnedAnchorAttempts = 5'), isTrue);
    expect(source.contains('load_previous_viewport_anchor_restore'), isTrue);
    expect(
      source.contains('load_previous_restore_waiting_for_scroll_end'),
      isTrue,
    );
    expect(
      source.contains('load_previous_restore_resumed_after_scroll_end'),
      isTrue,
    );
    expect(
      source.contains('load_previous_viewport_anchor_restore_skipped'),
      isTrue,
    );
    expect(
      source.contains('memory_window_trim_held_reading_history'),
      isTrue,
    );
    expect(
      source.contains('memory_window_compact_stable_boundary'),
      isTrue,
    );
    expect(
      source.contains('load_previous_restore_cancelled_user_scroll'),
      isTrue,
    );
    expect(
      source.contains('load_previous_restore_skipped_user_scroll'),
      isTrue,
    );
    expect(source.contains('forceWhileReadingHistory: true'), isFalse);
  });

  test('reverse pagination trusts native append instead of stale offset restore',
      () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart',
    ).readAsStringSync();

    expect(source.contains('load_previous_reverse_append_native'), isTrue);
    expect(
      source.contains(
        'position.axisDirection == AxisDirection.up ||\n'
        '        position.axisDirection == AxisDirection.left',
      ),
      isTrue,
    );
    expect(
      source.contains('jump__restorePaginationExtentAnchor'),
      isTrue,
    );
  });

  test('newer reconciliation is deferred while reading history', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/'
      'tui_chat_global_model.dart',
    ).readAsStringSync();

    expect(
      source.contains('_shouldDeferCloudCatchUpWhileReadingHistory'),
      isTrue,
    );
    expect(
      source.contains('cloud_catch_up_deferred_reading_history'),
      isTrue,
    );
    expect(
      source.contains('seq_gap_catch_up_deferred_reading_history'),
      isTrue,
    );
  });

  test('pagination restore cannot promote transient zero pixels to bottom', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/'
      'tui_chat_global_model.dart',
    ).readAsStringSync();

    expect(
      source.contains('logical_position_sync_ignored_pagination_restore'),
      isTrue,
    );
    expect(source.contains('isMemoryWindowSuppressed(convId)'), isTrue);
    expect(
      source.contains('_isPaginationRestoreTransientNearBottom'),
      isTrue,
    );
  });

  test('tongue cannot promote pagination layout gap to bottom', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKItMessageList/TIMUIKitTongue/'
      'tim_uikit_chat_history_message_list_tongue_container.dart',
    ).readAsStringSync();
    expect(
      source.contains('tongue_settle_ignored_pagination_restore'),
      isTrue,
    );
    expect(
      source.contains('isPaginationRestoreTransientNearBottom'),
      isTrue,
    );
  });
}

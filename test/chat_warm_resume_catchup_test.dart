import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/chat_warm_resume_catchup.dart';
import 'package:tencent_cloud_chat_demo/src/utils/conversation_preview_history_sync.dart';

void main() {
  group('shouldAllowCloudCatchUp', () {
    test('preview ahead always allows cloud', () {
      expect(
        shouldAllowCloudCatchUp(source: 'other', previewAhead: true),
        isTrue,
      );
      expect(
        shouldAllowCloudCatchUp(source: null, previewAhead: true),
        isTrue,
      );
    });

    test('warm resume and reconnect reasons allow cloud without preview ahead',
        () {
      for (final source in <String>[
        'app_resumed',
        'im_reconnected',
        'connect_success',
        'sync_server_finish',
      ]) {
        expect(
          shouldAllowCloudCatchUp(source: source, previewAhead: false),
          isTrue,
          reason: source,
        );
      }
    });

    test('open-preview-ahead reason does not force cloud when not ahead', () {
      expect(
        shouldAllowCloudCatchUp(
          source: ConversationPreviewHistorySync.previewAheadOnOpenReason,
          previewAhead: false,
        ),
        isFalse,
      );
    });

    test('unknown or null source without preview ahead denies cloud', () {
      expect(
        shouldAllowCloudCatchUp(source: null, previewAhead: false),
        isFalse,
      );
      expect(
        shouldAllowCloudCatchUp(source: 'external_entry', previewAhead: false),
        isFalse,
      );
    });
  });
}

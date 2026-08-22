import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';

void main() {
  group('resolveHaveMoreAfterPage', () {
    test('non-zero nextSeq keeps pagination alive without finished signal', () {
      expect(
        ConversationSyncService.resolveHaveMoreAfterPage(
          haveMoreBeforePage: false,
          pageLength: 0,
          pagesLoadedBeforeThisPage: 0,
          nextSeq: '862',
        ),
        isTrue,
      );
      expect(
        ConversationSyncService.resolveHaveMoreAfterPage(
          haveMoreBeforePage: true,
          pageLength: 10,
          pagesLoadedBeforeThisPage: 0,
          nextSeq: '862',
        ),
        isTrue,
      );
    });

    test('SDK isFinished overrides a stale non-zero nextSeq', () {
      expect(
        ConversationSyncService.resolveHaveMoreAfterPage(
          haveMoreBeforePage: true,
          pageLength: 21,
          pagesLoadedBeforeThisPage: 0,
          nextSeq: '2',
          isFinished: true,
        ),
        isFalse,
      );
    });

    test('nextSeq zero is an exhausted cursor', () {
      expect(
        ConversationSyncService.resolveHaveMoreAfterPage(
          haveMoreBeforePage: true,
          pageLength: 0,
          pagesLoadedBeforeThisPage: 0,
          nextSeq: '0',
          requestedNextSeq: '2',
        ),
        isFalse,
      );
    });

    test('data page with empty nextSeq is exhausted', () {
      expect(
        ConversationSyncService.resolveHaveMoreAfterPage(
          haveMoreBeforePage: true,
          pageLength: 15,
          pagesLoadedBeforeThisPage: 0,
          nextSeq: '',
        ),
        isFalse,
      );
    });

    test('cold empty page keeps prior true (c2c_tab poison fix)', () {
      expect(
        ConversationSyncService.resolveHaveMoreAfterPage(
          haveMoreBeforePage: true,
          pageLength: 0,
          pagesLoadedBeforeThisPage: 0,
          nextSeq: '',
        ),
        isTrue,
      );
    });

    test('empty continuation page is exhausted', () {
      expect(
        ConversationSyncService.resolveHaveMoreAfterPage(
          haveMoreBeforePage: true,
          pageLength: 0,
          pagesLoadedBeforeThisPage: 0,
          nextSeq: '',
          requestedNextSeq: '2',
        ),
        isFalse,
      );
    });

    test('empty page after loaded pages is exhausted', () {
      expect(
        ConversationSyncService.resolveHaveMoreAfterPage(
          haveMoreBeforePage: true,
          pageLength: 0,
          pagesLoadedBeforeThisPage: 2,
          nextSeq: '',
        ),
        isFalse,
      );
    });

    test('cold empty page keeps prior false', () {
      expect(
        ConversationSyncService.resolveHaveMoreAfterPage(
          haveMoreBeforePage: false,
          pageLength: 0,
          pagesLoadedBeforeThisPage: 0,
          nextSeq: '',
        ),
        isFalse,
      );
    });
  });

  group('shouldHealHaveMoreFromNextSeq', () {
    test('heals false flag when nextSeq is real cursor', () {
      expect(
        ConversationSyncService.shouldHealHaveMoreFromNextSeq(
          haveMore: false,
          nextSeq: '862',
        ),
        isTrue,
      );
    });

    test('does not heal when already true', () {
      expect(
        ConversationSyncService.shouldHealHaveMoreFromNextSeq(
          haveMore: true,
          nextSeq: '862',
        ),
        isFalse,
      );
    });

    test('does not heal nextSeq 0 or empty', () {
      expect(
        ConversationSyncService.shouldHealHaveMoreFromNextSeq(
          haveMore: false,
          nextSeq: '0',
        ),
        isFalse,
      );
      expect(
        ConversationSyncService.shouldHealHaveMoreFromNextSeq(
          haveMore: false,
          nextSeq: '',
        ),
        isFalse,
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_feed/conversation_feed_ui.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';

void main() {
  test('same fingerprint + same themeToken → no rebuild', () {
    expect(
      conversationFeedRowSlotNeedsRebuild(
        nextFingerprint: 'fp-a',
        currentFingerprint: 'fp-a',
        nextThemeToken: DefTheme.blueTheme,
        currentThemeToken: DefTheme.blueTheme,
      ),
      isFalse,
    );
  });

  test('same fingerprint + dark/light themeToken → rebuild', () {
    expect(
      conversationFeedRowSlotNeedsRebuild(
        nextFingerprint: 'fp-a',
        currentFingerprint: 'fp-a',
        nextThemeToken: DefTheme.darkTheme,
        currentThemeToken: DefTheme.blueTheme,
      ),
      isTrue,
    );
  });

  test('fingerprint change → rebuild even if theme same', () {
    expect(
      conversationFeedRowSlotNeedsRebuild(
        nextFingerprint: 'fp-b',
        currentFingerprint: 'fp-a',
        nextThemeToken: DefTheme.darkTheme,
        currentThemeToken: DefTheme.darkTheme,
      ),
      isTrue,
    );
  });

  test('inactive tab cache reusable only when theme identity matches', () {
    expect(
      conversationFeedInactiveTabCacheReusable(
        hasCachedChild: true,
        cachedThemeToken: DefTheme.blueTheme,
        currentThemeToken: DefTheme.blueTheme,
      ),
      isTrue,
    );
    expect(
      conversationFeedInactiveTabCacheReusable(
        hasCachedChild: true,
        cachedThemeToken: DefTheme.blueTheme,
        currentThemeToken: DefTheme.darkTheme,
      ),
      isFalse,
    );
    expect(
      conversationFeedInactiveTabCacheReusable(
        hasCachedChild: false,
        cachedThemeToken: DefTheme.darkTheme,
        currentThemeToken: DefTheme.darkTheme,
      ),
      isFalse,
    );
  });

  test('active tab never reuses inactive feed cache', () {
    expect(
      shouldReuseInactiveConversationFeed(
        tabActive: true,
        hasCachedChild: true,
        cachedThemeToken: DefTheme.blueTheme,
        currentThemeToken: DefTheme.blueTheme,
        cachedContentRevision: 1,
        currentContentRevision: 1,
      ),
      isFalse,
    );
  });

  test('inactive tab reuses feed cache when reusable', () {
    expect(
      shouldReuseInactiveConversationFeed(
        tabActive: false,
        hasCachedChild: true,
        cachedThemeToken: DefTheme.blueTheme,
        currentThemeToken: DefTheme.blueTheme,
        cachedContentRevision: 1,
        currentContentRevision: 1,
      ),
      isTrue,
    );
  });

  test('inactive tab rebuilds feed when contentRevision changes', () {
    expect(
      shouldReuseInactiveConversationFeed(
        tabActive: false,
        hasCachedChild: true,
        cachedThemeToken: DefTheme.blueTheme,
        currentThemeToken: DefTheme.blueTheme,
        cachedContentRevision: 1,
        currentContentRevision: 2,
      ),
      isFalse,
    );
  });

  group('conversationFeedCanSkipVisibleMaterialization', () {
    const base = (
      useVirtual: true,
      folderFilterActive: false,
      structureRevision: 3,
      lastStructureRevision: 3,
      includeArchivedEntry: true,
      cachedIncludeArchived: true,
      includeGroupNoticeEntry: true,
      cachedIncludeGroupNotice: true,
      groupNoticePinned: false,
      cachedGroupNoticePinned: false,
      noticeSignature: 42,
      cachedGroupNoticeSignature: 42,
    );

    test('virtual + same structure + same chrome → true', () {
      expect(
        conversationFeedCanSkipVisibleMaterialization(
          useVirtual: base.useVirtual,
          folderFilterActive: base.folderFilterActive,
          structureRevision: base.structureRevision,
          lastStructureRevision: base.lastStructureRevision,
          includeArchivedEntry: base.includeArchivedEntry,
          cachedIncludeArchived: base.cachedIncludeArchived,
          includeGroupNoticeEntry: base.includeGroupNoticeEntry,
          cachedIncludeGroupNotice: base.cachedIncludeGroupNotice,
          groupNoticePinned: base.groupNoticePinned,
          cachedGroupNoticePinned: base.cachedGroupNoticePinned,
          noticeSignature: base.noticeSignature,
          cachedGroupNoticeSignature: base.cachedGroupNoticeSignature,
        ),
        isTrue,
      );
    });

    test('lastStructureRevision == -1 → false', () {
      expect(
        conversationFeedCanSkipVisibleMaterialization(
          useVirtual: true,
          folderFilterActive: false,
          structureRevision: 0,
          lastStructureRevision: -1,
          includeArchivedEntry: false,
          cachedIncludeArchived: false,
          includeGroupNoticeEntry: false,
          cachedIncludeGroupNotice: false,
          groupNoticePinned: false,
          cachedGroupNoticePinned: false,
          noticeSignature: 0,
          cachedGroupNoticeSignature: 0,
        ),
        isFalse,
      );
    });

    test('structureRevision differs → false', () {
      expect(
        conversationFeedCanSkipVisibleMaterialization(
          useVirtual: base.useVirtual,
          folderFilterActive: base.folderFilterActive,
          structureRevision: 4,
          lastStructureRevision: base.lastStructureRevision,
          includeArchivedEntry: base.includeArchivedEntry,
          cachedIncludeArchived: base.cachedIncludeArchived,
          includeGroupNoticeEntry: base.includeGroupNoticeEntry,
          cachedIncludeGroupNotice: base.cachedIncludeGroupNotice,
          groupNoticePinned: base.groupNoticePinned,
          cachedGroupNoticePinned: base.cachedGroupNoticePinned,
          noticeSignature: base.noticeSignature,
          cachedGroupNoticeSignature: base.cachedGroupNoticeSignature,
        ),
        isFalse,
      );
    });

    test('folderFilterActive true → false', () {
      expect(
        conversationFeedCanSkipVisibleMaterialization(
          useVirtual: base.useVirtual,
          folderFilterActive: true,
          structureRevision: base.structureRevision,
          lastStructureRevision: base.lastStructureRevision,
          includeArchivedEntry: base.includeArchivedEntry,
          cachedIncludeArchived: base.cachedIncludeArchived,
          includeGroupNoticeEntry: base.includeGroupNoticeEntry,
          cachedIncludeGroupNotice: base.cachedIncludeGroupNotice,
          groupNoticePinned: base.groupNoticePinned,
          cachedGroupNoticePinned: base.cachedGroupNoticePinned,
          noticeSignature: base.noticeSignature,
          cachedGroupNoticeSignature: base.cachedGroupNoticeSignature,
        ),
        isFalse,
      );
    });

    test('useVirtual false → false', () {
      expect(
        conversationFeedCanSkipVisibleMaterialization(
          useVirtual: false,
          folderFilterActive: base.folderFilterActive,
          structureRevision: base.structureRevision,
          lastStructureRevision: base.lastStructureRevision,
          includeArchivedEntry: base.includeArchivedEntry,
          cachedIncludeArchived: base.cachedIncludeArchived,
          includeGroupNoticeEntry: base.includeGroupNoticeEntry,
          cachedIncludeGroupNotice: base.cachedIncludeGroupNotice,
          groupNoticePinned: base.groupNoticePinned,
          cachedGroupNoticePinned: base.cachedGroupNoticePinned,
          noticeSignature: base.noticeSignature,
          cachedGroupNoticeSignature: base.cachedGroupNoticeSignature,
        ),
        isFalse,
      );
    });

    test('noticeSignature differs → false', () {
      expect(
        conversationFeedCanSkipVisibleMaterialization(
          useVirtual: base.useVirtual,
          folderFilterActive: base.folderFilterActive,
          structureRevision: base.structureRevision,
          lastStructureRevision: base.lastStructureRevision,
          includeArchivedEntry: base.includeArchivedEntry,
          cachedIncludeArchived: base.cachedIncludeArchived,
          includeGroupNoticeEntry: base.includeGroupNoticeEntry,
          cachedIncludeGroupNotice: base.cachedIncludeGroupNotice,
          groupNoticePinned: base.groupNoticePinned,
          cachedGroupNoticePinned: base.cachedGroupNoticePinned,
          noticeSignature: 99,
          cachedGroupNoticeSignature: base.cachedGroupNoticeSignature,
        ),
        isFalse,
      );
    });
  });

  group('conversationFeedCanSkipHydrateAfterChatReturn', () {
    test('live viewport + opened row present → true', () {
      expect(
        conversationFeedCanSkipHydrateAfterChatReturn(
          firstLiveHydrated: true,
          lastLiveHydrated: true,
          openedConversationInLiveWindow: true,
        ),
        isTrue,
      );
    });

    test('cache-only first/last must not skip', () {
      expect(
        conversationFeedCanSkipHydrateAfterChatReturn(
          firstLiveHydrated: false,
          lastLiveHydrated: false,
          openedConversationInLiveWindow: false,
        ),
        isFalse,
      );
    });

    test('viewport live but opened row missing → false', () {
      expect(
        conversationFeedCanSkipHydrateAfterChatReturn(
          firstLiveHydrated: true,
          lastLiveHydrated: true,
          openedConversationInLiveWindow: false,
        ),
        isFalse,
      );
    });
  });

  test('inactive tab cache not reusable when contentRevision changes', () {
    expect(
      conversationFeedInactiveTabCacheReusable(
        hasCachedChild: true,
        cachedThemeToken: DefTheme.blueTheme,
        currentThemeToken: DefTheme.blueTheme,
        cachedContentRevision: 1,
        currentContentRevision: 1,
      ),
      isTrue,
    );
    expect(
      conversationFeedInactiveTabCacheReusable(
        hasCachedChild: true,
        cachedThemeToken: DefTheme.blueTheme,
        currentThemeToken: DefTheme.blueTheme,
        cachedContentRevision: 1,
        currentContentRevision: 2,
      ),
      isFalse,
    );
  });

  test('dark non-pinned row bg matches page background', () {
    final page = conversationFeedPageBackground(DefTheme.darkTheme);
    final row = conversationFeedItemBackground(
      DefTheme.darkTheme,
      pinned: false,
    );
    expect(row, page);
    expect(row, DefTheme.darkTheme.weakBackgroundColor);
    expect(
      row,
      isNot(equals(DefTheme.darkTheme.conversationItemBgColor)),
    );
  });

  test('dark pinned row keeps elevated surface', () {
    final pinned = conversationFeedItemBackground(
      DefTheme.darkTheme,
      pinned: true,
    );
    expect(pinned, DefTheme.darkTheme.conversationItemPinedBgColor);
  });

  test('light non-pinned still uses conversationItemBgColor', () {
    expect(
      conversationFeedItemBackground(DefTheme.blueTheme, pinned: false),
      DefTheme.blueTheme.conversationItemBgColor,
    );
  });
}

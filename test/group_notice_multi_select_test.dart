import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_notice_selection.dart';

void main() {
  group('group_notice_selection', () {
    test('sentinel id is stable and detectable', () {
      expect(kGroupNoticeSelectionId, '__group_notice_entry__');
      expect(isGroupNoticeSelectionId(kGroupNoticeSelectionId), isTrue);
      expect(isGroupNoticeSelectionId('group_abc'), isFalse);
      expect(isGroupNoticeSelectionId('c2c_1'), isFalse);
    });

    test('selectionIdsWithoutGroupNotice strips sentinel', () {
      expect(
        selectionIdsWithoutGroupNotice({
          'group_a',
          kGroupNoticeSelectionId,
          'group_b',
        }),
        {'group_a', 'group_b'},
      );
    });

    test('selectAllIds includes notice when visible', () {
      expect(
        selectAllIds(
          visibleConvIds: const ['group_a', 'group_b'],
          noticeVisible: true,
        ),
        {'group_a', 'group_b', kGroupNoticeSelectionId},
      );
      expect(
        selectAllIds(
          visibleConvIds: const ['group_a'],
          noticeVisible: false,
        ),
        {'group_a'},
      );
    });

    test('isAllSelectedWithGroupNotice requires notice when visible', () {
      expect(
        isAllSelectedWithGroupNotice(
          visibleConvIds: const ['group_a'],
          selected: {'group_a'},
          noticeVisible: true,
        ),
        isFalse,
      );
      expect(
        isAllSelectedWithGroupNotice(
          visibleConvIds: const ['group_a'],
          selected: {'group_a', kGroupNoticeSelectionId},
          noticeVisible: true,
        ),
        isTrue,
      );
    });

    test('isAllSelectedWithGroupNotice rejects leftover sentinel when hidden',
        () {
      expect(
        isAllSelectedWithGroupNotice(
          visibleConvIds: const ['group_a'],
          selected: {'group_a', kGroupNoticeSelectionId},
          noticeVisible: false,
        ),
        isFalse,
      );
      expect(
        isAllSelectedWithGroupNotice(
          visibleConvIds: const ['group_a'],
          selected: {'group_a'},
          noticeVisible: false,
        ),
        isTrue,
      );
    });

    test('empty visible without notice is not all-selected', () {
      expect(
        isAllSelectedWithGroupNotice(
          visibleConvIds: const [],
          selected: <String>{},
          noticeVisible: false,
        ),
        isFalse,
      );
      expect(
        isAllSelectedWithGroupNotice(
          visibleConvIds: const [],
          selected: {kGroupNoticeSelectionId},
          noticeVisible: true,
        ),
        isTrue,
      );
    });
  });
}

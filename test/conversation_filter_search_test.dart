import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';

void main() {
  test('dateSearchTimeRange maps a calendar day to an exact SDK window', () {
    final range = dateSearchTimeRange(DateTime(2026, 8, 22));
    final restored = timestampRangeFromSearchParams(
      searchTimePosition: range.searchTimePosition,
      searchTimePeriod: range.searchTimePeriod,
    );

    final start = DateTime(2026, 8, 22);
    final end = DateTime(2026, 8, 22, 23, 59, 59);
    expect(restored.startTs, start.millisecondsSinceEpoch ~/ 1000);
    expect(restored.endTs, end.millisecondsSinceEpoch ~/ 1000);
    expect(range.searchTimePeriod, restored.endTs - restored.startTs);
    expect(range.searchTimePeriod, lessThan(86400));
  });

  test('conversation filter prefers cloud, then local and history scan', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/'
      'view_models/tui_search_view_model.dart',
    ).readAsStringSync();

    expect(source, contains('searchConversationWithFilter'));
    expect(source, contains('_searchConversationFilterViaLocalMessages'));
    expect(source, contains('_searchConversationFilterViaCloudMessages'));
    expect(source, contains('_searchConversationFilterViaHistoryScan'));
    expect(source, contains('_conversationFilterPreferHistoryScan'));
    expect(source, contains('_conversationFilterSearchPageIndex'));

    final filterFn =
        source.indexOf('Future<void> searchConversationWithFilter(');
    final localFn = source.indexOf(
      'Future<bool> _searchConversationFilterViaLocalMessages(',
    );
    final cloudFn = source.indexOf(
      'Future<bool> _searchConversationFilterViaCloudMessages(',
    );
    final scanFn = source.indexOf(
      'Future<void> _searchConversationFilterViaHistoryScan(',
    );
    expect(filterFn, greaterThanOrEqualTo(0));
    expect(cloudFn, greaterThan(filterFn));
    expect(localFn, greaterThan(filterFn));
    expect(scanFn, greaterThan(localFn));

    final localBody = source.substring(localFn, scanFn);
    expect(localBody, contains('searchLocalMessages'));
    expect(localBody, contains('userIDList: senderList'));
    expect(localBody, contains('searchTimePosition:'));
    expect(localBody, contains('searchTimePeriod:'));
    expect(localBody, contains('keywordList: const <String>[]'));
    expect(localBody, contains('_conversationFilterSearchMessageTypes'));

    final entryBody = source.substring(filterFn, localFn);
    expect(entryBody, contains('_searchConversationFilterViaCloudMessages'));
    expect(entryBody, contains('_searchConversationFilterViaLocalMessages'));
    expect(entryBody, contains('_searchConversationFilterViaHistoryScan'));
    expect(entryBody, contains('_conversationFilterPreferHistoryScan = true'));

    final cloudBody = source.substring(cloudFn, localFn);
    expect(cloudBody, contains('searchCloudMessages'));
    expect(cloudBody, contains('searchCursor: _conversationFilterCloudCursor'));
    expect(cloudBody, contains('userIDList: senderList'));
    expect(cloudBody, contains('searchTimePosition:'));
    expect(cloudBody, contains('searchTimePeriod:'));
  });

  test('media and file filters use cloud cursor with local fallback', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/'
      'view_models/tui_search_view_model.dart',
    ).readAsStringSync();

    final keywordStart = source.indexOf(
      'Future<void> loadMediaAndFileForConversation(',
    );
    final assetStart = source.indexOf(
      'Future<void> loadConversationAssets(',
    );
    final searchStart = source.indexOf('void searchFriendByKey(');
    expect(keywordStart, greaterThanOrEqualTo(0));
    expect(assetStart, greaterThan(keywordStart));
    expect(searchStart, greaterThan(assetStart));

    final keywordBody = source.substring(keywordStart, assetStart);
    expect(keywordBody, contains('searchCloudMessages'));
    expect(keywordBody, contains('searchCursor: _mediaFileCloudCursor'));
    expect(keywordBody, contains('V2TIM_ELEM_TYPE_FILE'));
    expect(keywordBody, contains('_loadConversationHistoryBatch'));

    final assetBody = source.substring(assetStart, searchStart);
    expect(assetBody, contains('searchCloudMessages'));
    expect(assetBody, contains('searchCursor: _conversationAssetCloudCursor'));
    expect(assetBody, contains('_conversationAssetSearchMessageTypes'));
    expect(assetBody, contains('_loadConversationHistoryBatch'));
  });

  test('chat history date search uses Cupertino sheet like live schedule', () {
    final sheet = File(
      'lib/src/ui/widgets/app_cupertino_datetime_sheet.dart',
    ).readAsStringSync();
    expect(sheet, contains('showAppCupertinoDateTimeSheet'));
    expect(sheet, contains('showChatHistoryDatePicker'));
    expect(sheet, contains('CupertinoDatePickerMode.date'));
    expect(sheet, contains('showAdaptiveModalSheet'));

    final live = File(
      'lib/src/pages/group_live/group_live_online_live_scaffold.dart',
    ).readAsStringSync();
    expect(live, contains('showAppCupertinoDateTimeSheet'));
    expect(live, contains('CupertinoDatePickerMode.dateAndTime'));

    final search = File('lib/src/search.dart').readAsStringSync();
    expect(search, contains('pickSearchDate: showChatHistoryDatePicker'));
    expect(
      search,
      contains('messageAbstractBuilder: buildReplyAbstractMessage'),
    );

    final detail = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitSearch/'
      'tim_uikit_search_msg_detail.dart',
    ).readAsStringSync();
    expect(detail, contains('pickSearchDate'));
    expect(detail, contains('customPick(context)'));
    expect(detail, contains('messageAbstractBuilder'));
    expect(
      detail,
      contains('messageAbstractBuilder: widget.messageAbstractBuilder'),
    );

    final filter = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitSearch/'
      'tim_uikit_conversation_filter_msg_page.dart',
    ).readAsStringSync();
    expect(
      filter,
      contains('widget.messageAbstractBuilder?.call(message)'),
    );
  });
}

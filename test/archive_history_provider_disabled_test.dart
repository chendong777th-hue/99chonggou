import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/archive_history_provider.dart';

void main() {
  test('older archive fetch is disabled at the provider boundary', () async {
    var fetcherCalled = false;
    ArchiveHistoryProvider.register((request) async {
      fetcherCalled = true;
      return ArchiveHistoryResult.empty;
    });

    expect(ArchiveHistoryProvider.isAvailable, isFalse);
    final result = await ArchiveHistoryProvider.fetchOlder(
      const ArchiveHistoryRequest(
        isGroup: false,
        conversationID: 'peer-disabled-archive',
        count: 40,
      ),
    );

    expect(result.messages, isEmpty);
    expect(result.hasMore, isFalse);
    expect(fetcherCalled, isFalse);
    ArchiveHistoryProvider.register(null);
  });
}

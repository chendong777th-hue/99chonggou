import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('media and file page keeps spinner across chained empty pages', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/'
      'TIMUIKitSearch/tim_uikit_conversation_media_file_page.dart',
    ).readAsStringSync();

    expect(source.contains('bool _isFillingCurrentTab = true;'), isTrue);
    expect(
      source.contains(
        '_model.conversationAssetLoading || _isFillingCurrentTab',
      ),
      isTrue,
    );
    expect(source.contains('if (loadingMore)'), isTrue);
    expect(source.contains('cacheExtent: 640'), isTrue);
    expect(source.contains('RepaintBoundary('), isTrue);
    expect(source.contains('String _assetUiSignature()'), isTrue);
    expect(source.contains("TIM_t('暂无数据')"), isTrue);
  });

  test('chat opens media page before starting its history load', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/'
      'TIMUIKitSearch/conversation_media_navigation.dart',
    ).readAsStringSync();

    expect(
        source.contains('await serviceLocator<TUISearchViewModel>()'), isFalse);
    expect(source.contains('await pushConversationMediaFilePage('), isTrue);
  });
}

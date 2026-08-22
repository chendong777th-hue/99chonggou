import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Moments feed thumbnails enforce bounded decode sizes', () {
    final source = File(
      'lib/src/pages/moments/moments_media_thumbnail.dart',
    ).readAsStringSync();
    expect(source, contains('memCacheWidth: cacheSize'));
    expect(source, contains('maxWidthDiskCache: cacheSize'));
    expect(source, contains('cacheWidth: cacheSize'));
    expect(source, contains('max: 1080'));
  });

  test('call timer refresh is isolated from the full call page', () {
    final source = File(
      'lib/src/pages/livekit_call_page.dart',
    ).readAsStringSync();
    expect(source, contains('_durationTick.value++'));
    expect(source, contains('ValueListenableBuilder<int>'));
  });

  test('folder selection hydrates its complete local id set', () {
    final source = File('lib/src/conversation.dart').readAsStringSync();
    expect(source, contains("caller: 'folder_full_index'"));
    expect(source, contains('folder.conversationIds.toList'));
    expect(source, contains('_folderHydratedConversations'));
  });

  test('home startup work is coalesced onto the idle scheduler', () {
    final source = File('lib/src/pages/home_page.dart').readAsStringSync();
    expect(source, contains("'home_post_startup'"));
    expect(source, contains('_loginUserInfoTask'));
  });
}

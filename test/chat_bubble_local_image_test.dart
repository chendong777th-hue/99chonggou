import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_bubble_local_image.dart';

void main() {
  group('resolveChatBubbleLocalImageChoice', () {
    test('prefers type=1 thumb over large and original', () {
      final choice = resolveChatBubbleLocalImageChoice(
        largeLocalUrl: '/tmp/large.jpg',
        originalLocalUrl: '/tmp/origin.jpg',
        thumbLocalUrl: '/tmp/thumb.jpg',
        fileExists: (_) => true,
      );
      expect(choice?.path, '/tmp/thumb.jpg');
      expect(choice?.isThumbFallback, isTrue);
    });

    test('uses original when type=2 file is missing and thumb missing', () {
      final choice = resolveChatBubbleLocalImageChoice(
        largeLocalUrl: '/tmp/missing-large.jpg',
        originalLocalUrl: '/tmp/origin.jpg',
        thumbLocalUrl: '/tmp/missing-thumb.jpg',
        fileExists: (path) => path == '/tmp/origin.jpg',
      );
      expect(choice?.path, '/tmp/origin.jpg');
      expect(choice?.isThumbFallback, isFalse);
    });

    test('uses archive cache when thumb is missing', () {
      final choice = resolveChatBubbleLocalImageChoice(
        thumbLocalUrl: '/tmp/missing-thumb.jpg',
        archiveCachePath: '/tmp/archive.jpg',
        fileExists: (path) => path == '/tmp/archive.jpg',
      );
      expect(choice?.path, '/tmp/archive.jpg');
      expect(choice?.isThumbFallback, isFalse);
    });

    test('uses thumb when it is the only existing file', () {
      final choice = resolveChatBubbleLocalImageChoice(
        largeLocalUrl: '/tmp/missing.jpg',
        thumbLocalUrl: '/tmp/thumb.jpg',
        fileExists: (path) => path == '/tmp/thumb.jpg',
      );
      expect(choice?.path, '/tmp/thumb.jpg');
      expect(choice?.isThumbFallback, isTrue);
    });

    test('skips thumb when allowThumbFallback is false', () {
      final choice = resolveChatBubbleLocalImageChoice(
        thumbLocalUrl: '/tmp/thumb.jpg',
        fileExists: (_) => true,
        allowThumbFallback: false,
      );
      expect(choice, isNull);
    });
  });

  group('planChatBubbleDisplay', () {
    test('HTTP + local type=2 uses local large, not network', () {
      const local = ChatBubbleLocalImageChoice(
        path: '/tmp/large.jpg',
        isThumbFallback: false,
      );
      final plan = planChatBubbleDisplay(
        hasNetworkUrl: true,
        local: local,
      );
      expect(plan.source, ChatBubbleDisplaySource.localLarge);
      expect(plan.useNetwork, isFalse);
      expect(plan.localPath, '/tmp/large.jpg');
    });

    test('HTTP + local thumb uses local thumb immediately', () {
      const local = ChatBubbleLocalImageChoice(
        path: '/tmp/thumb.jpg',
        isThumbFallback: true,
      );
      final plan = planChatBubbleDisplay(
        hasNetworkUrl: true,
        local: local,
      );
      expect(plan.source, ChatBubbleDisplaySource.localThumb);
      expect(plan.useNetwork, isFalse);
      expect(plan.localPath, '/tmp/thumb.jpg');
    });

    test('HTTP without local uses network', () {
      final plan = planChatBubbleDisplay(
        hasNetworkUrl: true,
      );
      expect(plan.source, ChatBubbleDisplaySource.network);
      expect(plan.useNetwork, isTrue);
      expect(plan.localPath, isNull);
    });

    test('keeps network when frame already ready even if local thumb exists',
        () {
      const local = ChatBubbleLocalImageChoice(
        path: '/tmp/thumb.jpg',
        isThumbFallback: true,
      );
      final plan = planChatBubbleDisplay(
        hasNetworkUrl: true,
        local: local,
        keepNetworkAfterFrameReady: true,
      );
      expect(plan.source, ChatBubbleDisplaySource.network);
      expect(plan.useNetwork, isTrue);
      expect(plan.localPath, '/tmp/thumb.jpg');
    });

    test('offline thumb-only uses local thumb', () {
      const local = ChatBubbleLocalImageChoice(
        path: '/tmp/thumb.jpg',
        isThumbFallback: true,
      );
      final plan = planChatBubbleDisplay(
        hasNetworkUrl: false,
        local: local,
      );
      expect(plan.source, ChatBubbleDisplaySource.localThumb);
      expect(plan.useNetwork, isFalse);
    });
  });

  group('resolveChatBubbleImagePersistAction', () {
    test('normal received image with HTTP still downloads SDK thumb', () {
      final action = resolveChatBubbleImagePersistAction(
        isSelf: false,
        isArchive: false,
        hasUsableHttpUrl: true,
        hasBubbleLocalFile: false,
      );
      expect(action, ChatBubbleImagePersistAction.sdkDownloadThumb);
      expect(shouldCallSdkImageDownload(action: action), isTrue);
    });

    test('skips SDK download when bubble local file already exists', () {
      final action = resolveChatBubbleImagePersistAction(
        isSelf: false,
        isArchive: false,
        hasUsableHttpUrl: true,
        hasBubbleLocalFile: true,
      );
      expect(action, ChatBubbleImagePersistAction.none);
      expect(shouldCallSdkImageDownload(action: action), isFalse);
    });

    test('archive with HTTP persists file and never calls SDK download', () {
      final action = resolveChatBubbleImagePersistAction(
        isSelf: false,
        isArchive: true,
        hasUsableHttpUrl: true,
        hasBubbleLocalFile: false,
      );
      expect(action, ChatBubbleImagePersistAction.httpPersistArchive);
      expect(shouldCallSdkImageDownload(action: action), isFalse);
    });

    test('self-sent images do not auto persist', () {
      final action = resolveChatBubbleImagePersistAction(
        isSelf: true,
        isArchive: false,
        hasUsableHttpUrl: true,
        hasBubbleLocalFile: false,
      );
      expect(action, ChatBubbleImagePersistAction.none);
    });
  });

  group('ChatBubbleArchiveImageStore', () {
    setUp(ChatBubbleArchiveImageStore.resetForTest);
    tearDown(ChatBubbleArchiveImageStore.resetForTest);

    test('sanitizes msgID for filename', () {
      expect(
        ChatBubbleArchiveImageStore.fileNameForMsgId('@TGS#abc:12'),
        '_TGS_abc_12',
      );
      expect(
        ChatBubbleArchiveImageStore.fileNameForMsgId('  '),
        'unknown',
      );
    });

    test('persistHttpToFile writes bytes once and reuses the file', () async {
      final dir = await Directory.systemTemp.createTemp('bubble_archive_');
      addTearDown(() => dir.delete(recursive: true));
      var loads = 0;
      Future<List<int>> load(String url) async {
        loads += 1;
        expect(url, 'https://example.com/a.jpg');
        return <int>[1, 2, 3, 4];
      }

      final first = await ChatBubbleArchiveImageStore.persistHttpToFile(
        directory: dir,
        msgID: 'msg-1',
        url: 'https://example.com/a.jpg',
        loadBytes: load,
      );
      final second = await ChatBubbleArchiveImageStore.persistHttpToFile(
        directory: dir,
        msgID: 'msg-1',
        url: 'https://example.com/a.jpg',
        loadBytes: load,
      );

      expect(first, isNotNull);
      expect(second, first);
      expect(loads, 1);
      expect(File(first!).readAsBytesSync(), <int>[1, 2, 3, 4]);
    });
  });
}

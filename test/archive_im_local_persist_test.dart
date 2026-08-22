import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/archive_im_local_persist_service.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/archive_history_provider.dart';

void main() {
  group('ArchiveImLocalPersistService.looksLikeArchiveMsgKey', () {
    test('seq_random_ts is archive key', () {
      expect(
        ArchiveImLocalPersistService.looksLikeArchiveMsgKey('12_345_1785000000'),
        isTrue,
      );
    });

    test('empty is treated as invalid', () {
      expect(ArchiveImLocalPersistService.looksLikeArchiveMsgKey(''), isTrue);
      expect(ArchiveImLocalPersistService.looksLikeArchiveMsgKey(null), isTrue);
    });

    test('uuid-like cloud id is not archive key', () {
      expect(
        ArchiveImLocalPersistService.looksLikeArchiveMsgKey(
          '144115213910123456-1234567890',
        ),
        isFalse,
      );
    });
  });

  group('ArchiveImLocalPersistService.isTrustedCloudMsgId', () {
    test('tencent cloud id trusted', () {
      expect(
        ArchiveImLocalPersistService.isTrustedCloudMsgId(
          '144115268026882536-1784319908-1876410780',
        ),
        isTrue,
      );
    });

    test('msgKey and group archive key rejected', () {
      expect(
        ArchiveImLocalPersistService.isTrustedCloudMsgId(
          '3358721060_1876410779_1784319889',
        ),
        isFalse,
      );
      expect(
        ArchiveImLocalPersistService.isTrustedCloudMsgId('@TGS#abc:12'),
        isFalse,
      );
    });
  });

  group('ArchiveImLocalPersistService.isArchiveSynthesizedInsertAllowed', () {
    test('archive body never insertable even with trusted msgId', () {
      expect(
        ArchiveImLocalPersistService.isArchiveSynthesizedInsertAllowed(
          hasTrustedCloudMsgId: true,
        ),
        isFalse,
      );
      expect(
        ArchiveImLocalPersistService.isArchiveSynthesizedInsertAllowed(
          hasTrustedCloudMsgId: false,
        ),
        isFalse,
      );
    });
  });

  group('ArchiveImLocalPersistService.isSpuriousArchiveLocalImported', () {
    test('LOCAL_IMPORTED user-style id is spurious', () {
      expect(
        ArchiveImLocalPersistService.isSpuriousArchiveLocalImportedFields(
          status: 5,
          msgID: 'q14gkm5swv-1785813840-14214776',
        ),
        isTrue,
      );
    });

    test('cloud id and send_succ are not spurious', () {
      expect(
        ArchiveImLocalPersistService.isSpuriousArchiveLocalImportedFields(
          status: 5,
          msgID: '144115268026882536-1784319908-1876410780',
        ),
        isFalse,
      );
      expect(
        ArchiveImLocalPersistService.isSpuriousArchiveLocalImportedFields(
          status: 2,
          msgID: 'q14gkm5swv-1785813840-14214776',
        ),
        isFalse,
      );
    });
  });

  group('ArchiveHistoryRequest ranges', () {
    test('hasSeqRange / hasTimeRange', () {
      expect(
        const ArchiveHistoryRequest(
          isGroup: true,
          conversationID: 'g',
          count: 10,
          fromSeq: 11,
          toSeq: 14,
        ).hasSeqRange,
        isTrue,
      );
      expect(
        const ArchiveHistoryRequest(
          isGroup: false,
          conversationID: 'u',
          count: 10,
          fromTimeMs: 1000,
          toTimeMs: 2000,
        ).hasTimeRange,
        isTrue,
      );
      expect(
        const ArchiveHistoryRequest(
          isGroup: false,
          conversationID: 'u',
          count: 10,
          fromTimeMs: 2000,
          toTimeMs: 1000,
        ).hasTimeRange,
        isFalse,
      );
    });
  });
}

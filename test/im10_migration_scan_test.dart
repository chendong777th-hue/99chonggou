// IM-10 phase A: 静态门禁测试
//
// 守住 docs/im10_overlay_row_namespace.md §3.1 的临时白名单必须真实指向
// `setMessageList` 调用行。如果有人错误移除了白名单条目而没有收口代码,
// 这个测试会失败。
//
// IM-10 phase B..G 每收口一个,必须同时:
//   1. 改源码走 commitMessageDelta (移除 setMessageList 直调)
//   2. 把对应条目从 ADR §3.1 表格移除
//
// IM-10 phase J 期望白名单为空 (ADR 表格清零 + 此测试 assert 0)。

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

const List<String> _allowList = <String>[
  'lib/src/chat.dart:8070',
  'lib/src/chat.dart:8439',
  'lib/src/chat.dart:9885',
  'lib/src/services/archive_im_local_persist_service.dart:344',
  'lib/src/services/archive_im_local_persist_service.dart:766',
  'lib/src/services/group_local/group_tips_operator_patch_service.dart:207',
  'lib/src/services/group_local/group_tips_operator_patch_service.dart:255',
  'lib/src/services/silent_archive_service.dart:235',
  'lib/src/utils/call_bubble_dedupe.dart:283',
];

void main() {
  group('IM-10 allow list points at real setMessageList calls', () {
    test('every allow-list line has a setMessageList(...) call', () async {
      for (final entry in _allowList) {
        final sep = entry.lastIndexOf(':');
        final relPath = entry.substring(0, sep);
        final lineNo = int.parse(entry.substring(sep + 1));
        final absolute = File('${Directory.current.path}/$relPath');
        expect(
          absolute.existsSync(),
          isTrue,
          reason: '$entry source file missing',
        );
        final lines = absolute.readAsLinesSync();
        expect(
          lineNo - 1 < lines.length,
          isTrue,
          reason: '$entry line out of range (file has ${lines.length} lines)',
        );
        final actual = lines[lineNo - 1];
        expect(
          actual,
          contains('setMessageList('),
          reason: '$entry expected to be a setMessageList call, '
              'got: ${actual.trim()}',
        );
      }
    });

    test(
        'ADR mentions every allow-list entry '
        '(drift detector)', () async {
      final adr = File('${Directory.current.path}/docs/im10_overlay_row_namespace.md')
          .readAsStringSync();
      final tableRe = RegExp(r'lib/src/[^\s`]+\.dart:\d+');
      final tableEntries = tableRe
          .allMatches(adr)
          .map((m) => m.group(0)!.trim())
          .toSet();
      final testEntries = _allowList.toSet();
      final missingFromAdr = testEntries.difference(tableEntries);
      expect(
        missingFromAdr,
        isEmpty,
        reason: 'ADR must list every allow-list entry; missing: '
            '$missingFromAdr',
      );
    });

    test(
        'rg scan is a superset of the allow-list (no setMessageList '
        'added without ADR entry)', () async {
      final result = await Process.run(
        'rg',
        <String>[
          '-n',
          '--glob', 'lib/src/**/*.dart',
          'setMessageList\\s*\\(',
          'lib/src',
        ],
      );
      expect(
        result.exitCode,
        anyOf(0, 1),
        reason: 'rg must succeed (or 1=NoMatch): '
            '${result.stderr.toString().trim()}',
      );
      final hits = (result.stdout.toString().trim().isEmpty)
          ? <String>[]
          : result.stdout.toString().trim().split('\n');
      final rgKeys = hits
          .map((h) {
            final p = h.split(':');
            if (p.length < 3) return null;
            return '${p[0].replaceAll(r'\', '/')}:${p[1]}';
          })
          .whereType<String>()
          .toSet();
      final notInList = rgKeys.difference(_allowList.toSet());
      expect(
        notInList,
        isEmpty,
        reason: 'rg hit setMessageList outside allow-list: $notInList '
            '(add to ADR §3.1 OR converge to commitMessageDelta)',
      );
    });
  });
}

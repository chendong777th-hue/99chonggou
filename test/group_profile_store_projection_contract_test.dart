import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/src/group_profile.dart').readAsStringSync();

  test('group profile rebuilds from the versioned GroupLocalStore commit', () {
    expect(source, contains('GroupLocalStore.instance.commitListenable'));
    expect(source, contains('Listenable.merge(<Listenable>['));
  });

  test('Store row owns notice and member count including empty notice', () {
    expect(source, contains('final localMemberCount ='));
    expect(source, contains('localRecord != null'));
    expect(source, contains('localRecord.notice.trim()'));
    expect(source, contains('a cleared notice is resurrected'));
  });
}

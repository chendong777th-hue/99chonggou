import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chat header does not refresh member count from realtime events', () {
    final source = File('lib/src/chat.dart').readAsStringSync();

    expect(source, isNot(contains('_loadGroupMemberCount(force: true)')));
    expect(source, contains('GroupLocalStore.instance.commitListenable'));
  });

  test('membership list sync does not write group metadata memberCount', () {
    final source = File(
      'lib/src/services/group_local/group_membership_sync_service.dart',
    ).readAsStringSync();
    final incremental = File(
      'lib/src/services/group_local/group_member_incremental_sync_service.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('patchMemberCountForSync')));
    expect(source, isNot(contains('memberCount: page.total')));
    expect(source, isNot(contains('incrementIfMissing')));
    expect(incremental, isNot(contains('patchMemberCountForSync')));
  });

  test('realtime membership changes trigger the metadata coordinator', () {
    final source = File(
      'lib/src/services/group_local/group_sync_service.dart',
    ).readAsStringSync();

    expect(
      source,
      contains(RegExp(
        r'GroupMetadataRefreshCoordinator\.instance\s*\.refresh',
      )),
    );
    expect(source, contains('force: true'));
  });

  test('entity history treats payloads as invalidations only', () {
    final source = File(
      'lib/src/services/group_local/group_entity_incremental_sync_service.dart',
    ).readAsStringSync();

    expect(source, contains('changedGroups'));
    expect(source, contains('GroupMetadataRefreshCoordinator.instance'));
    expect(source, isNot(contains('applyOptimisticGroupName')));
    expect(source, isNot(contains('applyOptimisticNotice')));
    expect(source, isNot(contains('upsertGroupAvatar')));
  });
}

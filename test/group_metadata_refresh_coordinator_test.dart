import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/models/me_group_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_metadata_refresh_coordinator.dart';

MeGroupRecord _record({String name = 'remote', int count = 8}) => MeGroupRecord(
      groupId: 'group-1',
      groupType: 'Work',
      groupName: name,
      displayAlias: '',
      avatarUrl: 'avatar',
      notice: 'notice',
      memberCount: count,
      myRole: 0,
      myNameCard: '',
      joinedAt: 0,
      updatedAt: 0,
    );

void main() {
  test('concurrent refreshes share one remote request', () async {
    var remoteCalls = 0;
    final gate = Completer<void>();
    final coordinator = GroupMetadataRefreshCoordinator(
      readLocal: (_) async => _record(),
      refreshRemote: (_) async {
        remoteCalls++;
        await gate.future;
      },
    );

    final first = coordinator.refresh('group-1');
    final second = coordinator.refresh('group-1');
    gate.complete();
    final snapshots = await Future.wait([first, second]);

    expect(remoteCalls, 1);
    expect(identical(snapshots[0], snapshots[1]), isTrue);
  });

  test('forced refresh is not swallowed by throttled local read', () async {
    var remoteCalls = 0;
    var localReads = 0;
    final localReadGate = Completer<void>();
    final coordinator = GroupMetadataRefreshCoordinator(
      readLocal: (_) async {
        localReads++;
        if (localReads == 2) {
          await localReadGate.future;
        }
        return _record();
      },
      refreshRemote: (_) async {
        remoteCalls++;
      },
      throttle: const Duration(hours: 1),
    );

    await coordinator.refresh('group-1');
    final throttledRead = coordinator.refresh('group-1');
    final forcedRefresh = coordinator.refresh('group-1', force: true);
    localReadGate.complete();

    await Future.wait([throttledRead, forcedRefresh]);
    expect(remoteCalls, 2);
  });

  test('invalidated generation rejects stale response', () async {
    final gate = Completer<void>();
    final coordinator = GroupMetadataRefreshCoordinator(
      readLocal: (_) async => _record(),
      refreshRemote: (_) => gate.future,
    );
    final pending = coordinator.refresh('group-1');
    coordinator.invalidate('group-1');
    gate.complete();
    expect(await pending, isNull);
  });

  test('local placeholder cannot claim remote source', () async {
    final coordinator = GroupMetadataRefreshCoordinator(
      readLocal: (_) async => _record(name: 'cached', count: 3),
      refreshRemote: (_) async {},
      readStoreVersion: () => 42,
    );
    final snapshot = await coordinator.readLocalPlaceholder('group-1');
    expect(snapshot?.source, GroupMetadataSource.localPlaceholder);
    expect(snapshot?.name, 'cached');
    expect(snapshot?.memberCount, 3);
    expect(snapshot?.generation, 42);
  });
}

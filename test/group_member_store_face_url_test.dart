import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/group_member_store.dart';

void main() {
  tearDown(() {
    GroupMemberStore.instance.clear(notify: false);
  });

  test('putFaceUrlForUser updates existing member and bumps avatar revision',
      () {
    final store = GroupMemberStore.instance;
    store.putMember(
      'g1',
      V2TimGroupMemberFullInfo(
        userID: 'u1',
        faceUrl: 'https://cdn.example/old.png',
      ),
      notify: false,
    );
    final listenable = store.avatarListenable('g1', 'u1');
    final before = listenable.value;

    store.putFaceUrlForUser('u1', 'https://cdn.example/new.png');

    expect(store.memberOf('g1', 'u1')?.faceUrl, 'https://cdn.example/new.png');
    expect(listenable.value, before + 1);
  });

  test('putFaceUrlForUser no-ops on empty face or identical url', () {
    final store = GroupMemberStore.instance;
    store.putMember(
      'g1',
      V2TimGroupMemberFullInfo(
        userID: 'u1',
        faceUrl: 'https://cdn.example/a.png',
      ),
      notify: false,
    );
    final listenable = store.avatarListenable('g1', 'u1');
    final before = listenable.value;

    store.putFaceUrlForUser('u1', '   ');
    store.putFaceUrlForUser('u1', 'https://cdn.example/a.png');

    expect(store.memberOf('g1', 'u1')?.faceUrl, 'https://cdn.example/a.png');
    expect(listenable.value, before);
  });

  test('putFaceUrlForUser does not invent members in other groups', () {
    final store = GroupMemberStore.instance;
    store.putMember(
      'g1',
      V2TimGroupMemberFullInfo(
        userID: 'u1',
        faceUrl: 'https://cdn.example/old.png',
      ),
      notify: false,
    );

    store.putFaceUrlForUser('u2', 'https://cdn.example/new.png');

    expect(store.memberOf('g1', 'u2'), isNull);
    expect(store.memberOf('g2', 'u2'), isNull);
    expect(store.memberOf('g1', 'u1')?.faceUrl, 'https://cdn.example/old.png');
  });

  test('fresh profile survives a later stale group member snapshot', () {
    final store = GroupMemberStore.instance;
    store.putMember(
      'g1',
      V2TimGroupMemberFullInfo(
        userID: 'u1',
        nickName: '旧昵称',
        faceUrl: 'https://cdn.example/old.png',
      ),
      notify: false,
    );

    store.putProfileForUser(
      userID: 'u1',
      nickName: '新昵称',
      faceUrl: 'https://cdn.example/new.png',
      notify: false,
    );
    store.putMember(
      'g1',
      V2TimGroupMemberFullInfo(
        userID: 'u1',
        nickName: '旧昵称',
        faceUrl: 'https://cdn.example/old.png',
      ),
      notify: false,
    );

    expect(store.memberOf('g1', 'u1')?.nickName, '新昵称');
    expect(store.memberOf('g1', 'u1')?.faceUrl, 'https://cdn.example/new.png');
  });

  test('putMember notify coalesces into one listener tick', () async {
    final store = GroupMemberStore.instance;
    var ticks = 0;
    void listener() => ticks++;
    store.addListener(listener);
    addTearDown(() => store.removeListener(listener));
    store.putMember(
      'g1',
      V2TimGroupMemberFullInfo(userID: 'u1', nickName: 'a'),
    );
    store.putMember(
      'g1',
      V2TimGroupMemberFullInfo(userID: 'u2', nickName: 'b'),
    );
    store.putMember(
      'g1',
      V2TimGroupMemberFullInfo(userID: 'u3', nickName: 'c'),
    );
    expect(ticks, 0);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(ticks, 1);
    expect(store.membersForGroup('g1'), hasLength(3));
  });
}

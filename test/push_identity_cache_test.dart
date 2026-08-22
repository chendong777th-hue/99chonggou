import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/push_identity_cache.dart';

void main() {
  test('mergeGroupPushIdentity prefers local group name over stale conversation',
      () {
    final merged = PushIdentityCache.mergeGroupPushIdentity(
      conversationShowName: '旧群名',
      conversationFaceUrl: 'https://example.com/old.png',
      localGroupName: '新群名',
      localGroupAvatarUrl: 'https://example.com/new.png',
      groupId: 'g1',
    );
    expect(merged.showName, '新群名');
    expect(merged.faceUrl, contains('new.png'));
  });

  test('mergeGroupPushIdentity fills from conversation when local empty', () {
    final merged = PushIdentityCache.mergeGroupPushIdentity(
      conversationShowName: '会话群名',
      conversationFaceUrl: 'https://example.com/conv.png',
      localGroupName: '',
      localGroupAvatarUrl: '',
      groupId: 'g1',
    );
    expect(merged.showName, '会话群名');
    expect(merged.faceUrl, contains('conv.png'));
  });

  test('mergeGroupPushIdentity keeps local name when only conversation has face',
      () {
    final merged = PushIdentityCache.mergeGroupPushIdentity(
      conversationShowName: '旧群名',
      conversationFaceUrl: 'https://example.com/old.png',
      localGroupName: '新群名',
      localGroupAvatarUrl: '',
      groupId: 'g1',
    );
    expect(merged.showName, '新群名');
    expect(merged.faceUrl, contains('old.png'));
  });
}

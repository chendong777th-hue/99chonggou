import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';

void main() {
  test('preferLiveProfile picks live local over stale conversation snapshot',
      () {
    final picked = UserAvatarHelper.resolvePeerFaceUrlFromCandidates(
      preferLiveProfile: true,
      liveProfile: 'https://cdn.example/live.png',
      conversationOrMessage: 'https://cdn.example/stale.png',
      groupMember: 'https://cdn.example/group.png',
    );
    expect(picked, 'https://cdn.example/live.png');
  });

  test('default path still prefers conversation snapshot over live', () {
    final picked = UserAvatarHelper.resolvePeerFaceUrlFromCandidates(
      preferLiveProfile: false,
      liveProfile: 'https://cdn.example/live.png',
      conversationOrMessage: 'https://cdn.example/stale.png',
      groupMember: 'https://cdn.example/group.png',
    );
    expect(picked, 'https://cdn.example/stale.png');
  });

  test('preferLiveProfile falls back to snapshot when live empty', () {
    final picked = UserAvatarHelper.resolvePeerFaceUrlFromCandidates(
      preferLiveProfile: true,
      liveProfile: '',
      conversationOrMessage: 'https://cdn.example/stale.png',
      groupMember: 'https://cdn.example/group.png',
    );
    expect(picked, 'https://cdn.example/stale.png');
  });
}

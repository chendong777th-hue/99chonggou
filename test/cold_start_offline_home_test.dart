import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/api/auth_api.dart';
import 'package:tencent_cloud_chat_demo/src/services/login_coordinator.dart';

void main() {
  test('offline cold start uses cache when network profile fails', () {
    expect(
      LoginCoordinator.shouldUseOfflineColdStartCache(
        hasValidJwt: true,
        networkProfileOk: false,
        isAuthFailure: false,
        hasCachedUserSig: true,
      ),
      isTrue,
    );
    expect(
      LoginCoordinator.shouldUseOfflineColdStartCache(
        hasValidJwt: true,
        networkProfileOk: false,
        isAuthFailure: true,
        hasCachedUserSig: true,
      ),
      isFalse,
    );
    expect(
      LoginCoordinator.shouldUseOfflineColdStartCache(
        hasValidJwt: true,
        networkProfileOk: false,
        isAuthFailure: false,
        hasCachedUserSig: false,
      ),
      isFalse,
    );
  });

  test('offline path may enter home even when IM login fails', () {
    expect(
      LoginCoordinator.shouldEnterHomeDespiteImLoginFailure(
        usedOfflineCachedSig: true,
        imCode: 6014,
      ),
      isTrue,
    );
    expect(
      LoginCoordinator.shouldEnterHomeDespiteImLoginFailure(
        usedOfflineCachedSig: false,
        imCode: 6014,
      ),
      isFalse,
    );
  });

  test('me stub from cached sig keeps userId', () {
    final me = LoginCoordinator.meStubFromCachedSig(
      UserSigResult(
        sdkAppId: 1,
        userId: 'u_42',
        userSig: 'sig',
        expiresIn: 3600,
      ),
    );
    expect(me.userId, 'u_42');
    expect(me.nickname, 'u_42');
  });
}

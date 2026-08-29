import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';
import 'package:tencent_cloud_chat_demo/src/api/auth_api.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_session_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ApiClient.instance.clearToken();
    await ImSessionCache.instance.clear();
  });

  test('delayed account A cleanup cannot erase account B token', () async {
    const tokenA = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const tokenB = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

    await ApiClient.instance.saveToken(tokenA, userId: 'account-a');
    final capturedByLogoutA = ApiClient.instance.token;
    await ApiClient.instance.saveToken(tokenB, userId: 'account-b');

    final cleared =
        await ApiClient.instance.clearTokenIfCurrent(capturedByLogoutA);
    expect(cleared, isFalse);
    expect(ApiClient.instance.token, tokenB);

    // Simulate process bootstrap reading the durable value again.
    await ApiClient.instance.loadToken();
    expect(ApiClient.instance.token, tokenB);
    expect(ApiClient.instance.authenticatedUserId, 'account-b');
  });

  test('delayed account A cleanup cannot erase account B UserSig', () async {
    final cache = ImSessionCache.instance;
    await cache.save(_sig(userId: 'account-a', userSig: 'sig-a'));
    await cache.save(_sig(userId: 'account-b', userSig: 'sig-b'));

    final cleared = await cache.clearForUser('account-a');
    final restored = await cache.loadIfValid();

    expect(cleared, isFalse);
    expect(restored?.userId, 'account-b');
    expect(restored?.userSig, 'sig-b');
  });

  test('UserSig is committed as one atomic secure-storage record', () async {
    await ImSessionCache.instance.save(
      _sig(userId: 'account-b', userSig: 'sig-b'),
    );

    const secure = FlutterSecureStorage();
    final values = await secure.readAll();
    expect(values['im_session_v2'], isNotEmpty);
    expect(values['im_session_sdk_app_id'], isNull);
    expect(values['im_session_user_id'], isNull);
    expect(values['im_session_user_sig'], isNull);
    expect(values['im_session_expires_at_ms'], isNull);
  });

  test('expired v2 session never falls back to another legacy account',
      () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'im_session_v2': jsonEncode(<String, Object>{
        'sdkAppId': 1400000001,
        'userId': 'account-b',
        'userSig': 'expired-b',
        'expiresAtMs': now - 1000,
      }),
      'im_session_sdk_app_id': '1400000001',
      'im_session_user_id': 'account-a',
      'im_session_user_sig': 'valid-a',
      'im_session_expires_at_ms': '${now + 3600000}',
    });

    expect(await ImSessionCache.instance.loadIfValid(), isNull);
    expect(await ImSessionCache.instance.readCachedUserId(), 'account-b');
  });

  test('foreground login persists UserSig before entering home', () {
    final source = File(
      'lib/src/services/login_coordinator.dart',
    ).readAsStringSync();
    final methodStart =
        source.indexOf('Future<void> _completeForegroundLoginAndEnterHome');
    final methodEnd = source.indexOf(
      'Future<void> _finishWebColdStartBackground',
      methodStart,
    );
    expect(methodStart, greaterThanOrEqualTo(0));
    expect(methodEnd, greaterThan(methodStart));

    final body = source.substring(methodStart, methodEnd);
    final persist = body.indexOf('bootstrapAuthenticatedSession()');
    final enterHome = body.indexOf('enterHomeAfterBusinessAuth(');
    expect(persist, greaterThanOrEqualTo(0));
    expect(enterHome, greaterThan(persist));
  });
}

UserSigResult _sig({required String userId, required String userSig}) {
  return UserSigResult(
    sdkAppId: 1400000001,
    userId: userId,
    userSig: userSig,
    expiresIn: 3600,
  );
}

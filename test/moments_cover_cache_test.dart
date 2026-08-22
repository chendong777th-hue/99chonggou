import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_cover_cache.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_local_prefs.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_settings_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    MomentsStore.debugAccountScopeOverride = 'moments_cover_cache_test';
    MomentsCoverCache.debugDisablePrefetch = true;
    MomentsSettingsService.instance.clearMemoryCache();
  });

  tearDown(() {
    MomentsStore.debugAccountScopeOverride = null;
    MomentsCoverCache.debugDisablePrefetch = false;
    MomentsSettingsService.instance.clearMemoryCache();
  });

  test('hydrateFromLocal restores cover url from prefs before network',
      () async {
    await MomentsLocalPrefs.saveCoverPath(
      'https://cdn.example.com/moments/cover.jpg',
    );

    expect(MomentsSettingsService.instance.cachedSettings, isNull);

    final settings = await MomentsSettingsService.instance.hydrateFromLocal();
    expect(settings.coverUrl, 'https://cdn.example.com/moments/cover.jpg');
    expect(
      MomentsSettingsService.instance.cachedSettings?.coverUrl,
      'https://cdn.example.com/moments/cover.jpg',
    );
  });

  test('cover cache key matches resolved http url', () {
    expect(
      MomentsCoverCache.cacheKeyFor('https://cdn.example.com/cover.jpg'),
      'https://cdn.example.com/cover.jpg',
    );
    expect(MomentsCoverCache.cacheKeyFor('assets/cover.png'), isNull);
    expect(MomentsCoverCache.cacheKeyFor(''), isNull);
  });
}

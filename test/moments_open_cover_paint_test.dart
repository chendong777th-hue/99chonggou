import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('moments page paints cover during first-load instead of swapping body',
      () {
    final source = File('lib/src/pages/moments/moments_page.dart').readAsStringSync();
    expect(source, isNot(contains('body: _feedController.loading')));
    expect(source, contains('_feedController.loading && posts.isEmpty'));
    expect(source, contains('cachedSettings?.coverUrl'));
    expect(source, contains('_primeCoverFromCache'));
    expect(source, contains('hydrateFromLocal'));
    expect(source, contains('placeholderColor: coverFallback'));

    final thumbnail =
        File('lib/src/pages/moments/moments_media_thumbnail.dart')
            .readAsStringSync();
    expect(thumbnail, contains('cacheKey: resolved'));
  });
}

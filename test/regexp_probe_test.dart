import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/regexp_probe.dart';

void main() {
  tearDown(() {
    RegExpProbe.debugForceEnabled = false;
    RegExpProbe.reset();
  });

  test('measure accumulates when force-enabled', () {
    RegExpProbe.debugForceEnabled = true;
    RegExpProbe.reset();

    final value = RegExpProbe.measure('site.a', () {
      var x = 0;
      for (var i = 0; i < 1000; i++) {
        x += i;
      }
      return x;
    });
    expect(value, greaterThan(0));

    final snap = RegExpProbe.snapshotForTesting();
    expect(snap['site.a']?.calls, 1);
    expect(snap['site.a']?.elapsedUs, greaterThan(0));
  });

  test('measure is transparent when disabled', () {
    RegExpProbe.debugForceEnabled = false;
    RegExpProbe.reset();

    expect(RegExpProbe.measure('site.b', () => 42), 42);
    expect(RegExpProbe.snapshotForTesting(), isEmpty);
  });

  test('dump ranks by elapsedUs', () {
    RegExpProbe.debugForceEnabled = true;
    RegExpProbe.reset();

    RegExpProbe.measure('fast', () => 1);
    RegExpProbe.measure('slow', () {
      var x = 0;
      for (var i = 0; i < 20000; i++) {
        x += i;
      }
      return x;
    });

    final ranked = RegExpProbe.snapshotForTesting().entries.toList()
      ..sort((a, b) => b.value.elapsedUs.compareTo(a.value.elapsedUs));
    expect(ranked.first.key, 'slow');
    expect(ranked.last.key, 'fast');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/contact_data_source_enter_gate.dart';

void main() {
  group('ContactDataSourceEnterGate.shouldRunNetworkPhase', () {
    final now = DateTime.utc(2026, 8, 22, 3, 0, 0);

    test('runs when never entered', () {
      expect(
        ContactDataSourceEnterGate.shouldRunNetworkPhase(
          now: now,
          lastEnterAt: null,
        ),
        isTrue,
      );
    });

    test('skips inside 2s debounce', () {
      expect(
        ContactDataSourceEnterGate.shouldRunNetworkPhase(
          now: now,
          lastEnterAt: now.subtract(const Duration(seconds: 1)),
        ),
        isFalse,
      );
    });

    test('runs at or after debounce', () {
      expect(
        ContactDataSourceEnterGate.shouldRunNetworkPhase(
          now: now,
          lastEnterAt: now.subtract(const Duration(seconds: 2)),
        ),
        isTrue,
      );
    });
  });

  group('ContactDataSourceEnterSingleFlight', () {
    test('second begin joins the same Future', () async {
      final gate = ContactDataSourceEnterSingleFlight();
      var runs = 0;
      late final Future<void> first;
      first = gate.run(() async {
        runs++;
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      final second = gate.run(() async {
        runs++;
      });
      expect(identical(first, second), isTrue);
      await first;
      expect(runs, 1);
      expect(gate.isInFlight, isFalse);
    });

    test('after complete, next begin starts a new run', () async {
      final gate = ContactDataSourceEnterSingleFlight();
      var runs = 0;
      await gate.run(() async {
        runs++;
      });
      await gate.run(() async {
        runs++;
      });
      expect(runs, 2);
    });
  });
}

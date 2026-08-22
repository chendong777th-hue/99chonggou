import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_calls_uikit/src/impl/call_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  final state = CallState.instance;

  tearDown(state.resetSystemCallKitPresentation);

  test('uses an already resolved system CallKit decision', () async {
    state.updateSystemCallKitPresentation(true);

    expect(await state.waitForSystemCallKitPresentation(), isTrue);
  });

  test('wakes a pending decision when native CallKit reports failure', () async {
    final pending = state.waitForSystemCallKitPresentation(
      timeout: const Duration(seconds: 1),
    );

    state.updateSystemCallKitPresentation(false);

    expect(await pending, isFalse);
  });

  test('keeps system-first ownership when native result is unknown', () async {
    final result = await state.waitForSystemCallKitPresentation(
      timeout: const Duration(milliseconds: 1),
    );

    expect(result, isNull);
  });
}

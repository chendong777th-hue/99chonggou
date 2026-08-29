import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/frame.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(Frame.debugReset);

  test('double init does not recurse on report', () {
    var externalCalls = 0;
    void external(List<FrameTiming> timings) {
      externalCalls++;
    }

    window.onReportTimings = external;
    Frame.init();
    Frame.init(); // must be idempotent — old bug chained self → Stack Overflow

    expect(Frame.debugIsInstalled, isTrue);
    expect(Frame.debugInstallDepth, 2);

    Frame.onReportTimings(const <FrameTiming>[]);
    expect(externalCalls, 1);

    Frame.destroy();
    expect(Frame.debugIsInstalled, isTrue);
    expect(Frame.debugInstallDepth, 1);

    Frame.destroy();
    expect(Frame.debugIsInstalled, isFalse);
    expect(window.onReportTimings, same(external));
  });

  test('init when already installed as self does not self-chain', () {
    Frame.init();
    // Simulate a bad re-entry path that would see ourselves as current.
    Frame.debugReset();
    window.onReportTimings = Frame.onReportTimings;
    Frame.init();

    // Must not stack-overflow.
    Frame.onReportTimings(const <FrameTiming>[]);
    expect(Frame.debugIsInstalled, isTrue);
  });

  test('fps log is off by default', () {
    Frame.fpsLogEveryNFrames = 0;
    Frame.init();
    // Smoke: reporting must not throw.
    Frame.onReportTimings(const <FrameTiming>[]);
  });

  test('passive timing listeners do not replace the platform callback', () {
    var calls = 0;
    void listener(List<FrameTiming> timings) {
      calls++;
    }

    Frame.addTimingsListener(listener);
    Frame.onReportTimings(const <FrameTiming>[]);
    expect(calls, 1);

    Frame.removeTimingsListener(listener);
    Frame.onReportTimings(const <FrameTiming>[]);
    expect(calls, 1);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/wallet_screen.dart';

void main() {
  test('360 logical width at dpr 3 decodes to 1080', () {
    expect(
      walletPromoCacheWidth(
        logicalWidth: 360,
        devicePixelRatio: 3,
        sourcePx: 1848,
      ),
      1080,
    );
  });

  test('decoded width never exceeds source pixels', () {
    expect(
      walletPromoCacheWidth(
        logicalWidth: 1000,
        devicePixelRatio: 3,
        sourcePx: 1848,
      ),
      1848,
    );
  });

  test('zero logical width clamps to 1', () {
    expect(
      walletPromoCacheWidth(
        logicalWidth: 0,
        devicePixelRatio: 3,
        sourcePx: 1848,
      ),
      1,
    );
  });
}

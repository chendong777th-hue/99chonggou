import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/tron_address_validator.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/withdraw_transfer_target_validator.dart';

void main() {
  group('TronAddressValidator', () {
    test('accepts known valid mainnet address', () {
      expect(
        TronAddressValidator.isValid('TJRabPrwbZy45sbavfcjinPJC18kjpRTv8'),
        isTrue,
      );
    });

    test('rejects wrong checksum', () {
      expect(
        TronAddressValidator.isValid('TJRabPrwbZy45sbavfcjinPJC18kjpRTv9'),
        isFalse,
      );
    });

    test('rejects wrong length', () {
      expect(TronAddressValidator.isValid('TShort'), isFalse);
    });
  });

  group('WithdrawTransferTargetValidator', () {
    test('accepts valid TRON address', () {
      const addr = 'TJRabPrwbZy45sbavfcjinPJC18kjpRTv8';
      final target = WithdrawTransferTargetValidator.resolve(
        raw: addr,
        isBlockedUserId: (_) => false,
      );
      expect(target?.isChain, isTrue);
      expect(target?.value, addr);
    });

    test('accepts valid 99Chat user id', () {
      final target = WithdrawTransferTargetValidator.resolve(
        raw: 'udohh1rryx',
        isBlockedUserId: (_) => false,
      );
      expect(target?.isFriend, isTrue);
      expect(target?.value, 'udohh1rryx');
    });

    test('accepts @ prefixed 99Chat user id', () {
      final target = WithdrawTransferTargetValidator.resolve(
        raw: '@udohh1rryx',
        isBlockedUserId: (_) => false,
      );
      expect(target?.isFriend, isTrue);
      expect(target?.value, 'udohh1rryx');
    });

    test('rejects too short user id', () {
      final target = WithdrawTransferTargetValidator.resolve(
        raw: 'abc',
        isBlockedUserId: (_) => false,
      );
      expect(target, isNull);
    });

    test('rejects too long user id', () {
      final target = WithdrawTransferTargetValidator.resolve(
        raw: 'abcdefghijklmnop',
        isBlockedUserId: (_) => false,
      );
      expect(target, isNull);
    });

    test('rejects user id with underscore', () {
      final target = WithdrawTransferTargetValidator.resolve(
        raw: 'official_b',
        isBlockedUserId: (_) => false,
      );
      expect(target, isNull);
    });

    test('resolves friend nickname via callback', () {
      final target = WithdrawTransferTargetValidator.resolve(
        raw: '冬🐉',
        isBlockedUserId: (_) => false,
        resolveFriendUserId: (value) {
          if (value == '冬🐉') return 'ithlxvup5h';
          return null;
        },
      );
      expect(target?.isFriend, isTrue);
      expect(target?.value, 'ithlxvup5h');
    });

    test('rejects invalid garbage input', () {
      final target = WithdrawTransferTargetValidator.resolve(
        raw: 'not-a-valid-target',
        isBlockedUserId: (_) => false,
      );
      expect(target, isNull);
    });

    test('rejects blocked official account', () {
      final target = WithdrawTransferTargetValidator.resolve(
        raw: 'officialbot',
        isBlockedUserId: (id) => id == 'officialbot',
      );
      expect(target, isNull);
    });

    test('extractTronAddress finds embedded valid address', () {
      expect(
        WithdrawTransferTargetValidator.extractTronAddress(
          ' pay to TJRabPrwbZy45sbavfcjinPJC18kjpRTv8 ',
        ),
        'TJRabPrwbZy45sbavfcjinPJC18kjpRTv8',
      );
    });

    test('extractTronAddress ignores invalid checksum embedded address', () {
      expect(
        WithdrawTransferTargetValidator.extractTronAddress(
          ' pay to TXYZopYRdj2D9XRtbG411XZZ3kM4VkWFq2 ',
        ),
        isNull,
      );
    });

    test('normalizedTargetValue strips @ from user id', () {
      expect(
        WithdrawTransferTargetValidator.normalizedTargetValue('@udohh1rryx'),
        'udohh1rryx',
      );
    });
  });
}

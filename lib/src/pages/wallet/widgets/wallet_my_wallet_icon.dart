import 'package:flutter/material.dart';

/// 收款地址等场景「我的钱包」列表项左侧图标。
class WalletMyWalletIcon extends StatelessWidget {
  final double size;

  const WalletMyWalletIcon({
    super.key,
    this.size = 42,
  });

  static const _asset = 'assets/wallet/my_wallet.webp';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        _asset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

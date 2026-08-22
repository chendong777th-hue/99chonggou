import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class WalletCoinIcon extends StatelessWidget {
  final String coin;
  final Color color;
  final double size;

  const WalletCoinIcon({
    super.key,
    required this.coin,
    this.color = const Color(0xFF26A17B),
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Text(
        coin.isEmpty ? '?' : coin.substring(0, 1),
        style: TextStyle(
          color: Colors.white,
          fontSize: (size * 0.42).sp,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';

import 'wallet_page_colors.dart';

class WalletActionButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool loading;

  const WalletActionButton({
    super.key,
    required this.text,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    final cs = WalletPageColors.of(context);

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          height: AppTokens.buttonHeight.h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? cs.red : cs.disabledButton,
            borderRadius: BorderRadius.circular(AppTokens.rLg.r),
          ),
          child: loading
              ? SizedBox(
                  width: 24.w,
                  height: 24.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  text,
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

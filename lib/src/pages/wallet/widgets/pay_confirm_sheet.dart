import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/ui/utils/adaptive_modal.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';

import 'wallet_page_colors.dart';

class PayConfirmSheet extends StatelessWidget {
  final String title;
  final String amountText;
  final List<MapEntry<String, String>> rows;

  const PayConfirmSheet({
    super.key,
    required this.title,
    required this.amountText,
    required this.rows,
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String amountText,
    required List<MapEntry<String, String>> rows,
  }) async {
    final ret = await showAdaptiveModalSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) =>
          PayConfirmSheet(title: title, amountText: amountText, rows: rows),
    );
    return ret == true;
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final cs = WalletPageColors.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(28.w, 20.h, 28.w, 28.h),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTokens.rXl.r)),
        border: Border(
          top: BorderSide(color: cs.line, width: 0.5),
          left: BorderSide(color: cs.line, width: 0.5),
          right: BorderSide(color: cs.line, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72.w,
              height: 5.h,
              decoration: BoxDecoration(
                color: cs.subText.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(99.r),
              ),
            ),
            SizedBox(height: 22.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 24.sp,
                color: cs.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              amountText,
              style: TextStyle(
                fontSize: 38.sp,
                color: cs.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 18.h),
            ...rows.map((e) => _RowItem(cs: cs, label: e.key, value: e.value)),
            SizedBox(height: 16.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: cs.warningBg,
                borderRadius: BorderRadius.circular(AppTokens.rMd.r),
                border: Border.all(color: cs.tagBorder, width: 0.5),
              ),
              child: Text(
                i18n.t(
                  zhHans: '请确认币种和网络，转错链可能无法找回。',
                  zhHant: '請確認幣種與網路，若選錯鏈路，資產可能無法找回。',
                  en: 'Please confirm the token and network carefully. Assets sent on the wrong chain may not be recoverable.',
                  ja: '通貨とネットワークを必ずご確認ください。誤ったチェーンへ送信した場合、資産を取り戻せない可能性があります。',
                  ko: '코인과 네트워크를 꼭 확인해 주세요. 잘못된 체인으로 전송된 자산은 복구되지 않을 수 있습니다.',
                ),
                style: TextStyle(
                  fontSize: 14.sp,
                  color: cs.warningText,
                  height: 1.45,
                ),
              ),
            ),
            SizedBox(height: 22.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.text,
                      backgroundColor: cs.inputFill,
                      side: BorderSide(color: cs.line, width: 1),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTokens.rLg.r),
                      ),
                    ),
                    child: Text(
                      i18n.t(
                        zhHans: '取消',
                        zhHant: '取消',
                        en: 'Cancel',
                        ja: 'キャンセル',
                        ko: '취소',
                      ),
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTokens.rLg.r),
                      ),
                    ),
                    child: Text(
                      i18n.t(
                        zhHans: '确认',
                        zhHant: '確認',
                        en: 'Confirm',
                        ja: '確認',
                        ko: '확인',
                      ),
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RowItem extends StatelessWidget {
  final WalletPageColors cs;
  final String label;
  final String value;

  const _RowItem({
    required this.cs,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 9.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128.w,
            child: Text(
              label,
              style: TextStyle(fontSize: 15.sp, color: cs.subText),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 15.sp,
                color: cs.text,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

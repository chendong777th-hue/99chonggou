import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';

class PayResultLayer extends StatelessWidget {
  final String state;
  final String err;
  final VoidCallback? onClose;

  const PayResultLayer({
    super.key,
    required this.state,
    this.err = '',
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final failed = state == 'failed';
    final success = state == 'success';
    final loading = state == 'loading' || state == 'submitting';
    return Positioned.fill(
      child: GestureDetector(
        onTap: loading ? null : onClose,
        child: Container(
          color: Colors.black.withOpacity(0.48),
          alignment: Alignment.center,
          child: Container(
            width: 250.w,
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 30.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 110.w,
                  height: 110.w,
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : Icon(
                          success ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          size: 78.sp,
                          color: success ? const Color(0xFF21B26B) : failed ? const Color(0xFFFF3B30) : const Color(0xFF2B72FF),
                        ),
                ),
                SizedBox(height: 18.h),
                Text(
                  loading
                      ? i18n.t(
                          zhHans: '处理中',
                          zhHant: '處理中',
                          en: 'Processing',
                          ja: '処理中',
                          ko: '처리 중',
                        )
                      : success
                          ? i18n.t(
                              zhHans: '操作成功',
                              zhHant: '操作成功',
                              en: 'Success',
                              ja: '操作が完了しました',
                              ko: '작업 성공',
                            )
                          : i18n.t(
                              zhHans: '操作失败',
                              zhHant: '操作失敗',
                              en: 'Operation failed',
                              ja: '操作に失敗しました',
                              ko: '작업 실패',
                            ),
                  style: TextStyle(fontSize: 23.sp, fontWeight: FontWeight.w800, color: const Color(0xFF101010)),
                ),
                if (failed) ...[
                  SizedBox(height: 12.h),
                  Text(
                    err.isEmpty
                        ? i18n.t(
                            zhHans: '请稍后重试',
                            zhHant: '請稍後重試',
                            en: 'Please try again later',
                            ja: 'しばらくしてから再度お試しください',
                            ko: '잠시 후 다시 시도해 주세요',
                          )
                        : err,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17.sp, color: const Color(0xFF8B8B8B)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

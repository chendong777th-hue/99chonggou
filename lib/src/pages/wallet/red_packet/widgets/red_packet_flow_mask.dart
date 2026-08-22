import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';

import '../red_packet_models.dart';

class RedPacketFlowMask extends StatelessWidget {
  final RpFlow flow;
  final String err;
  final VoidCallback onClose;

  const RedPacketFlowMask({
    super.key,
    required this.flow,
    required this.err,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final failed = flow == RpFlow.failed;
    final success = flow == RpFlow.success;
    final pending = flow == RpFlow.pending;

    return Positioned.fill(
      child: GestureDetector(
        onTap: (failed || success || pending) ? onClose : null,
        child: Container(
          color: Colors.black.withOpacity(0.48),
          alignment: Alignment.center,
          child: Container(
            width: 270.w,
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 30.h),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22.r)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 110.w, height: 110.w, child: _Anim(flow: flow)),
                SizedBox(height: 18.h),
                Text(
                  flow == RpFlow.loading
                      ? i18n.t(
                          zhHans: '支付中',
                          zhHant: '支付中',
                          en: 'Paying',
                          ja: '支払い中',
                          ko: '결제 중',
                        )
                      : pending
                          ? i18n.t(
                              zhHans: '处理中',
                              zhHant: '處理中',
                              en: 'Processing',
                              ja: '処理中',
                              ko: '처리 중',
                            )
                          : success
                              ? i18n.t(
                                  zhHans: '红包已提交',
                                  zhHant: '紅包已提交',
                                  en: 'Red packet submitted',
                                  ja: '紅包を送信しました',
                                  ko: '레드패킷이 제출되었습니다',
                                )
                              : i18n.t(
                                  zhHans: '支付失败',
                                  zhHant: '支付失敗',
                                  en: 'Payment failed',
                                  ja: '支払いに失敗しました',
                                  ko: '결제 실패',
                                ),
                  style: TextStyle(fontSize: 23.sp, fontWeight: FontWeight.w800, color: const Color(0xFF101010)),
                ),
                if (failed || pending) ...[
                  SizedBox(height: 12.h),
                  Text(
                    failed
                        ? (err.isEmpty
                            ? i18n.t(
                                zhHans: '请稍后重试',
                                zhHant: '請稍後重試',
                                en: 'Please try again later',
                                ja: 'しばらくしてから再度お試しください',
                                ko: '잠시 후 다시 시도해 주세요',
                              )
                            : err)
                        : i18n.t(
                            zhHans: '红包已提交，可在聊天和记录中查看',
                            zhHant: '紅包已提交，可在聊天和記錄中查看',
                            en: 'Red packet submitted. View it in chat and records.',
                            ja: '紅包を送信しました。チャットと履歴で確認できます。',
                            ko: '레드패킷이 제출되었습니다. 채팅과 기록에서 확인할 수 있습니다.',
                          ),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17.sp, color: const Color(0xFF8B8B8B), height: 1.4),
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

class _Anim extends StatelessWidget {
  final RpFlow flow;

  const _Anim({required this.flow});

  @override
  Widget build(BuildContext context) {
    if (flow == RpFlow.none) return const SizedBox.shrink();

    final asset = switch (flow) {
      RpFlow.success => 'assets/lottie/Payment_ok.json',
      RpFlow.failed => 'assets/lottie/Payment_no.json',
      _ => 'assets/lottie/Paying.json',
    };

    return Lottie.asset(
      asset,
      repeat: flow == RpFlow.loading || flow == RpFlow.pending,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) {
        if (flow == RpFlow.loading || flow == RpFlow.pending) {
          return const Center(child: CircularProgressIndicator());
        }
        return Icon(
          flow == RpFlow.success ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: flow == RpFlow.success ? const Color(0xFF21B26B) : const Color(0xFFFF3B30),
          size: 78.sp,
        );
      },
    );
  }
}

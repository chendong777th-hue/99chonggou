import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/api/sangong_admin_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/sangong_game_http.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/sangong_admin_models.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/group_game/sangong_round_settle_dialog.dart';
import 'package:tencent_cloud_chat_demo/utils/dio_error_message.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';

/// 开彩录入 + 结算；已结算本局则走冲正重结（方案 B）。
class SangongRoundSettleFlow {
  SangongRoundSettleFlow._();

  static Future<bool> run(BuildContext context) async {
    final i18n = AppI18n.of(context);
    if (!SangongGameHttp.canCallAdmin) {
      ToastUtils.toast(i18n.t(
        zhHans: SangongGameHttp.hasAuth ? '请先进入游戏群' : '请先登录',
        zhHant: SangongGameHttp.hasAuth ? '請先進入遊戲群' : '請先登入',
        en: SangongGameHttp.hasAuth
            ? 'Open a game group first'
            : 'Please sign in first',
      ));
      return false;
    }

    SangongDrawFetchResult fetchResult;
    try {
      fetchResult = await SangongAdminApi.instance.fetchCurrentDraws();
    } catch (error) {
      ToastUtils.toast(DioErrorMessage.forApp(error));
      return false;
    }

    final round = fetchResult.round;
    final drawStatus = fetchResult.draw;
    final roundId = drawStatus.roundId > 0
        ? drawStatus.roundId
        : (round?.id ?? 0);

    if (roundId <= 0) {
      ToastUtils.toast(i18n.t(
        zhHans: '当前无有效局',
        zhHant: '當前無有效局',
        en: 'No active round',
      ));
      return false;
    }

    if (round?.canVoidResettle == true) {
      if (!context.mounted) {
        return false;
      }
      return _runResettle(
        context,
        i18n: i18n,
        roundId: roundId,
        round: round!,
        drawStatus: drawStatus,
      );
    }

    if (round != null && !round.hasBetWindowClose) {
      ToastUtils.toast(i18n.t(
        zhHans: '请先截止下注，再录入开彩',
        zhHant: '請先截止下注，再錄入開彩',
        en: 'Close betting before entering draws',
      ));
      return false;
    }

    if (!context.mounted) {
      return false;
    }

    List<SangongDrawInput> inputs;
    if (drawStatus.complete) {
      inputs = const [];
    } else {
      final dialogResult = await SangongRoundSettleDialog.show(
        context,
        drawStatus: drawStatus,
      );
      if (dialogResult == null) {
        return false;
      }
      inputs = dialogResult;
    }

    try {
      var latestDraw = drawStatus;
      unawaited(AppDialog.showLoading(
        text: i18n.t(
          zhHans: '正在结算…',
          zhHant: '正在結算…',
          en: 'Settling…',
        ),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 16));
      try {
        if (inputs.isNotEmpty) {
          final mutation = await SangongAdminApi.instance.submitDraws(inputs);
          latestDraw = mutation.draw;
          if (!mutation.draw.complete) {
            final missing = mutation.draw.missingDoors;
            final missingText = missing.isEmpty
                ? ''
                : i18n.t(
                    zhHans: '：门${missing.join('、门')}',
                    zhHant: '：門${missing.join('、門')}',
                    en: ': doors ${missing.join(', ')}',
                  );
            if (context.mounted) {
              ToastUtils.toast(i18n.t(
                zhHans: '开彩未录满$missingText',
                zhHant: '開彩未錄滿$missingText',
                en: 'Draws incomplete$missingText',
              ));
            }
            return false;
          }
        } else if (!latestDraw.complete) {
          if (context.mounted) {
            ToastUtils.toast(i18n.t(
              zhHans: '开彩未录满，无法结算',
              zhHant: '開彩未錄滿，無法結算',
              en: 'Draws incomplete, cannot settle',
            ));
          }
          return false;
        }

        await SangongAdminApi.instance.settleRound(roundId);
      } finally {
        AppDialog.hideLoading();
      }
      if (!context.mounted) {
        return true;
      }
      ToastUtils.toast(i18n.t(
        zhHans: '结算成功',
        zhHant: '結算成功',
        en: 'Round settled',
      ));
      return true;
    } catch (error) {
      if (context.mounted) {
        ToastUtils.toast(DioErrorMessage.forApp(error));
      }
      return false;
    }
  }

  /// 方案 B：二次确认 → 空开彩表 → `POST .../resettle`。
  static Future<bool> _runResettle(
    BuildContext context, {
    required AppI18n i18n,
    required int roundId,
    required SangongAdminRound round,
    required SangongDrawStatus drawStatus,
  }) async {
    final periodText = round.periodNo > 0 ? '${round.periodNo}' : '';
    final confirmed = await AppDialog.confirm(
      title: i18n.t(
        zhHans: '冲正重结',
        zhHant: '沖正重結',
        en: 'Void & resettle',
      ),
      message: periodText.isNotEmpty
          ? i18n.t(
              zhHans: '将撤销第 $periodText 期结算并清空开奖号码，下注保留。确定后请重新录入开奖。',
              zhHant: '將撤銷第 $periodText 期結算並清空開獎號碼，下注保留。確定後請重新錄入開獎。',
              en:
                  'Void period $periodText settlement and clear draws. Bets stay. Re-enter draws next.',
            )
          : i18n.t(
              zhHans: '将撤销本局结算并清空开奖号码，下注保留。确定后请重新录入开奖。',
              zhHant: '將撤銷本局結算並清空開獎號碼，下注保留。確定後請重新錄入開獎。',
              en:
                  'Void this round settlement and clear draws. Bets stay. Re-enter draws next.',
            ),
      confirmText: i18n.t(
        zhHans: '重新开奖',
        zhHant: '重新開獎',
        en: 'Re-draw',
      ),
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return false;
    }

    final emptyDraw = sangongEmptyDrawStatusForResettle(drawStatus);
    final inputs = await SangongRoundSettleDialog.show(
      context,
      drawStatus: emptyDraw,
      clearExisting: true,
      titleText: i18n.t(
        zhHans: '重新开奖',
        zhHant: '重新開獎',
        en: 'Re-enter draws',
      ),
      subtitleText: i18n.t(
        zhHans: '请重新录入各门号码，勿沿用旧开奖',
        zhHant: '請重新錄入各門號碼，勿沿用舊開獎',
        en: 'Enter new draws; do not reuse old values',
      ),
      confirmLabel: i18n.t(
        zhHans: '冲正重结',
        zhHant: '沖正重結',
        en: 'Resettle',
      ),
    );
    if (inputs == null || !context.mounted) {
      return false;
    }
    if (inputs.isEmpty) {
      ToastUtils.toast(i18n.t(
        zhHans: '冲正重结须重新录入开奖号码',
        zhHant: '沖正重結須重新錄入開獎號碼',
        en: 'Resettle requires new draws',
      ));
      return false;
    }

    try {
      unawaited(AppDialog.showLoading(
        text: i18n.t(
          zhHans: '冲正并重新结算中…',
          zhHant: '沖正並重新結算中…',
          en: 'Voiding and resettling…',
        ),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 16));
      try {
        await SangongAdminApi.instance.resettleRound(
          roundId: roundId,
          draws: inputs,
        );
      } finally {
        AppDialog.hideLoading();
      }
      if (!context.mounted) {
        return true;
      }
      ToastUtils.toast(i18n.t(
        zhHans: '冲正重结成功',
        zhHant: '沖正重結成功',
        en: 'Resettled successfully',
      ));
      return true;
    } catch (error) {
      if (context.mounted) {
        ToastUtils.toast(DioErrorMessage.forApp(error));
      }
      return false;
    }
  }
}

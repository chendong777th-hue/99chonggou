import 'dart:async';

import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/utils/dio_error_message.dart';

class AgentRebateError {
  AgentRebateError._();

  static String code(Object error) {
    if (error is! DioError) return '';
    final data = error.response?.data;
    if (data is! Map) return '';
    return (data['code'] ?? data['errorCode'] ?? data['errCode'])
            ?.toString()
            .trim()
            .toUpperCase() ??
        '';
  }

  static bool revokesAccess(Object error) {
    final value = code(error);
    return value == 'NOT_AGENT' || value == 'PLAYER_NOT_FOUND';
  }

  static String message(Object error) {
    final i18n = AppI18n.current;
    if (error is TimeoutException) {
      return i18n.t(
        zhHans: '导出处理超时，请稍后重试',
        zhHant: '匯出處理逾時，請稍後重試',
        en: 'Export timed out. Please try again.',
      );
    }
    if (error is StateError || error is FormatException) {
      return i18n.t(
        zhHans: '下载失败，请稍后重试',
        zhHant: '下載失敗，請稍後重試',
        en: 'Download failed. Please try again.',
      );
    }
    return switch (code(error)) {
      'GROUP_NOT_BOUND' => i18n.t(
          zhHans: '该群尚未配对机器码',
          zhHant: '該群尚未配對機器碼',
          en: 'This group is not bound to a machine code.',
        ),
      'GROUP_NOT_ENABLED' => i18n.t(
          zhHans: '该群已配对但未开启',
          zhHant: '該群已配對但未開啟',
          en: 'This group is bound but not enabled.',
        ),
      'NOT_AGENT' => i18n.t(
          zhHans: '当前账号不是代理，无法查看反水数据',
          zhHant: '目前帳號不是代理，無法查看反水資料',
          en: 'This account is not an agent.',
        ),
      'PLAYER_NOT_FOUND' => i18n.t(
          zhHans: '未找到当前玩家资料',
          zhHant: '找不到目前玩家資料',
          en: 'Player profile was not found.',
        ),
      'NOT_IN_SCOPE' => i18n.t(
          zhHans: '该玩家不在您的下级范围内',
          zhHant: '該玩家不在您的下級範圍內',
          en: 'This player is outside your downline.',
        ),
      'INVALID_SCOPE' => i18n.t(
          zhHans: '下级查询范围无效',
          zhHant: '下級查詢範圍無效',
          en: 'The downline scope is invalid.',
        ),
      'DATE_RANGE_REQUIRED' => i18n.t(
          zhHans: '请选择查询日期',
          zhHant: '請選擇查詢日期',
          en: 'Please select a date range.',
        ),
      'INVALID_DATE_RANGE' => i18n.t(
          zhHans: '查询日期范围无效',
          zhHant: '查詢日期範圍無效',
          en: 'The date range is invalid.',
        ),
      'DATE_RANGE_TOO_LARGE' => i18n.t(
          zhHans: '日期范围最多包含93天',
          zhHant: '日期範圍最多包含93天',
          en: 'The date range can include at most 93 days.',
        ),
      'EXPORT_NOT_READY' => i18n.t(
          zhHans: '导出文件仍在生成，请稍后重试',
          zhHant: '匯出檔案仍在產生，請稍後重試',
          en: 'The export is still being generated.',
        ),
      'EXPORT_EXPIRED' => i18n.t(
          zhHans: '导出文件已过期，请重新下载',
          zhHant: '匯出檔案已過期，請重新下載',
          en: 'The export has expired. Please download it again.',
        ),
      'EXPORT_TASK_NOT_FOUND' || 'EXPORT_FILE_NOT_FOUND' => i18n.t(
          zhHans: '未找到导出文件，请重新下载',
          zhHant: '找不到匯出檔案，請重新下載',
          en: 'The export file was not found.',
        ),
      _ => DioErrorMessage.forApp(error),
    };
  }
}

import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/utils/dio_error_message.dart';

/// 表情上传接口错误文案。
class StickerUploadError {
  StickerUploadError._();

  static String message(Object error) {
    if (error is DioError) {
      final code = _readCode(error);
      switch (code) {
        case 'VIDEO_TOO_LONG':
          return AppI18n.current.t(
            zhHans: '视频不能超过 10 秒',
            zhHant: '視頻不能超過 10 秒',
            en: 'Video must be 10 seconds or shorter.',
            ja: '動画は10秒以内にしてください。',
            ko: '동영상은 10초 이하여야 합니다.',
          );
        case 'FFMPEG_NOT_CONFIGURED':
          return AppI18n.current.t(
            zhHans: '服务器暂不支持视频转表情，请稍后再试',
            zhHant: '伺服器暫不支援視頻轉表情，請稍後再試',
            en: 'Video-to-sticker is not available on the server yet.',
            ja: 'サーバーは動画スタンプ変換に未対応です。',
            ko: '서버에서 동영상 스티커 변환을 지원하지 않습니다.',
          );
        case 'FILE_TOO_LARGE':
        case 'VIDEO_TOO_LARGE':
          return AppI18n.current.t(
            zhHans: '文件过大',
            zhHant: '檔案過大',
            en: 'File is too large.',
            ja: 'ファイルが大きすぎます。',
            ko: '파일이 너무 큽니다.',
          );
        case 'INVALID_FILE':
        case 'UNSUPPORTED_MEDIA':
          return AppI18n.current.t(
            zhHans: '不支持的文件格式',
            zhHant: '不支援的檔案格式',
            en: 'Unsupported file format.',
            ja: '対応していない形式です。',
            ko: '지원하지 않는 형식입니다.',
          );
        case 'STICKER_UNAVAILABLE':
          return AppI18n.current.t(
            zhHans: '该表情不可用',
            zhHant: '該表情不可用',
            en: 'This sticker is unavailable.',
            ja: 'このスタンプは利用できません。',
            ko: '이 스티커를 사용할 수 없습니다.',
          );
      }
    }
    return DioErrorMessage.forApp(error);
  }

  static String? _readCode(DioError error) {
    final data = error.response?.data;
    if (data is! Map) {
      return null;
    }
    final map = Map<String, dynamic>.from(data);
    for (final key in const ['code', 'errorCode', 'errCode']) {
      final value = map[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim().toUpperCase();
      }
    }
    final inner = map['data'];
    if (inner is Map) {
      final innerMap = Map<String, dynamic>.from(inner);
      for (final key in const ['code', 'errorCode', 'errCode']) {
        final value = innerMap[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim().toUpperCase();
        }
      }
    }
    return null;
  }
}

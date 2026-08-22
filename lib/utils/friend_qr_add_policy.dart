import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';

bool isQrAddSource(String? addSource) {
  final raw = addSource?.trim() ?? '';
  if (raw.isEmpty) {
    return false;
  }
  final normalized = raw.toLowerCase().replaceAll('_', '');
  return normalized == 'addsourcetypeqrcode' ||
      normalized == 'qrcode' ||
      normalized == 'qr';
}

String qrAddNotAllowedText() => AppI18n.current.t(
      zhHans: '对方未开放通过二维码添加',
      zhHant: '對方未開放透過 QR 碼添加',
      en: 'This user does not allow adds via QR code.',
      ja: 'This user does not allow adds via QR code.',
      ko: 'This user does not allow adds via QR code.',
    );

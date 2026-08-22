import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';

enum LifePaymentType {
  mobile,
  electricity,
  water,
  gas,
}

extension LifePaymentTypeX on LifePaymentType {
  IconData get icon {
    switch (this) {
      case LifePaymentType.mobile:
        return Icons.smartphone_rounded;
      case LifePaymentType.electricity:
        return Icons.bolt_rounded;
      case LifePaymentType.water:
        return Icons.water_drop_rounded;
      case LifePaymentType.gas:
        return Icons.local_fire_department_rounded;
    }
  }

  Color accentColor(bool dark) {
    switch (this) {
      case LifePaymentType.mobile:
        return const Color(0xFF1E90FF);
      case LifePaymentType.electricity:
        return const Color(0xFFF59E0B);
      case LifePaymentType.water:
        return const Color(0xFF0EA5E9);
      case LifePaymentType.gas:
        return const Color(0xFFEF4444);
    }
  }

  bool get isMobile => this == LifePaymentType.mobile;
}

class LifePaymentRecord {
  const LifePaymentRecord({
    required this.type,
    required this.account,
    required this.amount,
    required this.paidAt,
    required this.status,
  });

  final LifePaymentType type;
  final String account;
  final String amount;
  final DateTime paidAt;
  final LifePaymentRecordStatus status;
}

enum LifePaymentRecordStatus { success, pending, failed }

/// 手机充值地区：国内 / 海外。
enum LifePaymentRechargeRegion { domestic, overseas }

class LifePaymentMobileCarrier {
  const LifePaymentMobileCarrier({
    required this.id,
    required this.region,
    required this.nameZh,
    required this.nameZhHant,
    required this.nameEn,
  });

  final String id;
  final LifePaymentRechargeRegion region;
  final String nameZh;
  final String nameZhHant;
  final String nameEn;

  String label(AppI18n i18n) {
    return i18n.t(
      zhHans: nameZh,
      zhHant: nameZhHant,
      en: nameEn,
      ja: nameEn,
      ko: nameEn,
    );
  }
}

const List<LifePaymentMobileCarrier> kLifePaymentDomesticCarriers = [
  LifePaymentMobileCarrier(
    id: 'cmcc',
    region: LifePaymentRechargeRegion.domestic,
    nameZh: '中国移动',
    nameZhHant: '中國移動',
    nameEn: 'China Mobile',
  ),
  LifePaymentMobileCarrier(
    id: 'cucc',
    region: LifePaymentRechargeRegion.domestic,
    nameZh: '中国联通',
    nameZhHant: '中國聯通',
    nameEn: 'China Unicom',
  ),
  LifePaymentMobileCarrier(
    id: 'ctcc',
    region: LifePaymentRechargeRegion.domestic,
    nameZh: '中国电信',
    nameZhHant: '中國電信',
    nameEn: 'China Telecom',
  ),
];

const List<LifePaymentMobileCarrier> kLifePaymentOverseasCarriers = [
  LifePaymentMobileCarrier(
    id: 'cmhk',
    region: LifePaymentRechargeRegion.overseas,
    nameZh: '中国移动香港',
    nameZhHant: '中國移動香港',
    nameEn: 'China Mobile HK',
  ),
  LifePaymentMobileCarrier(
    id: 'cuhk',
    region: LifePaymentRechargeRegion.overseas,
    nameZh: '中国联通香港',
    nameZhHant: '中國聯通香港',
    nameEn: 'China Unicom HK',
  ),
  LifePaymentMobileCarrier(
    id: 'three_hk',
    region: LifePaymentRechargeRegion.overseas,
    nameZh: '3香港',
    nameZhHant: '3香港',
    nameEn: '3 Hong Kong',
  ),
  LifePaymentMobileCarrier(
    id: 'csl',
    region: LifePaymentRechargeRegion.overseas,
    nameZh: 'csl',
    nameZhHant: 'csl',
    nameEn: 'csl',
  ),
  LifePaymentMobileCarrier(
    id: 'smartone',
    region: LifePaymentRechargeRegion.overseas,
    nameZh: 'SmarTone',
    nameZhHant: 'SmarTone',
    nameEn: 'SmarTone',
  ),
  LifePaymentMobileCarrier(
    id: 'singtel',
    region: LifePaymentRechargeRegion.overseas,
    nameZh: 'Singtel',
    nameZhHant: 'Singtel',
    nameEn: 'Singtel',
  ),
  LifePaymentMobileCarrier(
    id: 'starhub',
    region: LifePaymentRechargeRegion.overseas,
    nameZh: 'StarHub',
    nameZhHant: 'StarHub',
    nameEn: 'StarHub',
  ),
  LifePaymentMobileCarrier(
    id: 'chunghwa',
    region: LifePaymentRechargeRegion.overseas,
    nameZh: '中华电信',
    nameZhHant: '中華電信',
    nameEn: 'Chunghwa Telecom',
  ),
  LifePaymentMobileCarrier(
    id: 'taiwan_mobile',
    region: LifePaymentRechargeRegion.overseas,
    nameZh: '台湾大哥大',
    nameZhHant: '台灣大哥大',
    nameEn: 'Taiwan Mobile',
  ),
  LifePaymentMobileCarrier(
    id: 'far_eastone',
    region: LifePaymentRechargeRegion.overseas,
    nameZh: '远传电信',
    nameZhHant: '遠傳電信',
    nameEn: 'Far EasTone',
  ),
  LifePaymentMobileCarrier(
    id: 'cmacau',
    region: LifePaymentRechargeRegion.overseas,
    nameZh: '中国移动澳门',
    nameZhHant: '中國移動澳門',
    nameEn: 'China Mobile Macau',
  ),
  LifePaymentMobileCarrier(
    id: 'ctm',
    region: LifePaymentRechargeRegion.overseas,
    nameZh: '澳门电讯',
    nameZhHant: '澳門電訊',
    nameEn: 'CTM',
  ),
];

List<LifePaymentMobileCarrier> lifePaymentCarriersForRegion(
  LifePaymentRechargeRegion region,
) {
  switch (region) {
    case LifePaymentRechargeRegion.domestic:
      return kLifePaymentDomesticCarriers;
    case LifePaymentRechargeRegion.overseas:
      return kLifePaymentOverseasCarriers;
  }
}

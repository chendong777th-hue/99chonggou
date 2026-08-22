import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/settings_widgets.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/biometric_pay_enable_page.dart';
import 'package:tencent_cloud_chat_demo/src/services/biometric_pay_service.dart';
import 'package:tencent_cloud_chat_demo/utils/navigation_routes.dart';

/// 账号安全页 — 面容 / 指纹支付入口（点击进入全屏设置页）。
class BiometricPaySettingsCell extends StatefulWidget {
  const BiometricPaySettingsCell({super.key});

  @override
  State<BiometricPaySettingsCell> createState() =>
      _BiometricPaySettingsCellState();
}

class _BiometricPaySettingsCellState extends State<BiometricPaySettingsCell> {
  final _bio = BiometricPayService.instance;

  bool _loading = true;
  bool _visible = false;
  bool _enabled = false;
  String _label = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bio = _bio;
    if (!bio.isAvailableOnPlatform) {
      if (mounted) {
        setState(() {
          _loading = false;
          _visible = false;
        });
      }
      return;
    }

    var supported = false;
    var enabled = false;
    var label = '';
    try {
      supported = await bio.isDeviceSupported();
      enabled = await bio.isEnabled();
      label = await bio.paymentLabel(AppI18n.current);
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _loading = false;
      _visible = supported;
      _enabled = enabled;
      _label = label;
    });
  }

  Future<void> _openPage() async {
    await Navigator.of(context).push(
      NavigationRoutes.cupertino(
        builder: (_) => const BiometricPayEnablePage(),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || !_visible) {
      return const SizedBox.shrink();
    }

    final i18n = AppI18n.of(context);
    final title = _label.isNotEmpty
        ? _label
        : i18n.t(
            zhHans: '指纹支付',
            zhHant: '指紋支付',
            en: 'Fingerprint Pay',
            ja: '指紋支払い',
            ko: '지문 결제',
          );

    final value = _enabled
        ? i18n.t(
            zhHans: '已开启',
            zhHant: '已開啟',
            en: 'Enabled',
            ja: '有効',
            ko: '사용 중',
          )
        : i18n.t(
            zhHans: '未开启',
            zhHant: '未開啟',
            en: 'Disabled',
            ja: '無効',
            ko: '미사용',
          );

    return SettingsCell(
      title: title,
      value: value,
      showDivider: true,
      onTap: _openPage,
    );
  }
}

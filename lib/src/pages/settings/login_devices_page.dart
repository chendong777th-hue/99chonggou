import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';
import 'package:tencent_cloud_chat_demo/src/api/device_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/settings_widgets.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_empty_state.dart';
import 'package:tencent_cloud_chat_demo/utils/ip_region_resolver.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';

class LoginDevicesPage extends StatefulWidget {
  const LoginDevicesPage({super.key});

  @override
  State<LoginDevicesPage> createState() => _LoginDevicesPageState();
}

class _LoginDevicesPageState extends State<LoginDevicesPage> {
  bool _loading = true;
  bool _refreshing = false;
  bool _busy = false;
  String? _error;
  List<UserDevice> _devices = const [];
  Map<String, String> _ipRegionByIp = const {};
  String _localDeviceId = '';

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  bool _isLocalDevice(UserDevice device) {
    final localId = _localDeviceId.trim();
    final remoteId = device.deviceId.trim();
    return localId.isNotEmpty && remoteId.isNotEmpty && localId == remoteId;
  }

  bool _isProtectedDevice(UserDevice device) =>
      device.isCurrent || _isLocalDevice(device);

  bool get _hasOtherDevices => _devices.any((d) => !_isProtectedDevice(d));

  Future<void> _ensureLocalDeviceIdReady() async {
    await ApiClient.instance.ensureDeviceIdReady();
    _localDeviceId = ApiClient.instance.deviceId.trim();
  }

  Future<void> _loadDevices({bool refresh = false}) async {
    if (refresh) {
      setState(() => _refreshing = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      await _ensureLocalDeviceIdReady();
      final result = await DeviceApi.instance.fetchDevices();
      if (!mounted) return;
      setState(() {
        _devices = result.items;
        _loading = false;
        _refreshing = false;
        _error = null;
      });
      await _resolveIpRegions();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        _error = _formatError(e);
      });
    }
  }

  Future<void> _resolveIpRegions() async {
    final ips = _devices
        .where(
          (device) =>
              (device.lastLoginIpRegion?.trim().isEmpty ?? true) &&
              IpRegionResolver.isPublicIp(device.lastLoginIp),
        )
        .map((device) => device.lastLoginIp)
        .toList();
    if (ips.isEmpty) {
      return;
    }
    final resolved = await IpRegionResolver.resolveMany(ips);
    if (!mounted || resolved.isEmpty) {
      return;
    }
    setState(() {
      _ipRegionByIp = {..._ipRegionByIp, ...resolved};
    });
  }

  String _ipRegion(UserDevice device) {
    final fromApi = device.lastLoginIpRegion?.trim();
    if (fromApi != null && fromApi.isNotEmpty) {
      return fromApi;
    }
    final ip = device.lastLoginIp?.trim() ?? '';
    if (ip.isEmpty) {
      return '';
    }
    return _ipRegionByIp[ip]?.trim() ?? '';
  }

  String _formatError(Object error) {
    if (error is DioError) {
      final code = _readErrorCode(error);
      if (code != null) {
        return _formatErrorCode(code);
      }
    }
    return _formatErrorCode(null);
  }

  String _formatErrorCode(String? code) {
    final i18n = AppI18n.of(context);
    switch (code) {
      case 'CURRENT_DEVICE_UNKNOWN':
        return i18n.t(
          zhHans: '无法识别当前设备，请重新登录后再试',
          zhHant: '無法識別目前裝置，請重新登入後再試',
          en: 'Unable to identify this device. Please sign in again and retry.',
          ja: '現在の端末を識別できません。再ログインしてからお試しください。',
          ko: '현재 기기를 식별할 수 없습니다. 다시 로그인한 뒤 시도해 주세요.',
        );
      case 'CANNOT_KICK_SELF':
        return i18n.t(
          zhHans: '不能移除当前设备',
          zhHant: '不能移除目前裝置',
          en: 'You cannot remove the current device.',
          ja: '現在の端末は削除できません。',
          ko: '현재 기기는 제거할 수 없습니다.',
        );
      case 'DEVICE_NOT_FOUND':
        return i18n.t(
          zhHans: '设备不存在或已下线',
          zhHant: '裝置不存在或已下線',
          en: 'Device not found or already offline.',
          ja: '端末が見つからないか、すでにオフラインです。',
          ko: '기기를 찾을 수 없거나 이미 오프라인입니다.',
        );
    }
    return i18n.t(
      zhHans: '加载失败，请检查网络后重试',
      zhHant: '載入失敗，請檢查網路後重試',
      en: 'Failed to load. Please check your connection and try again.',
      ja: '読み込みに失敗しました。通信状況を確認してからもう一度お試しください。',
      ko: '불러오기에 실패했습니다. 네트워크를 확인한 뒤 다시 시도해 주세요.',
    );
  }

  String? _readErrorCode(DioError error) {
    final data = error.response?.data;
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      for (final key in const ['code', 'errorCode', 'errCode']) {
        final value = map[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim().toUpperCase();
        }
      }
    }
    return null;
  }

  Future<void> _kickDevice(UserDevice device) async {
    if (_busy || _isProtectedDevice(device)) return;
    final i18n = AppI18n.of(context);
    final title = _deviceTitle(device, i18n);
    final confirmed = await AppDialog.confirm(
      title: i18n.t(
        zhHans: '移除设备',
        zhHant: '移除裝置',
        en: 'Remove Device',
        ja: '端末を削除',
        ko: '기기 제거',
      ),
      message: i18n.format(
        zhHans: '确定将「{title}」从账号中移除吗？该设备将被强制下线。',
        zhHant: '確定將「{title}」從帳號中移除嗎？該裝置將被強制下線。',
        en: 'Remove "{title}" from your account? That device will be signed out.',
        ja: '「{title}」をアカウントから削除しますか？その端末は強制的にログアウトされます。',
        ko: '「{title}」을(를) 계정에서 제거하시겠습니까? 해당 기기는 강제로 로그아웃됩니다.',
        vars: {'title': title},
      ),
      cancelText: i18n.t(
        zhHans: '取消',
        zhHant: '取消',
        en: 'Cancel',
        ja: 'キャンセル',
        ko: '취소',
      ),
      confirmText: i18n.t(
        zhHans: '移除',
        zhHant: '移除',
        en: 'Remove',
        ja: '削除',
        ko: '제거',
      ),
      destructive: true,
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await DeviceApi.instance.kickDevice(device.deviceId);
      if (!mounted) return;
      setState(() {
        _devices = _devices
            .where((item) => item.deviceId != device.deviceId)
            .toList();
      });
      ToastUtils.toast(i18n.t(
        zhHans: '已移除该设备',
        zhHant: '已移除該裝置',
        en: 'Device removed',
        ja: '端末を削除しました',
        ko: '기기가 제거되었습니다',
      ));
    } catch (e) {
      if (!mounted) return;
      ToastUtils.toast(_formatError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _kickOthers() async {
    if (_busy || !_hasOtherDevices) return;
    await _ensureLocalDeviceIdReady();
    if (!mounted) return;
    if (_localDeviceId.isEmpty) {
      ToastUtils.toast(_formatErrorCode('CURRENT_DEVICE_UNKNOWN'));
      return;
    }
    final i18n = AppI18n.of(context);
    final confirmed = await AppDialog.confirm(
      title: i18n.t(
        zhHans: '移除其他设备',
        zhHant: '移除其他裝置',
        en: 'Remove Other Devices',
        ja: '他の端末を削除',
        ko: '다른 기기 제거',
      ),
      message: i18n.t(
        zhHans: '确定将除本机外的所有设备强制下线吗？',
        zhHant: '確定將除本機外的所有裝置強制下線嗎？',
        en: 'Sign out all devices except this one?',
        ja: 'この端末以外のすべての端末を強制的にログアウトしますか？',
        ko: '현재 기기를 제외한 모든 기기를 강제 로그아웃하시겠습니까?',
      ),
      cancelText: i18n.t(
        zhHans: '取消',
        zhHant: '取消',
        en: 'Cancel',
        ja: 'キャンセル',
        ko: '취소',
      ),
      confirmText: i18n.t(
        zhHans: '移除',
        zhHant: '移除',
        en: 'Remove',
        ja: '削除',
        ko: '제거',
      ),
      destructive: true,
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final result = await DeviceApi.instance.kickOthers(
        currentDeviceId: _localDeviceId,
      );
      if (!mounted) return;
      setState(() {
        _devices = _devices.where(_isProtectedDevice).toList();
      });
      ToastUtils.toast(i18n.format(
        zhHans: '已移除 {count} 台设备',
        zhHant: '已移除 {count} 台裝置',
        en: 'Removed {count} device(s)',
        ja: '{count} 台の端末を削除しました',
        ko: '{count}대의 기기를 제거했습니다',
        vars: {'count': '${result.kickedCount}'},
      ));
    } catch (e) {
      if (!mounted) return;
      ToastUtils.toast(_formatError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _deviceTitle(UserDevice device, AppI18n i18n) {
    final model = device.model?.trim();
    if (model != null && model.isNotEmpty) {
      return model;
    }
    return _platformLabel(device.platform, i18n);
  }

  String _platformLabel(String platform, AppI18n i18n) {
    final normalized = platform.trim().toLowerCase();
    switch (normalized) {
      case 'ios':
        return 'iOS';
      case 'android':
        return 'Android';
      case 'web':
        return i18n.t(
          zhHans: '网页端',
          zhHant: '網頁端',
          en: 'Web',
          ja: 'Web',
          ko: '웹',
        );
      case 'macos':
        return 'macOS';
      case 'windows':
        return 'Windows';
      default:
        if (platform.trim().isNotEmpty) return platform.trim();
        return i18n.t(
          zhHans: '未知设备',
          zhHant: '未知裝置',
          en: 'Unknown device',
          ja: '不明な端末',
          ko: '알 수 없는 기기',
        );
    }
  }

  IconData _platformIcon(String platform) {
    final normalized = platform.trim().toLowerCase();
    switch (normalized) {
      case 'ios':
      case 'macos':
        return Icons.phone_iphone_rounded;
      case 'android':
        return Icons.phone_android_rounded;
      case 'web':
        return Icons.language_rounded;
      case 'windows':
        return Icons.computer_rounded;
      default:
        return Icons.devices_other_rounded;
    }
  }

  String _formatLastLogin(DateTime? time, AppI18n i18n) {
    if (time == null) {
      return i18n.t(
        zhHans: '暂无登录记录',
        zhHant: '暫無登入記錄',
        en: 'No login record',
        ja: 'ログイン記録なし',
        ko: '로그인 기록 없음',
      );
    }
    final local = time.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day;
    final clock = DateFormat('HH:mm').format(local);
    if (sameDay) {
      return i18n.format(
        zhHans: '今天 {time}',
        zhHant: '今天 {time}',
        en: 'Today {time}',
        ja: '今日 {time}',
        ko: '오늘 {time}',
        vars: {'time': clock},
      );
    }
    if (isYesterday) {
      return i18n.format(
        zhHans: '昨天 {time}',
        zhHant: '昨天 {time}',
        en: 'Yesterday {time}',
        ja: '昨日 {time}',
        ko: '어제 {time}',
        vars: {'time': clock},
      );
    }
    return DateFormat('yyyy-MM-dd HH:mm').format(local);
  }

  Widget _buildBody(AppI18n i18n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.subText(dark: settingsIsDark(context)),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => _loadDevices(),
                child: Text(i18n.t(
                  zhHans: '重试',
                  zhHant: '重試',
                  en: 'Retry',
                  ja: '再試行',
                  ko: '다시 시도',
                )),
              ),
            ],
          ),
        ),
      );
    }
    if (_devices.isEmpty) {
      return AppEmptyState(
        message: i18n.t(
          zhHans: '暂无登录设备',
          zhHant: '暫無登入裝置',
          en: 'No signed-in devices',
          ja: 'ログイン中の端末はありません',
          ko: '로그인된 기기가 없습니다',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadDevices(refresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              i18n.t(
                zhHans: '以下设备已登录你的账号。移除后该设备将被强制下线。',
                zhHant: '以下裝置已登入你的帳號。移除後該裝置將被強制下線。',
                en: 'These devices are signed in to your account. Removing a device will sign it out.',
                ja: '以下の端末があなたのアカウントにログインしています。削除すると強制的にログアウトされます。',
                ko: '아래 기기가 계정에 로그인되어 있습니다. 제거하면 해당 기기는 강제 로그아웃됩니다.',
              ),
              style: TextStyle(
                color: AppColors.subText(dark: settingsIsDark(context)),
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
          SettingsGroup(
            margin: const EdgeInsets.only(bottom: 0),
            children: List.generate(_devices.length, (index) {
              final device = _devices[index];
              final isLast = index == _devices.length - 1;
              return _DeviceRow(
                device: device,
                title: _deviceTitle(device, i18n),
                platformIcon: _platformIcon(device.platform),
                meta: _buildDeviceMeta(device, i18n),
                badges: _buildBadges(device, i18n),
                showDivider: !isLast,
                onRemove: _isProtectedDevice(device) || _busy
                    ? null
                    : () => _kickDevice(device),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceMeta(UserDevice device, AppI18n i18n) {
    final dark = settingsIsDark(context);
    final labelStyle = TextStyle(
      color: AppColors.subText(dark: dark).withValues(alpha: 0.72),
      fontSize: 11,
      height: 1.2,
    );
    final valueStyle = TextStyle(
      color: AppColors.subText(dark: dark),
      fontSize: 12,
      height: 1.2,
    );
    final items = <_DeviceMetaItem>[
      _DeviceMetaItem(
        label: i18n.t(
          zhHans: '最近登录',
          zhHant: '最近登入',
          en: 'Last active',
          ja: '最終ログイン',
          ko: '최근 로그인',
        ),
        value: _formatLastLogin(device.lastLoginAt, i18n),
      ),
    ];
    final version = device.appVersion?.trim() ?? '';
    if (version.isNotEmpty) {
      items.add(
        _DeviceMetaItem(
          label: i18n.t(
            zhHans: '应用版本',
            zhHant: '應用版本',
            en: 'App version',
            ja: 'アプリ版',
            ko: '앱 버전',
          ),
          value: version.startsWith('v') ? version : 'v$version',
        ),
      );
    }
    final ip = device.lastLoginIp?.trim() ?? '';
    final region = _ipRegion(device);
    if (ip.isNotEmpty || region.isNotEmpty) {
      final value = ip.isNotEmpty && region.isNotEmpty
          ? '$ip · $region'
          : (ip.isNotEmpty ? ip : region);
      items.add(
        _DeviceMetaItem(
          label: i18n.t(
            zhHans: '登录 IP',
            zhHant: '登入 IP',
            en: 'IP / location',
            ja: 'IP / 場所',
            ko: 'IP / 위치',
          ),
          value: value,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 2),
          _DeviceMetaLine(
            item: items[i],
            labelStyle: labelStyle,
            valueStyle: valueStyle,
          ),
        ],
      ],
    );
  }

  List<Widget> _buildBadges(UserDevice device, AppI18n i18n) {
    final dark = settingsIsDark(context);
    final badges = <Widget>[];
    if (_isProtectedDevice(device)) {
      badges.add(_DeviceBadge(
        label: i18n.t(
          zhHans: '本机',
          zhHant: '本機',
          en: 'This device',
          ja: 'この端末',
          ko: '현재 기기',
        ),
        color: AppColors.primaryBlue,
        dark: dark,
      ));
    }
    if (device.isOnline) {
      badges.add(_DeviceBadge(
        label: i18n.t(
          zhHans: '在线',
          zhHant: '在線',
          en: 'Online',
          ja: 'オンライン',
          ko: '온라인',
        ),
        color: const Color(0xFF34C759),
        dark: dark,
      ));
    }
    if (device.isTrusted) {
      badges.add(_DeviceBadge(
        label: i18n.t(
          zhHans: '已信任',
          zhHant: '已信任',
          en: 'Trusted',
          ja: '信頼済み',
          ko: '신뢰됨',
        ),
        color: AppColors.subText(dark: dark),
        dark: dark,
      ));
    }
    return badges;
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final dark = settingsIsDark(context);
    final dividerColor = AppColors.line(dark: dark);

    return Scaffold(
      backgroundColor: AppColors.background(dark: dark),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: AppColors.card(dark: dark),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: AppColors.primaryBlue,
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.6),
          child: Container(
            height: 0.6,
            color: dividerColor,
          ),
        ),
        title: Text(
          i18n.t(
            zhHans: '登录设备',
            zhHant: '登入裝置',
            en: 'Signed-in Devices',
            ja: 'ログイン端末',
            ko: '로그인 기기',
          ),
          style: TextStyle(
            color: AppColors.text(dark: dark),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_refreshing)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(child: _buildBody(i18n)),
            if (_hasOtherDevices && !_loading && _error == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _busy ? null : _kickOthers,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF3B36),
                      side: const BorderSide(color: Color(0xFFEF3B36)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      i18n.t(
                        zhHans: '移除其他设备',
                        zhHant: '移除其他裝置',
                        en: 'Remove Other Devices',
                        ja: '他の端末を削除',
                        ko: '다른 기기 제거',
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DeviceMetaItem {
  const _DeviceMetaItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class _DeviceMetaLine extends StatelessWidget {
  const _DeviceMetaLine({
    required this.item,
    required this.labelStyle,
    required this.valueStyle,
  });

  final _DeviceMetaItem item;
  final TextStyle labelStyle;
  final TextStyle valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 58,
          child: Text(item.label, style: labelStyle),
        ),
        Expanded(
          child: Text(
            item.value,
            style: valueStyle,
          ),
        ),
      ],
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.device,
    required this.title,
    required this.platformIcon,
    required this.meta,
    required this.badges,
    required this.showDivider,
    this.onRemove,
  });

  final UserDevice device;
  final String title;
  final IconData platformIcon;
  final Widget meta;
  final List<Widget> badges;
  final bool showDivider;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final dark = settingsIsDark(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: AppColors.line(dark: dark),
                  width: 0.7,
                ),
              )
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.background(dark: dark),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              platformIcon,
              color: AppColors.primaryBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.text(dark: dark),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (badges.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: badges,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                meta,
              ],
            ),
          ),
          if (onRemove != null)
            TextButton(
              onPressed: onRemove,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF3B36),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(AppI18n.of(context).t(
                zhHans: '移除',
                zhHant: '移除',
                en: 'Remove',
                ja: '削除',
                ko: '제거',
              )),
            ),
        ],
      ),
    );
  }
}

class _DeviceBadge extends StatelessWidget {
  const _DeviceBadge({
    required this.label,
    required this.color,
    required this.dark,
  });

  final String label;
  final Color color;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w500,
          height: 1.1,
        ),
      ),
    );
  }
}

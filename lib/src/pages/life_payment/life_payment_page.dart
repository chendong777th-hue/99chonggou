import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/pages/life_payment/life_payment_decorations.dart';
import 'package:tencent_cloud_chat_demo/src/pages/life_payment/electricity_payment_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/life_payment/gas_payment_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/life_payment/water_payment_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/life_payment/life_payment_detail_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/life_payment/life_payment_location_service.dart';
import 'package:tencent_cloud_chat_demo/src/pages/life_payment/life_payment_models.dart';
import 'package:tencent_cloud_chat_demo/src/pages/life_payment/life_payment_repository.dart';
import 'package:tencent_cloud_chat_demo/src/pages/life_payment/utility_account_flow.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/src/pages/life_payment/life_payment_theme.dart';
import 'package:tencent_cloud_chat_demo/src/pages/life_payment/mobile_recharge_page.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_responsive.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/src/utils/immersive_app_system_ui.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_empty_state.dart';

const String _heroAsset = 'assets/img/Top-up-card.webp';
const String _mobileAsset = 'assets/img/Mobile_Phone.webp';
const String _electricityAsset = 'assets/img/Electricity_bill.webp';
const String _waterAsset = 'assets/img/Water_bill.webp';
const String _gasAsset = 'assets/img/Gas_bill.webp';
const double _heroAspectRatio = 1916 / 821;
const double _utilityAspectRatio = 832 / 260;

class LifePaymentPage extends StatefulWidget {
  const LifePaymentPage({super.key});

  @override
  State<LifePaymentPage> createState() => _LifePaymentPageState();
}

class _LifePaymentPageState extends State<LifePaymentPage> {
  final LifePaymentRepository _repo = LifePaymentRepository();

  LifePaymentLocationState _locationState = const LifePaymentLocationState(
    phase: LifePaymentLocationPhase.checking,
  );
  bool _locationResolving = false;
  LifePaymentHomeData? _homeData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveLocation());
    _loadHome();
  }

  /// 首页数据（服务开关 + 最近缴费）来自后端，加载失败时保持静态入口可用，
  /// 仅缺少维护开关与缴费记录，不阻塞用户进入各缴费页。
  Future<void> _loadHome() async {
    try {
      final data = await _repo.getHome();
      if (!mounted) return;
      setState(() => _homeData = data);
    } catch (_) {
      // 静默降级：无网/后端异常时首页仍可用
    }
  }

  Future<void> _resolveLocation() async {
    if (_locationResolving) return;
    _locationResolving = true;
    if (mounted) {
      setState(() {
        _locationState = const LifePaymentLocationState(
          phase: LifePaymentLocationPhase.checking,
        );
      });
    }
    final next = await LifePaymentLocationService.resolveOnEnter(context);
    if (!mounted) return;
    setState(() {
      _locationState = next;
      _locationResolving = false;
    });
  }

  bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final bg = AppColors.background(dark: dark);
    final overlay = immersiveOverlayForColors(
      statusBarBackground: AppColors.card(dark: dark),
      navigationBarBackground: bg,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          backgroundColor: AppColors.card(dark: dark),
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: overlay,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: AppTokens.accent,
            onPressed: () => Navigator.of(context).pop(),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(0.6),
            child: Container(height: 0.6, color: AppColors.line(dark: dark)),
          ),
          title: Text(
            '生活缴费',
            style: TextStyle(
              color: AppColors.text(dark: dark),
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = 22.w;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: 18.h),
              children: [
                SizedBox(height: 0.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: _HeroPanel(
                    dark: dark,
                    locationState: _locationState,
                    onRetryLocation: _resolveLocation,
                  ),
                ),
                SizedBox(height: 8.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: _ServicesSection(dark: dark, onTap: _openDetail),
                ),
                SizedBox(height: 20.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: _RecentPaymentsSection(
                    dark: dark,
                    records: _buildRecentRecords(),
                    monthPaidAmount: _homeData?.monthPaidAmount,
                  ),
                ),
                SizedBox(height: 8.h),
                LifePaymentWaveDecoration(dark: dark, height: 72.h),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 后端 service_type 与前端枚举的映射（electric 命名对齐队列契约）。
  static const Map<LifePaymentType, String> _serviceTypeKeys = {
    LifePaymentType.mobile: 'mobile',
    LifePaymentType.electricity: 'electric',
    LifePaymentType.water: 'water',
    LifePaymentType.gas: 'gas',
  };

  Future<void> _openDetail(LifePaymentType type) async {
    // 维护开关：后端未下发该服务或 enabled=false 时拦截入口，
    // 避免用户下单后在执行端必然失败（如水/燃气流程未验证期）。
    final services = _homeData?.services;
    if (services != null && services.isNotEmpty) {
      final key = _serviceTypeKeys[type];
      final matched = services.where((item) => item.serviceType == key);
      final service = matched.isEmpty ? null : matched.first;
      if (service != null && !service.enabled) {
        ToastUtils.toast(
          service.maintenanceMessage.isNotEmpty
              ? service.maintenanceMessage
              : '该服务维护中，暂时无法使用',
        );
        return;
      }
    }
    // 已绑定燃气户号时跳过单位选择页，直接进入与电费一致的「新增缴费 + 我的户号」页。
    // 这样用户能立刻看到已绑定卡片并继续缴费；没有有效绑定记录时维持原选择单位流程。
    GasProviderItem? boundGasProvider;
    if (type == LifePaymentType.gas) {
      boundGasProvider = await _loadBoundGasProvider();
      if (!mounted) return;
    }
    Navigator.of(context).push(
      AppMaterialPageRoute(
        builder: (_) {
          if (type.isMobile) return const MobileRechargePage();
          if (type == LifePaymentType.electricity) {
            return ElectricityPaymentPage(
              locationData: _locationState.data,
            );
          }
          if (type == LifePaymentType.water) {
            return WaterProviderSelectionPage(
              locationData: _locationState.data,
            );
          }
          if (type == LifePaymentType.gas) {
            if (boundGasProvider != null) {
              return GasPaymentPage(
                locationData: _locationState.data,
                initialProvider: boundGasProvider,
              );
            }
            return GasProviderSelectionPage(
              locationData: _locationState.data,
            );
          }
          return LifePaymentDetailPage(type: type);
        },
      ),
    );
  }

  /// 首页不应只因用户再次缴费而要求重选燃气单位。
  /// 读取本地已确认的档案，复用其城市/单位作为 GasPaymentPage 的初始选择。
  Future<GasProviderItem?> _loadBoundGasProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kGasServiceSpec.prefsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final records = decoded
          .whereType<Map>()
          .map((item) => UtilityAccountRecord.fromJson(
                Map<String, Object?>.from(item),
              ))
          .where((item) =>
              item.status == 'success' &&
              item.cityName.isNotEmpty &&
              item.providerName.isNotEmpty)
          .toList(growable: false);
      if (records.isEmpty) return null;
      final record = records.first;
      return GasProviderItem(
        city: record.cityName,
        providerName: record.providerName,
        searchKey: '${record.cityName}${record.providerName}',
      );
    } catch (_) {
      return null;
    }
  }

  /// 后端最近缴费订单转展示模型；后端数据未就绪时返回空列表（显示空态）。
  List<LifePaymentRecord> _buildRecentRecords() {
    final orders = _homeData?.recentOrders ?? const <LifePaymentRecentOrder>[];
    final records = <LifePaymentRecord>[];
    for (final order in orders) {
      final type = _serviceTypeKeys.entries
          .where((entry) => entry.value == order.serviceType)
          .map((entry) => entry.key)
          .toList();
      if (type.isEmpty) continue;
      records.add(LifePaymentRecord(
        type: type.first,
        account: order.accountMask,
        amount: order.amount,
        paidAt: DateTime.tryParse(order.createdAt) ?? DateTime.now(),
        status: _mapOrderStatus(order.orderStatus),
      ));
    }
    return records;
  }

  static LifePaymentRecordStatus _mapOrderStatus(String status) {
    switch (status) {
      case 'success':
        return LifePaymentRecordStatus.success;
      case 'failed':
      case 'retryable_failed':
        return LifePaymentRecordStatus.failed;
      default:
        return LifePaymentRecordStatus.pending;
    }
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.dark,
    required this.locationState,
    required this.onRetryLocation,
  });

  final bool dark;
  final LifePaymentLocationState locationState;
  final VoidCallback onRetryLocation;

  static double _heroTitleFontSize({
    required double width,
    required bool isDesktop,
  }) {
    final base = width * (isDesktop ? 0.066 : 0.078);
    return base.clamp(isDesktop ? 28.0 : 24.0, isDesktop ? 42.0 : 36.0);
  }

  static double _heroSubtitleFontSize({
    required double width,
    required bool isDesktop,
  }) {
    final base = width * (isDesktop ? 0.036 : 0.042);
    return base.clamp(isDesktop ? 15.0 : 13.0, isDesktop ? 22.0 : 18.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = width / _heroAspectRatio;
        final isDesktop = context.isDesktopFormFactor;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.rXl.r),
            boxShadow: dark
                ? null
                : [
                    BoxShadow(
                      color: AppTokens.appShadow(dark),
                      blurRadius: 12.r,
                      offset: Offset(0, 4.h),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.rXl.r),
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Transform.scale(
                    scale: 1.10,
                    child: Image.asset(
                      _heroAsset,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  Positioned(
                    left: (width * 0.055).clamp(14.0, 28.0),
                    // 右侧留给插画，避免「一站搞定 / 安全快捷」被裁切或压住。
                    right: width * 0.36,
                    top: height * 0.16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '便民缴费，一站搞定',
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: _heroTitleFontSize(
                                width: width,
                                isDesktop: isDesktop,
                              ),
                              fontWeight: FontWeight.w800,
                              height: 1.08,
                            ),
                          ),
                        ),
                        SizedBox(height: (height * 0.045).clamp(8.0, 16.0)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '手机充值 · 水电燃气 · 安全快捷',
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.94),
                              fontSize: _heroSubtitleFontSize(
                                width: width,
                                isDesktop: isDesktop,
                              ),
                              fontWeight: FontWeight.w500,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: (width * 0.055).clamp(14.0, 28.0),
                    bottom: 14.h,
                    child: _LocationChip(
                      dark: dark,
                      state: locationState,
                      onRetry: onRetryLocation,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LocationChip extends StatelessWidget {
  const _LocationChip({
    required this.dark,
    required this.state,
    required this.onRetry,
  });

  final bool dark;
  final LifePaymentLocationState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    switch (state.phase) {
      case LifePaymentLocationPhase.checking:
        return _chip(
          icon: SizedBox(
            width: 10.w,
            height: 10.w,
            child: const CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Colors.white,
            ),
          ),
          label: '定位中',
        );
      case LifePaymentLocationPhase.ready:
        return _chip(
          icon: const Icon(
            Icons.near_me_rounded,
            size: 11,
            color: Colors.white,
          ),
          label: _localizedLocationLabel(state.data),
        );
      case LifePaymentLocationPhase.denied:
      case LifePaymentLocationPhase.serviceDisabled:
      case LifePaymentLocationPhase.failed:
        return GestureDetector(
          onTap: onRetry,
          child: _chip(
            icon: const Icon(
              Icons.refresh_rounded,
              size: 11,
              color: Colors.white,
            ),
            label: '点击授权定位',
          ),
        );
    }
  }

  String _localizedLocationLabel(LifePaymentLocationData? data) {
    final raw = data?.locality?.trim().isNotEmpty == true
        ? data!.locality!.trim()
        : data?.displayLabel.trim() ?? '';
    if (raw.isEmpty) return '定位中';
    final normalized = raw
        .toLowerCase()
        .replaceAll('市', '')
        .replaceAll('city', '')
        .replaceAll(' ', '')
        .replaceAll('-', '');
    const cityMap = {
      'beijing': '北京市',
      'peking': '北京市',
      'shanghai': '上海市',
      'tianjin': '天津市',
      'chongqing': '重庆市',
      'hangzhou': '杭州市',
      'jinbian': '金边市',
      'phnompenh': '金边市',
      'vealsbov': '金边市',
      'guangzhou': '广州市',
      'shenzhen': '深圳市',
      'chengdu': '成都市',
      'xian': '西安市',
      'xi’an': '西安市',
      'nanjing': '南京市',
      'suzhou': '苏州市',
      'wuhan': '武汉市',
      'changsha': '长沙市',
      'zhengzhou': '郑州市',
      'qingdao': '青岛市',
      'xiamen': '厦门市',
    };
    final mapped = cityMap[normalized];
    if (mapped != null) return mapped;
    if (RegExp(r'[A-Za-z]').hasMatch(raw)) return '当前位置';
    return raw.endsWith('市') ? raw : '${raw}市';
  }

  Widget _chip({required Widget icon, required String label}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(AppTokens.rPill.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          SizedBox(width: 7.w),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServicesSection extends StatelessWidget {
  const _ServicesSection({required this.dark, required this.onTap});

  final bool dark;
  final ValueChanged<LifePaymentType> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 18.w,
              height: 18.w,
              child: GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 2.5,
                crossAxisSpacing: 2.5,
                physics: const NeverScrollableScrollPhysics(),
                children: List.generate(
                  9,
                  (_) => const DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFF1E90FF),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 16.w),
            Text(
              '缴费服务',
              style: TextStyle(
                color: LifePaymentTheme.text(dark),
                fontSize: 28.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SizedBox(height: 18.h),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final gap = width < 340 ? 8.w : 10.w;
            final stackGap = gap;
            final utilityToMobileRatio = 3 / _utilityAspectRatio;
            final leftWidth =
                (utilityToMobileRatio * (width - gap) + stackGap * 2) /
                    (1 + utilityToMobileRatio);
            final rightWidth = width - gap - leftWidth;
            final utilityHeight = rightWidth / _utilityAspectRatio;
            final leftHeight = utilityHeight * 3 + stackGap * 2;
            return SizedBox(
              height: leftHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: leftWidth,
                    child: _MobileServiceCard(
                      onTap: () => onTap(LifePaymentType.mobile),
                    ),
                  ),
                  SizedBox(width: gap),
                  SizedBox(
                    width: rightWidth,
                    child: Column(
                      children: [
                        SizedBox(
                          height: utilityHeight,
                          child: _UtilityServiceCard(
                            type: LifePaymentType.electricity,
                            title: '电费',
                            subtitle: '国网缴费',
                            asset: _electricityAsset,
                            accent: const Color(0xFFFF9500),
                            onTap: () => onTap(LifePaymentType.electricity),
                          ),
                        ),
                        SizedBox(height: stackGap),
                        SizedBox(
                          height: utilityHeight,
                          child: _UtilityServiceCard(
                            type: LifePaymentType.water,
                            title: '水费',
                            subtitle: '水务缴费',
                            asset: _waterAsset,
                            accent: const Color(0xFF1E90FF),
                            onTap: () => onTap(LifePaymentType.water),
                          ),
                        ),
                        SizedBox(height: stackGap),
                        SizedBox(
                          height: utilityHeight,
                          child: _UtilityServiceCard(
                            type: LifePaymentType.gas,
                            title: '燃气费',
                            subtitle: '燃气缴费',
                            asset: _gasAsset,
                            accent: const Color(0xFFFF3B30),
                            onTap: () => onTap(LifePaymentType.gas),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _MobileServiceCard extends StatelessWidget {
  const _MobileServiceCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ImageCard(
      asset: _mobileAsset,
      imageScale: 1.14,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(18.w, 0, 10.w, 0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '手机充值',
              style: TextStyle(
                color: const Color(0xFF1A1A1A),
                fontSize: 28.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              '三网通充',
              style: TextStyle(
                color: const Color(0xFF8A94A6),
                fontSize: 20.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 7.h),
            Container(
              width: 24.w,
              height: 3.h,
              decoration: BoxDecoration(
                color: const Color(0xFF1E90FF),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 20.h),
            _ArrowButton(color: const Color(0xFF1E90FF), filled: true),
          ],
        ),
      ),
    );
  }
}

class _UtilityServiceCard extends StatelessWidget {
  const _UtilityServiceCard({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.asset,
    required this.accent,
    required this.onTap,
  });

  final LifePaymentType type;
  final String title;
  final String subtitle;
  final String asset;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ImageCard(
      asset: asset,
      imageScale: 1.0,
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Padding(
            padding:
                EdgeInsets.only(left: constraints.maxWidth * 0.42, right: 38.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF1A1A1A),
                    fontSize: 26.sp,
                    fontWeight: FontWeight.w700,
                    height: 1.08,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF8A94A6),
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w500,
                    height: 1.08,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ImageCard extends StatelessWidget {
  const _ImageCard({
    required this.asset,
    required this.onTap,
    required this.child,
    this.imageScale = 1.0,
    this.imageFit = BoxFit.cover,
  });

  final String asset;
  final VoidCallback onTap;
  final Widget child;
  final double imageScale;
  final BoxFit imageFit;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.rMd.r),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTokens.rMd.r),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Transform.scale(
                  scale: imageScale,
                  child: Image.asset(
                    asset,
                    fit: imageFit,
                    filterQuality: FilterQuality.high,
                    gaplessPlayback: true,
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.color, this.filled = false});

  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final size = filled ? 46.w : 30.w;
    return Container(
      width: size,
      height: filled ? 36.h : size,
      decoration: BoxDecoration(
        color: filled ? color : Colors.white,
        borderRadius: BorderRadius.circular(AppTokens.rPill.r),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: filled ? 0.22 : 0.10),
            blurRadius: 8.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.arrow_forward_rounded,
        color: filled ? Colors.white : color,
        size: filled ? 20.w : 17.w,
      ),
    );
  }
}

class _RecentPaymentsSection extends StatelessWidget {
  const _RecentPaymentsSection({
    required this.dark,
    required this.records,
    this.monthPaidAmount,
  });

  final bool dark;
  final List<LifePaymentRecord> records;

  /// 后端下发的本月已缴金额；为空时回退为本地记录求和。
  final String? monthPaidAmount;

  double get _monthlyTotal => records.fold(
        0.0,
        (sum, record) => sum + (double.tryParse(record.amount) ?? 0),
      );

  String get _monthPaidText {
    final backend = double.tryParse(monthPaidAmount ?? '');
    return (backend ?? _monthlyTotal).toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final surface = dark ? LifePaymentTheme.card(dark) : Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppTokens.rCard.r),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: AppTokens.appShadow(dark),
                  blurRadius: 10.r,
                  offset: Offset(0, 4.h),
                ),
              ],
      ),
      padding: EdgeInsets.fromLTRB(32.w, 28.h, 32.w, 28.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5.w,
                height: 28.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E90FF),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  '最近缴费',
                  style: TextStyle(
                    color: LifePaymentTheme.text(dark),
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '全部',
                style: TextStyle(
                  color: LifePaymentTheme.subText(dark),
                  fontSize: 22.sp,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 28.w,
                color: LifePaymentTheme.subText(dark),
              ),
            ],
          ),
          SizedBox(height: 18.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: const Color(0xFF1E90FF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTokens.rPill.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E90FF),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.trending_up_rounded,
                    color: Colors.white,
                    size: 22.w,
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  '本月已缴 ¥$_monthPaidText',
                  style: TextStyle(
                    color: const Color(0xFF1E90FF),
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          if (records.isEmpty)
            AppEmptyState(
              message: '暂无最近缴费记录',
              imageWidth: 140.w,
              padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 16.w),
            )
          else
            ...records.map(
              (record) => _RecentPaymentItem(record: record, dark: dark),
            ),
        ],
      ),
    );
  }
}

class _RecentPaymentItem extends StatelessWidget {
  const _RecentPaymentItem({required this.record, required this.dark});

  final LifePaymentRecord record;
  final bool dark;

  String get _title {
    switch (record.type) {
      case LifePaymentType.mobile:
        return '手机充值';
      case LifePaymentType.electricity:
        return '电费';
      case LifePaymentType.water:
        return '水费';
      case LifePaymentType.gas:
        return '燃气费';
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = record.type.accentColor(dark);
    final dateText = DateFormat('MM-dd HH:mm').format(record.paidAt);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Row(
        children: [
          Container(
            width: 72.w,
            height: 72.w,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.20),
                  blurRadius: 10.r,
                  offset: Offset(0, 3.h),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(record.type.icon, color: Colors.white, size: 36.w),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: TextStyle(
                    color: LifePaymentTheme.text(dark),
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  '${record.account} | $dateText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: LifePaymentTheme.subText(dark),
                    fontSize: 20.sp,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Container(
            width: 12.w,
            height: 12.w,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          SizedBox(width: 12.w),
          Text(
            '-¥${record.amount}',
            style: TextStyle(
              color: LifePaymentTheme.text(dark),
              fontSize: 26.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 28.w,
            color: LifePaymentTheme.subText(dark),
          ),
        ],
      ),
    );
  }
}

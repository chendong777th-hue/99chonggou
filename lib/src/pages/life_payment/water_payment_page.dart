import 'dart:async' show unawaited;

import 'package:azlistview_all_platforms/azlistview_all_platforms.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:scrollable_positioned_list_for_us/scrollable_positioned_list_for_us.dart';
import 'package:tencent_cloud_chat_demo/src/pages/life_payment/life_payment_location_service.dart';
import 'package:tencent_cloud_chat_demo/src/pages/life_payment/life_payment_city_index_bar.dart';
import 'package:tencent_cloud_chat_demo/src/pages/life_payment/life_payment_theme.dart';
import 'package:tencent_cloud_chat_demo/src/pages/life_payment/utility_account_flow.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_responsive.dart';

class WaterProviderSelectionPage extends StatefulWidget {
  const WaterProviderSelectionPage({
    super.key,
    this.locationData,
    this.initialCity,
    this.returnSelection = false,
  });

  final LifePaymentLocationData? locationData;
  final String? initialCity;
  final bool returnSelection;

  @override
  State<WaterProviderSelectionPage> createState() =>
      _WaterProviderSelectionPageState();
}

class _WaterProviderSelectionPageState
    extends State<WaterProviderSelectionPage> {
  final TextEditingController _searchController = TextEditingController();
  late String _selectedCity;
  String _query = '';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCity?.trim();
    if (initial != null && initial.isNotEmpty) {
      _selectedCity = WaterProviderCatalog.locationLabelFromRaw(initial);
    } else {
      _selectedCity = WaterProviderCatalog.locationLabel(widget.locationData);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isSupportedCity =>
      WaterProviderCatalog.byCity(_selectedCity) != null;

  List<WaterProviderItem> get _providers {
    final items = WaterProviderCatalog.providersOf(_selectedCity);
    final normalized =
        _query.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (normalized.isEmpty) return items;
    return items.where((item) {
      return item.providerName.contains(_query.trim()) ||
          item.searchKey.contains(normalized);
    }).toList();
  }

  Future<void> _selectCity() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await Navigator.of(context).push<WaterCityOption>(
      MaterialPageRoute(
        builder: (_) => WaterCitySelectionPage(
          selectedCity: _selectedCity,
          locationLabel:
              WaterProviderCatalog.locationLabel(widget.locationData),
        ),
      ),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _selectedCity = picked.city;
      _query = '';
      _searchController.clear();
    });
  }

  void _handleProviderTap(WaterProviderItem item) {
    if (widget.returnSelection) {
      Navigator.of(context).pop(item);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WaterPaymentPage(
          locationData: widget.locationData,
          initialProvider: item,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textColor = LifePaymentTheme.text(dark);
    final subColor = LifePaymentTheme.subText(dark);
    final bg = LifePaymentTheme.background(dark);
    final overlay = LifePaymentTheme.systemOverlay(dark);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          foregroundColor: textColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: overlay,
          leading: IconButton(
            tooltip: '返回',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          titleSpacing: 0,
          title: Text(
            '选择缴费单位',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal =
                (constraints.maxWidth * 0.032).clamp(14.0, 30.0).toDouble();
            final titleSize =
                (constraints.maxWidth * 0.052).clamp(16.0, 24.0).toDouble();
            final labelSize = titleSize * 0.68;
            final providerSize = titleSize * 0.80;
            return SafeArea(
              top: false,
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      horizontal * 0.7,
                      horizontal,
                      horizontal * 0.4,
                    ),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: _selectCity,
                          borderRadius: BorderRadius.circular(labelSize * 0.8),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontal * 0.10,
                              vertical: horizontal * 0.22,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  WaterProviderCatalog.locationLabelFromRaw(
                                      _selectedCity),
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: providerSize,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: horizontal * 0.10),
                                Icon(
                                  Icons.arrow_drop_down_rounded,
                                  color: textColor,
                                  size: providerSize * 1.05,
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: horizontal * 0.32),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) =>
                                setState(() => _query = value),
                            style: TextStyle(
                                color: textColor, fontSize: labelSize * 1.05),
                            cursorColor: LifePaymentTheme.brandBlue,
                            decoration: InputDecoration(
                              hintText: '搜缴费单位名称',
                              hintStyle: TextStyle(color: subColor),
                              prefixIcon:
                                  Icon(Icons.search_rounded, color: subColor),
                              suffixIcon: _query.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: '清空',
                                      icon: Icon(Icons.close_rounded,
                                          color: subColor),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _query = '');
                                      },
                                    ),
                              filled: true,
                              fillColor: LifePaymentTheme.searchFill(dark),
                              border: OutlineInputBorder(
                                borderSide: BorderSide.none,
                                borderRadius:
                                    BorderRadius.circular(titleSize * 0.52),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: horizontal,
                                vertical: horizontal * 0.18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      0,
                      horizontal,
                      horizontal * 0.55,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: LifePaymentTheme.tipAmber,
                          size: labelSize * 1.18,
                        ),
                        SizedBox(width: horizontal * 0.14),
                        Expanded(
                          child: Text(
                            '可通过缴费账单或短信查看缴费单位',
                            style: TextStyle(
                              color: LifePaymentTheme.tipAmber,
                              fontSize: labelSize,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontal,
                      vertical: horizontal * 0.38,
                    ),
                    color: LifePaymentTheme.tipBannerBg(dark),
                    child: Text(
                      '99chat和缴费单位官方联合运营',
                      style: TextStyle(
                        color: LifePaymentTheme.tipBannerText(dark),
                        fontSize: labelSize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _providers.isEmpty
                        ? Center(
                            child: Padding(
                              padding: EdgeInsets.all(horizontal * 1.5),
                              child: Text(
                                _isSupportedCity ? '暂无可用缴费单位' : '该地区不支持',
                                style: TextStyle(
                                  color: subColor,
                                  fontSize: providerSize,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: _providers.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: LifePaymentTheme.formDivider(dark),
                            ),
                            itemBuilder: (context, index) {
                              final item = _providers[index];
                              return Material(
                                color: bg,
                                child: InkWell(
                                  onTap: () => _handleProviderTap(item),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: horizontal,
                                      vertical: horizontal * 0.86,
                                    ),
                                    child: Text(
                                      item.providerName,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: providerSize,
                                        fontWeight: FontWeight.w500,
                                        height: 1.28,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class WaterPaymentPage extends StatefulWidget {
  const WaterPaymentPage({
    super.key,
    this.locationData,
    required this.initialProvider,
  });

  final LifePaymentLocationData? locationData;
  final WaterProviderItem initialProvider;

  @override
  State<WaterPaymentPage> createState() => _WaterPaymentPageState();
}

class _WaterPaymentPageState extends State<WaterPaymentPage>
    with UtilityAccountFlowMixin {
  final TextEditingController _accountController = TextEditingController();
  late WaterProviderItem _selectedProvider;

  /// 后端 providers 接口返回的城市/单位编码；本地目录只有名称，
  /// 编码用于让后端与执行端精确路由，取不到时留空由名称兜底。
  String _cityCode = '';
  String _providerCode = '';

  @override
  UtilityServiceSpec get utilitySpec => kWaterServiceSpec;
  @override
  String get utilityCityName => _selectedProvider.city;
  @override
  String get utilityCityCode => _cityCode;
  @override
  String get utilityProviderName => _selectedProvider.providerName;
  @override
  String get utilityProviderCode => _providerCode;

  @override
  void initState() {
    super.initState();
    _selectedProvider = widget.initialProvider;
    loadUtilityAccountRecords();
    _resolveProviderCodes();
  }

  @override
  void dispose() {
    _accountController.dispose();
    super.dispose();
  }

  /// 用后端 providers 接口反查当前所选单位的编码；失败静默（名称仍可路由）。
  Future<void> _resolveProviderCodes() async {
    _cityCode = '';
    _providerCode = '';
    try {
      final providers = await utilityRepo.getProviders(
        serviceType: utilitySpec.serviceType,
        cityName: _selectedProvider.city,
        pageSize: 100,
      );
      if (!mounted) return;
      final matched = providers.where(
        (item) =>
            item.enabled && item.providerName == _selectedProvider.providerName,
      );
      if (matched.isNotEmpty) {
        setState(() {
          _cityCode = matched.first.cityCode;
          _providerCode = matched.first.providerCode;
        });
      }
    } catch (_) {
      // 编码仅是优化项，接口失败不打扰用户
    }
  }

  Future<void> _selectProvider() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await Navigator.of(context).push<WaterProviderItem>(
      MaterialPageRoute(
        builder: (_) => WaterProviderSelectionPage(
          locationData: widget.locationData,
          initialCity: _selectedProvider.city,
          returnSelection: true,
        ),
      ),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _selectedProvider = picked;
      _accountController.clear();
    });
    unawaited(_resolveProviderCodes());
  }

  void _showAccountHelp() {
    ToastUtils.toast('请通过${_selectedProvider.providerName}官方渠道获取户号');
  }

  Future<void> _bindAccount() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await bindUtilityAccount(_accountController.text);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    const brandBlue = LifePaymentTheme.brandBlue;
    final pageBackground = LifePaymentTheme.pageBackground(dark);
    final overlay = LifePaymentTheme.systemOverlay(dark);
    final textColor = LifePaymentTheme.text(dark);
    final appBarBg = LifePaymentTheme.card(dark);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: pageBackground,
        appBar: AppBar(
          backgroundColor: appBarBg,
          foregroundColor: textColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: overlay,
          leading: IconButton(
            tooltip: '返回',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          titleSpacing: 0,
          title: Text(
            '新增缴费',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal =
                (constraints.maxWidth * 0.032).clamp(14.0, 30.0).toDouble();
            final radius =
                (constraints.maxWidth * 0.042).clamp(16.0, 28.0).toDouble();
            final titleSize =
                (constraints.maxWidth * 0.058).clamp(18.0, 26.0).toDouble();
            final citySize =
                (constraints.maxWidth * 0.048).clamp(15.0, 22.0).toDouble();

            return SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        horizontal,
                        horizontal,
                        horizontal * 1.6,
                      ),
                      child: Column(
                        children: [
                          _WaterPaymentForm(
                            provider: _selectedProvider,
                            accountController: _accountController,
                            radius: radius,
                            titleSize: titleSize,
                            citySize: citySize,
                            onCityTap: _selectProvider,
                            onHelpTap: _showAccountHelp,
                            onAccountChanged: (_) => setState(() {}),
                          ),
                          SizedBox(height: horizontal),
                          UtilityAccountRecordList(
                            spec: utilitySpec,
                            records: accountRecords,
                            radius: radius,
                            titleSize: titleSize,
                            refreshingAccountNo: refreshingAccountNo,
                            onTap: onUtilityRecordTap,
                            onUnbind: confirmUnbindUtilityAccount,
                            onRefresh: refreshUtilityQueryResult,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        horizontal * 0.4,
                        horizontal,
                        horizontal * 0.6,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: utilitySubmitting ||
                                  _accountController.text.trim().isEmpty
                              ? null
                              : _bindAccount,
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: brandBlue,
                            disabledBackgroundColor:
                                LifePaymentTheme.disabledButton(dark),
                            foregroundColor: Colors.white,
                            disabledForegroundColor: Colors.white,
                            shape: const StadiumBorder(),
                            textStyle: TextStyle(
                              fontSize: titleSize * 0.68,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: Text(
                            utilitySubmitting
                                ? (utilityProgressText.isEmpty
                                    ? '绑定中...'
                                    : utilityProgressText)
                                : '绑定户号',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WaterPaymentForm extends StatelessWidget {
  const _WaterPaymentForm({
    required this.provider,
    required this.accountController,
    required this.radius,
    required this.titleSize,
    required this.citySize,
    required this.onCityTap,
    required this.onHelpTap,
    required this.onAccountChanged,
  });

  final WaterProviderItem provider;
  final TextEditingController accountController;
  final double radius;
  final double titleSize;
  final double citySize;
  final VoidCallback onCityTap;
  final VoidCallback onHelpTap;
  final ValueChanged<String> onAccountChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    const brandBlue = LifePaymentTheme.brandBlue;
    final labelSize = titleSize * 0.56;
    final providerSize = titleSize * 0.78;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF69AFFF), Color(0xFF177BF2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          radius * 0.78,
          radius * 0.70,
          radius * 0.78,
          radius * 0.78,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: citySize * 1.25,
                  height: citySize * 1.25,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.water_drop_rounded,
                    color: const Color(0xFF4A7CEB),
                    size: citySize * 0.86,
                  ),
                ),
                SizedBox(width: radius * 0.48),
                Text(
                  '水费',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: citySize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(radius),
                  onTap: onCityTap,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: radius * 0.22,
                      vertical: radius * 0.16,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          provider.city,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: citySize * 0.92,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: radius * 0.08),
                        Icon(
                          Icons.arrow_drop_down_rounded,
                          color: Colors.white,
                          size: citySize * 1.06,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: radius * 0.52),
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                radius * 0.72,
                radius * 0.82,
                radius * 0.72,
                radius * 0.92,
              ),
              decoration: BoxDecoration(
                color: LifePaymentTheme.formCard(dark),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(radius * 0.95),
                  bottom: Radius.circular(radius * 0.72),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '缴费单位',
                    style: TextStyle(
                      color: LifePaymentTheme.formLabel(dark),
                      fontSize: labelSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: radius * 0.34),
                  InkWell(
                    onTap: onCityTap,
                    borderRadius: BorderRadius.circular(radius * 0.36),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: radius * 0.10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              provider.providerName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: LifePaymentTheme.formValue(dark),
                                fontSize: providerSize,
                                fontWeight: FontWeight.w600,
                                height: 1.16,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: LifePaymentTheme.formChevron(dark),
                            size: providerSize * 1.25,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(
                    height: radius * 1.34,
                    color: LifePaymentTheme.formDivider(dark),
                  ),
                  Text(
                    '户号',
                    style: TextStyle(
                      color: LifePaymentTheme.formLabel(dark),
                      fontSize: labelSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: radius * 0.18),
                  TextField(
                    controller: accountController,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [LengthLimitingTextInputFormatter(32)],
                    onChanged: onAccountChanged,
                    style: TextStyle(
                      color: LifePaymentTheme.formValue(dark),
                      fontSize: providerSize * 0.90,
                      fontWeight: FontWeight.w500,
                    ),
                    cursorColor: brandBlue,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: radius * 0.28,
                      ),
                      hintText: '请输入户号',
                      hintStyle: TextStyle(
                        color: LifePaymentTheme.formHint(dark),
                        fontSize: providerSize * 0.90,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  Divider(
                    height: radius * 1.28,
                    color: LifePaymentTheme.formDivider(dark),
                  ),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: radius * 0.48,
                      vertical: radius * 0.35,
                    ),
                    decoration: BoxDecoration(
                      color: LifePaymentTheme.selectedSoft(dark),
                      borderRadius: BorderRadius.circular(radius * 0.44),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.home_outlined,
                          color: brandBlue,
                          size: providerSize * 0.80,
                        ),
                        SizedBox(width: radius * 0.24),
                        Expanded(
                          child: Text(
                            '快速获取户号',
                            style: TextStyle(
                              color: LifePaymentTheme.formValue(dark),
                              fontSize: labelSize * 0.98,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: onHelpTap,
                          style: TextButton.styleFrom(
                            backgroundColor: brandBlue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: radius * 0.54,
                              vertical: radius * 0.24,
                            ),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            '去获取',
                            style: TextStyle(
                              fontSize: labelSize * 0.82,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WaterCitySelectionPage extends StatefulWidget {
  const WaterCitySelectionPage({
    super.key,
    required this.selectedCity,
    this.locationLabel,
  });

  final String selectedCity;
  final String? locationLabel;

  @override
  State<WaterCitySelectionPage> createState() => _WaterCitySelectionPageState();
}

class _WaterCitySelectionPageState extends State<WaterCitySelectionPage> {
  final TextEditingController _searchController = TextEditingController();
  final ItemScrollController _itemScrollController = ItemScrollController();
  String _query = '';

  static const _hotCities = [
    '杭州',
    '北京',
    '上海',
    '广州',
    '深圳',
    '成都',
    '重庆',
    '天津',
    '南京',
    '苏州',
    '武汉',
    '西安',
    '澳门',
    '香港',
    '台北市',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<WaterCityOption> get _filteredCities {
    final normalized =
        _query.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (normalized.isEmpty) return WaterProviderCatalog.cityOptions;
    return WaterProviderCatalog.cityOptions.where((item) {
      return item.city.contains(_query.trim()) ||
          item.searchKey.contains(normalized);
    }).toList();
  }

  List<LifePaymentCityIndexItem<Object?>> _buildIndexItems({
    required List<WaterCityOption> cities,
    required bool searching,
  }) {
    final items = <LifePaymentCityIndexItem<Object?>>[];
    if (!searching) {
      items.add(LifePaymentCityIndexItem<Object?>(tagIndex: '@', data: null));
    }
    for (final city in cities) {
      items.add(LifePaymentCityIndexItem<Object?>(
        tagIndex: city.initial,
        data: city,
      ));
    }
    SuspensionUtil.setShowSuspensionStatus(items);
    return items;
  }

  List<String> _availableInitials(
      List<LifePaymentCityIndexItem<Object?>> items) {
    return items
        .map((item) => item.tagIndex)
        .where((tag) => tag != '@')
        .toSet()
        .toList()
      ..sort();
  }

  void _jumpToInitial(
    String initial,
    List<LifePaymentCityIndexItem<Object?>> items,
  ) {
    LifePaymentCityIndexBar.jumpToTag(
      controller: _itemScrollController,
      data: items,
      tag: initial,
    );
  }

  void _pick(WaterCityOption city) {
    Navigator.of(context).pop(city);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textColor = LifePaymentTheme.text(dark);
    final subColor = LifePaymentTheme.subText(dark);
    final bg = LifePaymentTheme.background(dark);
    final overlay =
        (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
            .copyWith(
      statusBarColor: bg,
      systemNavigationBarColor: bg,
      systemNavigationBarIconBrightness:
          dark ? Brightness.light : Brightness.dark,
    );
    final cities = _filteredCities;
    final searching = _query.trim().isNotEmpty;
    final indexItems = _buildIndexItems(cities: cities, searching: searching);
    final availableInitials = _availableInitials(indexItems);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          foregroundColor: textColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: overlay,
          leading: IconButton(
            tooltip: '返回',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          titleSpacing: 0,
          title: Text(
            '城市选择',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal =
                (constraints.maxWidth * 0.032).clamp(14.0, 30.0).toDouble();
            final titleSize =
                (constraints.maxWidth * 0.052).clamp(16.0, 24.0).toDouble();
            final sectionSize = titleSize * 0.70;

            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    horizontal * 0.8,
                    horizontal,
                    horizontal * 0.4,
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    textInputAction: TextInputAction.search,
                    style: TextStyle(
                      fontSize: sectionSize,
                      color: textColor,
                    ),
                    cursorColor: LifePaymentTheme.brandBlue,
                    decoration: InputDecoration(
                      hintText: '输入城市名、拼音或首字母查询',
                      hintStyle: TextStyle(color: subColor),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: subColor,
                      ),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: '清空',
                              icon: Icon(
                                Icons.close_rounded,
                                color: subColor,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                      filled: true,
                      fillColor: LifePaymentTheme.searchFill(dark),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(titleSize * 0.62),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: horizontal,
                        vertical: titleSize * 0.34,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: cities.isEmpty
                      ? Center(
                          child: Text(
                            '未找到支持缴费的城市',
                            style: TextStyle(
                              color: subColor,
                              fontSize: sectionSize,
                            ),
                          ),
                        )
                      : Stack(
                          children: [
                            AzListView(
                              data: indexItems,
                              itemCount: indexItems.length,
                              itemScrollController: _itemScrollController,
                              physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics(),
                              ),
                              padding: EdgeInsets.fromLTRB(
                                horizontal,
                                horizontal * 0.2,
                                searching
                                    ? horizontal
                                    : horizontal +
                                        LifePaymentCityIndexBar.barWidth,
                                horizontal * 1.4,
                              ),
                              indexBarData: const [],
                              susItemHeight: searching ? titleSize * 1.6 : 0.01,
                              susItemBuilder: searching
                                  ? (context, index) {
                                      final tag =
                                          indexItems[index].getSuspensionTag();
                                      if (tag == '@') {
                                        return const SizedBox.shrink();
                                      }
                                      return Container(
                                        height: titleSize * 1.6,
                                        alignment: Alignment.centerLeft,
                                        color: bg,
                                        padding: EdgeInsets.only(
                                          left: horizontal * 0.1,
                                        ),
                                        child: Text(
                                          tag,
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: titleSize * 0.88,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      );
                                    }
                                  : (context, index) => const SizedBox.shrink(),
                              itemBuilder: (context, index) {
                                final item = indexItems[index];
                                if (item.tagIndex == '@') {
                                  return _WaterCityHeaderBlock(
                                    dark: dark,
                                    locationLabel: widget.locationLabel,
                                    selectedCity: widget.selectedCity,
                                    hotCities: _hotCities,
                                    horizontal: horizontal,
                                    sectionSize: sectionSize,
                                    onPick: _pick,
                                  );
                                }
                                final city = item.data as WaterCityOption;
                                final showSectionHeader = !searching &&
                                    item.isShowSuspension &&
                                    item.tagIndex != '@';
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (showSectionHeader)
                                      Padding(
                                        padding: EdgeInsets.only(
                                          top: horizontal * 0.65,
                                          bottom: horizontal * 0.20,
                                        ),
                                        child: Text(
                                          item.tagIndex,
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: titleSize * 0.88,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    _WaterCityListTile(
                                      dark: dark,
                                      city: city,
                                      selected:
                                          city.city == widget.selectedCity,
                                      onTap: () => _pick(city),
                                      fontSize: sectionSize * 1.03,
                                    ),
                                  ],
                                );
                              },
                            ),
                            if (!searching && availableInitials.isNotEmpty)
                              LifePaymentCityIndexBar(
                                dark: dark,
                                availableInitials: availableInitials,
                                onSelect: (tag) =>
                                    _jumpToInitial(tag, indexItems),
                              ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WaterCityHeaderBlock extends StatelessWidget {
  const _WaterCityHeaderBlock({
    required this.dark,
    required this.locationLabel,
    required this.selectedCity,
    required this.hotCities,
    required this.horizontal,
    required this.sectionSize,
    required this.onPick,
  });

  final bool dark;
  final String? locationLabel;
  final String selectedCity;
  final List<String> hotCities;
  final double horizontal;
  final double sectionSize;
  final ValueChanged<WaterCityOption> onPick;

  @override
  Widget build(BuildContext context) {
    final subColor = LifePaymentTheme.subText(dark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: horizontal * 0.6),
        Text(
          '你所在的地区',
          style: TextStyle(
            color: subColor,
            fontSize: sectionSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: horizontal * 0.55),
        Align(
          alignment: Alignment.centerLeft,
          child: _WaterLocationCityChip(
            dark: dark,
            city: locationLabel,
            onTap: locationLabel == null ||
                    WaterProviderCatalog.byCity(locationLabel!) == null
                ? null
                : () {
                    final item = WaterProviderCatalog.byCity(locationLabel!);
                    if (item != null) onPick(item);
                  },
          ),
        ),
        SizedBox(height: horizontal * 1.35),
        Text(
          '热门城市',
          style: TextStyle(
            color: subColor,
            fontSize: sectionSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: horizontal * 0.65),
        _WaterHotCityGrid(
          dark: dark,
          cities: hotCities
              .map(WaterProviderCatalog.byCity)
              .whereType<WaterCityOption>()
              .toList(),
          selectedCity: selectedCity,
          onPick: onPick,
          labelSize: sectionSize,
        ),
        SizedBox(height: horizontal * 1.18),
      ],
    );
  }
}

class _WaterLocationCityChip extends StatelessWidget {
  const _WaterLocationCityChip({
    required this.dark,
    required this.city,
    this.onTap,
  });

  final bool dark;
  final String? city;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = city ?? '定位未开启';
    final isDesktop = context.isDesktopFormFactor;
    final horizontal = isDesktop ? 18.0 : 14.0;
    final vertical = isDesktop ? 12.0 : 9.0;
    final radius = isDesktop ? 12.0 : 10.0;
    final fg = LifePaymentTheme.text(dark);
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        disabledForegroundColor: fg,
        side: BorderSide(color: LifePaymentTheme.hairline(dark)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: horizontal,
          vertical: vertical,
        ),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: isDesktop ? 16.0 : 15.0,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _WaterHotCityGrid extends StatelessWidget {
  const _WaterHotCityGrid({
    required this.dark,
    required this.cities,
    required this.selectedCity,
    required this.onPick,
    required this.labelSize,
  });

  final bool dark;
  final List<WaterCityOption> cities;
  final String selectedCity;
  final ValueChanged<WaterCityOption> onPick;
  final double labelSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final preferredWidth = constraints.maxWidth * 0.23;
        final columns =
            (constraints.maxWidth / preferredWidth).floor().clamp(2, 4).toInt();
        final spacing = constraints.maxWidth * 0.025;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: 2.45,
          ),
          itemCount: cities.length,
          itemBuilder: (context, index) {
            final city = cities[index];
            final selected = city.city == selectedCity;
            return OutlinedButton(
              onPressed: () => onPick(city),
              style: OutlinedButton.styleFrom(
                foregroundColor: LifePaymentTheme.text(dark),
                backgroundColor: selected
                    ? LifePaymentTheme.selectedSoft(dark)
                    : LifePaymentTheme.card(dark),
                side: BorderSide(
                  color: selected
                      ? LifePaymentTheme.brandBlue
                      : LifePaymentTheme.hairline(dark),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(labelSize * 0.42),
                ),
                padding: EdgeInsets.zero,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  city.city,
                  style: TextStyle(
                    fontSize: labelSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _WaterCityListTile extends StatelessWidget {
  const _WaterCityListTile({
    required this.dark,
    required this.city,
    required this.selected,
    required this.onTap,
    required this.fontSize,
  });

  final bool dark;
  final WaterCityOption city;
  final bool selected;
  final VoidCallback onTap;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: fontSize * 0.86),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: LifePaymentTheme.hairline(dark)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  city.city,
                  style: TextStyle(
                    color: LifePaymentTheme.text(dark),
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_rounded,
                  color: LifePaymentTheme.brandBlue,
                  size: fontSize * 1.1,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class WaterProviderItem {
  const WaterProviderItem({
    required this.city,
    required this.providerName,
    required this.searchKey,
  });

  final String city;
  final String providerName;
  final String searchKey;
}

class WaterCityOption {
  const WaterCityOption({
    required this.city,
    required this.initial,
    required this.searchKey,
  });

  final String city;
  final String initial;
  final String searchKey;
}

class WaterProviderCatalog {
  WaterProviderCatalog._();

  static final List<WaterProviderItem> all = _buildProviders();
  static final List<WaterCityOption> cityOptions = _buildCityOptions();
  static final Map<String, List<WaterProviderItem>> _providersByCity =
      _groupProviders();

  static const initials = <String>[
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'J',
    'K',
    'L',
    'M',
    'N',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'W',
    'X',
    'Y',
    'Z',
  ];

  static List<WaterProviderItem> providersOf(String city) {
    final key = _normalizeCity(city);
    return List<WaterProviderItem>.unmodifiable(
        _providersByCity[key] ?? const []);
  }

  static WaterCityOption? byCity(String city) {
    final key = _normalizeCity(city);
    for (final item in cityOptions) {
      if (_normalizeCity(item.city) == key) return item;
    }
    return null;
  }

  static WaterCityOption? matchLocation(LifePaymentLocationData? data) {
    if (data == null) return null;
    final candidates = <String>[
      if (data.locality != null) data.locality!,
      if (data.displayLabel.isNotEmpty) data.displayLabel,
      if (data.administrativeArea != null) data.administrativeArea!,
    ];
    for (final raw in candidates) {
      final exact = byCity(raw);
      if (exact != null) return exact;

      final normalized = _normalizeCity(raw);
      for (final item in cityOptions) {
        if (normalized.contains(item.city) || raw.contains(item.city)) {
          return item;
        }
      }

      final latinKey = _normalizeLatinLocation(raw);
      if (latinKey.length >= 3) {
        for (final item in cityOptions) {
          if (item.searchKey.contains(latinKey)) {
            return item;
          }
        }
      }
    }
    return null;
  }

  static String locationLabel(LifePaymentLocationData? data) {
    if (data == null) return '选择城市';
    final matched = matchLocation(data);
    if (matched != null) return matched.city;

    final locality = data.locality?.trim() ?? '';
    if (locality.isNotEmpty) return locationLabelFromRaw(locality);
    final display = data.displayLabel.trim();
    return display.isEmpty ? '选择城市' : locationLabelFromRaw(display);
  }

  static String locationLabelFromRaw(String raw) {
    final matched = byCity(raw);
    if (matched != null) return matched.city;
    return _localizeKnownLocation(raw.trim().isEmpty ? '选择城市' : raw.trim());
  }

  static List<WaterProviderItem> _buildProviders() {
    return List<WaterProviderItem>.unmodifiable(
      _kWaterProviderRaw.map((item) {
        final city = item[0];
        final provider = item[1];
        final searchKey = _buildSearchKey(city, provider);
        return WaterProviderItem(
          city: city,
          providerName: provider,
          searchKey: searchKey,
        );
      }),
    );
  }

  static List<WaterCityOption> _buildCityOptions() {
    final seen = <String>{};
    final result = <WaterCityOption>[];
    for (final item in _kWaterProviderRaw) {
      final city = item[0];
      final normalized = _normalizeCity(city);
      if (!seen.add(normalized)) continue;

      // 搜索键明确分开保存：中文、完整拼音、完整首字母。
      // lpinyin 自带 getShortPinyin() 专门返回首字母：杭州 -> hz、北京 -> bj。
      // 不能从整段全拼中猜首字母，否则 hz / bj 在部分机型上会匹配失败。
      final fullPinyin = _pinyin(normalized);
      final shortPinyin = _shortPinyin(normalized);
      var initial = shortPinyin.isEmpty ? '#' : shortPinyin[0].toUpperCase();
      if (!RegExp(r'^[A-Z]$').hasMatch(initial)) initial = '#';
      result.add(
        WaterCityOption(
          city: city,
          initial: initial,
          searchKey: '${city.toLowerCase()}$fullPinyin$shortPinyin$initial'
              .replaceAll(RegExp(r'\s+'), '')
              .toLowerCase(),
        ),
      );
    }
    result.sort((a, b) {
      final ai =
          initials.contains(a.initial) ? initials.indexOf(a.initial) : 999;
      final bi =
          initials.contains(b.initial) ? initials.indexOf(b.initial) : 999;
      if (ai != bi) return ai.compareTo(bi);
      return a.searchKey.compareTo(b.searchKey);
    });
    return List<WaterCityOption>.unmodifiable(result);
  }

  static Map<String, List<WaterProviderItem>> _groupProviders() {
    final map = <String, List<WaterProviderItem>>{};
    for (final item in all) {
      final key = _normalizeCity(item.city);
      map.putIfAbsent(key, () => <WaterProviderItem>[]).add(item);
    }
    return map.map((key, value) {
      value.sort((a, b) => a.searchKey.compareTo(b.searchKey));
      return MapEntry(key, List<WaterProviderItem>.unmodifiable(value));
    });
  }

  static String _buildSearchKey(String city, String provider) {
    final cityPinyin = _pinyin(city);
    final providerPinyin = _pinyin(provider);
    return '${city.toLowerCase()}${provider.toLowerCase()}$cityPinyin$providerPinyin'
        .replaceAll(RegExp(r'\s+'), '')
        .toLowerCase();
  }

  static String _pinyin(String raw) {
    return PinyinHelper.getPinyinE(raw)
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toLowerCase();
  }

  static String _shortPinyin(String raw) {
    return PinyinHelper.getShortPinyin(raw)
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toLowerCase();
  }

  static String _localizeKnownLocation(String raw) {
    final key = _normalizeLatinLocation(raw);
    for (final item in cityOptions) {
      if (item.searchKey.contains(key) && key.isNotEmpty) return item.city;
    }
    const aliases = <String, String>{
      'phnompenh': '金边',
      'jinbian': '金边',
      'vealsbov': '金边',
      'hangzhou': '杭州',
      'beijing': '北京',
      'shanghai': '上海',
      'guangzhou': '广州',
      'shenzhen': '深圳',
      'chengdu': '成都',
      'chongqing': '重庆',
      'tianjin': '天津',
      'nanjing': '南京',
      'suzhou': '苏州',
      'wuhan': '武汉',
      'xian': '西安',
      'xianshi': '西安',
      'macau': '澳门',
      'hongkong': '香港',
      'taipei': '台北市',
    };
    return aliases[key] ?? raw;
  }

  static String _normalizeCity(String raw) {
    return raw
        .trim()
        .replaceAll('特别行政区', '')
        .replaceAll('自治区', '')
        .replaceAll('自治州', '')
        .replaceAll('地区', '')
        .replaceAll('盟', '')
        .replaceAll('省', '')
        .replaceAll('市', '');
  }

  static String _normalizeLatinLocation(String raw) {
    var value = raw.toLowerCase().trim();
    value = value
        .replaceAll('municipality', '')
        .replaceAll('autonomousregion', '')
        .replaceAll('autonomous region', '')
        .replaceAll('province', '')
        .replaceAll('prefecture', '')
        .replaceAll('district', '')
        .replaceAll('city', '');
    return value.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
}

const List<List<String>> _kWaterProviderRaw = <List<String>>[
  ['七台河', '勃利县清源供水有限责任公司'],
  ['三亚', '三亚环投清润供水有限公司'],
  ['三明', '尤溪水务有限公司'],
  ['三明', '永安市自来水有限责任公司'],
  ['三明', '福建恒源供水股份有限公司'],
  ['三明', '福建水投集团大田水务有限公司'],
  ['三明', '福建水投集团建宁水务有限公司'],
  ['三明', '福建水投集团明溪水务有限公司'],
  ['三明', '福建水投集团沙县水务有限公司'],
  ['三明', '福建水投集团泰宁水务有限公司'],
  ['三门峡', '三门峡市供水集团有限公司'],
  ['三门峡', '三门峡市陕州区自来水公司'],
  ['三门峡', '三门峡联合水务有限公司'],
  ['三门峡', '义马水务集团有限公司'],
  ['三门峡', '卢氏县自来水公司'],
  ['三门峡', '渑池县韶龙水务有限责任公司'],
  ['三门峡', '灵宝市金城水务有限责任公司'],
  ['上海', '上海南汇自来水有限公司[表号]'],
  ['上海', '上海嘉定外冈自来水厂'],
  ['上海', '上海嘉定沪翔自来水厂'],
  ['上海', '上海城投水务(集团)有限公司'],
  ['上海', '上海封浜自来水有限公司'],
  ['上海', '上海崇明自来水有限公司'],
  ['上海', '上海市北宝山自来水有限公司'],
  ['上海', '上海市嘉定自来水有限公司'],
  ['上海', '上海市松江自来水有限公司'],
  ['上海', '上海市自来水奉贤有限公司'],
  ['上海', '上海星火中法供水有限公司'],
  ['上海', '上海沪江自来水有限公司'],
  ['上海', '上海浦东威立雅自来水有限公司'],
  ['上海', '上海浦东新区自来水有限公司'],
  ['上海', '上海瀚达水务有限公司'],
  ['上海', '上海金山自来水有限公司'],
  ['上海', '上海青浦自来水有限公司'],
  ['上海', '嘉定区黄渡自来水厂'],
  ['上饶', '上饶市和济水务有限公司'],
  ['上饶', '上饶市广丰区丰溪自来水有限公司'],
  ['上饶', '上饶市广丰区城南供水有限公司'],
  ['上饶', '上饶市广信区福田自来水有限公司'],
  ['上饶', '上饶市自来水公司'],
  ['上饶', '上饶高铁经济试验区自来水'],
  ['上饶', '余干县供水有限责任公司'],
  ['上饶', '婺源县清华自来水厂'],
  ['上饶', '横峰供水'],
  ['上饶', '江西万年银龙水务有限责任公司'],
  ['上饶', '江西水务农场润泉'],
  ['上饶', '江西水务德兴润泉'],
  ['上饶', '江西省婺源润泉供水有限公司'],
  ['上饶', '江西省弋阳润泉供水有限公司'],
  ['上饶', '江西省鄱阳县自来水公司'],
  ['上饶', '玉山县自来水公司'],
  ['东莞', '东莞市水务环境投资控股集团供水有限公司'],
  ['东莞', '东莞市清溪粤海水务有限公司'],
  ['东莞', '东莞常平粤海水务有限公司'],
  ['东营', '东营市垦利区自来水公司'],
  ['东营', '东营市鲁辰水务有限责任公司'],
  ['东营', '东营鲁兴水务有限公司'],
  ['东营', '利津水务发展有限公司'],
  ['东营', '广饶县自来水公司'],
  ['中卫', '宁夏水投中卫水务有限公司'],
  ['中山', '中山公用水务投资有限公司'],
  ['中山', '中山坦洲自来水有限公司'],
  ['中山', '中山市小榄水务有限公司'],
  ['中山', '中山市新涌口粤海水务有限公司'],
  ['中山', '中山市横栏粤海水务有限公司'],
  ['中山', '中山翠亨新区水务有限公司'],
  ['临汾', '临汾市自来水有限公司'],
  ['临汾', '乡宁县城市供水有限公司'],
  ['临汾', '古县城乡水务有限公司'],
  ['临汾', '古县城市供水公司'],
  ['临汾', '安泽县自来水公司'],
  ['临汾', '曲沃县供水有限公司'],
  ['临汾', '永和县自来水有限责任公司'],
  ['临汾', '汾西县供水有限公司'],
  ['临汾', '洪洞县城市供水有限公司'],
  ['临汾', '洪洞县广胜寺镇润合水务有限公司'],
  ['临汾', '翼城县翼投水务有限公司'],
  ['临汾', '隰县供水公司'],
  ['临汾', '霍州市自来水有限责任公司'],
  ['临沂', '临沂实康水务有限公司'],
  ['临沂', '临沂市水务集团城区供水有限公司'],
  ['临沂', '临沂市润城水务有限公司'],
  ['临沂', '临沂市盛泉水务有限公司'],
  ['临沂', '临沂市罗新水务有限公司'],
  ['临沂', '临沂市罗泉水务有限公司'],
  ['临沂', '临沂市高新区新泉水务有限公司'],
  ['临沂', '临沂经开水务有限公司'],
  ['临沂', '临沂西新水务工程有限公司'],
  ['临沂', '临沂西新水务有限公司'],
  ['临沂', '临沂钦源自来水有限公司'],
  ['临沂', '临沭县城投自来水有限公司'],
  ['临沂', '兰陵县自来水公司'],
  ['临沂', '山东云蒙水务有限公司'],
  ['临沂', '平邑县润泽水务有限公司'],
  ['临沂', '平邑县自来水公司'],
  ['临沂', '沂南县阳都水务集团有限公司'],
  ['临沂', '莒南县大店供水有限公司'],
  ['临沂', '莒南县文疃供水有限公司'],
  ['临沂', '莒南县涝坡供水有限公司'],
  ['临沂', '莒南县相沟供水有限公司'],
  ['临沂', '莒南县相邸供水有限公司'],
  ['临沂', '费县和源水务有限公司'],
  ['临沂', '郯城县水务集团'],
  ['丹东', '东港市孤山镇自来水管理站'],
  ['丹东', '东港市自来水公司'],
  ['丹东', '丹东市临港产业园区自来水公司'],
  ['丹东', '丹东市水务发展集团有限责任公司'],
  ['丹东', '宽甸满族自治县自来水公司'],
  ['丽水', '松阳县润阳供水有限责任公司'],
  ['丽水', '缙云县壶镇供水有限公司'],
  ['丽水', '青田县水务有限公司'],
  ['丽江', '丽江市水务集团有限公司'],
  ['乌兰察布', '内蒙古兴和县丰华自来水有限公司'],
  ['乌兰察布', '内蒙古润川水务有限公司'],
  ['乌兰察布', '凉城县城镇供水中心(物联网表)'],
  ['乌兰察布', '卓资县生华供水有限责任公司'],
  ['乌兰察布', '察右中旗自来水公司'],
  ['乌兰察布', '察右前旗清源水务投资有限公司'],
  ['乌海', '乌海市乌达区水务集团有限公司'],
  ['乌海', '乌海市海勃湾城市供水有限公司'],
  ['乐山', '乐山市梓宇自来水有限公司'],
  ['乐山', '乐山市沙湾区华盈水务投资有限公司'],
  ['乐山', '乐山电力-自来水费'],
  ['乐山', '四川郡城水务集团有限公司（原犍为县江诚水务）'],
  ['九江', '九江市水务有限公司'],
  ['九江', '九江彭泽银龙水务有限公司'],
  ['九江', '庐山文控水务（原庐山自来水公司）'],
  ['九江', '彭泽县东升自来水有限公司'],
  ['九江', '武宁供水'],
  ['九江', '武宁农村供水有限公司'],
  ['九江', '武宁县横路自来水服务中心'],
  ['九江', '江西水务修水润泉'],
  ['九江', '江西水务共青城润泉'],
  ['九江', '江西水务庐山润泉'],
  ['九江', '江西水务德安润泉'],
  ['九江', '江西水务永修润泉'],
  ['九江', '江西水务湖口润泉'],
  ['九江', '江西水务瑞昌润泉'],
  ['九江', '江西水务都昌润泉'],
  ['九江', '湖口县自来水公司'],
  ['九江', '赣北水务'],
  ['云浮', '云安粤海城乡供水'],
  ['云浮', '云浮市粤海水务发展有限公司'],
  ['云浮', '云浮粤海水务有限公司'],
  ['云浮', '罗定粤海水务有限公司'],
  ['亳州', '亳州市自来水公司'],
  ['亳州', '亳州盛源水务有限公司'],
  ['亳州', '利辛县自来水公司'],
  ['亳州', '涡阳县乐行水务集团有限公司'],
  ['亳州', '蒙城县三义自来水厂'],
  ['亳州', '蒙城县惠民自来水有限公司篱笆水厂'],
  ['亳州', '蒙城自来水厂'],
  ['伊春', '南岔县供水服务中心'],
  ['伊春', '铁力市多元水务有限公司'],
  ['佛山', '佛山市禅城区供水有限公司'],
  ['佛山', '佛山市金沙佛水供水有限公司'],
  ['佛山', '佛山市顺德区供水有限公司'],
  ['佛山', '佛山新城供水有限公司'],
  ['佛山', '佛山水业三水供水有限公司'],
  ['佛山', '佛山水业集团高明供水有限公司'],
  ['佛山', '瀚蓝供水（南海）'],
  ['佳木斯', '佳木斯龙江环保供水有限公司'],
  ['佳木斯', '同江市自来水公司'],
  ['佳木斯', '富锦市城市供水有限责任公司'],
  ['佳木斯', '桦南县清源供水有限公司'],
  ['佳木斯', '汤原县自来水有限责任公司'],
  ['保定', '中国雄安集团水务有限公司'],
  ['保定', '保定徐润水务有限公司'],
  ['保定', '保定白沟新城泉润供水有限公司'],
  ['保定', '安国市自来水有限公司'],
  ['保定', '定州市东方供水有限公司'],
  ['保定', '定州市首创水务有限公司'],
  ['保定', '容城县益民供水有限公司'],
  ['保定', '易县供水'],
  ['保定', '曲阳县恒发供水有限公司'],
  ['保定', '涞水县自来水公司'],
  ['保定', '涿州市建投水务有限公司'],
  ['保定', '蠡县自来水公司'],
  ['保定', '阜平县供水站'],
  ['保定', '雄县供水有限责任公司'],
  ['保定', '高阳县润阳水务工程有限公司'],
  ['信阳', '信阳市供水集团有限公司'],
  ['信阳', '光山县自来水总公司'],
  ['信阳', '商城县城市供水有限责任公司'],
  ['信阳', '固始县自来水总公司'],
  ['信阳', '息县发投供水有限公司'],
  ['信阳', '新县自来水公司'],
  ['信阳', '淮滨县清泉自来水有限责任公司'],
  ['信阳', '潢川县白大山自来水厂'],
  ['信阳', '潢川县自来水公司'],
  ['信阳', '罗山县朱堂乡自来水厂'],
  ['信阳', '罗山县自来水有限责任公司'],
  ['儋州', '海南儋州粤海水务有限公司'],
  ['儋州', '海南儋州粤海自来水有限公司'],
  ['六安', '三十铺镇利民供水公司'],
  ['六安', '六安市城南供水有限公司'],
  ['六安', '六安市清泉水务有限公司'],
  ['六安', '六安市清源自来水有限公司'],
  ['六安', '六安市裕安区钱集供水站'],
  ['六安', '六安市裕安自来水厂'],
  ['六安', '六安市裕源供水有限责任公司'],
  ['六安', '姚李供水有限公司'],
  ['六安', '舒城县五显自来水厂'],
  ['六安', '舒城县杭城自来水有限公司'],
  ['六安', '舒城县自来水有限公司'],
  ['六安', '金寨金叶供水有限公司'],
  ['六安', '霍山县乡源供水有限公司'],
  ['六安', '霍山县清源供水有限责任公司'],
  ['六安', '霍邱县自来水有限责任公司'],
  ['六盘水', '六盘水市水城区供水有限公司'],
  ['六盘水', '盘州市东风自来水有限公司'],
  ['六盘水', '贵州水投水务盘州市有限责任公司'],
  ['兰州', '兰州城市供水（集团）有限公司'],
  ['兰州', '甘肃融泽水务有限责任公司'],
  ['内江', '兴泸水务集团'],
  ['内江', '内江市水务有限责任公司'],
  ['内江', '内江鑫亿水务有限责任公司'],
  ['内江', '威远县新店自来水厂'],
  ['内江', '资中县高楼集中供水站'],
  ['内江', '隆昌市泽源村镇供水有限公司'],
  ['内江', '隆昌市润泽水务有限公司'],
  ['包头', '内蒙古融通水务有限责任公司'],
  ['包头', '内蒙古远达水务有限公司'],
  ['包头', '包头市供水有限责任公司'],
  ['包头', '包头惠民水务股份有限公司'],
  ['包头', '土默特右旗自来水有限公司'],
  ['包头', '达茂旗茂源自来水有限责任公司'],
  ['北京', '北京兴怀供水有限公司'],
  ['北京', '北京市自来水集团有限责任公司'],
  ['北京', '北京燕龙供水有限公司'],
  ['北京', '北京融泽水务有限责任公司'],
  ['北京', '北京顺义自来水有限责任公司'],
  ['北京', '昌平自来水公司'],
  ['北海', '北海市铁山港区南康自来水厂'],
  ['北海', '广西北海市供水有限责任公司'],
  ['十堰', '丹江口市清源供水有限公司'],
  ['十堰', '十堰市城市供水有限公司'],
  ['十堰', '十堰市武当山水务有限公司'],
  ['十堰', '十堰市车城水务有限公司'],
  ['十堰', '十堰市郧阳区供水有限公司'],
  ['十堰', '竹山县自来水有限责任公司'],
  ['十堰', '老河口市清源供水有限公司'],
  ['南京', '南京丰源水务建设有限公司'],
  ['南京', '南京冶山水务有限公司'],
  ['南京', '南京市六合区城西自来水有限公司'],
  ['南京', '南京市六合区瓜埠自来水厂'],
  ['南京', '南京市江宁区湖熟自来水厂'],
  ['南京', '南京市溧水区自来水有限公司'],
  ['南京', '南京市高淳区漆桥自来水厂'],
  ['南京', '南京棠邑水务有限公司'],
  ['南京', '南京横梁水务有限公司'],
  ['南京', '南京水务集团有限公司'],
  ['南京', '南京江宁水务集团有限公司（银行代缴）'],
  ['南京', '南京泉水水务有限公司（竹镇）'],
  ['南京', '南京浦口自来水有限公司'],
  ['南京', '南京长芦水务有限公司'],
  ['南京', '南京青龙水务有限公司（金牛湖）'],
  ['南京', '南京龙池水务有限公司'],
  ['南京', '南京龙袍水务有限公司（东沟）'],
  ['南京', '南京龙袍水务有限公司（龙袍）'],
  ['南京', '高淳县丹湖自来水厂'],
  ['南京', '高淳县阳江镇沧溪自来水厂'],
  ['南充', '南充市高坪区东观镇自来水厂'],
  ['南充', '南部县城乡水务有限公司'],
  ['南充', '南部福康供水有限责任公司'],
  ['南充', '营山县乡镇供水站'],
  ['南宁', '上林县振林环保水务有限公司'],
  ['南宁', '宾阳县鲲鹏供水有限公司'],
  ['南宁', '广西农投水务廖平分公司'],
  ['南宁', '广西南宁北控水务有限公司'],
  ['南宁', '广西横州市东冠自来水有限公司'],
  ['南宁', '广西绿城水务集团股份有限公司'],
  ['南宁', '马山县绿源供水有限责任公司'],
  ['南平', '南平水务发展有限公司（延平区）'],
  ['南平', '厦门水务集团建瓯城建投资有限公司'],
  ['南平', '建瓯市新源供水有限责任公司'],
  ['南平', '武夷山市崇安自来水有限公司'],
  ['南平', '福建武夷水务发展有限公司(建阳区、武夷新区)'],
  ['南平', '福建浦开城乡水务有限公司'],
  ['南平', '邵武水务'],
  ['南平', '顺昌县水之城供水有限公司'],
  ['南昌', '南昌县供水有限责任公司'],
  ['南昌', '南昌县水投向塘供水有限公司'],
  ['南昌', '南昌县赣渤水务有限公司'],
  ['南昌', '江西水务农场润泉'],
  ['南昌', '江西水务新建润泉'],
  ['南昌', '江西水务桑海润泉'],
  ['南昌', '江西水务进贤润泉'],
  ['南通', '南通市海门区海永自来水厂'],
  ['南通', '南通市通州区水务有限公司'],
  ['南通', '南通水务集团有限公司'],
  ['南通', '南通海江供水有限公司'],
  ['南通', '启东市吕四自来水厂有限公司'],
  ['南通', '启东市自来水厂有限公司'],
  ['南通', '如东县东泽源供水有限公司'],
  ['南通', '如皋市自来水厂有限公司'],
  ['南通', '新天地供水'],
  ['南通', '海安市水务集团供水有限公司'],
  ['南通', '海门市自来水有限公司'],
  ['南阳', '内乡县自来水公司'],
  ['南阳', '内乡县自来水公司（汉威）'],
  ['南阳', '北控南阳水务集团有限公司'],
  ['南阳', '南召县水务服务中心'],
  ['南阳', '南阳北控天润水务有限公司'],
  ['南阳', '南阳官庄北控水务有限公司'],
  ['南阳', '唐河县自来水公司'],
  ['南阳', '方城县新裕自来水有限公司'],
  ['南阳', '桐柏县城区水务管理公司'],
  ['南阳', '桐柏县绿源水务有限公司'],
  ['南阳', '淅川县中州供水有限公司'],
  ['南阳', '社旗县自来水公司'],
  ['南阳', '西峡县自来水务有限公司'],
  ['南阳', '邓州市自来水有限公司'],
  ['南阳', '镇平县自来水公司'],
  ['厦门', '厦门市安兜自来水有限公司'],
  ['厦门', '厦门市政水务集团有限公司'],
  ['厦门', '厦门舫山供水有限公司'],
  ['双鸭山', '友谊县清源供水有限公司'],
  ['双鸭山', '双鸭山市自来水公司'],
  ['双鸭山', '饶河县龙源供水有限责任公司'],
  ['台州', '临海市供水有限公司'],
  ['台州', '台州市椒北供水有限公司'],
  ['台州', '台州市路桥自来水有限公司'],
  ['台州', '台州市黄岩城乡自来水有限公司'],
  ['台州', '台州市黄岩宁川供水有限公司'],
  ['台州', '台州椒江洪家自来水厂'],
  ['台州', '台州自来水有限公司'],
  ['台州', '天台县水务集团有限公司'],
  ['台州', '浙江永安水务集团有限公司'],
  ['台州', '温岭市供水有限公司'],
  ['台州', '温岭市泽国自来水有限公司'],
  ['台州', '玉环市自来水有限公司'],
  ['合肥', '三河自来水'],
  ['合肥', '合肥水务集团有限公司'],
  ['合肥', '合肥龙岗自来水'],
  ['合肥', '庐江县供水集团有限责任公司'],
  ['合肥', '磨墩供水'],
  ['合肥', '肥东县供水有限公司'],
  ['合肥', '肥西自来水有限公司'],
  ['合肥', '长丰县自来水有限责任公司'],
  ['吉安', '万安润安水务集团有限公司'],
  ['吉安', '井冈山市自来水有限公司'],
  ['吉安', '吉安水务集团有限公司'],
  ['吉安', '吉安银龙水务有限公司'],
  ['吉安', '安福县水务建设集团有限公司'],
  ['吉安', '峡江县玉华水务有限公司'],
  ['吉安', '新干县自来水'],
  ['吉安', '永丰城发水务有限公司'],
  ['吉安', '永新润泉供水公司'],
  ['吉安', '江西水务吉水润泉'],
  ['吉安', '泰和供水'],
  ['吉安', '遂川县源丰水务集团有限公司（牛头脑水厂）'],
  ['吉安', '遂川县自来水公司'],
  ['吉林', '吉林市水务股份有限公司'],
  ['吉林', '桦甸市自来水有限责任公司'],
  ['吉林', '永吉县和泰供水有限公司'],
  ['吉林', '磐石市供水公司'],
  ['吉林', '舒兰市水务有限责任公司'],
  ['吕梁', '中阳县供水服务中心'],
  ['吕梁', '交城县城镇供水有限公司'],
  ['吕梁', '兴县供水管理中心'],
  ['吕梁', '吕梁市供水公司'],
  ['吕梁', '山西省石楼县自来水公司'],
  ['吕梁', '文水县文兴水务有限公司'],
  ['吕梁', '柳林县自来水有限责任公司'],
  ['周口', '周口上善水务有限公司'],
  ['周口', '周口市淮阳区水务运营发展有限公司'],
  ['周口', '周口银龙水务有限公司'],
  ['周口', '商水县上善水务有限公司'],
  ['周口', '商水县浩源自来水发展有限公司'],
  ['周口', '太康县自来水供应公司'],
  ['周口', '扶沟银龙供水有限公司'],
  ['周口', '沈丘县康洁自来水有限公司'],
  ['周口', '沈丘县润丰自来水有限公司'],
  ['周口', '沈丘国投水务有限公司'],
  ['周口', '河南鹿邑银龙供水有限公司'],
  ['周口', '淮阳县自来水公司'],
  ['周口', '西华银龙供水有限公司'],
  ['周口', '郸城县自来水公司'],
  ['周口', '项城市国控水务发展有限公司'],
  ['周口', '项城市国控自来水有限公司'],
  ['周口', '项城市城乡水务发展有限公司'],
  ['呼伦贝尔', '新巴尔虎左旗鑫泰自来水'],
  ['呼伦贝尔', '鄂伦春自治旗大杨树自来水'],
  ['呼和浩特', '呼和浩特融通供水有限责任公司'],
  ['呼和浩特', '土默特左旗城投供水有限责任公司'],
  ['呼和浩特', '土默特左旗自来水（525智能水表）'],
  ['呼和浩特', '武川县城镇供水管理中心'],
  ['咸宁', '南川源水务'],
  ['咸宁', '咸宁思源水务有限公司'],
  ['咸宁', '咸宁联合水务有限公司'],
  ['咸宁', '崇阳县明春供水有限责任公司'],
  ['咸宁', '老河口市清源供水有限公司'],
  ['咸宁', '赤壁市乡镇水务投资运营有限公司'],
  ['咸宁', '赤壁市尚源供水有限公司'],
  ['咸宁', '通城城发水务集团有限公司'],
  ['咸宁', '通山县城乡供水有限公司'],
  ['咸阳', '咸阳经开城乡供水有限公司'],
  ['咸阳', '咸阳自来水有限公司'],
  ['咸阳', '咸阳高新供水水费缴纳'],
  ['咸阳', '陕西水务发展集团武功县供水有限公'],
  ['咸阳', '陕西西咸新区水务集团有限公司'],
  ['哈尔滨', '哈尔滨供水集团有限责任公司'],
  ['哈尔滨', '哈尔滨利民经济技术开发区自来水有限公司'],
  ['唐山', '乐亭县沁澈城南供水有限公司'],
  ['唐山', '京唐智慧港（唐山）自来水有限公司'],
  ['唐山', '凯发新泉水务遵化有限公司'],
  ['唐山', '唐山国盛水务有限公司'],
  ['唐山', '唐山市丰南区自来水公司'],
  ['唐山', '唐山市丰润区供水公司'],
  ['唐山', '唐山市曹妃甸供水有限责任公司'],
  ['唐山', '唐山市自来水公司'],
  ['唐山', '唐山海港开发区供水工程管理中心'],
  ['唐山', '建投南堡供水'],
  ['唐山', '滦州市城市供水中心'],
  ['唐山', '迁安市供水服务中心'],
  ['唐山', '迁安市自来水公司'],
  ['唐山', '迁西供水'],
  ['唐山', '遵化市国瑞供水有限责任公司'],
  ['商丘', '商丘市正源水务有限公司'],
  ['商丘', '商丘市正源水务有限公司示范区分公司'],
  ['商丘', '夏邑县佳明自来水厂'],
  ['商丘', '夏邑县北岭镇北岭自来水厂'],
  ['商丘', '夏邑县太平镇甘泉供水厂'],
  ['商丘', '夏邑县曹集乡净源供水厂'],
  ['商丘', '夏邑县胡桥自来水厂'],
  ['商丘', '夏邑县鑫源自来水厂'],
  ['商丘', '柘城县自来水厂'],
  ['商丘', '民权县水务公司'],
  ['商丘', '永城市供水集团有限公司'],
  ['商丘', '永城市水务发展有限公司'],
  ['商丘', '睢县中州供水有限公司'],
  ['商丘', '虞城县供水发展服务中心'],
  ['商洛', '山阳农村供水'],
  ['商洛', '洛南县自来水有限责任公司'],
  ['商洛', '镇安县自来水公司'],
  ['商洛', '陕西省水务集团丹凤县供水有限公司'],
  ['嘉兴', '嘉兴市自来水有限公司'],
  ['嘉兴', '嘉兴港区供水有限责任公司(乍浦)'],
  ['嘉兴', '嘉善县幽澜自来水有限公司'],
  ['嘉兴', '嘉善县水务投资有限公司'],
  ['嘉兴', '平湖市自来水有限公司'],
  ['嘉兴', '桐乡市凤栖自来水有限公司'],
  ['嘉兴', '海宁上塘水务有限公司'],
  ['嘉兴', '海宁市水务投资集团有限公司'],
  ['嘉兴', '海盐县天仙河自来水经营有限公司'],
  ['嘉峪关', '嘉峪关市益民通供水有限公司'],
  ['四平', '中核四平水务集团有限公司'],
  ['四平', '伊通满族自治县自来水公司'],
  ['大同', '大同市供水排水集团有限责任公司'],
  ['大同', '广灵县神泉供水有限责任公司'],
  ['大庆', '大庆市水务集团有限公司'],
  ['大庆', '大龙供水'],
  ['大庆', '林甸县自来水公司'],
  ['大庆', '肇源县农村供水（连心井）缴费平台'],
  ['大连', '大连市自来水集团有限公司'],
  ['大连', '大连旅开供水有限公司'],
  ['大连', '大连水务集团水资源公司长海供水'],
  ['大连', '大连花园供水有限公司'],
  ['天水', '天水市自来水有限责任公司'],
  ['天水', '武山县自来水有限公司'],
  ['天水', '甘肃水务甘谷供水有限责任公司'],
  ['天津', '天津临港工业区华滨水务有限公司'],
  ['天津', '天津华新水务有限公司'],
  ['天津', '天津塘沽中法供水有限公司'],
  ['天津', '天津宜达水务有限公司'],
  ['天津', '天津市中部新城水务有限公司'],
  ['天津', '天津市宁河区首创供水有限公司'],
  ['天津', '天津市安达供水有限公司'],
  ['天津', '天津市泉州水务有限公司'],
  ['天津', '天津市津北水务有限公司'],
  ['天津', '天津市瑞兴供水有限公司'],
  ['天津', '天津市自来水集团有限公司'],
  ['天津', '天津市蓟州区自来水供水有限公司'],
  ['天津', '天津市赛达水务有限公司'],
  ['天津', '天津市雍泉水务有限公司'],
  ['天津', '天津市首创水务有限责任公司'],
  ['天津', '天津泉兴水务有限公司'],
  ['天津', '天津泰达津联自来水有限公司'],
  ['天津', '天津津港水务有限公司'],
  ['天津', '天津生态城水务投资建设有限公司'],
  ['天津', '天津空港经济区水务有限公司'],
  ['天津', '天津雍盛源水务有限公司'],
  ['天津', '武清开发区自来水公司'],
  ['天津', '津南水务有限公司'],
  ['天津', '滨海水务大港油田水务分公司'],
  ['天津', '静海水务有限公司'],
  ['太原', '古交市城乡供水有限公司'],
  ['太原', '太原供水集团有限公司'],
  ['威海', '乳山市自来水有限公司'],
  ['威海', '威海市水务集团有限公司(不包含荣成)'],
  ['娄底', '冷水江市骏马自来水有限责任公司'],
  ['娄底', '双峰县自来水公司'],
  ['娄底', '安平镇自来水'],
  ['娄底', '新化北控水务有限公司'],
  ['娄底', '桥头河石狗自来水'],
  ['娄底', '涟源市株木自来水有限公司'],
  ['娄底', '涟源市桥头河镇城建供水站'],
  ['娄底', '涟源市自来水公司'],
  ['孝感', '云梦县波澜自来水有限公司'],
  ['孝感', '大悟县宣化店镇自来水公司'],
  ['孝感', '大悟县益源供水有限责任公司'],
  ['孝感', '孝感市自来水有限公司'],
  ['孝感', '孝昌县供水有限公司'],
  ['孝感', '安陆市浩源自来水有限公司'],
  ['孝感', '应城市和润自来水有限公司'],
  ['孝感', '汉川市城隍自来水有限公司'],
  ['孝感', '汉川市自来水公司'],
  ['孝感', '汉川市马口自来水公司'],
  ['孝感', '老河口市清源供水有限公司'],
  ['宁德', '福安市水投水务有限公司'],
  ['宁德', '福建水投集团宁德水务有限公司'],
  ['宁德', '福建水投集团屏南水务有限公司'],
  ['宁德', '福建水投集团柘荣水务有限公司'],
  ['宁德', '福建水投集团福安水务有限公司'],
  ['宁德', '福建水投集团福鼎水务有限公司'],
  ['宁德', '霞浦县福宁水务有限公司'],
  ['宁波', '余姚市姚东自来水有限公司'],
  ['宁波', '余姚市富陆自来水有限公司'],
  ['宁波', '余姚市泗门自来水有限公司'],
  ['宁波', '余姚市自来水有限公司'],
  ['宁波', '余姚市长丰自来水厂'],
  ['宁波', '余姚市隐溪自来水有限责任公司'],
  ['宁波', '宁波大榭开发区自来水有限公司'],
  ['宁波', '宁波市奉化区水务有限公司'],
  ['宁波', '宁波市奉化区萧王庙自来水厂'],
  ['宁波', '宁波市奉化溪口自来水有限公司'],
  ['宁波', '宁波市水务环境集团股份有限公司'],
  ['宁波', '宁波市鄞州瞻岐自来水有限公司'],
  ['宁波', '宁波杭州湾新区自来水有限公司'],
  ['宁波', '宁海县水务集团有限公司'],
  ['宁波', '慈溪市慈东自来水有限公司'],
  ['宁波', '慈溪市横河自来水厂'],
  ['宁波', '慈溪市自来水有限公司'],
  ['宁波', '象山县爵溪自来水有限公司'],
  ['宁波', '象山县第一自来水有限公司'],
  ['宁波', '象山县第三自来水有限公司'],
  ['宁波', '象山县第二自来水有限公司'],
  ['安庆', '北控水务（望江）有限公司'],
  ['安庆', '太湖县利源自来水厂'],
  ['安庆', '太湖县大石乡泊湖自来水厂'],
  ['安庆', '太湖县江塘自来水厂'],
  ['安庆', '太湖县牛镇兴利自来水厂'],
  ['安庆', '太湖县百里镇百康自来水厂'],
  ['安庆', '太湖县自来水有限责任公司'],
  ['安庆', '太湖县龙山水务投资有限公司'],
  ['安庆', '太湖县龙山腾达供水有限公司'],
  ['安庆', '安庆市伊秀水务有限责任公司'],
  ['安庆', '安庆水务集团有限公司'],
  ['安庆', '宿松下仓自来水有限公司'],
  ['安庆', '宿松县二郎镇自来水有限公司'],
  ['安庆', '宿松县兹元水务集团有限公司'],
  ['安庆', '宿松县华阳河自来水厂'],
  ['安庆', '宿松县城东自来水厂'],
  ['安庆', '宿松县复兴镇自来水供水有限公司'],
  ['安庆', '宿松县松兹自来水有限公司'],
  ['安庆', '岳西供水'],
  ['安庆', '岳西县店前自来水有限公司'],
  ['安庆', '岳西县菖蒲自来水有限公司'],
  ['安庆', '怀宁县黄墩自来水有限公司'],
  ['安庆', '怀宁城乡供水集团有限公司'],
  ['安庆', '望江县太慈镇沈冲自来水厂'],
  ['安庆', '望江县宏源自来水有限公司'],
  ['安庆', '望江县思源水务高士供水'],
  ['安庆', '望江县慈和自来水有限责任公司'],
  ['安庆', '望江县第二自来水有限责任公司'],
  ['安庆', '望江县雷池莲洲金红自来水厂'],
  ['安庆', '桐城市卅铺自来水有限责任公司'],
  ['安庆', '桐城市吕亭自来水有限公司'],
  ['安庆', '桐城市城乡供水集团有限公司'],
  ['安庆', '桐城市新渡自来水'],
  ['安庆', '桐城市青草自来水有限公司'],
  ['安庆', '潜山县双峰自来水有限公司'],
  ['安庆', '潜山县源潭自来水厂'],
  ['安庆', '潜山天柱山自来水公司'],
  ['安庆', '潜山市舒州供水集团有限公司'],
  ['安康', '安康水务集团有限公司'],
  ['安康', '岚皋县自来水公司'],
  ['安康', '紫阳县水务集团有限公司'],
  ['安康', '陕西水务发展集团汉阴县供水有限公司'],
  ['安康', '陕西省水务集团恒口供水有限公司'],
  ['安阳', '内黄县开源水务有限公司'],
  ['安阳', '内黄县源泉供水有限公司'],
  ['安阳', '安阳城乡水务集团有限公司'],
  ['安阳', '安阳源波供水公司'],
  ['安阳', '汤阴中州供水有限公司'],
  ['安阳', '滑县城市供水有限公司'],
  ['安顺', '普定首创水务有限公司'],
  ['安顺', '贵州水投关岭水务有限责任公司'],
  ['安顺', '贵州水投水务集团平坝有限公司'],
  ['安顺', '镇宁布依族苗族自治县自来水有限责任公司'],
  ['安顺', '黄果树水务公司'],
  ['定西', '定西水务城市供水有限公司'],
  ['定西', '渭源县农村供水'],
  ['定西', '漳县水务投资有限公司'],
  ['定西', '通渭县润襄水务有限公司'],
  ['定西', '陇西县首阳供水有限公司'],
  ['宜宾', '宜宾市二次供水公司'],
  ['宜宾', '宜宾市南溪区供水排水有限公司'],
  ['宜宾', '宜宾市叙州区嘉润供水有限责任公司'],
  ['宜宾', '宜宾市叙州区岷泉供水有限责任公司'],
  ['宜宾', '宜宾市叙州区金泉供水有限责任公司'],
  ['宜宾', '宜宾市清源水务集团有限公司'],
  ['宜宾', '宜宾市翠屏区万淼水务有限责任公司'],
  ['宜宾', '宜宾翠旅投集团水务发展有限公司'],
  ['宜宾', '志鸿自来水有限责任公司'],
  ['宜宾', '筠连县自来水有限责任公司'],
  ['宜昌', '三峡日新水务环保（秭归）有限公司'],
  ['宜昌', '五峰丰城水务有限公司渔洋关营业所'],
  ['宜昌', '兴山县自来水有限责任公司'],
  ['宜昌', '宜昌市分乡自来水厂'],
  ['宜昌', '宜昌市官庄自来水有限公司'],
  ['宜昌', '宜昌市泓淼自来水有限公司'],
  ['宜昌', '宜昌市鸦鹊岭自来水厂'],
  ['宜昌', '宜昌市黄花自来水有限公司'],
  ['宜昌', '宜昌桥边自来水公司'],
  ['宜昌', '宜昌民生供水有限责任公司'],
  ['宜昌', '宜昌浦华三峡水务有限公司'],
  ['宜昌', '宜都市供水有限公司'],
  ['宜昌', '宜都市陆城城东供水有限公司'],
  ['宜昌', '当阳市农村供水有限公司'],
  ['宜昌', '当阳市双莲供水有限公司'],
  ['宜昌', '当阳市自来水有限公司'],
  ['宜昌', '枝江市江口自来水厂'],
  ['宜昌', '枝江市活源供水服务有限公司'],
  ['宜昌', '枝江市港清水务有限公司'],
  ['宜昌', '枝江市金润源水务有限公司'],
  ['宜昌', '老河口市清源供水有限公司'],
  ['宜昌', '远安晟源供水有限责任公司'],
  ['宜昌', '长江三峡水务(宜昌)有限公司'],
  ['宜昌', '长阳丹水供水有限公司'],
  ['宜春', '丰城市供水有限责任公司'],
  ['宜春', '丰城市剑邑供水有限责任公司'],
  ['宜春', '宜春水务集团有限公司'],
  ['宜春', '樟树市供水有限公司'],
  ['宜春', '江西奉新城市供水有限责任公司'],
  ['宜春', '江西水务万载润泉'],
  ['宜春', '江西水务上高润泉'],
  ['宜春', '江西水务铜鼓润泉'],
  ['宜春', '靖安县潦河供水有限公司'],
  ['宝鸡', '凤县供水有限责任公司'],
  ['宝鸡', '宝鸡市自来水集团有限公司'],
  ['宝鸡', '宝鸡渭之水供水有限公司'],
  ['宝鸡', '眉县平阳自来水有限责任公司'],
  ['宝鸡', '陕西省水务发展集团麟游供水'],
  ['宣城', '宁国水务有限公司'],
  ['宣城', '宣城市双桥自来水厂'],
  ['宣城', '宣城市宣州区周王自来水厂'],
  ['宣城', '宣城市开源水务集团有限公司'],
  ['宣城', '宣城市新建自来水有限责任公司'],
  ['宣城', '宣城市新田自来水厂'],
  ['宣城', '宣城市水务有限公司'],
  ['宣城', '宣城市盛业自来水有限公司'],
  ['宣城', '宣城市黄渡自来水厂'],
  ['宣城', '宣城狸桥胜业自来水公司'],
  ['宣城', '广德市新东方水务有限公司'],
  ['宣城', '旌德县供水公司'],
  ['宣城', '旌德县新建自来水有限责任公司'],
  ['宣城', '泾县昌桥自来水厂'],
  ['宣城', '泾县自来水有限公司'],
  ['宣城', '绩溪县城市供水有限公司'],
  ['宣城', '郎溪郎源自来水有限责任公司'],
  ['宿州', '埇桥水务'],
  ['宿州', '安徽海纳水务有限公司'],
  ['宿州', '安徽磬乡水务有限公司'],
  ['宿州', '宿州市埇桥区金鑫自来水服务中心'],
  ['宿州', '宿州市徽泽水务有限公司'],
  ['宿州', '宿州市新区水务有限公司'],
  ['宿州', '宿州市水务集团有限公司'],
  ['宿州', '宿州市汴水源水务有限公司'],
  ['宿州', '宿州市清淼水务有限公司'],
  ['宿州', '宿州市鑫淼水务有限公司'],
  ['宿州', '泗县首创水务有限责任公司'],
  ['宿州', '灵璧县光明自来水厂'],
  ['宿州', '灵璧县惠民农村供水有限公司'],
  ['宿州', '砀山中环水务有限公司'],
  ['宿州', '萧县云水水务投资有限公司'],
  ['宿州', '萧县彤萍自来水厂（高庄水厂）'],
  ['宿州', '萧县民生水务有限公司'],
  ['宿州', '萧县永源自来水有限公司'],
  ['宿州', '萧县深岩水务有限公司'],
  ['宿州', '萧县碧水星城供水有限公司'],
  ['宿州', '萧县祖楼自来水厂'],
  ['宿州', '萧县青龙镇高丹自来水厂'],
  ['宿迁', '江苏新源水务有限公司'],
  ['宿迁', '江苏浦华沭源自来水有限公司'],
  ['宿迁', '江苏深水水务有限公司'],
  ['宿迁', '江苏联合水务科技股份有限公司'],
  ['宿迁', '沭阳县城乡水务发展有限公司'],
  ['宿迁', '泗洪博世科水务有限公司'],
  ['宿迁', '泗洪县集泰自来水有限公司'],
  ['山南', '山南市自来水总公司'],
  ['岳阳', '东山自来水厂'],
  ['岳阳', '临湘市桃林自来水有限公司'],
  ['岳阳', '临湘市自来水'],
  ['岳阳', '云河城乡水务平台'],
  ['岳阳', '华容县自来水有限责任公司'],
  ['岳阳', '岳阳县洞庭供水有限公司'],
  ['岳阳', '岳阳县洞庭供水有限公司（麻塘镇片区）'],
  ['岳阳', '岳阳市屈原供水有限公司'],
  ['岳阳', '岳阳市自来水公司'],
  ['岳阳', '岳阳市钱粮湖自来水有限公司'],
  ['岳阳', '岳阳核兴水务有限公司（君山）'],
  ['岳阳', '平江县润恒自来水有限公司'],
  ['岳阳', '汨罗市川山自来水有限公司'],
  ['岳阳', '汨罗市自来水公司'],
  ['岳阳', '湖南汨罗市桥坪自来水有限公司'],
  ['岳阳', '湘阴粤海水务有限公司'],
  ['崇左', '大新县水利供水有限公司'],
  ['崇左', '天等县水利供水有限公司'],
  ['崇左', '广西扶绥县自来水有限责任公司'],
  ['崇左', '龙州县水利供水有限公司'],
  ['巴彦淖尔', '乌拉特后旗塞北源供水有限责任公司'],
  ['巴彦淖尔', '五原县自来水公司'],
  ['巴彦淖尔', '磴口县丰华供水有限公司'],
  ['巴彦淖尔', '磴口县清泉自来水有限责任公司'],
  ['常州', '常州通用自来水有限公司'],
  ['常州', '江河港武水务（常州）有限公司'],
  ['常州', '溧阳市上黄自来水管理有限公司'],
  ['常州', '溧阳新源水务有限公司'],
  ['常州', '溧阳水务集团有限公司'],
  ['常州', '金坛市自来水公司'],
  ['常德', '临澧县常澧水务有限公司'],
  ['常德', '临澧县自来水公司'],
  ['常德', '临澧新安安康自来水公司'],
  ['常德', '常德市自来水有限责任公司'],
  ['常德', '常德市鼎城区自来水有限责任公司'],
  ['常德', '常德津市北控城乡水务有限公司'],
  ['常德', '桃源县自来水公司'],
  ['常德', '桃源县陬市镇自来水厂'],
  ['常德', '汉寿北控中科水务有限责任公司'],
  ['常德', '汉寿县自来水公司'],
  ['常德', '津市市灵泉兴辉自来水厂'],
  ['常德', '澧县自来水公司'],
  ['常德', '石门县自来水公司'],
  ['常德', '鼎城区蔡家岗镇迪成北自来水厂'],
  ['平凉', '甘肃源通城乡自来水水费'],
  ['平顶山', '中国平煤集团供水总厂'],
  ['平顶山', '叶县国源水务有限公司'],
  ['平顶山', '宝丰县银龙水务有限公司'],
  ['平顶山', '平顶山天安煤业供水分公司'],
  ['平顶山', '平顶山市城乡水务运营有限公司'],
  ['平顶山', '平顶山市新城水务有限公司'],
  ['平顶山', '平顶山市明润二次供水服务有限公司'],
  ['平顶山', '平顶山市自来水有限公司'],
  ['平顶山', '平顶山市贺嘉二次供水开发有限公司'],
  ['平顶山', '平顶山自来水二次供水有限公司'],
  ['平顶山', '汝州市自来水发展有限公司'],
  ['平顶山', '舞钢市天源水务有限责任公司'],
  ['平顶山', '郏县银龙水务有限公司'],
  ['平顶山', '鲁山县银龙水务有限公司'],
  ['广元', '广元市国开水务有限公司'],
  ['广元', '旺苍县水务建设发展有限公司'],
  ['广元', '昭化区通达自来水有限责任公司'],
  ['广元', '朝天供水'],
  ['广安', '武胜县嘉陵水务服务有限公司'],
  ['广州', '增城新和自来水有限公司'],
  ['广州', '广州从化自来水有限公司'],
  ['广州', '广州南沙粤海水务有限公司'],
  ['广州', '广州市增城自来水有限公司'],
  ['广州', '广州市穗云自来水有限公司'],
  ['广州', '广州市自来水有限公司'],
  ['广州', '广州新泉自来水有限公司'],
  ['庆阳', '正宁县供水有限责任公司'],
  ['庆阳', '镇原县农村供水有限公司'],
  ['廊坊', '三河北控燕郊自来水有限公司'],
  ['廊坊', '大厂国信城乡供水有限公司'],
  ['廊坊', '廊坊市清泉供水临空自贸区分公司'],
  ['廊坊', '廊坊市清泉供水有限责任公司'],
  ['廊坊', '霸州市新胜供水有限公司'],
  ['廊坊', '霸州财信水务有限公司'],
  ['延安', '延安新区市政公司水务中心直饮水'],
  ['延安', '延安新区市政公司水务中心自来水'],
  ['延安', '延安水务环保集团宜川自来水有限公司'],
  ['延安', '延安水务环保集团自来水公司'],
  ['延安', '陕西省水务集团洛川县供水有限公司'],
  ['延安', '陕西省水务集团甘泉县水务有限公司'],
  ['延安', '黄龙县城乡供水公司'],
  ['开封', '兰考县中州水务有限公司'],
  ['开封', '兰考良龙水务有限公司'],
  ['开封', '尉氏县自来水公司'],
  ['开封', '尉氏县金财水务有限公司'],
  ['开封', '开封市城市水务集团有限公司'],
  ['开封', '杞县自来水公司'],
  ['开封', '通许县碧泉自来水有限公司'],
  ['张家口', '张家口市宣化供水有限责任公司'],
  ['张家口', '张家口市政水务有限责任公司'],
  ['张家口', '怀安县供水公司'],
  ['张家口', '怀来县自来水管理处'],
  ['张家口', '涿鹿县供水公司'],
  ['张家界', '张家界市永定区湘源自来水公司'],
  ['张家界', '张家界市自来水公司'],
  ['张家界', '慈利县溇澧城乡供水'],
  ['张家界', '慈利县自来水公司'],
  ['张家界', '桑植县自来水公司'],
  ['张掖', '张掖市甘州区水务营管平台'],
  ['徐州', '徐州市泉城水务有限公司'],
  ['徐州', '徐州市铜山区自来水有限公司'],
  ['徐州', '徐州康宏供水有限责任公司'],
  ['徐州', '徐州经济技术开发区水务有限公司'],
  ['徐州', '徐州首创水务有限责任公司'],
  ['徐州', '新沂市乡镇供水有限公司'],
  ['徐州', '新沂市自来水有限公司'],
  ['徐州', '江苏汉之源水务有限公司'],
  ['徐州', '沛县兴蓉水务发展有限公司'],
  ['徐州', '沛县清源供水有限公司'],
  ['徐州', '沛县清源供水有限公司杨屯镇分公司'],
  ['徐州', '睢宁县自来水有限公司'],
  ['徐州', '邳州水务有限责任公司'],
  ['徐州', '邳州粤海水务有限公司'],
  ['德州', '凯发新泉自来水德州有限公司'],
  ['德州', '夏津财金水务投资发展有限公司'],
  ['德州', '宁津惠宁供水'],
  ['德州', '山东昌源水务发展有限公司'],
  ['德州', '德州公用水务有限公司'],
  ['德州', '德州市润通水务有限公司'],
  ['德州', '武城县瑞丰水务有限公司'],
  ['德州', '武城瑞源城乡供水'],
  ['德州', '禹城市润禹水务有限公司（乡镇）'],
  ['德州', '禹城市润禹水务有限公司（城区）'],
  ['德州', '陵城区康润供水有限公司'],
  ['德阳', '什邡国润供水有限公司'],
  ['德阳', '德阳市潺亭水务有限公司'],
  ['德阳', '德阳市自来水公司'],
  ['德阳', '生环水务(中江)有限公司'],
  ['忻州', '五台山景源供水'],
  ['忻州', '原平市自来水有限公司'],
  ['忻州', '宁武县供水有限责任公司'],
  ['忻州', '定襄县华襄水务有限公司'],
  ['忻州', '定襄县自来水服务中心'],
  ['忻州', '忻州市水务有限责任公司'],
  ['忻州', '繁峙县砂河镇供水中心'],
  ['怀化', '中方县鸿源自来水有限责任公司'],
  ['怀化', '会同县供水'],
  ['怀化', '怀化市洪江区自来水有限责任公司'],
  ['怀化', '怀化市自来水有限公司'],
  ['怀化', '沅陵县自来水有限公司'],
  ['怀化', '洪江市供水有限公司'],
  ['怀化', '洪江市安江自来水公司'],
  ['怀化', '芷江侗族自治县自来水'],
  ['怀化', '通道侗族自治县自来水公司'],
  ['怀化', '靖州苗族侗族自治县自来水公司'],
  ['怀化', '麻阳长河农村供水有限责任公司'],
  ['惠州', '博罗县长盛水务有限公司罗阳分公司'],
  ['惠州', '惠东县安墩镇自来水厂'],
  ['惠州', '惠东县高潭五指嶂供水有限公司'],
  ['惠州', '惠州市东部供水有限公司'],
  ['惠州', '惠州市供水有限公司'],
  ['惠州', '惠州水务集团惠东水务有限公司'],
  ['惠州', '惠州水务集团惠阳水务有限公司'],
  ['惠州', '惠州水口思源自来水费'],
  ['成都', '北控彭州自来水有限公司'],
  ['成都', '四川瑞云水务投资经营管理有限公司'],
  ['成都', '大邑县瑞云水务有限公司'],
  ['成都', '崇州市聚源供水有限责任公司'],
  ['成都', '崇州市自来水有限责任公司'],
  ['成都', '崇州首创水务有限公司'],
  ['成都', '彭州市生源供水管理有限公司'],
  ['成都', '成都兴蓉沱源自来水有限责任公司'],
  ['成都', '成都市中兴供水有限公司'],
  ['成都', '成都市岷江自来水厂'],
  ['成都', '成都市自来水有限责任公司'],
  ['成都', '成都市香源供水有限责任公司'],
  ['成都', '成都首创水务有限公司'],
  ['成都', '新津区花源自来水有限公司'],
  ['成都', '新津海天水务有限公司'],
  ['成都', '简阳海天水务有限公司'],
  ['成都', '都江堰岷江水务集团有限公司'],
  ['成都', '都江堰科技产业开发区自来水公司'],
  ['成都', '首创水务崇州分公司'],
  ['扬州', '仪征市水达供水有限公司'],
  ['扬州', '仪征市长江自来水有限公司'],
  ['扬州', '仪征粤海水务有限公司'],
  ['扬州', '宝应县汇丰水务有限公司'],
  ['扬州', '宝应粤海水务有限公司'],
  ['扬州', '扬州市湖西供水有限责任公司'],
  ['扬州', '扬州江源供水有限公司'],
  ['扬州', '江苏长江水务股份有限公司(扬州城区)'],
  ['扬州', '江苏长江水务股份有限公司（银行代缴）'],
  ['扬州', '江都自来水有限公司'],
  ['扬州', '高邮市润邮供水有限公司'],
  ['扬州', '高邮粤海水务有限公司'],
  ['承德', '围场满族蒙古族自治县自来水'],
  ['承德', '平泉市溥泽供水有限公司'],
  ['承德', '承德供水集团有限公司'],
  ['承德', '承德县盛源供水服务有限公司'],
  ['承德', '承德市双滦区滦江供水有限公司'],
  ['承德', '承德市鹰手营子矿区自来水公司'],
  ['承德', '承德润蓝水务有限公司'],
  ['承德', '滦平供水'],
  ['抚州', '乐安县樟泉供水有限公司'],
  ['抚州', '南丰县白舍自来水厂'],
  ['抚州', '崇仁县公共供水有限公司'],
  ['抚州', '抚州公用水务有限公司'],
  ['抚州', '江西水务东临润泉'],
  ['抚州', '江西水务东乡润泉'],
  ['抚州', '江西水务临川润泉'],
  ['抚州', '江西水务南丰润泉'],
  ['抚州', '江西水务南城润泉'],
  ['抚州', '江西水务宜黄润泉'],
  ['抚州', '江西水务广昌润泉'],
  ['抚州', '江西水务资溪润泉'],
  ['抚州', '江西水务金溪润泉'],
  ['抚州', '黎川县供水公司'],
  ['抚顺', '抚顺同盛水务有限公司'],
  ['抚顺', '抚顺市供水（集团）有限公司'],
  ['拉萨', '当雄县自来水有限责任公司'],
  ['拉萨', '拉萨市堆龙德庆区龙腾水务有限公司'],
  ['拉萨', '拉萨市自来水公司'],
  ['揭阳', '揭西粤海水务有限公司'],
  ['揭阳', '揭阳粤海水务有限公司'],
  ['攀枝花', '攀枝花市水务（集团）有限公司'],
  ['新乡', '卫辉市供水有限责任公司'],
  ['新乡', '原阳县城市供水有限公司'],
  ['新乡', '封丘县自来水有限公司'],
  ['新乡', '延津中州供水有限公司'],
  ['新乡', '延津首创水务有限公司'],
  ['新乡', '新乡县本源自来水有限公司'],
  ['新乡', '新乡市金盛水务有限公司'],
  ['新乡', '新乡首创水务有限责任公司'],
  ['新乡', '河南丽华水务有限公司'],
  ['新乡', '辉县市供水有限责任公司'],
  ['新乡', '长垣市首创水务有限公司'],
  ['新余', '分宜银龙水务有限公司'],
  ['新余', '新余水务集团有限公司'],
  ['无锡', '宜兴水务集团有限公司'],
  ['无锡', '无锡市水务集团有限公司'],
  ['无锡', '江苏江南水务股份有限公司（江阴）'],
  ['日照', '五莲县水务集团有限公司'],
  ['日照', '日照岚源水务有限公司'],
  ['日照', '日照市水务集团供水有限公司'],
  ['日照', '日照市禹泉供水有限公司'],
  ['日照', '莒县自来水公司'],
  ['昆明', '寻甸回族彝族自治县自来水厂'],
  ['昆明', '昆明市晋宁区自来水有限责任公司'],
  ['昆明', '昆明水务集团（清源公司）'],
  ['昆明', '昆明水务集团（通用水务)'],
  ['昆明', '昆明粤海水务有限公司'],
  ['昆明', '昆明通用水务自来水有限公司（银行渠道）'],
  ['昆明', '石林县城市供水有限公司'],
  ['昭通', '巧家县供水有限责任公司'],
  ['昭通', '彝良县洛泽河镇自来水有限责任公司'],
  ['昭通', '昭通市靖桉水投水务产业有限公司'],
  ['昭通', '盐津明丰供水有限公司'],
  ['昭通', '绥江县自来水厂'],
  ['昭通', '镇雄县自来水有限公司'],
  ['昭通', '鲁甸县水投水务产业有限公司'],
  ['晋中', '寿阳县自来水公司'],
  ['晋中', '左权县辽润城乡供水有限公司'],
  ['晋中', '平遥县东源供水有限公司'],
  ['晋中', '平遥碧源供水有限公司'],
  ['晋中', '昔阳县自来水有限公司'],
  ['晋中', '晋中供水有限责任公司'],
  ['晋中', '晋中市太谷区自来水有限公司'],
  ['晋中', '榆社县自来水公司'],
  ['晋城', '晋城市自来水有限公司'],
  ['晋城', '沁水县自来水有限公司'],
  ['晋城', '阳城县星海自来水有限公司'],
  ['晋城', '陵川县晋泽源供水有限公司'],
  ['晋城', '高平市清泉供水有限公司'],
  ['普洱', '普洱市水务有限责任公司'],
  ['普洱', '西盟水务有限责任公司'],
  ['景德镇', '江西水务乐平润泉'],
  ['景德镇', '江西水务浮梁润泉'],
  ['景德镇', '江西省景德镇水务有限责任公司'],
  ['曲靖', '会泽县城乡供水总厂'],
  ['曲靖', '富源县自来水有限责任公司'],
  ['曲靖', '师宗自来水有限公司'],
  ['曲靖', '曲靖市水务投资有限公司'],
  ['曲靖', '曲靖泽沣水务有限公司'],
  ['朔州', '右玉县供水保障中心'],
  ['朔州', '应县城乡供水总公司'],
  ['朝阳', '凌源供水'],
  ['朝阳', '喀左县自来水公司'],
  ['朝阳', '朝阳市自来水有限责任公司'],
  ['本溪', '本溪满族自治县自来水公司'],
  ['本溪', '辽宁辽东水务经营管理有限责任公司'],
  ['本溪', '辽宁辽水供水有限公司'],
  ['来宾', '来宾市自来水有限公司'],
  ['来宾', '象州县自来水公司有限责任公司'],
  ['杭州', '建德市大同新昌自来水有限公司'],
  ['杭州', '建德市水务有限公司'],
  ['杭州', '杭州临安水务有限公司'],
  ['杭州', '杭州余杭水务控股集团有限公司'],
  ['杭州', '杭州富阳水务有限公司'],
  ['杭州', '杭州市临安区农村水务资产经营有限公司'],
  ['杭州', '杭州市水务集团有限公司'],
  ['杭州', '杭州建德自来水有限公司'],
  ['杭州', '杭州滨江水务有限公司'],
  ['杭州', '杭州萧山供水有限公司'],
  ['杭州', '桐庐水务有限公司'],
  ['杭州', '桐庐泓源水务有限公司'],
  ['杭州', '淳安县水务有限公司'],
  ['松原', '扶余市自来水公司'],
  ['松原', '松原市自来水有限公司'],
  ['松原', '长岭县水务有限公司'],
  ['林芝', '察隅县自来水有限责任公司'],
  ['林芝', '朗县自来水有限公司'],
  ['枣庄', '山东国晟水务有限公司'],
  ['枣庄', '山东晟润供水有限公司'],
  ['枣庄', '枣庄上善自来水有限公司'],
  ['枣庄', '枣庄大禹供水有限公司'],
  ['枣庄', '枣庄市中区水务有限公司'],
  ['枣庄', '枣庄市汇泉供水有限责任公司'],
  ['枣庄', '枣庄市润禹水务供水有限公司'],
  ['枣庄', '枣庄汇深供水有限公司'],
  ['枣庄', '滕州市中润供水有限公司'],
  ['柳州', '三江侗族自治县农投供水有限公司'],
  ['柳州', '广西农投水务柳州分公司'],
  ['柳州', '柳州市自来水有限责任公司'],
  ['柳州', '融水苗族自治县自来水厂'],
  ['株洲', '株洲市水务投资集团有限公司'],
  ['株洲', '株洲高科水务环境科技有限公司'],
  ['株洲', '湖南攸州水务有限公司'],
  ['株洲', '炎陵县供水中心'],
  ['株洲', '炎陵县自来水公司'],
  ['株洲', '茶陵县云阳自来水有限公司'],
  ['株洲', '茶陵县洣云水务有限公司'],
  ['株洲', '茶陵县自来水公司'],
  ['株洲', '醴陵市瓷城水务发展有限公司'],
  ['桂林', '兴安县自来水公司'],
  ['桂林', '恭城瑶族自治县自来水公司'],
  ['桂林', '桂林城乡环境水务有限公司'],
  ['桂林', '灌阳县水利供水有限公司'],
  ['桂林', '灵川县自来水公司'],
  ['梅州', '丰顺粤海水务有限公司'],
  ['梅州', '五华县华康供水有限公司'],
  ['梅州', '兴宁市齐昌供水有限公司'],
  ['梅州', '兴新供水'],
  ['梅州', '平远粤海水务有限公司'],
  ['梅州', '梅州市梅县区雁洋自来水有限公司'],
  ['梅州', '梅州粤海水务有限公司'],
  ['梅州', '龙村供水'],
  ['梧州', '岑溪市水利供水有限公司'],
  ['梧州', '梧州粤海江河水务有限公司'],
  ['梧州', '苍梧县苍城水务有限公司'],
  ['梧州', '藤县水利供水有限公司'],
  ['榆林', '府谷县自来水公司'],
  ['榆林', '榆林市自来水公司'],
  ['榆林', '榆林高新区水务有限责任公司水费'],
  ['榆林', '神木市自来水有限责任公司'],
  ['榆林', '绥德县自来水公司'],
  ['榆林', '陕西省水务集团子洲县供水有限公司'],
  ['武汉', '武汉市东西湖自来水公司'],
  ['武汉', '武汉市保民供水实业有限公司'],
  ['武汉', '武汉市新洲区长源供水有限公司'],
  ['武汉', '武汉市水务集团有限公司'],
  ['武汉', '武汉市江夏区水务发展有限公司'],
  ['武汉', '武汉市蔡甸区张湾街自来水厂'],
  ['武汉', '武汉市蔡甸区玉贤自来水厂'],
  ['武汉', '武汉新道鸿观供水有限公司'],
  ['武汉', '武汉水务集团有限公司（银行渠道）'],
  ['武汉', '武汉蔡甸区奓山自来水有限公司'],
  ['武汉', '武汉车谷供水实业有限公司'],
  ['武汉', '武汉长江供水实业股份有限公司'],
  ['武汉', '武汉长江供水实业股份有限公司（银行渠道）'],
  ['武汉', '武汉长江现代水务发展有限公司'],
  ['武汉', '武汉鲁控水务有限公司'],
  ['武汉', '武汉黄陂上实水务有限公司'],
  ['武汉', '老河口市清源供水有限公司'],
  ['毕节', '纳雍泽泉水务有限公司'],
  ['毕节', '贵州毕节水务有限责任公司'],
  ['毕节', '贵州水投水务威宁乡镇供水公司'],
  ['毕节', '贵州水投水务集团大方有限公司'],
  ['毕节', '贵州水投水务集团威宁乡镇供水'],
  ['毕节', '贵州水投水务集团赫章有限公司'],
  ['毕节', '贵州水投水务集团金沙有限公司'],
  ['毕节', '金沙弘禹供水有限责任公司'],
  ['永州', '东安县自来水有限公司'],
  ['永州', '双牌县水务建设投资有限公司'],
  ['永州', '宁远县自来水公司'],
  ['永州', '新田县自来水公司'],
  ['永州', '永州市回龙圩管理区雷井自来水有限公司'],
  ['永州', '永州市水务运营'],
  ['永州', '永州市金洞银山水务有限公司'],
  ['永州', '江华供水'],
  ['永州', '江华瑶族自治县自来水'],
  ['永州', '江永县城乡供水有限公司'],
  ['永州', '祁阳市自来水有限责任公司'],
  ['永州', '祁阳碧水源水务有限公司'],
  ['永州', '蓝山县自来水公司'],
  ['永州', '道县自来水有限责任公司'],
  ['永州', '零陵自来水'],
  ['汉中', '镇巴县自来水公司'],
  ['汉中', '陕西水务发展集团洋县供水有限公司'],
  ['汉中', '陕西省水务集团佛坪县供水有限公司'],
  ['汕头', '汕头市澄海区益民水务有限公司'],
  ['汕头', '汕头市粤海水务有限公司'],
  ['汕头', '汕头市粤海水务有限公司（银行代缴）'],
  ['汕尾', '汕尾市红海湾供水有限公司'],
  ['汕尾', '汕尾粤海水务有限公司'],
  ['汕尾', '海丰县水务集团有限公司'],
  ['汕尾', '深圳市深汕特别合作区深水水务有限公司'],
  ['汕尾', '陆丰市双坑供水有限公司'],
  ['汕尾', '陆丰市河西自来水有限公司'],
  ['汕尾', '陆丰市自来水公司'],
  ['汕尾', '陆河县供水公司'],
  ['江门', '台山市自来水有限公司'],
  ['江门', '开平市龙胜自来水厂'],
  ['江门', '开平润福供水有限公司'],
  ['江门', '江门公用水务环境股份有限公司'],
  ['江门', '江门市滨江供水有限公司'],
  ['江门', '江门市睦州润源供水有限公司'],
  ['池州', '东至供水'],
  ['池州', '东至县东流自来水厂'],
  ['池州', '东至县泽农供水有限责任公司'],
  ['池州', '东至龙江供水'],
  ['池州', '池州临江水务有限公司'],
  ['池州', '池州市供水有限公司'],
  ['池州', '池州市大渡口供水有限公司'],
  ['池州', '池州市贵池区晏塘自来水厂'],
  ['池州', '池州金桥水务有限公司'],
  ['池州', '石台县供水有限公司'],
  ['沈阳', '新民市自来水总公司'],
  ['沈阳', '沈阳水务集团'],
  ['沈阳', '沈阳胜科水务'],
  ['沈阳', '沈阳近海水务发展有限公司'],
  ['沈阳', '沈阳锦北水务有限公司'],
  ['沧州', '东光县水务局供水公司'],
  ['沧州', '任丘供水'],
  ['沧州', '南皮县城乡供水有限公司'],
  ['沧州', '孟村回族自治县供水排水集团有限公司'],
  ['沧州', '沧州南大港供水有限公司'],
  ['沧州', '沧州市供水排水集团有限公司'],
  ['沧州', '沧州渤海新区供水排水有限公司'],
  ['沧州', '沧州青县城乡供水股份有限公司'],
  ['沧州', '河间供水排水有限责任公司'],
  ['沧州', '泊头润泊供水有限公司'],
  ['沧州', '献县自来水公司'],
  ['沧州', '盐山县供水排水有限责任公司'],
  ['沧州', '肃宁县供水公司'],
  ['沧州', '青县农网供水服务有限公司'],
  ['沧州', '黄骅市供水公司'],
  ['沧州', '黄骅市瑞通供水有限公司'],
  ['河池', '天峨县农投供水有限公司'],
  ['河池', '巴马瑶族自治县自来水有限责任公司'],
  ['河池', '广西南丹城乡水务有限公司'],
  ['河池', '广西大化北投环保水务有限公司'],
  ['河池', '都安瑶族自治县水利供水有限公司'],
  ['河源', '东源县城仙塘自来水厂'],
  ['河源', '河源市粤海水务有限公司'],
  ['河源', '河源市粤海水务有限公司东源分公司'],
  ['河源', '连平县忠信镇桥南岗自来水厂'],
  ['河源', '连平县自来水公司'],
  ['泉州', '南安市仑苍联兴供水有限公司'],
  ['泉州', '德化县自来水有限公司'],
  ['泉州', '惠安县城乡供水有限责任公司'],
  ['泉州', '晋江市金井金泉自来水有限公司'],
  ['泉州', '泉州台商投资区自来水有限公司'],
  ['泉州', '泉州安平供水有限公司'],
  ['泉州', '泉州市晋江永源自来水有限公司'],
  ['泉州', '泉州市自来水有限公司'],
  ['泉州', '泉州永春水务有限公司'],
  ['泉州', '泉州永春水务有限公司（乡镇）'],
  ['泉州', '泉州金浦供水有限公司'],
  ['泉州', '泉港区水利水务建设发展有限公司'],
  ['泉州', '福建省南安市水头供水有限公司'],
  ['泉州', '福建省南安市自来水公司'],
  ['泉州', '福建省安溪县自来水有限公司'],
  ['泉州', '福建省晋江自来水股份有限公司'],
  ['泉州', '福建省石狮供水股份有限公司'],
  ['泰安', '东平县润城供水有限公司'],
  ['泰安', '新泰市惠民供水有限公司'],
  ['泰安', '新泰市新汶自来水有限公司'],
  ['泰安', '新泰市自来水有限公司'],
  ['泰安', '泰安市东平县智慧供水服务有限公司'],
  ['泰安', '泰安市安通供水工程有限责任公司'],
  ['泰安', '泰安市恒通水务有限公司'],
  ['泰安', '泰安市自来水有限公司'],
  ['泰安', '肥城市桃乡供水有限公司'],
  ['泰安', '肥城市桃都供水有限公司'],
  ['泰州', '兴化城投供水集团-区域供水'],
  ['泰州', '兴化市兴合供水'],
  ['泰州', '兴化市城投供水（集团）有限公司'],
  ['泰州', '兴化市永丰供水'],
  ['泰州', '兴化市自来水总公司'],
  ['泰州', '泰兴市自来水有限公司'],
  ['泰州', '泰州市姜城水务有限责任公司'],
  ['泰州', '泰州市姜堰区张甸供水服务有限公司'],
  ['泰州', '泰州市水务有限公司'],
  ['泰州', '泰州市永安自来水有限公司'],
  ['泰州', '泰州市润溱水务有限公司'],
  ['泰州', '泰州市淤溪供水服务有限公司'],
  ['泰州', '泰州市金源水务有限公司'],
  ['泰州', '泰州市高港自来水有限公司'],
  ['泰州', '泰州龙源水务'],
  ['泰州', '苏陈顺和水务'],
  ['泰州', '靖江市华汇水务集团有限公司'],
  ['泸州', '兴泸水务集团'],
  ['泸州', '叙永县春海供水有限公司'],
  ['洛阳', '伊川县万泉自来水有限公司'],
  ['洛阳', '宜阳县水务集团有限公司'],
  ['洛阳', '嵩县湖城水务有限公司'],
  ['洛阳', '嵩县银基水务有限公司'],
  ['洛阳', '新安县淼源水务有限公司'],
  ['洛阳', '栾川县自来水有限公司'],
  ['洛阳', '汝阳县龙泉水务有限公司'],
  ['洛阳', '洛阳北控水务集团有限公司'],
  ['洛阳', '洛阳吉利自来水公司'],
  ['洛阳', '洛阳市亳源水务集团有限责任公司'],
  ['洛阳', '洛阳市洛宁县禹魂自来水有限公司'],
  ['洛阳', '洛阳市洛新水务有限公司'],
  ['洛阳', '洛阳汇兴水务有限公司'],
  ['济南', '商河智慧供水服务有限公司'],
  ['济南', '山东龙兴供水有限公司'],
  ['济南', '平阴县生源供水有限责任公司'],
  ['济南', '平阴县自来水公司'],
  ['济南', '济南东泉供水有限公司'],
  ['济南', '济南南美水务有限公司(济南南部山区)'],
  ['济南', '济南市济阳区农发供水有限公司'],
  ['济南', '济南市章丘区自来水有限公司'],
  ['济南', '济南市莱芜区智慧供水服务有限公司'],
  ['济南', '济南市钢城区双山自来水中心'],
  ['济南', '济南市钢城区昌源水务集团有限公司'],
  ['济南', '济南水务集团'],
  ['济南', '济南鲁中水务集团农村供水有限公司'],
  ['济南', '济南鲁中水务集团有限公司'],
  ['济宁', '嘉祥公用水务有限公司'],
  ['济宁', '微山县水务公司'],
  ['济宁', '曲阜市自来水公司'],
  ['济宁', '梁山公用水务有限公司'],
  ['济宁', '汶上公用水务有限公司'],
  ['济宁', '泗水公用水务有限公司'],
  ['济宁', '泗水县泗河水务有限公司'],
  ['济宁', '济中水务'],
  ['济宁', '济宁中山公用水务有限公司'],
  ['济宁', '济宁兖州区公用水务有限公司'],
  ['济宁', '济宁市汶上县康达自来水有限公司'],
  ['济宁', '济宁新城自来水有限公司'],
  ['济宁', '邹城市自来水有限公司'],
  ['济宁', '金乡县金思泉水务有限公司'],
  ['济宁', '鱼台县水费（贤达水务）'],
  ['海东', '循化县自来水费'],
  ['海东', '民和县城乡供水有限公司'],
  ['海东', '海东市水务集团有限责任公司'],
  ['海口', '海口开源水务有限公司'],
  ['淄博', '山东省沂源县自来水有限公司'],
  ['淄博', '桓台县万泉供水有限责任公司'],
  ['淄博', '淄博圣水源自来水供水厂'],
  ['淄博', '淄博天润供水有限公司'],
  ['淄博', '淄博市博山区津源供水有限责任公司'],
  ['淄博', '淄博市天齐渊供水有限公司'],
  ['淄博', '淄博市自来水有限责任公司'],
  ['淄博', '淄博星辰供水有限公司'],
  ['淄博', '高青丰源水务有限公司'],
  ['淮北', '淮北市供水有限责任公司'],
  ['淮北', '濉溪供水有限责任公司'],
  ['淮北', '濉溪县思源供水有限公司'],
  ['淮北', '濉溪县自来水公司'],
  ['淮北', '濉溪县自来水公司开发区分公司'],
  ['淮南', '凤台华水水务有限责任公司'],
  ['淮南', '凤台县泉润自来水有限公司'],
  ['淮南', '淮南市民利自来水销售有限公司'],
  ['淮南', '淮南毛集首创水务有限责任公司'],
  ['淮南', '淮南首创水务'],
  ['淮安', '井源水务（洪泽）有限公司'],
  ['淮安', '洪泽区自来水公司'],
  ['淮安', '涟水县涟缘水务有限公司'],
  ['淮安', '润湖水务'],
  ['淮安', '淮安市淮安区农村供水有限公司'],
  ['淮安', '淮安市淮阴自来水有限公司'],
  ['淮安', '淮安自来水有限公司'],
  ['淮安', '盱眙粤海水务有限公司'],
  ['淮安', '金湖县自来水有限责任公司'],
  ['深圳', '深圳市大工业区水务有限公司'],
  ['深圳', '深圳市大鹏新区环水水务有限公司'],
  ['深圳', '深圳市布吉供水有限公司'],
  ['深圳', '深圳市水务集团（原特区内）'],
  ['深圳', '深圳市深水龙岗水务集团有限公司'],
  ['深圳', '深圳水务集团（银行代缴）'],
  ['清远', '佛冈县三八自来水有限公司水费'],
  ['清远', '佛冈县光明公司（原佛冈供水）'],
  ['清远', '浸潭供水'],
  ['清远', '清远市供水拓展有限责任公司'],
  ['清远', '清远市清新区德源供水'],
  ['清远', '清远市清新区蒲坑自来水有限公司'],
  ['清远', '清远市龙塘粤海水务有限公司'],
  ['清远', '滨源供水'],
  ['清远', '英德市常青自来水有限公司'],
  ['清远', '英德市润泽自来水有限公司'],
  ['清远', '英德市金泰供水有限公司'],
  ['温州', '永嘉县枫林镇供水有限公司'],
  ['温州', '永嘉水务银泉自来水分公司'],
  ['温州', '温州公用乐清水务'],
  ['温州', '温州公用平阳水务'],
  ['温州', '温州公用文成水务'],
  ['温州', '温州公用永嘉水务'],
  ['温州', '温州公用泰顺水务'],
  ['温州', '温州公用瑞安水务'],
  ['温州', '温州公用自来水公司'],
  ['温州', '温州公用苍南水务'],
  ['温州', '温州公用龙港水务'],
  ['温州', '苍南县仙居天源自来水有限公司'],
  ['温州', '苍南县宜山镇珠山自来水厂'],
  ['温州', '苍南县新安环川自来水有限公司'],
  ['温州', '苍南县望里自来水厂'],
  ['温州', '龙港市鲸头自来水厂'],
  ['渭南', '渭南市区供水有限公司'],
  ['渭南', '渭南市华州区自来水公司'],
  ['渭南', '渭南高新区水务投资发展有限公司'],
  ['渭南', '韩城市城市供水有限公司'],
  ['湖州', '安吉双源自来水有限公司'],
  ['湖州', '安吉思源供水有限公司'],
  ['湖州', '德清县士林益康水务有限公司'],
  ['湖州', '德清县康益自来水有限公司'],
  ['湖州', '德清县新安镇利民水务有限公司'],
  ['湖州', '德清县水务有限公司'],
  ['湖州', '德清县钟管镇辉山水务有限公司'],
  ['湖州', '浙江安吉水务有限公司'],
  ['湖州', '浙江长兴水务有限公司'],
  ['湖州', '湖州市水务集团有限公司'],
  ['湖州', '长兴小浦清泉水务'],
  ['湖州', '长兴清泉供水有限公司'],
  ['湘潭', '射埠自来水'],
  ['湘潭', '湘乡市振湘供水有限公司'],
  ['湘潭', '湘潭中环水务有限公司'],
  ['湘潭', '湘潭京湘供水有限责任公司'],
  ['湘潭', '湘潭县百泉湖供水有限公司'],
  ['湘潭', '湘潭县石潭安泰自来水有限公司'],
  ['湘潭', '湘潭县谭家山自来水供应有限公司'],
  ['湘潭', '湘潭国中水务有限公司'],
  ['湘潭', '湘潭天星水务有限公司'],
  ['湘潭', '湘潭市源畅供水有限公司'],
  ['湘潭', '韶山供水有限公司'],
  ['湛江', '廉江市自来水有限公司'],
  ['湛江', '湛江市坡头区福泽自来水有限公司'],
  ['湛江', '湛江市坡头自来水厂'],
  ['湛江', '湛江市粤海自来水有限公司'],
  ['湛江', '遂溪粤海水务有限公司'],
  ['湛江', '雷州市龙门镇自来水厂'],
  ['滁州', '全椒县全润供水有限公司'],
  ['滁州', '凤阳县益民供水有限责任公司'],
  ['滁州', '凤阳明中都水务集团有限公司'],
  ['滁州', '南谯水务'],
  ['滁州', '天长市仁和集镇芦龙自来水厂'],
  ['滁州', '天长市城发水务广陵街道水费'],
  ['滁州', '天长市城发水务有限公司'],
  ['滁州', '天长市城发水务有限公司万寿分公司'],
  ['滁州', '天长市城发水务有限公司仁和分公司'],
  ['滁州', '天长市城发水务有限公司冶山分公司'],
  ['滁州', '天长市城发水务有限公司金集分公司'],
  ['滁州', '天长市富民自来水厂'],
  ['滁州', '天长市釜山自来水有限公司'],
  ['滁州', '天长市铜城镇自来水厂'],
  ['滁州', '定远县城乡水务投资建设有限公司'],
  ['滁州', '新泉自来水（明光）有限公司'],
  ['滁州', '施官自来水厂'],
  ['滁州', '明光明诚供水集团有限公司'],
  ['滁州', '来安县永阳水务公司农村分公司'],
  ['滁州', '来安县永阳水务公司城市分公司'],
  ['滁州', '来安县粤海供水'],
  ['滁州', '来安县自来水厂'],
  ['滁州', '滁州市自来水公司'],
  ['滁州', '王店自来水厂'],
  ['滁州', '龙泉水务（天长）有限公司'],
  ['滨州', '山东黎滨水务有限公司'],
  ['滨州', '山东龙吟水务有限公司'],
  ['滨州', '无棣县乡村供水服务有限公司'],
  ['滨州', '无棣县城区供水服务有限公司'],
  ['滨州', '无棣县城区供水（农村）'],
  ['滨州', '无棣县柳堡镇为民供水服务有限公司'],
  ['滨州', '无棣县芦家河子乡村供水有限公司'],
  ['滨州', '无棣碣石山供水服务有限公司'],
  ['滨州', '滨州北控西海水务'],
  ['滨州', '滨州北海农村供水有限公司'],
  ['滨州', '滨州市北海水务有限公司'],
  ['滨州', '滨州市南海水务有限责任公司'],
  ['滨州', '阳信县第一自来水公司'],
  ['滨州', '阳信梨乡供水有限公司'],
  ['漯河', '漯河华电水务有限公司'],
  ['漯河', '漯河市清源供水有限公司'],
  ['漯河', '漯河银河水务有限公司'],
  ['漯河', '漯河银龙农村供水有限公司'],
  ['漯河', '漯河银龙水务有限公司'],
  ['漯河', '舞阳县润泉供水有限公司'],
  ['漳州', '东山水务有限公司'],
  ['漳州', '云霄水务有限公司'],
  ['漳州', '南靖县水务有限公司'],
  ['漳州', '平和县自来水公司'],
  ['漳州', '漳州发展水务集团有限公司'],
  ['漳州', '漳州市古雷水务发展有限公司'],
  ['漳州', '漳州市角美自来水有限公司'],
  ['漳州', '漳州市长泰区兴泰水务有限公司'],
  ['漳州', '漳州市龙池水务有限公司'],
  ['漳州', '漳州开发区招商水务有限公司'],
  ['漳州', '漳浦县旧镇众生供水站'],
  ['漳州', '长泰水务有限公司'],
  ['漳州', '龙海水务有限公司'],
  ['漳州', '龙海角美开发区供水水厂'],
  ['潍坊', '寿光市自来水有限责任公司'],
  ['潍坊', '寿光市锦源供水有限公司'],
  ['潍坊', '晖泽水务（青州）有限公司'],
  ['潍坊', '滨海新源供水有限责任公司'],
  ['潍坊', '潍坊市坊子区上实环境供水有限公司'],
  ['潍坊', '潍坊市寒亭区上实环境供水有限公司'],
  ['潍坊', '潍坊市自来水有限公司'],
  ['潍坊', '潍坊滨海区央子供水有限公司'],
  ['潍坊', '潍坊舜源水务有限公司'],
  ['潍坊', '高密市粼波水务有限公司'],
  ['潮州', '潮州市湘桥区铁铺自来水供应站'],
  ['潮州', '潮州市潮安区彩塘镇供水站'],
  ['潮州', '饶平粤海水务有限公司'],
  ['濮阳', '南乐中州水务有限公司'],
  ['濮阳', '台前县农村供水有限公司'],
  ['濮阳', '台前县城区供水有限公司'],
  ['濮阳', '清丰中州农村供水有限公司'],
  ['濮阳', '清丰中州水务有限公司'],
  ['濮阳', '濮阳华源水务有限公司'],
  ['濮阳', '濮阳县中州供水有限公司'],
  ['濮阳', '濮阳县中州金堤供水有限公司'],
  ['濮阳', '濮阳县维康供水有限公司'],
  ['濮阳', '濮阳市自来水公司'],
  ['濮阳', '濮阳开发区中州供水有限公司'],
  ['濮阳', '范县中州供水有限公司'],
  ['濮阳', '范县清源水务有限公司'],
  ['烟台', '山东水务蓬莱华建水业有限公司'],
  ['烟台', '招远市金都水务有限公司'],
  ['烟台', '招远市鸿源供水有限公司'],
  ['烟台', '招远金都自来水有限公司'],
  ['烟台', '海阳市自来水有限公司'],
  ['烟台', '烟台市福山供水有限责任公司'],
  ['烟台', '烟台市福山区畅盛供水有限公司'],
  ['烟台', '烟台市福山自来水有限公司'],
  ['烟台', '烟台市自来水有限公司'],
  ['烟台', '烟台市蓬莱区盛润供水有限公司'],
  ['烟台', '烟台市蓬莱区蓬润供水有限公司'],
  ['烟台', '烟台水务清泉有限公司'],
  ['烟台', '烟台经济开发区自来水有限公司'],
  ['烟台', '牟平润新供水（原牟平供水总公司）'],
  ['烟台', '莱州市渤海水务有限公司'],
  ['烟台', '莱州市渤海水务有限公司（农水）'],
  ['烟台', '莱阳市自来水有限公司'],
  ['烟台', '龙口市自来水有限公司'],
  ['焦作', '修武县水务有限公司'],
  ['焦作', '修武县鑫源水务有限公司'],
  ['焦作', '博爱县清华水务公司'],
  ['焦作', '孟州市鑫通水务有限公司'],
  ['焦作', '沁阳市鑫通水务有限公司'],
  ['焦作', '温县中投水务乡镇水处理分公司'],
  ['焦作', '温县中投水务有限公司'],
  ['焦作', '焦作市水务有限责任公司'],
  ['牡丹江', '东宁市绥阳润泽自来水有限公司'],
  ['牡丹江', '牡丹江龙江环保供水有限公司'],
  ['牡丹江', '绥芬河中环水务有限公司'],
  ['玉林', '兴业县第一供水有限公司'],
  ['玉林', '北流市永安自来水有限公司'],
  ['玉林', '博白供水'],
  ['玉林', '广西容县桂侨供水有限责任公司'],
  ['玉林', '广西容县水利供水有限公司'],
  ['玉林', '玉林市玉州区寒山自来水厂'],
  ['玉林', '玉林市自来水有限公司'],
  ['玉林', '陆川县北部水务有限责任公司'],
  ['玉林', '陆川县南部水务有限责任公司'],
  ['玉林', '陆川县水利供水有限公司'],
  ['玉溪', '峨山彝族自治县自来水有限责任公司'],
  ['玉溪', '峨山水投水务有限公司'],
  ['玉溪', '新平县水务产业投资开发有限公司'],
  ['玉溪', '易门清源自来水有限责任公司'],
  ['玉溪', '玉溪国润水务发展集团有限公司'],
  ['玉溪', '玉溪市江川区轩湖水务有限公司'],
  ['玉溪', '通海县自来水厂'],
  ['珠海', '珠海市供水有限公司'],
  ['白城', '洮南市自来水有限责任公司'],
  ['白城', '白城市自来水公司'],
  ['白城', '通榆县供水公司'],
  ['白山', '抚松亿源供水有限公司'],
  ['白山', '靖宇县自来水费（居民）'],
  ['白山', '靖宇县自来水费（非居民）'],
  ['百色', '平果市鸿铝水务有限责任公司'],
  ['百色', '广西百色右江水务股份有限公司'],
  ['百色', '广西鹤城水务有限公司'],
  ['百色', '德保惠民水务'],
  ['百色', '田东县供水有限责任公司'],
  ['百色', '那坡县壮源水务有限公司'],
  ['百色', '靖西市祥瑞水务投资有限公司'],
  ['益阳', '南县城乡水务有限公司'],
  ['益阳', '安化县马路镇自来水厂'],
  ['益阳', '安化水务有限公司'],
  ['益阳', '桃江县灰山港自来水厂'],
  ['益阳', '桃江县自来水公司'],
  ['益阳', '益阳市大通湖鑫源自来水'],
  ['益阳', '益阳市自来水有限公司'],
  ['盐城', '东台市自来水有限公司'],
  ['盐城', '响水县沿海自来水有限公司'],
  ['盐城', '响水县自来水有限公司'],
  ['盐城', '响水县运河自来水有限公司'],
  ['盐城', '射阳县农村水务有限公司'],
  ['盐城', '射阳水务有限责任公司'],
  ['盐城', '建湖县农村供水'],
  ['盐城', '建湖县自来水有限公司'],
  ['盐城', '滨海县自来水有限责任公司'],
  ['盐城', '盐城大丰自来水有限公司'],
  ['盐城', '盐城市水务集团有限公司'],
  ['盐城', '盐城市潘黄水务有限公司'],
  ['盐城', '盐城市盐都水务有限公司'],
  ['盐城', '盐城市盐龙水务有限公司'],
  ['盐城', '盐城经济技术开发区步凤镇自来水厂'],
  ['盐城', '阜宁县自来水有限公司'],
  ['盘锦', '盘山县城乡水务有限公司'],
  ['盘锦', '盘锦兴辽水务有限公司'],
  ['盘锦', '辽河水务公司缴费'],
  ['眉山', '丹棱中车水务'],
  ['眉山', '四川顺源水务有限公司'],
  ['眉山', '眉山环天水务有限公司'],
  ['眉山', '青神川环水务有限公司'],
  ['石家庄', '平山县益民城市供水有限公司'],
  ['石家庄', '新乐市伏羲供水有限公司'],
  ['石家庄', '正定县自来水公司'],
  ['石家庄', '石家庄供水有限责任公司'],
  ['石家庄', '石家庄市鹿泉区江源供水有限公司'],
  ['石家庄', '石家庄市鹿泉区海山供水管理站'],
  ['石家庄', '石家庄市鹿泉区绿岛供水管理站'],
  ['石家庄', '石家庄市鹿泉区西山供水管理站'],
  ['石家庄', '石家庄正定新区水务有限公司'],
  ['石家庄', '石家庄经济技术开发区供水公司'],
  ['石家庄', '石家庄高新供水运营服务有限公司'],
  ['石家庄', '石家庄鹿泉区水投供水有限公司'],
  ['石家庄', '行唐县联村供水'],
  ['石家庄', '赞皇绿色晖泽水务有限公司'],
  ['福州', '平潭水务公司'],
  ['福州', '流水威隆自来水供水公司'],
  ['福州', '福州南港水务有限公司'],
  ['福州', '福州市自来水有限公司'],
  ['福州', '福州市长乐区城乡水务有限公司'],
  ['福州', '福州市长乐区远航供水有限责任公司'],
  ['福州', '福州市长乐区金峰自来水公司'],
  ['福州', '福州旗山供水有限公司'],
  ['福州', '福州滨海水务'],
  ['福州', '福州胜科水务有限公司'],
  ['福州', '福建水投集团福清水务有限公司'],
  ['福州', '闽侯县三溪口自来水有限公司'],
  ['福州', '闽侯县自来水有限公司'],
  ['秦皇岛', '秦皇岛北戴河供水总公司'],
  ['秦皇岛', '秦皇岛太平洋引供水有限公司'],
  ['秦皇岛', '秦皇岛市自来水有限公司'],
  ['绍兴', '上虞区农村供水'],
  ['绍兴', '嵊州市自来水'],
  ['绍兴', '新昌县农村供水'],
  ['绍兴', '新昌县自来水有限公司'],
  ['绍兴', '新昌县西桥弄自来水有限公司'],
  ['绍兴', '浣江水务股份有限公司(诸暨市自来水)'],
  ['绍兴', '绍兴市上虞区供水有限公司'],
  ['绍兴', '绍兴市水务产业有限公司'],
  ['绍兴', '绍兴柯桥供水有限公司'],
  ['绥化', '兰西县供水公司'],
  ['绥化', '望奎县供水服务中心'],
  ['绥化', '绥棱县润泽二次供水服务有限公司'],
  ['绥化', '绥棱县自来水有限公司'],
  ['绥化', '青冈县银河供水公司'],
  ['绵阳', '梓潼县思源供水有限公司'],
  ['绵阳', '绵阳市昊池供水有限公司杨家水务分公司'],
  ['绵阳', '绵阳市水务（集团）有限公司'],
  ['绵阳', '绵阳市泉洲供水有限责任公司'],
  ['绵阳', '绵阳市泓泉水务有限责任公司'],
  ['聊城', '东阿瑞泓水务有限公司'],
  ['聊城', '临清市众源水务有限公司'],
  ['聊城', '冠县城区供水服务有限公司'],
  ['聊城', '山东星润供水有限公司'],
  ['聊城', '山东聊城恒润供水有限责任公司'],
  ['聊城', '聊城市茌平区洰源自来水公司'],
  ['聊城', '阳谷城乡供水有限公司'],
  ['聊城', '高唐水务集团有限公司'],
  ['肇庆', '肇庆肇水水务发展（四会）'],
  ['肇庆', '肇庆肇水水务发展（封开）'],
  ['肇庆', '肇庆肇水水务发展（广宁）'],
  ['肇庆', '肇庆肇水水务发展（端州）'],
  ['肇庆', '肇庆肇水水务发展（鼎湖）'],
  ['肇庆', '肇庆高新区粤海水务有限公司'],
  ['自贡', '富顺县富洲水务集团有限公司'],
  ['自贡', '自贡市源泉供水有限公司'],
  ['自贡', '自贡水务投资集团有限公司'],
  ['自贡', '荣县水务投资有限公司'],
  ['舟山', '岱山县秀山乡自来水厂'],
  ['舟山', '嵊泗县自来水有限公司'],
  ['舟山', '浙江岱山衢投水务有限公司'],
  ['舟山', '舟山市自来水有限公司'],
  ['芜湖', '南陵陵都供水有限公司'],
  ['芜湖', '安徽省南陵县供水有限公司'],
  ['芜湖', '安徽省江北华衍水务有限公司'],
  ['芜湖', '无为县供水公司'],
  ['芜湖', '无为市濡须供水有限公司'],
  ['芜湖', '芜湖华衍水务'],
  ['芜湖', '芜湖津江供水有限公司'],
  ['芜湖', '芜湖首创水务有限责任公司'],
  ['苏州', '吴江华衍水务有限公司'],
  ['苏州', '太仓市自来水有限公司'],
  ['苏州', '昆山市自来水集团有限公司'],
  ['苏州', '江苏中法水务股份有限公司'],
  ['苏州', '苏州吴中供水有限公司（银行代缴）'],
  ['苏州', '苏州太湖国家旅游度假区自来水有限公司'],
  ['苏州', '苏州工业园区清源华衍水务有限公司'],
  ['苏州', '苏州工业园区清源华衍水务有限公司（银行代缴）'],
  ['苏州', '苏州市相城区自来水公司（银行代缴）'],
  ['苏州', '苏州市自来水有限公司'],
  ['苏州', '苏州高新区自来水有限公司（银行代缴）'],
  ['苏州', '苏州高铁苏水水务有限公司'],
  ['茂名', '信宜粤海水务有限公司'],
  ['茂名', '化州市塘岗岭自来水厂'],
  ['茂名', '茂名市电白区国丰自来水有限公司'],
  ['茂名', '茂名市电白区琅江自来水有限公司'],
  ['茂名', '茂名市电白区霞洞自来水有限公司'],
  ['茂名', '茂名市茂南区镇盛自来水厂'],
  ['茂名', '茂名粤海水务有限公司'],
  ['茂名', '高州粤海水务有限公司'],
  ['荆州', '公安县银龙水务有限公司'],
  ['荆州', '松滋市城市水务有限公司'],
  ['荆州', '松滋市福达二次供水有限公司水费'],
  ['荆州', '梦源水务有限公司戴家场分公司'],
  ['荆州', '江陵银龙水务有限公司'],
  ['荆州', '洪湖市梦源水务有限公司大沙湖分公司'],
  ['荆州', '洪湖市梦源水务有限公司峰口分公司'],
  ['荆州', '洪湖市梦源水务有限公司汊河分公司'],
  ['荆州', '洪湖市梦源水务有限公司沙口分公司'],
  ['荆州', '洪湖市湖源水务有限公司'],
  ['荆州', '洪湖市第二自来水公司'],
  ['荆州', '洪湖梦源水务有限公司府场分公司'],
  ['荆州', '洪湖梦源水务有限公司新滩分公司'],
  ['荆州', '湖北省国营小港农场自来水厂'],
  ['荆州', '监利市沛然供水有限公司'],
  ['荆州', '石首市东旭自来水厂'],
  ['荆州', '石首市久合垸江波渡自来水厂'],
  ['荆州', '石首市新厂自来水公司'],
  ['荆州', '石首市横沟市自来水公司'],
  ['荆州', '石首市自来水公司'],
  ['荆州', '石首市调关镇自来水厂'],
  ['荆州', '石首银龙水务有限公司'],
  ['荆州', '老河口市清源供水有限公司'],
  ['荆州', '荆州市海润乡镇供水有限公司'],
  ['荆州', '荆州水务集团有限公司'],
  ['荆州', '高基庙镇自来水厂'],
  ['荆门', '东桥镇高冲供水公司'],
  ['荆门', '京山市海泓水务厂'],
  ['荆门', '京山市自来水有限公司'],
  ['荆门', '京山曹武自来水厂'],
  ['荆门', '京山民福源供水有限公司'],
  ['荆门', '京山淼淼自来水厂（原坪坝镇水厂）'],
  ['荆门', '沙洋县泽洋供水有限公司'],
  ['荆门', '湖北大柴湖自来水有限责任公司'],
  ['荆门', '老河口市清源供水有限公司'],
  ['荆门', '钟祥市东桥宏洋自来水厂'],
  ['荆门', '钟祥市坤龙供水有限公司'],
  ['莆田', '仙游县自来水有限公司'],
  ['莆田', '莆田壶山自来水有限公司'],
  ['莆田', '莆田市埭头半岛供水有限公司'],
  ['莆田', '莆田市水务集团涵江自来水有限公司'],
  ['莆田', '莆田市湄洲湾自来水有限公司'],
  ['莆田', '莆田市秀屿区通达供水有限公司'],
  ['莆田', '莆田市自来水有限公司'],
  ['菏泽', '成武县自来水公司'],
  ['菏泽', '曹县—晖泽水务（菏泽）有限公司'],
  ['菏泽', '曹县正源水务有限公司'],
  ['菏泽', '菏泽市定陶区自来水公司'],
  ['菏泽', '菏泽市水务集团自来水有限公司'],
  ['菏泽', '郓城县自来水有限公司'],
  ['菏泽', '鄄城县鄄润自来水有限公司'],
  ['萍乡', '上栗县鸡冠山秋江自来水厂'],
  ['萍乡', '彭高自来水供应有限公司'],
  ['萍乡', '江西水务湘东润泉'],
  ['萍乡', '江西水务莲花润泉'],
  ['萍乡', '芦溪水务有限公司'],
  ['萍乡', '萍乡市华云供水有限公司'],
  ['萍乡', '萍乡水务有限公司'],
  ['营口', '盖州市水务有限责任公司'],
  ['营口', '营口水务集团有限公司'],
  ['葫芦岛', '兴城市水务集团有限公司'],
  ['葫芦岛', '葫芦岛市汇泽自来水有限公司'],
  ['蚌埠', '五河中环水务有限公司'],
  ['蚌埠', '五河县小圩镇下黄自来水厂'],
  ['蚌埠', '五河县洁康自来水厂'],
  ['蚌埠', '固镇中环水务有限公司'],
  ['蚌埠', '固镇中环水务有限公司经开区分公司'],
  ['蚌埠', '固镇县刘集镇腾达自来水厂'],
  ['蚌埠', '固镇县新马桥镇怀洪自来水厂'],
  ['蚌埠', '怀远中环水务有限公司'],
  ['蚌埠', '怀远县万福亿达自来水厂'],
  ['蚌埠', '怀远县双桥恒旺自来水厂'],
  ['蚌埠', '怀远县古城乡坤裕自来水厂'],
  ['蚌埠', '怀远县淝南乡永达自来水厂'],
  ['蚌埠', '怀远县淝河利民自来水厂'],
  ['蚌埠', '怀远县荆芡源泉自来水厂'],
  ['蚌埠', '怀远县褚集益民自来水有限公司'],
  ['蚌埠', '怀远县诚达水务有限公司'],
  ['蚌埠', '怀远县魏庄镇洁康自来水厂'],
  ['蚌埠', '怀远县龙亢镇绿源自来水厂'],
  ['蚌埠', '蚌埠中环水务有限公司'],
  ['蚌埠', '蚌埠市临河水务有限公司'],
  ['衡水', '安平县农村供水管理有限公司'],
  ['衡水', '故城县泓洋城区供水有限公司'],
  ['衡水', '故城县浩泽农村供水有限公司'],
  ['衡水', '故城县自来水公司'],
  ['衡水', '景县沁泉供水服务有限公司'],
  ['衡水', '景县泓润供水管理有限公司'],
  ['衡水', '枣强县润泽供水服务有限公司'],
  ['衡水', '武邑县卓庆供水有限公司'],
  ['衡水', '河北建投衡水水务有限公司'],
  ['衡水', '深州市第二供水有限公司'],
  ['衡水', '衡水市冀泽水务投资集团有限公司(冀州城区）'],
  ['衡水', '衡水滨丰水务有限公司'],
  ['衡阳', '常宁市水松供水有限责任公司'],
  ['衡阳', '常宁市自来水公司'],
  ['衡阳', '祁东县太和堂江口自来水厂'],
  ['衡阳', '祁东县曹口堰供水公司'],
  ['衡阳', '祁东县水务集团'],
  ['衡阳', '祁东县白地市供水工程公司'],
  ['衡阳', '衡东县新塘自来水有限责任公司'],
  ['衡阳', '衡东县清泉供水有限公司'],
  ['衡阳', '衡东县自来水有限公司'],
  ['衡阳', '衡阳县自来水公司'],
  ['衡阳', '衡阳市南岳区水务有限责任公司'],
  ['衡阳', '衡阳市自来水有限公司'],
  ['衢州', '常山县水务发展投资有限公司'],
  ['衢州', '开化县水务有限公司'],
  ['衢州', '开化县润民水务有限公司'],
  ['衢州', '江山市水务有限公司'],
  ['衢州', '龙游华水农村供水发展有限公司'],
  ['襄阳', '南漳县水镜供水有限责任公司'],
  ['襄阳', '宜城天河供水公司'],
  ['襄阳', '枣阳市三泉供水有限公司'],
  ['襄阳', '枣阳市嘉源水务有限公司'],
  ['襄阳', '枣阳市帝泉供水有限公司'],
  ['襄阳', '石梯供水有限公司'],
  ['襄阳', '老河口市拓展智能水务有限责任公司'],
  ['襄阳', '老河口市清源供水有限公司'],
  ['襄阳', '襄阳中环水务有限公司'],
  ['襄阳', '襄阳金源供水有限公司'],
  ['襄阳', '谷城县谷源供水有限公司'],
  ['西安', '周至县城镇供水有限责任公司'],
  ['西安', '蓝田县碧源自来水有限责任公司'],
  ['西安', '西安市自来水有限公司'],
  ['西安', '西安市鄠邑区城乡水务有限公司'],
  ['西安', '西安市长安区自来水有限责任公司'],
  ['西安', '陕西西安阎良航城水务'],
  ['西安', '高陵区源盛水务有限公司'],
  ['许昌', '河南水投锦襄水务有限公司'],
  ['许昌', '许昌市建安区中州水务有限公司'],
  ['许昌', '鄢陵中州水务有限公司'],
  ['许昌', '长葛市葛源供水有限公司'],
  ['贵港', '广西国宏智鸿水务有限公司'],
  ['贵港', '桂平市自来水厂'],
  ['贵阳', '开阳县乡镇水务有限公司'],
  ['贵阳', '贵安新区城乡供水有限公司'],
  ['贵阳', '贵州水投水务集团修文有限公司'],
  ['贵阳', '贵州水投水务集团息烽有限公司'],
  ['贵阳', '贵州水投水务集团贵安新区有限公司'],
  ['贵阳', '贵州贵安水务有限公司'],
  ['贵阳', '贵阳北控水务有限责任公司'],
  ['贵阳', '贵阳市乌当区城乡水务发展有限公司'],
  ['贵阳', '贵阳市水务环境集团分质供水有限公司'],
  ['贵阳', '贵阳市水务环境集团有限公司'],
  ['贺州', '富川瑶族自治县自来水厂'],
  ['贺州', '钟山县水利供水有限公司'],
  ['资阳', '乐至海天水务有限公司'],
  ['资阳', '四川安岳县柠都自来水'],
  ['资阳', '安岳县关刀桥自来水有限公司'],
  ['资阳', '安岳县清源水务有限公司'],
  ['资阳', '资阳海天水务有限公司'],
  ['赣州', '上犹县营前云水自来水厂'],
  ['赣州', '于都县雩山水务有限公司'],
  ['赣州', '会昌县麻州镇自来水厂'],
  ['赣州', '信丰县大阿自来水厂'],
  ['赣州', '信丰县虎山乡自来水厂'],
  ['赣州', '全南县公用水务有限公司'],
  ['赣州', '兴国县潋城水务集团有限公司'],
  ['赣州', '大余县章江供水有限责任公司'],
  ['赣州', '宁都县源盛公用事业公司供水分公司'],
  ['赣州', '安远县九龙自来水有限责任公司'],
  ['赣州', '定南县自来水有限责任公司'],
  ['赣州', '崇义县水务集团有限公司'],
  ['赣州', '江西水务会昌润泉'],
  ['赣州', '江西水务信丰润泉'],
  ['赣州', '江西水务南康润泉'],
  ['赣州', '江西水务安远润泉'],
  ['赣州', '江西水务寻乌润泉'],
  ['赣州', '江西水务瑞金润泉'],
  ['赣州', '江西水务石城润泉'],
  ['赣州', '江西水务龙南润泉'],
  ['赣州', '江西省于都县自来水公司'],
  ['赣州', '赣州水务股份有限公司'],
  ['赣州', '赣州水务集团上犹县自来水有限公司'],
  ['赣州', '赣州水务集团南康区自来水有限公司'],
  ['赣州', '赣州水务集团赣县区自来水有限公司'],
  ['赤峰', '巴林右旗自来水有限责任公司'],
  ['赤峰', '敖汉旗顺通供水服务有限公司'],
  ['赤峰', '林西县自来水总公司'],
  ['赤峰', '翁牛特旗浩达供水有限责任公司'],
  ['赤峰', '赤峰市宏泽供水（原市自来水总公司）'],
  ['赤峰', '赤峰涌泉水务有限公司'],
  ['辽源', '辽源城市自来水有限责任公司'],
  ['辽阳', '凯发新泉水务辽阳弓长岭有限公司'],
  ['辽阳', '辽阳信环水务有限公司'],
  ['辽阳', '辽阳县小北河自来水公司'],
  ['达州', '达州水务集团'],
  ['运城', '万荣县泓润水务有限公司'],
  ['运城', '垣曲县自来水公司'],
  ['运城', '新绛县绛之泉城乡供水有限公司'],
  ['运城', '河津市供水公司'],
  ['运城', '河津市北源供水公司'],
  ['运城', '河津市城乡供水服务中心'],
  ['运城', '河津市市政供水公司'],
  ['运城', '河津市龙门集中供水公司'],
  ['运城', '稷山联合水务有限公司'],
  ['运城', '绛县供水服务站'],
  ['运城', '芮城县自来水公司'],
  ['运城', '运城银龙水务有限公司'],
  ['运城', '运城首创水务有限公司'],
  ['运城', '闻喜县自来水厂'],
  ['连云港', '东海县城乡供水有限公司'],
  ['连云港', '东海县城乡供水有限公司石榴分公司'],
  ['连云港', '东海县自来水有限公司'],
  ['连云港', '灌云县清源水务有限公司'],
  ['连云港', '灌云县自来水有限公司'],
  ['连云港', '灌云恒泰水务有限公司'],
  ['连云港', '灌南县硕项湖自来水有限公司'],
  ['连云港', '连云港市浦南自来水有限责任公司'],
  ['连云港', '连云港市自来水有限责任公司'],
  ['连云港', '连云港市赣榆城建水务有限公司'],
  ['连云港', '连云港开发区中云自来水服务公司'],
  ['连云港', '连云港新锦源水务有限公司'],
  ['通化', '吉林省嘉元水务有限公司'],
  ['通化', '梅河口市自来水公司'],
  ['通化', '辉南县沣泽源水务（集团）有限公司'],
  ['通化', '通化县信沣水务公司水费'],
  ['通化', '通化市自来水有限公司'],
  ['通化', '集安市天润供水有限公司'],
  ['通辽', '扎鲁特旗鲁北城市供水有限责任公司'],
  ['通辽', '通辽市城市供水有限责任公司'],
  ['通辽', '霍林郭勒市自来水有限责任公司水费'],
  ['通辽', '霍林郭勒市自来水（直饮水）'],
  ['遂宁', '遂宁发展水务投资有限公司'],
  ['遂宁', '遂宁市安居区润安供水有限公司'],
  ['遂宁', '遂宁市润生供水有限公司'],
  ['遂宁', '遂宁市鑫宇自来水有限公司'],
  ['遵义', '仁怀市水务供水有限责任公司'],
  ['遵义', '正安县水务投资有限责任公司'],
  ['遵义', '贵州水务赤水市有限公司'],
  ['遵义', '贵州水投水务习水集镇供水公司'],
  ['遵义', '贵州水投水务绥阳有限责任公司'],
  ['遵义', '贵州水投水务集团习水有限公司'],
  ['遵义', '贵州水投水务集团凤冈有限公司'],
  ['遵义', '贵州水投水务集团务川有限公司'],
  ['遵义', '贵州水投水务集团播州有限公司'],
  ['遵义', '道真供水公司'],
  ['遵义', '遵义市供水有限责任公司'],
  ['遵义', '遵义市播州区龙庆供水有限责任公司'],
  ['遵义', '遵义市新区供水有限责任公司'],
  ['遵义', '遵义湄潭供水有限责任公司'],
  ['邢台', '临西县城区供水服务中心'],
  ['邢台', '任县自来水公司'],
  ['邢台', '内丘县盛源供水有限公司'],
  ['邢台', '内丘致源自来水有限公司'],
  ['邢台', '南宫市源隆供水'],
  ['邢台', '威县博昌供水有限公司'],
  ['邢台', '平乡县自来水供应公司'],
  ['邢台', '广宗县自来水公司'],
  ['邢台', '清河县润民自来水有限公司'],
  ['邢台', '清河县润清水务有限公司'],
  ['邢台', '邢台市任泽区渚阳供水有限公司'],
  ['邢台', '邢台市南和区和润供水有限责任公司'],
  ['邯郸', '峰峰供水主城区'],
  ['邯郸', '峰峰供水矿务局'],
  ['邯郸', '曲周县自来水公司'],
  ['邯郸', '武安供水'],
  ['邯郸', '武安市城市供水管理处'],
  ['邯郸', '邯郸冀南新区城乡供水'],
  ['邯郸', '邯郸市供水有限责任公司'],
  ['邯郸', '邯郸市肥乡区江泉供水有限公司'],
  ['邯郸', '邺城供水'],
  ['邯郸', '魏县自来水公司'],
  ['邵阳', '城步苗族自治县自来水公司'],
  ['邵阳', '新宁县城乡供水有限责任公司'],
  ['邵阳', '新宁明仁自来水公司'],
  ['邵阳', '新邵县自来水公司'],
  ['邵阳', '武冈市城市供水公司（二水厂）'],
  ['邵阳', '洞口县自来水公司'],
  ['邵阳', '洞口县自来水公司高沙水厂'],
  ['邵阳', '湖南武冈湘水水务有限公司'],
  ['邵阳', '湖南省邵东市自来水公司'],
  ['邵阳', '绥宁县自来水公司'],
  ['邵阳', '邵阳县自来水公司'],
  ['邵阳', '邵阳市自来水公司'],
  ['邵阳', '隆回县农村供水有限责任公司'],
  ['邵阳', '隆回县自来水公司'],
  ['郑州', '云水纪（河南）水务科技有限公司'],
  ['郑州', '巩义市水务有限公司'],
  ['郑州', '巩义市银龙源盛水务有限公司'],
  ['郑州', '新密市溱顺腾水务有限公司'],
  ['郑州', '新郑市泽润自来水有限公司'],
  ['郑州', '新郑市溱洧水务有限公司'],
  ['郑州', '登封中州供水有限公司'],
  ['郑州', '荥阳市自来水有限公司'],
  ['郑州', '郑州东区水务有限公司'],
  ['郑州', '郑州市上街区自来水公司'],
  ['郑州', '郑州牟源水务发展有限公司'],
  ['郑州', '郑州经开水务发展有限公司'],
  ['郑州', '郑州经开水务发展有限公司-直饮水'],
  ['郑州', '郑州自来水投资控股有限公司'],
  ['郑州', '郑州航空港区水务有限公司'],
  ['郑州', '郑州航空港水务发展有限公司'],
  ['郑州', '郑州高新供水有限责任公司'],
  ['郑州', '郑汴水务'],
  ['郴州', '嘉禾县自来水'],
  ['郴州', '安仁县自来水公司'],
  ['郴州', '宜章县自来水公司'],
  ['郴州', '桂阳自来水有限公司'],
  ['郴州', '永兴县自来水公司'],
  ['郴州', '汝城县鑫荣水务投资有限公司'],
  ['郴州', '资兴市自来水有限公司'],
  ['郴州', '郴州市自来水有限责任公司'],
  ['郴州', '郴州良田自来水有限责任公司'],
  ['郴州', '长河自来水'],
  ['鄂尔多斯', '乌兰木伦自来水费缴费'],
  ['鄂尔多斯', '内蒙古东源水务有限公司'],
  ['鄂尔多斯', '内蒙古天河水务有限公司'],
  ['鄂尔多斯', '内蒙古科源水务有限公司'],
  ['鄂尔多斯', '准格尔旗泰禹供水有限责任公司'],
  ['鄂尔多斯', '泰禹供水纯净水水费'],
  ['鄂尔多斯', '泰禹供水薛家湾镇分公司'],
  ['鄂尔多斯', '鄂尔多斯市东胜区城市供水有限公司（东胜区）'],
  ['鄂尔多斯', '鄂尔多斯市城市水务有限责任公司'],
  ['鄂尔多斯', '鄂尔多斯市空港水务'],
  ['鄂州', '老河口市清源供水有限公司'],
  ['鄂州', '鄂州市水务集团'],
  ['酒泉', '酒泉畅通自来水有限公司'],
  ['重庆', '奉节县自来水有限公司'],
  ['重庆', '川渝高竹水务发展有限公司'],
  ['重庆', '开源水务有限公司（乡镇）'],
  ['重庆', '渝东北自来水公司巫溪分公司'],
  ['重庆', '璧山自来水'],
  ['重庆', '石柱源通水务公司'],
  ['重庆', '秀山县禹通水务有限公司'],
  ['重庆', '酉阳县缘溪水务有限责任公司'],
  ['重庆', '重庆中法供水有限公司'],
  ['重庆', '重庆凤华二次供水服务有限公司'],
  ['重庆', '重庆南城水务有限公司'],
  ['重庆', '重庆巴南区木洞水务'],
  ['重庆', '重庆市万州区开源水务有限公司（城区）'],
  ['重庆', '重庆市二次供水公司'],
  ['重庆', '重庆市兴源供水技术有限公司涂山自来水厂'],
  ['重庆', '重庆市南川区博泓水务有限责任公司'],
  ['重庆', '重庆市大足区高升自来水厂'],
  ['重庆', '重庆市大足区龙源供水有限公司'],
  ['重庆', '重庆市开州区家威自来水有限公司'],
  ['重庆', '重庆市开州区红亮自来水厂'],
  ['重庆', '重庆市武隆区自来水有限责任公司'],
  ['重庆', '重庆市武隆区鑫祥供水有限责任公司'],
  ['重庆', '重庆市永川区惠永水务有限公司'],
  ['重庆', '重庆市潼南自来水有限公司'],
  ['重庆', '重庆市自来水有限公司'],
  ['重庆', '重庆市葛兰供水有限公司'],
  ['重庆', '重庆市豪洋水务建设管理有限公司万盛分公司'],
  ['重庆', '重庆市铜梁区龙泽水务'],
  ['重庆', '重庆市铜梁区龙源乡镇供水有限责任公司'],
  ['重庆', '重庆惠源水务有限公司'],
  ['重庆', '重庆水务环境控股集团渝东北自来水有限公司'],
  ['重庆', '重庆水务环境控股集团渝东北自来水有限公司开州分公司'],
  ['重庆', '重庆水务环境控股集团渝东自来水有限公司'],
  ['重庆', '重庆水务环境控股集团渝东自来水有限公司忠县分公司'],
  ['重庆', '重庆水务环境控股集团渝东自来水有限公司綦江分公司'],
  ['重庆', '重庆水资源产业股份有限公司东部自来水分公司'],
  ['重庆', '重庆水资源产业股份有限公司高新区自来水分公司'],
  ['重庆', '重庆永川侨立水务'],
  ['重庆', '重庆永立水务有限公司'],
  ['重庆', '重庆江东水务公司'],
  ['重庆', '重庆江东水务公司（水土老街）'],
  ['重庆', '重庆江城水务有限公司'],
  ['重庆', '重庆渝江水务有限公司'],
  ['重庆', '重庆渝长燃气自来水有限责任公司'],
  ['重庆', '重庆玉龙水务有限公司'],
  ['重庆', '重庆蔡同水务有限公司'],
  ['重庆', '重庆豪洋水务江津分公司'],
  ['重庆', '重庆长寿开投水务有限公司'],
  ['重庆', '重庆长江水务集团有限公司'],
  ['重庆', '铜梁龙泽水务公司龙源乡镇分公司'],
  ['金华', '东阳市三乡水务有限公司'],
  ['金华', '东阳市思源供水有限公司'],
  ['金华', '东阳市横店自来水有限公司'],
  ['金华', '东阳市自来水有限公司'],
  ['金华', '义乌市城西自来水有限公司'],
  ['金华', '义乌市第三自来水有限公司'],
  ['金华', '义乌市第二自来水有限公司'],
  ['金华', '义乌市自来水有限公司'],
  ['金华', '兰溪市钱江水务有限公司'],
  ['金华', '武义县城市自来水有限公司'],
  ['金华', '武义县振兴乡村水务有限公司'],
  ['金华', '永康市自来水有限公司'],
  ['金华', '永康市钱江水务有限公司'],
  ['金华', '永康市钱江芝水水务有限公司'],
  ['金华', '浦江县城乡自来水有限公司'],
  ['金华', '浦江水务集团有限公司'],
  ['金华', '磐安县清泉水务有限公司'],
  ['金华', '磐安县自来水有限公司'],
  ['金华', '磐安江南药镇供水有限公司'],
  ['金华', '金华市自来水有限公司'],
  ['金华', '金华市金西自来水有限公司'],
  ['金昌', '金昌市城市公共供水有限责任公司'],
  ['钦州', '广西钦州北投环保水务有限公司'],
  ['钦州', '灵山县易泽水务有限公司'],
  ['钦州', '钦州市开投水务有限公司'],
  ['钦州', '钦州市钦南区发投水务有限公司'],
  ['钦州', '钦州皇马水务有限公司'],
  ['铁岭', '开原市自来水有限责任公司'],
  ['铁岭', '昌图县自来水有限公司'],
  ['铁岭', '西丰县百利丰自来水有限公司'],
  ['铁岭', '调兵山市润鑫水务有限责任公司'],
  ['铁岭', '调兵山市自来水供应处'],
  ['铁岭', '铁岭县凡兴自来水有限责任公司'],
  ['铁岭', '铁岭新铖水务有限公司'],
  ['铁岭', '铁岭水务有限公司'],
  ['铁岭', '铁岭水务有限公司经济开发区分公司'],
  ['铁岭', '铁岭水务有限公司铁岭清河分公司'],
  ['铜仁', '印江土家族苗族自治县供水有限公司'],
  ['铜仁', '思南县禹源供水有限责任公司'],
  ['铜仁', '江口县供水公司'],
  ['铜仁', '沿河土家族自治县供水公司'],
  ['铜仁', '石阡县城市供水有限公司'],
  ['铜仁', '贵州水务大龙有限公司'],
  ['铜仁', '贵州水投水务集团万山有限公司'],
  ['铜仁', '贵州水投水务集团松桃有限公司'],
  ['铜仁', '贵州水投水务集团碧江有限公司'],
  ['铜川', '铜川市自来水（集团）有限公司'],
  ['铜川', '陕西省水务集团宜君县供水有限公司'],
  ['铜川', '陕西铜川供水有限责任公司'],
  ['铜陵', '枞阳县横埠水务有限公司'],
  ['铜陵', '枞阳县自来水有限责任公司'],
  ['铜陵', '枞阳首创水务有限责任公司'],
  ['铜陵', '铜陵东城水务有限责任公司'],
  ['铜陵', '铜陵市义安区自来水有限责任公司'],
  ['铜陵', '铜陵悦江首创供水有限责任公司'],
  ['铜陵', '铜陵首创水务有限责任公司'],
  ['银川', '宁夏水投银川水务有限公司'],
  ['银川', '银川中铁水务集团有限公司'],
  ['银川', '银川中铁水务集团永宁供水有限公司'],
  ['银川', '银川中铁水务集团灵武供水有限公司'],
  ['银川', '银川中铁水务集团贺兰供水有限公司'],
  ['锦州', '北镇市金源自来水有限公司'],
  ['锦州', '锦州润万家城市供水有限公司'],
  ['镇江', '丹阳水务集团有限公司'],
  ['镇江', '句容市宝华自来水有限公司'],
  ['镇江', '句容市水务集团有限公司'],
  ['镇江', '扬中市碧泉自来水有限公司'],
  ['镇江', '扬中金州水务有限公司'],
  ['镇江', '镇江市丹徒区新源供水有限公司'],
  ['镇江', '镇江市京口区新泓供水有限公司'],
  ['镇江', '镇江市自来水有限责任公司'],
  ['镇江', '镇江新区新港供水有限公司'],
  ['长春', '农安县自来水有限公司'],
  ['长春', '德惠市自来水有限责任公司'],
  ['长春', '长春兴胜水务有限公司'],
  ['长春', '长春市九台区自来水'],
  ['长春', '长春市自来水公司'],
  ['长沙', '乌山自来水'],
  ['长沙', '浏阳市自来水有限公司'],
  ['长沙', '湖南浏阳经开区水务股份有限公司'],
  ['长沙', '湖南长大集团长沙黄花供水有限公司'],
  ['长沙', '美诚自来水'],
  ['长沙', '长沙供水有限公司'],
  ['长沙', '长沙市望城区丁字兴城自来水'],
  ['长沙', '长沙市望城区井源自来水有限公司'],
  ['长沙', '长沙市望城区自来水有限公司'],
  ['长沙', '长沙榔梨自来水有限公司'],
  ['长沙', '长沙灰汤温泉国际旅游度假区水务'],
  ['长沙', '长沙经济技术开发区星沙水务集团股份有限公司'],
  ['长治', '沁源县自来水公司'],
  ['长治', '襄垣县城乡供水有限公司'],
  ['长治', '长子县水务集团有限公司'],
  ['长治', '长治县黎都供水有限公司'],
  ['长治', '长治市城镇供水集团有限公司'],
  ['长治', '长治市潞城区城乡供水有限公司'],
  ['长治', '黎城县天海自来水有限公司'],
  ['阜新', '彰武县水务有限公司'],
  ['阜新', '阜新水务集团有限责任公司'],
  ['阜新', '阜新蒙古族自治县水务集团有限公司'],
  ['阜阳', '临泉县土陂宇博自来水有限公司'],
  ['阜阳', '临泉县大陈自来水有限公司'],
  ['阜阳', '临泉县永源自来水有限公司'],
  ['阜阳', '临泉徽润供水有限公司'],
  ['阜阳', '太和供水集团有限公司'],
  ['阜阳', '安徽利翔水务有限公司'],
  ['阜阳', '界首市亚杰供水服务有限公司'],
  ['阜阳', '界首市城乡水务集团有限公司'],
  ['阜阳', '阜南县清净水务有限公司'],
  ['阜阳', '阜南首创水务有限责任公司'],
  ['阜阳', '阜阳市供水有限公司（阜阳市区）'],
  ['阜阳', '颍上县城乡水务有限公司'],
  ['阜阳', '颍上首创水务有限责任公司'],
  ['防城港', '东兴市江平镇自来水厂'],
  ['防城港', '广西防城港北投水务有限公司'],
  ['防城港', '广西防城港北投环保水务有限公司'],
  ['防城港', '防城港市港口区民欣水务有限责任公司'],
  ['阳江', '豪江水务'],
  ['阳江', '阳春市公用水务有限公司'],
  ['阳江', '阳江市自来水有限公司'],
  ['阳江', '阳江市阳东漠江水务有限公司'],
  ['阳江', '阳西县丹江水务集团有限公司'],
  ['阳泉', '平定水务发展有限公司'],
  ['阳泉', '盂县城镇供水有限公司'],
  ['阳泉', '阳泉市自来水公司'],
  ['阳泉', '阳泉市西诚供水有限公司'],
  ['阳泉', '阳泉市郊区自来水公司'],
  ['陇南', '宕昌县松润农村供水公司'],
  ['陇南', '徽县徽泰供水有限公司'],
  ['陇南', '文县泉江供水有限公司'],
  ['陇南', '西和县陇泽水务有限公司'],
  ['随州', '广水市东润供水有限责任公司'],
  ['随州', '广水市广水供水公司'],
  ['随州', '广水市润通水务有限公司'],
  ['随州', '老河口市清源供水有限公司'],
  ['随州', '随州市曾都区乡村供水有限公司'],
  ['随州', '随州市曾都区府河自来水有限公司'],
  ['随州', '随州市水务集团城市供水有限公司'],
  ['随州', '随州市水务集团随县供水有限公司'],
  ['随州', '随州盛源水务有限公司'],
  ['青岛', '青岛城阳水务有限公司'],
  ['青岛', '青岛崂山海润水务有限公司'],
  ['青岛', '青岛市即墨区即水水务集团有限公司'],
  ['青岛', '青岛市城阳区自来水公司'],
  ['青岛', '青岛市海润自来水集团有限公司'],
  ['青岛', '青岛平度市自来水公司'],
  ['青岛', '青岛海润丰供水有限责任公司'],
  ['青岛', '青岛润集供水工程有限公司'],
  ['青岛', '青岛灵山源泉水务有限公司'],
  ['青岛', '青岛胶州自来水有限公司'],
  ['青岛', '青岛西海岸公用事业集团农村供水有限公司'],
  ['青岛', '青岛西海岸公用事业集团水务有限公司'],
  ['青岛', '青岛高新海润水务有限公司'],
  ['鞍山', '台安县自来水有限责任公司'],
  ['鞍山', '鞍山市水务集团有限公司'],
  ['韶关', '乐昌市自来水有限公司'],
  ['韶关', '始兴县供水公司水费（马市镇）'],
  ['韶关', '始兴县供水有限责任公司水费'],
  ['韶关', '广东仁化银龙供水有限公司'],
  ['韶关', '韶关市水务投资集团有限公司'],
  ['马鞍山', '和县和州自来水有限公司'],
  ['马鞍山', '安徽省含山县自来水厂'],
  ['马鞍山', '当涂华水水务有限公司'],
  ['马鞍山', '当涂县太白镇华业自来水厂'],
  ['马鞍山', '马鞍山华衍水务有限公司'],
  ['马鞍山', '马鞍山市丰盛薛津供水有限公司'],
  ['马鞍山', '马鞍山横望水务有限公司'],
  ['马鞍山', '马鞍山港润水务有限公司'],
  ['马鞍山', '马鞍山首创水务有限责任公司'],
  ['驻马店', '上蔡县重阳水务有限公司'],
  ['驻马店', '新蔡县自来水公司'],
  ['驻马店', '正阳县三源自来水有限公司'],
  ['驻马店', '汝南县清源自来水有限公司'],
  ['驻马店', '泌阳县自来水公司'],
  ['驻马店', '确山县水务有限公司'],
  ['驻马店', '西平县柏泉自来水有限公司'],
  ['驻马店', '遂平上实水务有限公司'],
  ['驻马店', '驻马店市中业自来水有限公司'],
  ['鸡西', '虎林市城市水务有限公司'],
  ['鸡西', '鸡西市供水有限公司'],
  ['鹤壁', '浚县中州供水有限公司'],
  ['鹤壁', '浚县骏港供水有限公司王庄区域'],
  ['鹤壁', '鹤壁华电水务有限公司'],
  ['鹤壁', '鹤壁市城市水务（集团）有限责任公司'],
  ['鹤壁', '鹤壁市骏港水务有限公司淇县分公司'],
  ['鹤壁', '鹤壁市骏港水务有限公司鹤淇分公司'],
  ['鹰潭', '贵溪市自来水公司'],
  ['鹰潭', '鹰潭市余江区恒源水务有限公司'],
  ['鹰潭', '鹰潭市余江区江川水务有限公司'],
  ['鹰潭', '鹰潭市供水集团有限公司'],
  ['鹰潭', '鹰潭景川水务（龙虎山景区）'],
  ['黄冈', '团风县天翔供水有限公司'],
  ['黄冈', '团风县清源水务集团有限公司'],
  ['黄冈', '武穴市水务有限公司'],
  ['黄冈', '浠水县关口自来水有限公司'],
  ['黄冈', '浠水润中水务有限公司（原浠水县自来水公司）'],
  ['黄冈', '红安县自来水公司'],
  ['黄冈', '罗田县清源水务有限公司'],
  ['黄冈', '老河口市清源供水有限公司'],
  ['黄冈', '英山县城区供水有限公司'],
  ['黄冈', '英山县西河供水有限公司'],
  ['黄冈', '蕲春县农村供水总站斌冲安饮水厂'],
  ['黄冈', '蕲春县蕲州自来水厂'],
  ['黄冈', '蕲春城市供水有限公司'],
  ['黄冈', '麻城市巴水源供水有限公司'],
  ['黄冈', '麻城市龙泉供水有限公司'],
  ['黄冈', '黄冈市自来水有限公司（仅黄州区用户）'],
  ['黄冈', '黄梅县分路镇自来水厂'],
  ['黄冈', '黄梅县民心自来水有限公司'],
  ['黄冈', '黄梅县鑫源自来水有限公司'],
  ['黄山', '休宁县供水有限责任公司'],
  ['黄山', '歙县自来水有限公司'],
  ['黄山', '祁门县钱水水务有限公司'],
  ['黄山', '黄山区(太平)自来水公司'],
  ['黄山', '黄山市徽州区潜口自来水有限公司'],
  ['黄山', '黄山市徽州区自来水有限公司'],
  ['黄山', '黄山水务控股集团有限公司'],
  ['黄山', '黟县国有自来水有限公司'],
  ['黄石', '大冶铜都自来水有限公司'],
  ['黄石', '老河口市清源供水有限公司'],
  ['黄石', '阳新县利民自来水有限公司'],
  ['黄石', '阳新县城发水务有限公司'],
  ['黄石', '阳新县浮屠自来水厂'],
  ['黄石', '黄石市城市水务集团有限公司'],
  ['黄石', '黄石新太水务投资发展有限公司'],
  ['黑河', '北安市供水服务中心'],
  ['齐齐哈尔', '富裕县鸿源供水有限公司'],
  ['齐齐哈尔', '拜泉县清源水务有限公司'],
  ['齐齐哈尔', '甘南县自来水有限责任公司'],
  ['齐齐哈尔', '齐齐哈尔水务集团有限公司'],
  ['龙岩', '上杭县蓝溪镇鑫荣自来水厂'],
  ['龙岩', '永定区坎市镇自来水厂'],
  ['龙岩', '漳平水务公司'],
  ['龙岩', '福建水投集团上杭水务有限公司'],
  ['龙岩', '福建水投集团新罗水务有限公司'],
  ['龙岩', '福建水投集团武平水务有限公司'],
  ['龙岩', '福建水投集团永定水务有限公司'],
  ['龙岩', '福建水投集团长汀水务有限公司'],
  ['龙岩', '连城水务有限公司'],
  ['龙岩', '长汀县自来水供应有限公司'],
  ['龙岩', '龙岩水发自来水有限责任公司'],
];

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

class GasProviderSelectionPage extends StatefulWidget {
  const GasProviderSelectionPage({
    super.key,
    this.locationData,
    this.initialCity,
    this.returnSelection = false,
  });

  final LifePaymentLocationData? locationData;
  final String? initialCity;
  final bool returnSelection;

  @override
  State<GasProviderSelectionPage> createState() =>
      _GasProviderSelectionPageState();
}

class _GasProviderSelectionPageState extends State<GasProviderSelectionPage> {
  final TextEditingController _searchController = TextEditingController();
  late String _selectedCity;
  String _query = '';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCity?.trim();
    if (initial != null && initial.isNotEmpty) {
      _selectedCity = GasProviderCatalog.locationLabelFromRaw(initial);
    } else {
      _selectedCity = GasProviderCatalog.locationLabel(widget.locationData);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isSupportedCity => GasProviderCatalog.byCity(_selectedCity) != null;

  List<GasProviderItem> get _providers {
    final items = GasProviderCatalog.providersOf(_selectedCity);
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
    final picked = await Navigator.of(context).push<GasCityOption>(
      MaterialPageRoute(
        builder: (_) => GasCitySelectionPage(
          selectedCity: _selectedCity,
          locationLabel: GasProviderCatalog.locationLabel(widget.locationData),
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

  void _handleProviderTap(GasProviderItem item) {
    if (widget.returnSelection) {
      Navigator.of(context).pop(item);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GasPaymentPage(
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
                                  GasProviderCatalog.locationLabelFromRaw(
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

class GasPaymentPage extends StatefulWidget {
  const GasPaymentPage({
    super.key,
    this.locationData,
    required this.initialProvider,
  });

  final LifePaymentLocationData? locationData;
  final GasProviderItem initialProvider;

  @override
  State<GasPaymentPage> createState() => _GasPaymentPageState();
}

class _GasPaymentPageState extends State<GasPaymentPage>
    with UtilityAccountFlowMixin {
  final TextEditingController _accountController = TextEditingController();
  late GasProviderItem _selectedProvider;

  /// 后端 providers 接口返回的城市/单位编码；本地目录只有名称，
  /// 编码用于让后端与执行端精确路由，取不到时留空由名称兜底。
  String _cityCode = '';
  String _providerCode = '';

  @override
  UtilityServiceSpec get utilitySpec => kGasServiceSpec;
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
    final picked = await Navigator.of(context).push<GasProviderItem>(
      MaterialPageRoute(
        builder: (_) => GasProviderSelectionPage(
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
                          _GasPaymentForm(
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

class _GasPaymentForm extends StatelessWidget {
  const _GasPaymentForm({
    required this.provider,
    required this.accountController,
    required this.radius,
    required this.titleSize,
    required this.citySize,
    required this.onCityTap,
    required this.onHelpTap,
    required this.onAccountChanged,
  });

  final GasProviderItem provider;
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
                    Icons.local_fire_department_rounded,
                    color: const Color(0xFFFF5A3D),
                    size: citySize * 0.86,
                  ),
                ),
                SizedBox(width: radius * 0.48),
                Text(
                  '燃气费',
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

class GasCitySelectionPage extends StatefulWidget {
  const GasCitySelectionPage({
    super.key,
    required this.selectedCity,
    this.locationLabel,
  });

  final String selectedCity;
  final String? locationLabel;

  @override
  State<GasCitySelectionPage> createState() => _GasCitySelectionPageState();
}

class _GasCitySelectionPageState extends State<GasCitySelectionPage> {
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

  List<GasCityOption> get _filteredCities {
    final normalized =
        _query.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (normalized.isEmpty) return GasProviderCatalog.cityOptions;
    return GasProviderCatalog.cityOptions.where((item) {
      return item.city.contains(_query.trim()) ||
          item.searchKey.contains(normalized);
    }).toList();
  }

  List<LifePaymentCityIndexItem<Object?>> _buildIndexItems({
    required List<GasCityOption> cities,
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

  void _pick(GasCityOption city) {
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
                      prefixIcon: Icon(Icons.search_rounded, color: subColor),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: '清空',
                              icon: Icon(Icons.close_rounded, color: subColor),
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
                                  return _GasCityHeaderBlock(
                                    dark: dark,
                                    locationLabel: widget.locationLabel,
                                    selectedCity: widget.selectedCity,
                                    hotCities: _hotCities,
                                    horizontal: horizontal,
                                    sectionSize: sectionSize,
                                    onPick: _pick,
                                  );
                                }
                                final city = item.data as GasCityOption;
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
                                    _GasCityListTile(
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

class _GasCityHeaderBlock extends StatelessWidget {
  const _GasCityHeaderBlock({
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
  final ValueChanged<GasCityOption> onPick;

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
          child: _GasLocationCityChip(
            dark: dark,
            city: locationLabel,
            onTap: locationLabel == null ||
                    GasProviderCatalog.byCity(locationLabel!) == null
                ? null
                : () {
                    final item = GasProviderCatalog.byCity(locationLabel!);
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
        _GasHotCityGrid(
          dark: dark,
          cities: hotCities
              .map(GasProviderCatalog.byCity)
              .whereType<GasCityOption>()
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

class _GasLocationCityChip extends StatelessWidget {
  const _GasLocationCityChip({
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

class _GasHotCityGrid extends StatelessWidget {
  const _GasHotCityGrid({
    required this.dark,
    required this.cities,
    required this.selectedCity,
    required this.onPick,
    required this.labelSize,
  });

  final bool dark;
  final List<GasCityOption> cities;
  final String selectedCity;
  final ValueChanged<GasCityOption> onPick;
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

class _GasCityListTile extends StatelessWidget {
  const _GasCityListTile({
    required this.dark,
    required this.city,
    required this.selected,
    required this.onTap,
    required this.fontSize,
  });

  final bool dark;
  final GasCityOption city;
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

class GasProviderItem {
  const GasProviderItem({
    required this.city,
    required this.providerName,
    required this.searchKey,
  });

  final String city;
  final String providerName;
  final String searchKey;
}

class GasCityOption {
  const GasCityOption({
    required this.city,
    required this.initial,
    required this.searchKey,
  });

  final String city;
  final String initial;
  final String searchKey;
}

class GasProviderCatalog {
  GasProviderCatalog._();

  static final List<GasProviderItem> all = _buildProviders();
  static final List<GasCityOption> cityOptions = _buildCityOptions();
  static final Map<String, List<GasProviderItem>> _providersByCity =
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

  static List<GasProviderItem> providersOf(String city) {
    final key = _normalizeCity(city);
    return List<GasProviderItem>.unmodifiable(
        _providersByCity[key] ?? const []);
  }

  static GasCityOption? byCity(String city) {
    final key = _normalizeCity(city);
    for (final item in cityOptions) {
      if (_normalizeCity(item.city) == key) return item;
    }
    return null;
  }

  static GasCityOption? matchLocation(LifePaymentLocationData? data) {
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

  static List<GasProviderItem> _buildProviders() {
    return List<GasProviderItem>.unmodifiable(
      _kGasProviderRaw.map((item) {
        final city = item[0];
        final provider = item[1];
        final searchKey = _buildSearchKey(city, provider);
        return GasProviderItem(
          city: city,
          providerName: provider,
          searchKey: searchKey,
        );
      }),
    );
  }

  static List<GasCityOption> _buildCityOptions() {
    final seen = <String>{};
    final result = <GasCityOption>[];
    for (final item in _kGasProviderRaw) {
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
        GasCityOption(
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
    return List<GasCityOption>.unmodifiable(result);
  }

  static Map<String, List<GasProviderItem>> _groupProviders() {
    final map = <String, List<GasProviderItem>>{};
    for (final item in all) {
      final key = _normalizeCity(item.city);
      map.putIfAbsent(key, () => <GasProviderItem>[]).add(item);
    }
    // 按上传 TXT 的原始顺序展示同一城市的缴费单位，便于与来源清单逐项核对。
    return map.map((key, value) {
      return MapEntry(key, List<GasProviderItem>.unmodifiable(value));
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

const List<List<String>> _kGasProviderRaw = <List<String>>[
  ['上海', '上海燃气有限公司'],
  ['上海', '上海大众燃气'],
  ['上海', '上海燃气有限公司（条形码）'],
  ['上海', '上海青浦燃气有限公司'],
  ['上海', '上海宝山燃气有限公司'],
  ['上海', '上海松江燃气有限公司'],
  ['上海', '上海海贤能源股份有限公司'],
  ['上海', '上海益流天然气销售有限公司'],
  ['上海', '上海青浦燃气有限公司（充值）'],
  ['重庆', '重庆燃气集团公司'],
  ['重庆', '神州能源集团股份有限公司'],
  ['重庆', '重庆万州燃气有限公司'],
  ['重庆', '重庆中民燃气有限公司'],
  ['重庆', '重庆中民燃气有限公司（物联网表）'],
  ['重庆', '重庆伟盛夔州燃气有限公司'],
  ['重庆', '重庆伟盛森宇燃气开发有限公司'],
  ['重庆', '重庆伟盛泽宇燃气开发有限公司'],
  ['重庆', '重庆伟盛燃气云阳分公司'],
  ['重庆', '重庆伟盛燃气南川分公司'],
  ['重庆', '重庆伟盛燃气垫江分公司'],
  ['重庆', '重庆伟盛燃气大渡口分公司'],
  ['重庆', '重庆伟盛燃气开发有限公司'],
  ['重庆', '重庆凯源石油天然气公司'],
  ['重庆', '重庆华邦燃气集团有限公司'],
  ['重庆', '重庆川友天然气有限公司'],
  ['重庆', '重庆川港燃气有限公司'],
  ['重庆', '重庆市众源天然气有限公司'],
  ['重庆', '重庆市武隆区民生燃气有限公司'],
  ['重庆', '重庆市永川区石油天然气安装工程有限公司'],
  ['重庆', '重庆市渝北区佳渝天然气有限公司'],
  ['重庆', '重庆市渝川燃气有限责任公司'],
  ['重庆', '重庆市铜梁区陆升天然气有限公司'],
  ['重庆', '重庆正能燃气有限责任公司'],
  ['重庆', '重庆永康燃气有限公司'],
  ['重庆', '重庆润民天然气有限责任公司'],
  ['重庆', '重庆潜能燃气股份有限公司'],
  ['重庆', '重庆神州天然气有限公司'],
  ['重庆', '重庆胜邦燃气有限公司'],
  ['重庆', '重庆胜邦燃气有限公司(物联网表)'],
  ['重庆', '重庆中燃城市燃气发展有限公司'],
  ['石家庄', '石家庄金明燃气有限公司'],
  ['石家庄', '(正定县域)河北潜能燃气股份有限公司'],
  ['石家庄', '元氏县元盛燃气有限公司'],
  ['石家庄', '晋州市建投燃气有限公司（卡表）'],
  ['石家庄', '晋州市建投燃气有限公司（普表）'],
  ['石家庄', '石家庄市捷诚天然气（远传表）'],
  ['石家庄', '石家庄建投天然气有限公司（卡表）'],
  ['石家庄', '石家庄建投天然气有限公司（普表）'],
  ['石家庄', '辛集市燃气公司'],
  ['石家庄', '石家庄空港天然气有限公司'],
  ['石家庄', '石家庄昆仑新奥燃气有限公司无极分公司'],
  ['石家庄', '石家庄昆仑新奥燃气有限公司行唐分公司'],
  ['石家庄', '石家庄昆仑新奥燃气有限公司辛集分公司'],
  ['石家庄', '石家庄昆仑新奥燃气有限公司灵寿分公司'],
  ['石家庄', '石家庄市鹿泉区昆仑新奥燃气有限公司'],
  ['石家庄', '石家庄昆仑新奥燃气有限公司晋州分公司'],
  ['石家庄', '昆仑新奥燃气发展有限公司'],
  ['石家庄', '石家庄新奥中泓燃气有限公司'],
  ['石家庄', '石家庄新奥燃气有限公司'],
  ['石家庄', '石家庄昆仑新奥燃气有限公司井陉分公司'],
  ['石家庄', '石家庄昆仑新奥燃气有限公司深泽分公司'],
  ['石家庄', '石家庄昆仑新奥燃气有限公司井陉矿区分公司'],
  ['石家庄', '石家庄新奥蓝天清洁能源有限公司无极分公司'],
  ['石家庄', '石家庄市鹿泉区新奥燃气有限公司'],
  ['石家庄', '高邑中燃能源发展有限公司'],
  ['石家庄', '鹿泉富新燃气有限公司'],
  ['石家庄', '石家庄市藁城区中燃翔科燃气有限公司'],
  ['石家庄', '石家庄中燃翔科燃气有限公司'],
  ['石家庄', '无极县中燃新能源开发有限公司'],
  ['石家庄', '元氏县中燃能源发展有限公司'],
  ['石家庄', '赵县中燃能源发展有限公司'],
  ['石家庄', '无极县中奥新能源有限公司'],
  ['石家庄', '石家庄新奥蓝天清洁能源有限公司赵县分公司'],
  ['石家庄', '平山新奥燃气有限公司'],
  ['唐山', '唐山市燃气集团有限公司'],
  ['唐山', '唐山市丰南区天达天然气有限公司'],
  ['唐山', '唐山泰达燃气有限公司'],
  ['唐山', '唐山滨海燃气有限公司'],
  ['唐山', '迁安华润燃气有限公司'],
  ['唐山', '迁西县天然气有限公司'],
  ['唐山', '滦州新奥清洁能源有限公司'],
  ['唐山', '乐亭中燃能源发展有限公司'],
  ['唐山', '乐亭中燃翔科燃气有限公司'],
  ['唐山', '唐山南堡中燃燃气有限公司'],
  ['唐山', '玉田中燃能源发展有限公司'],
  ['唐山', '唐山丰南新奥燃气有限公司'],
  ['唐山', '玉田新奥燃气有限公司'],
  ['秦皇岛', '华润燃气北戴河新区分公司'],
  ['秦皇岛', '华润燃气山海关分公司'],
  ['秦皇岛', '秦皇岛华润燃气北戴河分公司'],
  ['秦皇岛', '秦皇岛华润燃气有限公司'],
  ['秦皇岛', '秦皇岛聚能燃气有限公司'],
  ['秦皇岛', '秦皇岛中燃燃气有限公司'],
  ['邯郸', '临漳中裕燃气有限公司'],
  ['邯郸', '大名华润燃气有限公司'],
  ['邯郸', '武安华润燃气有限公司'],
  ['邯郸', '河北光祥燃气销售有限公司'],
  ['邯郸', '河北赵都天然气公司（卡表）'],
  ['邯郸', '河北赵都天然气公司（普表）'],
  ['邯郸', '河北赵都天然气肥乡分公司（卡表）'],
  ['邯郸', '河北赵都天然气肥乡分公司（普表）'],
  ['邯郸', '邯郸华润燃气有限公司'],
  ['邯郸', '邯郸华润燃气有限公司峰峰分公司'],
  ['邯郸', '邯郸市峰峰矿区华润燃气有限公司'],
  ['邯郸', '鸡泽中裕燃气有限公司'],
  ['邯郸', '磁县中燃能源发展有限公司'],
  ['邯郸', '大名县中燃能源发展有限公司'],
  ['邯郸', '馆陶县中燃能源发展有限公司'],
  ['邯郸', '广平中燃城市燃气发展有限公司'],
  ['邯郸', '邯郸市肥乡区中燃能源发展有限公司'],
  ['邯郸', '邯郸市中燃城市燃气发展有限公司'],
  ['邯郸', '鸡泽县中燃能源发展有限公司'],
  ['邯郸', '临漳县中燃能源发展有限公司'],
  ['邯郸', '邱县中燃能源发展有限公司'],
  ['邯郸', '曲周县中燃能源发展有限公司'],
  ['邯郸', '魏县中燃能源发展有限公司'],
  ['邢台', '临西县新能天然气工程公司（卡表）'],
  ['邢台', '临西县新能天然气工程公司（普表）'],
  ['邢台', '宁晋县中裕燃气有限公司'],
  ['邢台', '河北省天然气沙河分公司（卡表）'],
  ['邢台', '河北省天然气沙河分公司（普表）'],
  ['邢台', '清河县建投天然气有限公司（卡表）'],
  ['邢台', '清河县建投天然气有限公司（普表）'],
  ['邢台', '邢台中裕燃气有限公司'],
  ['邢台', '邢台天宏祥燃气有限公司（普表）'],
  ['邢台', '邢台燃气集团有限责任公司'],
  ['邢台', '柏乡县金鑫天然气有限公司'],
  ['邢台', '广宗县中燃能源发展有限公司'],
  ['邢台', '临城中燃能源发展有限公司'],
  ['邢台', '临西县川东天然气有限公司'],
  ['邢台', '隆尧县华澳天然气有限公司'],
  ['邢台', '隆尧县华燊天然气销售有限公司'],
  ['邢台', '南宫中燃能源发展有限公司'],
  ['邢台', '南和县华澳天然气有限公司'],
  ['邢台', '南和县中燃能源发展有限公司'],
  ['邢台', '宁晋县中燃能源发展有限公司'],
  ['邢台', '任县中燃能源发展有限公司'],
  ['邢台', '沙河市中燃能源发展有限公司'],
  ['邢台', '邢台中燃能源发展有限公司'],
  ['邢台', '邢台中燃能源发展有限公司威县分公司'],
  ['邢台', '邢台中燃能源发展有限公司邢台县分公司'],
  ['邢台', '邢台中燃能源管理有限公司'],
  ['邢台', '临城国源燃气有限公司'],
  ['邢台', '邢台新奥能源发展有限公司'],
  ['保定', '保定市恒燃燃气有限公司'],
  ['保定', '安国市华港燃气有限公司（卡表）'],
  ['保定', '安国市华港燃气有限公司（普表）'],
  ['保定', '安新泰达燃气有限公司'],
  ['保定', '河北省天然气涞源分公公司（卡表）'],
  ['保定', '河北省天然气涞源分公公司（普表）'],
  ['保定', '涿州滨海燃气有限公司'],
  ['保定', '清苑滨海燃气有限公司'],
  ['保定', '蠡县建投天然气有限公司（卡表）'],
  ['保定', '蠡县建投天然气有限公司（普表）'],
  ['保定', '雄县双盛燃气有限公司'],
  ['保定', '雄县民顺燃气有限公司'],
  ['保定', '顺平深燃天然气有限公司'],
  ['保定', '保定中石油昆仑能源有限公司'],
  ['保定', '保定中石油昆仑燃气有限公司'],
  ['保定', '保定中燃保北能源有限公司'],
  ['保定', '保定中燃保南能源有限公司'],
  ['保定', '保定中燃帝华清洁能源有限公司'],
  ['保定', '保定中燃宏洁能源开发有限公司'],
  ['保定', '博野县中燃能源有限公司'],
  ['保定', '定兴县中燃宏洁能源开发有限公司'],
  ['保定', '定州市中燃城市燃气有限公司'],
  ['保定', '定州中燃宏洁能源发展有限公司'],
  ['保定', '高碑店市中燃能源发展有限公司'],
  ['保定', '涞水中燃天然气有限公司'],
  ['保定', '蠡县中燃能源发展有限公司'],
  ['保定', '曲阳中燃燃气发展有限公司'],
  ['保定', '顺平县中燃天然气有限公司'],
  ['保定', '唐县中燃城市燃气发展有限公司'],
  ['保定', '望都中燃城市燃气发展有限公司'],
  ['保定', '保定奥嘉能源有限公司'],
  ['保定', '保定市中奥燃气有限公司'],
  ['保定', '博野县奥德燃气有限公司'],
  ['保定', '安国奥德燃气有限公司'],
  ['保定', '蠡县奥德燃气有限公司'],
  ['保定', '赤城县民乐燃气有限公司'],
  ['保定', '阜平奥德燃气有限公司'],
  ['保定', '雄县新长虹燃气有限公司'],
  ['保定', '定州昆仑新奥能源发展有限公司'],
  ['张家口', '张家口下花园中裕燃气有限责任公司'],
  ['张家口', '张家口中油金鸿天然气有限公司'],
  ['张家口', '张家口宣化金鸿燃气有限公司'],
  ['张家口', '怀来华港燃气'],
  ['张家口', '蔚县中裕燃气有限公司'],
  ['张家口', '怀来中燃翔科燃气有限公司'],
  ['张家口', '康保中燃城市燃气发展有限公司'],
  ['张家口', '沽源奥德燃气有限公司'],
  ['张家口', '怀来新奥燃气有限公司'],
  ['承德', '兴隆县恒安达燃气有限公司'],
  ['承德', '承德县盛德燃气有限公司'],
  ['承德', '承德市兴徳燃气供应有限公司（鹰手营子矿区）'],
  ['承德', '承德市建投天然气公司（卡表）'],
  ['承德', '承德市建投天然气公司（普表）'],
  ['承德', '承德建投天然气滦平分公司（普表）'],
  ['沧州', '吴桥中裕燃气有限公司'],
  ['沧州', '孟村宏道隆缘燃气有限公司'],
  ['沧州', '沧州华润燃气有限公司'],
  ['沧州', '沧州天庆燃气有限公司'],
  ['沧州', '沧州天硕天然气技术开发有限公司'],
  ['沧州', '河北天元天然气销售有限公司'],
  ['沧州', '河北省天然气肃宁分公司（卡表）'],
  ['沧州', '河北省天然气肃宁分公司（普表）'],
  ['沧州', '海兴县兴德燃气有限公司'],
  ['沧州', '泊头中燃能源发展有限公司'],
  ['沧州', '沧州中燃城市燃气发展有限公司'],
  ['沧州', '东光中燃能源发展有限公司'],
  ['沧州', '海兴中燃能源发展有限公司'],
  ['沧州', '河间市中燃能源发展有限公司'],
  ['沧州', '孟村回族自治县中燃能源发展有限公司'],
  ['沧州', '南皮中燃城市燃气发展有限公司'],
  ['沧州', '青县中燃能源发展有限公司'],
  ['沧州', '肃宁县中燃能源发展有限公司'],
  ['沧州', '吴桥中燃能源发展有限公司'],
  ['沧州', '献县川能天然气有限公司'],
  ['沧州', '献县中燃能源发展有限公司'],
  ['沧州', '盐山中燃能源发展有限公司'],
  ['沧州', '沧县奥德燃气有限公司'],
  ['沧州', '沧州金海岸燃气销售有限公司'],
  ['沧州', '沧州金海岸燃气销售有限公司北李庄'],
  ['沧州', '泊头中奥燃气有限公司'],
  ['沧州', '青县奥德燃气有限公司'],
  ['沧州', '献县新奥燃气有限公司'],
  ['沧州', '孟村回族自治县新奥燃气有限公司'],
  ['沧州', '沧州南大港新奥燃气有限公司'],
  ['廊坊', '三河泰达燃气有限公司'],
  ['廊坊', '廊坊市铭顺石油天然气销售有限公司'],
  ['廊坊', '霸州市华盛燃气有限公司'],
  ['廊坊', '廊坊新奥燃气有限公司'],
  ['廊坊', '大城县中燃宏胜能源科技有限公司'],
  ['廊坊', '文安县奥德燃气有限公司'],
  ['廊坊', '文安县奥德燃气有限公司左各庄分公司'],
  ['廊坊', '文安县中燃宏胜能源科技有限公司'],
  ['廊坊', '文安新奥铭顺燃气有限公司'],
  ['廊坊', '文安县昱通燃气有限公司'],
  ['衡水', '冀州滨海燃气有限公司'],
  ['衡水', '故城中裕燃气有限公司'],
  ['衡水', '枣强华润燃气有限公司'],
  ['衡水', '河北省天然气安平分公司（卡表）'],
  ['衡水', '河北省天然气安平分公司（普表）'],
  ['衡水', '深州市建投燃气有限公司（卡表）'],
  ['衡水', '深州市建投燃气有限公司（普表）'],
  ['衡水', '衡水中裕燃气有限公司'],
  ['衡水', '衡水华润燃气有限公司'],
  ['衡水', '衡水建投天然气有限公司（卡表）'],
  ['衡水', '衡水建投天然气有限公司（普表）'],
  ['衡水', '衡水恒洁燃气有限公司'],
  ['衡水', '饶阳县建投天然气有限公司（卡表）'],
  ['衡水', '饶阳县建投天然气有限公司（普表）'],
  ['衡水', '安平宏洁能源发展有限公司'],
  ['衡水', '阜城中燃能源发展有限公司'],
  ['衡水', '衡水中燃宏洁能源发展有限公司'],
  ['衡水', '衡水中燃能源发展有限公司'],
  ['衡水', '景县中燃能源发展有限公司'],
  ['衡水', '深州中燃能源发展有限公司'],
  ['衡水', '武邑中燃能源发展有限公司'],
  ['衡水', '枣强中燃能源发展有限公司'],
  ['衡水', '武强县武希天然气有限公司'],
  ['太原', '古交市国新燃气综合利用有限公司'],
  ['太原', '太原天然气有限公司'],
  ['太原', '娄烦华润燃气有限公司'],
  ['太原', '山西华新科莱天然气有限公司'],
  ['太原', '山西华腾能源科技有限公司'],
  ['太原', '阳曲华润燃气有限公司'],
  ['太原', '山西中燃国新城市燃气有限公司'],
  ['太原', '太原中燃能源发展有限公司'],
  ['大同', '大同华润燃气有限公司'],
  ['大同', '大同华润燃气有限公司大同县分公司'],
  ['大同', '大同华润燃气有限公司天镇县分公司'],
  ['大同', '大同华润燃气有限公司左云县分公司'],
  ['大同', '大同华润燃气有限公司广灵县分公司'],
  ['大同', '大同华润燃气有限公司浑源县分公司'],
  ['大同', '大同华润燃气有限公司灵丘县分公司'],
  ['大同', '大同华润燃气有限公司阳高县分公司'],
  ['阳泉', '山西晋东华润燃气有限公司'],
  ['阳泉', '阳泉华润燃气有限公司'],
  ['长治', '壶关华润燃气有限公司'],
  ['长治', '山西三晋新能源发展有限公司'],
  ['长治', '武乡县森众燃气有限公司'],
  ['长治', '潞城华润燃气有限公司'],
  ['长治', '长治华润燃气有限公司'],
  ['长治', '黎城森众燃气有限公司'],
  ['长治', '屯留县中燃宏洁能源发展有限公司'],
  ['长治', '襄垣县中燃能源有限公司'],
  ['长治', '长治中燃能源发展有限公司'],
  ['长治', '长子县中燃能源发展有限公司'],
  ['晋城', '华新城市燃气公司晋城分公司'],
  ['晋城', '晋城市燃气有限公司'],
  ['朔州', '大同华润燃气有限公司右玉县分公司'],
  ['朔州', '应县富华燃气有限责任公司'],
  ['朔州', '怀仁煤气化燃气有限公司'],
  ['朔州', '朔州能吉燃气有限公司'],
  ['晋中', '太原煤炭气化（集团）晋中燃气有限公司'],
  ['晋中', '祁县洁源天然气有限公司'],
  ['晋中', '介休中燃能源发展有限公司'],
  ['晋中', '昔阳县中燃能源发展有限公司'],
  ['运城', '绛县民利燃气有限公司'],
  ['运城', '绛县中燃能源发展有限公司'],
  ['运城', '临猗中燃能源发展有限公司'],
  ['运城', '万荣中燃宏洁能源发展有限公司'],
  ['运城', '运城中燃燃气有限公司'],
  ['忻州', '保德县海通燃气供应有限责任公司'],
  ['忻州', '原平市天然气有限责任公司'],
  ['忻州', '河曲县振刚天然气有限公司'],
  ['忻州', '繁峙中燃能源发展有限责任公司'],
  ['临汾', '山西新盛源能源有限公司'],
  ['临汾', '洪洞华润恒富燃气有限公司'],
  ['临汾', '霍州华润燃气有限公司'],
  ['临汾', '霍州中燃能源发展有限公司'],
  ['临汾', '山西中燃燃气发展有限公司曲沃分公司'],
  ['临汾', '乡宁中燃城市燃气发展有限公司'],
  ['临汾', '临汾中石油昆仑燃气有限公司'],
  ['临汾', '太原煤炭气化（集团）临汾燃气有限公司'],
  ['吕梁', '兴县华盛燃气有限责任公司'],
  ['吕梁', '柳林太燃燃气有限公司'],
  ['吕梁', '柳林太燃燃气有限公司(卡表)'],
  ['吕梁', '汾阳市中燃能源发展有限公司'],
  ['吕梁', '交城中燃能源发展有限公司'],
  ['吕梁', '柳林县中燃能源发展有限公司'],
  ['吕梁', '山西中燃国新城市燃气有限公司岚县分公司'],
  ['吕梁', '文水中燃燃气能源有限公司'],
  ['呼和浩特', '呼和浩特市燃气热力有限公司'],
  ['呼和浩特', '呼和浩特市盛乐经济园区中燃燃气有限公司'],
  ['呼和浩特', '呼和浩特市中燃百江能源有限公司'],
  ['呼和浩特', '呼和浩特市中燃物业服务有限公司'],
  ['呼和浩特', '清水河县中燃燃气有限公司'],
  ['呼和浩特', '土默特左旗中燃燃气有限公司'],
  ['呼和浩特', '托克托县中燃燃气有限公司'],
  ['呼和浩特', '武川县中燃燃气有限公司'],
  ['包头', '包头中燃'],
  ['包头', '包头市燃气有限公司'],
  ['包头', '包头市中燃百江能源有限公司'],
  ['包头', '包头市中燃投资清洁能源有限公司'],
  ['包头', '包头新奥燃气有限公司'],
  ['包头', '包头市东河中燃城市燃气发展有限公司'],
  ['赤峰', '巴林右旗中裕燃气（物联网表）'],
  ['赤峰', '赤峰华润燃气有限公司'],
  ['赤峰', '赤峰华润燃气有限公司平庄综合站'],
  ['赤峰', '赤峰新城富龙管道燃气公司物联网表'],
  ['赤峰', '赤峰市中燃清洁能源有限公司'],
  ['通辽', '通辽新奥燃气有限公司'],
  ['通辽', '科尔沁左翼中旗奥德燃气有限公司'],
  ['通辽', '霍林郭勒市恒通燃气有限责任公司'],
  ['通辽', '库伦旗奥德燃气有限公司'],
  ['鄂尔多斯', '准格尔旗国资燃气热力有限责任公司'],
  ['鄂尔多斯', '鄂托克旗长蒙天然气有限责任公司蒙西分公司'],
  ['鄂尔多斯', '鄂托克旗长蒙中燃清洁能源有限责任公司'],
  ['呼伦贝尔', '莫力达瓦达斡尔族自治旗奥德燃气有限公司'],
  ['巴彦淖尔', '巴彦淖尔市腾洁燃气有限责任公司'],
  ['巴彦淖尔', '腾洁燃气公司乌拉特中旗分公司'],
  ['巴彦淖尔', '腾洁燃气公司乌拉特前旗分公司'],
  ['巴彦淖尔', '腾洁燃气公司乌拉特后旗分公司'],
  ['巴彦淖尔', '腾洁燃气公司五原分公司'],
  ['巴彦淖尔', '腾洁燃气公司杭锦后旗分公司'],
  ['巴彦淖尔', '腾洁燃气公司磴口分公司'],
  ['巴彦淖尔', '磴口县中燃城市燃气发展有限公司'],
  ['巴彦淖尔', '乌拉特前旗中燃城市燃气发展有限公司'],
  ['巴彦淖尔', '乌拉特中旗中燃城市燃气发展有限公司'],
  ['乌兰察布', '凉城县中燃燃气有限公司'],
  ['沈阳', '沈阳燃气有限公司'],
  ['沈阳', '沈阳中燃城市燃气发展有限公司'],
  ['沈阳', '沈阳奥德燃气有限公司'],
  ['沈阳', '沈阳奥德燃气有限公司新民兴隆堡'],
  ['沈阳', '沈阳奥德燃气有限公司新民分公司'],
  ['沈阳', '灯塔恒泰利燃气有限公司'],
  ['沈阳', '辽宁中奥燃气有限公司'],
  ['大连', '大连华润燃气有限公司'],
  ['大连', '大连保税区华润燃气有限公司'],
  ['大连', '大连花园口华润燃气有限公司'],
  ['大连', '大连金州中燃城市燃气发展有限公司'],
  ['大连', '普兰店中燃城市燃气发展有限公司'],
  ['大连', '长海中燃城市燃气发展有限公司'],
  ['大连', '大连奥德燃气有限公司'],
  ['鞍山', '岫岩华润燃气有限公司'],
  ['鞍山', '海城华润燃气有限公司'],
  ['鞍山', '鞍山华润燃气有限公司'],
  ['鞍山', '台安奥德燃气有限公司'],
  ['鞍山', '鞍山中奥燃气有限公司'],
  ['抚顺', '抚顺中燃城市燃气发展有限公司'],
  ['抚顺', '清原中燃城市燃气发展有限公司'],
  ['抚顺', '新宾中燃城市燃气发展有限公司'],
  ['本溪', '本溪华润燃气有限公司'],
  ['本溪', '本溪南芬华润燃气有限公司'],
  ['本溪', '桓仁华润燃气有限公司'],
  ['丹东', '丹东华润燃气有限公司'],
  ['丹东', '丹东市燃气总公司'],
  ['丹东', '凤城华润燃气有限公司'],
  ['丹东', '丹东中燃城市燃气发展有限公司'],
  ['丹东', '宽甸中燃城市燃气发展有限公司'],
  ['丹东', '东港奥德燃气有限公司'],
  ['丹东', '东港孤山奥德燃气有限公司'],
  ['丹东', '丹东前阳奥德燃气有限公司'],
  ['锦州', '锦州华润燃气有限公司'],
  ['锦州', '锦州中燃城市燃气发展有限公司'],
  ['锦州', '锦州中燃能源发展有限公司'],
  ['锦州', '北镇奥德能源有限公司'],
  ['锦州', '黑山奥德燃气有限公司'],
  ['营口', '中海油新润辽宁燃气有限责任公司'],
  ['营口', '营口华润燃气有限公司'],
  ['营口', '营口宝明燃气费'],
  ['营口', '营口港华燃气有限公司'],
  ['营口', '营口燃气集团有限公司'],
  ['营口', '盖州中燃城市燃气发展有限公司'],
  ['阜新', '阜新港华燃气有限公司'],
  ['阜新', '彰武奥德燃气有限公司'],
  ['阜新', '阜新奥德燃气有限公司'],
  ['阜新', '阜新市清河门区奥德燃气有限公司'],
  ['辽阳', '辽阳华润燃气有限公司'],
  ['辽阳', '辽阳中燃城市燃气发展有限公司'],
  ['辽阳', '辽阳县奥德燃气输配有限公司'],
  ['辽阳', '辽阳奥德燃气有限公司'],
  ['盘锦', '盘锦华润燃气有限公司'],
  ['盘锦', '盘锦国华燃气有限公司'],
  ['盘锦', '盘山盛泰燃气有限公司'],
  ['铁岭', '铁岭港华燃气有限公司'],
  ['铁岭', '昌图奥德燃气有限公司'],
  ['铁岭', '西丰奥德燃气有限公司'],
  ['铁岭', '调兵山奥德燃气有限公司'],
  ['铁岭', '铁岭奥德燃气有限公司'],
  ['铁岭', '铁岭奥德管输燃气有限公司'],
  ['朝阳', '朝阳港华燃气有限公司'],
  ['葫芦岛', '葫芦岛新奥燃气有限公司'],
  ['葫芦岛', '建昌奥德燃气有限公司'],
  ['长春', '长春天然气集团有限公司'],
  ['长春', '长春燃气股份有限公司'],
  ['长春', '长春燃气（德惠）发展有限公司'],
  ['长春', '吉林中燃清洁能源有限公司'],
  ['吉林', '吉林市华润燃气有限公司'],
  ['吉林', '昆仑燃气吉林分公司'],
  ['吉林', '吉林吉港清洁能源有限公司松原分公司'],
  ['吉林', '吉林港华燃气有限公司'],
  ['吉林', '桦甸中润燃气有限公司'],
  ['吉林', '蛟河中燃城市燃气发展有限公司'],
  ['四平', '吉林省华生燃气集团有限公司'],
  ['四平', '梨树县华生燃气有限公司'],
  ['辽源', '辽源华润燃气有限公司'],
  ['辽源', '东丰能源有限公司'],
  ['通化', '集安华润燃气有限公司'],
  ['白山', '白山中裕城市燃气有限公司'],
  ['白山', '白山中裕燃气公司（物联网表）'],
  ['白山', '抚松中燃城市燃气发展有限公司'],
  ['白山', '靖宇县国德燃气有限公司'],
  ['松原', '松原华润燃气有限公司'],
  ['松原', '松原市北燃蓝天新能源有限公司燃气费（物联网表）'],
  ['白城', '大安市大地燃气'],
  ['白城', '白城华润燃气有限公司'],
  ['白城', '白城华润燃气有限公司洮南分公司'],
  ['白城', '镇赉县大地燃气'],
  ['白城', '镇赉县昆仑宏安燃气有限公司'],
  ['哈尔滨', '哈尔滨中庆燃气'],
  ['哈尔滨', '哈尔滨华润燃气有限公司'],
  ['哈尔滨', '尚志华润燃气有限公司'],
  ['哈尔滨', '宾县中燃城市燃气发展有限公司'],
  ['哈尔滨', '方正县中燃城市燃气发展有限公司'],
  ['哈尔滨', '哈尔滨阿城中燃城市燃气发展有限公司'],
  ['哈尔滨', '哈尔滨中庆清洁能源有限公司'],
  ['哈尔滨', '五常中燃城市燃气发展有限公司'],
  ['哈尔滨', '延寿奥德燃气有限公司'],
  ['哈尔滨', '黑龙江奥德燃气有限公司'],
  ['哈尔滨', '哈尔滨新奥燃气有限公司'],
  ['齐齐哈尔', '齐齐哈尔港华燃气有限公司'],
  ['齐齐哈尔', '泰来中燃城市燃气发展有限公司'],
  ['齐齐哈尔', '齐齐哈尔港华富拉尔基分公司'],
  ['鸡西', '黑龙江森林中燃城市燃气发展有限公司八五四农场分公司'],
  ['鸡西', '黑龙江森林中燃城市燃气发展有限公司东方红分公司'],
  ['鸡西', '鸡西中燃城市燃气发展有限公司'],
  ['鸡西', '密山奥德燃气有限公司'],
  ['鹤岗', '黑龙江省宝泉岭农垦中燃城市燃气发展有限公司'],
  ['鹤岗', '萝北中燃城市燃气发展有限公司'],
  ['鹤岗', '绥滨中燃城市燃气发展有限公司'],
  ['鹤岗', '鹤岗奥德燃气有限公司'],
  ['双鸭山', '黑龙江红兴隆农垦中燃城市燃气发展有限公司'],
  ['双鸭山', '饶河中燃城市燃气发展有限公司'],
  ['双鸭山', '双鸭山中燃城市燃气发展有限公司'],
  ['双鸭山', '集贤奥德燃气有限公司'],
  ['大庆', '大庆中石油昆仑燃气'],
  ['大庆', '黑龙江森林中燃城市燃气发展有限公司和平牧场分公司'],
  ['大庆', '肇源中燃城市燃气发展有限公司'],
  ['大庆', '大庆燃气公司'],
  ['大庆', '大庆奥德燃气有限公司'],
  ['佳木斯', '黑龙江省建三江农垦中燃城市燃气发展有限公司'],
  ['佳木斯', '桦川中燃城市燃气发展有限公司'],
  ['佳木斯', '桦南中燃城市燃气发展有限公司'],
  ['佳木斯', '佳木斯中燃城市燃气发展有限公司'],
  ['佳木斯', '汤原中燃城市燃气发展有限公司'],
  ['佳木斯', '同江中燃城市燃气发展有限公司'],
  ['七台河', '勃利中燃城市燃气发展有限公司'],
  ['七台河', '七台河中燃城市燃气发展有限公司'],
  ['牡丹江', '黑龙江森林中燃城市燃气发展有限公司柴河分公司'],
  ['牡丹江', '黑龙江森林中燃城市燃气发展有限公司海林大海林分公司'],
  ['牡丹江', '牡丹江中燃城市燃气发展有限公司'],
  ['牡丹江', '海林奥德燃气有限公司'],
  ['黑河', '黑河华润燃气有限公司'],
  ['黑河', '黑河中燃城市燃气发展有限公司'],
  ['黑河', '黑河中燃城市燃气发展有限公司呼玛分公司'],
  ['黑河', '孙吴中燃城市燃气发展有限公司'],
  ['黑河', '五大连池风景区中燃城市燃气发展有限公司'],
  ['黑河', '五大连池中燃城市燃气发展有限公司'],
  ['黑河', '逊克中燃城市燃气发展有限公司'],
  ['绥化', '肇东中石油昆仑燃气有限公司'],
  ['绥化', '安达中燃城市燃气发展有限公司'],
  ['绥化', '青冈奥德燃气有限公司'],
  ['绥化', '绥化新奥燃气有限公司'],
  ['南京', '南京华润燃气有限公司'],
  ['南京', '南京港华燃气有限公司'],
  ['南京', '南京滨海燃气有限公司'],
  ['南京', '南京高淳港华燃气有限公司'],
  ['南京', '中油燃气（南京）有限公司'],
  ['南京', '南京中燃百江能源有限公司'],
  ['南京', '南京中燃城市燃气发展有限公司'],
  ['南京', '南京中燃热力有限公司'],
  ['南京', '南京中燃热力有限公司江北分公司'],
  ['南京', '南乐中燃能源发展有限公司'],
  ['无锡', '无锡华润燃气有限公司'],
  ['无锡', '无锡洛社中石油昆仑燃气有限公司'],
  ['无锡', '无锡洛社昆仑燃气'],
  ['无锡', '宜兴港华燃气有限公司'],
  ['徐州', '丰县滨海燃气有限公司（物联网表）'],
  ['徐州', '徐州中裕能源有限公司'],
  ['徐州', '徐州港华燃气有限公司'],
  ['徐州', '铜山港华燃气有限公司'],
  ['徐州', '沛县港华燃气有限公司'],
  ['徐州', '丰县港华燃气有限公司'],
  ['徐州', '徐州中石油昆仑燃气有限公司'],
  ['徐州', '邳州中燃城市燃气发展有限公司'],
  ['徐州', '邳州中燃佳明燃气发展有限公司'],
  ['徐州', '新沂中燃城镇燃气有限公司'],
  ['徐州', '徐州贾汪中燃城市燃气发展有限公司'],
  ['徐州', '徐州奥德燃气有限公司'],
  ['徐州', '新沂奥德燃气有限公司'],
  ['徐州', '睢宁万丰天然气有限公司'],
  ['常州', '常州港华燃气居民客户（不含金坛区）'],
  ['常州', '常州港华燃气工商客户（充值）'],
  ['常州', '常州港华燃气工商客户（缴费）'],
  ['常州', '常州金坛港华燃气有限公司'],
  ['常州', '溧阳安顺燃气有限公司'],
  ['常州', '常州新奥燃气发展有限公司'],
  ['苏州', '太仓华润燃气有限公司'],
  ['苏州', '太仓市燃气有限公司'],
  ['苏州', '常熟市天然气有限公司（物联网表）'],
  ['苏州', '张家港港华燃气有限公司'],
  ['苏州', '昆山利通燃气有限公司'],
  ['苏州', '昆山华润城市燃气有限公司'],
  ['苏州', '昆山安达天然气发展有限公司'],
  ['苏州', '昆山高峰天然气有限公司物联网表'],
  ['苏州', '昆山高峰天然气有限公司（普表）'],
  ['苏州', '苏州华润燃气有限公司'],
  ['苏州', '苏州市吴中区燃气有限公司'],
  ['苏州', '苏州市相城区燃气有限责任公司'],
  ['苏州', '苏州燃气'],
  ['苏州', '苏州港华燃气有限公司'],
  ['苏州', '苏州中石油昆仑苏创燃气有限公司'],
  ['苏州', '昆山中石油昆仑燃气有限公司'],
  ['苏州', '常熟中石油昆仑燃气有限公司'],
  ['苏州', '常熟中燃港城能源有限公司'],
  ['苏州', '吴江港华燃气有限公司'],
  ['南通', '南通大众燃气有限公司（工商户）'],
  ['南通', '南通中油燃气有限责任公司'],
  ['南通', '南通华润燃气有限公司'],
  ['南通', '南通大众燃气有限公司（居民）'],
  ['南通', '启东华润燃气有限公司'],
  ['南通', '如东大众燃气有限公司'],
  ['南通', '如皋市益有管道燃气有限公司'],
  ['南通', '海门华润燃气有限公司'],
  ['南通', '海安新奥燃气有限公司'],
  ['南通', '海门中石油昆仑燃气有限公司'],
  ['南通', '彩虹（南通）能源有限公司'],
  ['连云港', '东海中石油昆仑燃气有限公司'],
  ['连云港', '东海县中裕燃气有限公司'],
  ['连云港', '灌南中裕燃气有限公司'],
  ['连云港', '连云港通裕天然气有限公司'],
  ['连云港', '灌南新奥燃气有限公司'],
  ['连云港', '连云港新奥燃气有限公司'],
  ['连云港', '江苏海州湾中燃能源有限公司'],
  ['连云港', '江苏中燃港大清洁能源有限公司赣榆分公司'],
  ['连云港', '连云港中燃燃气发展有限公司'],
  ['连云港', '东海县奥德燃气有限公司'],
  ['连云港', '连云港城新燃气有限公司'],
  ['连云港', '连云港紫源燃气有限公司'],
  ['连云港', '连云港徐圩新区新奥燃气有限公司'],
  ['淮安', '涟水天达燃气有限公司'],
  ['淮安', '涟水天达燃气有限公司（物联网表）'],
  ['淮安', '涟水深燃新星旺燃气有限公司'],
  ['淮安', '淮安庆鹏燃气有限公司'],
  ['淮安', '淮阴新奥燃气有限公司'],
  ['淮安', '淮安新奥燃气有限公司'],
  ['淮安', '洪泽新奥燃气有限公司'],
  ['淮安', '中油中泰(淮安)新能源有限公司'],
  ['淮安', '盱眙国联新奥燃气有限公司'],
  ['淮安', '淮安双闽管道燃气有限公司'],
  ['盐城', '响水富晨天然气有限公司'],
  ['盐城', '大丰中油燃气'],
  ['盐城', '大丰华润燃气有限公司'],
  ['盐城', '射阳华润燃气有限公司'],
  ['盐城', '滨海天达燃气有限公司'],
  ['盐城', '滨海天达燃气有限公司（物联网表）'],
  ['盐城', '盐城天达东益燃气有限公司'],
  ['盐城', '盐城天达东益燃气有限公司（物联网表）'],
  ['盐城', '阜宁城发燃气有限公司'],
  ['盐城', '阜宁天达燃气有限公司（物联网表）'],
  ['盐城', '盐城新城新奥燃气有限公司'],
  ['盐城', '盐城新奥燃气发展有限公司'],
  ['盐城', '建湖中石油昆仑燃气有限公司'],
  ['盐城', '射阳中石油昆仑燃气有限公司'],
  ['盐城', '东台新奥燃气有限公司'],
  ['盐城', '盐城双闽陈家港管道燃气有限公司'],
  ['盐城', '盐城大丰新奥恒新燃气有限公司'],
  ['盐城', '阜宁新奥燃气有限公司'],
  ['盐城', '盐城新奥燃气有限公司上冈分公司'],
  ['盐城', '射阳新奥燃气有限公司'],
  ['盐城', '建湖新奥燃气发展有限公司'],
  ['扬州', '仪征泰达燃气有限公司'],
  ['扬州', '扬州中燃城市燃气发展有限公司'],
  ['扬州', '江苏深燃清洁能源有限公司'],
  ['扬州', '高邮安源燃气有限公司'],
  ['扬州', '扬州新奥燃气有限公司'],
  ['扬州', '扬州中石油昆仑燃气有限公司'],
  ['扬州', '仪征中石油昆仑鑫泰燃气有限公司'],
  ['扬州', '宝应中石油昆仑燃气有限公司'],
  ['扬州', '宝应奥德燃气有限公司'],
  ['扬州', '扬州新奥裕和燃气有限公司'],
  ['镇江', '句容华润燃气有限公司'],
  ['镇江', '江苏宝华天然气有限公司'],
  ['镇江', '镇江华润燃气有限公司'],
  ['镇江', '丹阳港华燃气有限公司'],
  ['镇江', '扬中中燃城市燃气发展有限公司'],
  ['镇江', '镇江中燃百江能源有限公司'],
  ['泰州', '泰州华润燃气有限公司'],
  ['泰州', '泰州港华燃气有限公司'],
  ['泰州', '江苏中燃长江石化有限公司'],
  ['泰州', '靖江中油广汇能源有限公司'],
  ['泰州', '泰兴中燃燃气发展有限公司'],
  ['泰州', '兴化新奥燃气有限公司'],
  ['泰州', '泰兴新奥燃气有限公司'],
  ['泰州', '兴化东方燃气有限公司'],
  ['泰州', '泰兴新奥燃气发展有限公司'],
  ['宿迁', '宿迁中裕鸿城燃气有限公司'],
  ['宿迁', '宿迁中裕鸿城燃气（物联网表）'],
  ['宿迁', '宿迁华润燃气有限公司'],
  ['宿迁', '沭阳华润燃气有限公司'],
  ['宿迁', '泗洪中裕燃气有限公司'],
  ['宿迁', '泗洪中裕燃气有限公司（物联网表）'],
  ['宿迁', '泗洪沃金燃气'],
  ['宿迁', '泗洪沃金燃气（物联网表）'],
  ['宿迁', '泗阳荣浩天然气发展有限公司'],
  ['宿迁', '宿迁中石油昆仑燃气有限公司'],
  ['杭州', '杭州天然气有限公司'],
  ['杭州', '亚盛加气站'],
  ['杭州', '建德市天然气'],
  ['杭州', '杭州东能管道燃气有限公司'],
  ['杭州', '杭州临安燃气有限公司'],
  ['杭州', '杭州余杭港华燃气'],
  ['杭州', '杭州富阳华润燃气有限公司'],
  ['杭州', '杭州市临安区浙能天然气有限公司'],
  ['杭州', '杭州港华燃气有限公司'],
  ['杭州', '杭州钱江燃气有限公司'],
  ['杭州', '桐庐杭燃燃气有限公司'],
  ['杭州', '淳安杭燃燃气有限公司'],
  ['杭州', '杭州萧山管道燃气发展有限公司'],
  ['杭州', '杭州中燃'],
  ['杭州', '中燃荣威能源设备杭州有限公司'],
  ['杭州', '杭州中油高盛能源有限公司'],
  ['杭州', '杭州中燃城市燃气发展有限公司'],
  ['杭州', '杭州中燃热力科技有限公司'],
  ['宁波', '宁波华润兴光燃气有限公司'],
  ['宁波', '余姚市城市天然气有限公司'],
  ['宁波', '宁波东方管道燃气股份有限公司'],
  ['宁波', '宁波奉化华润兴光燃气有限公司'],
  ['宁波', '宁波市鄞州滨海燃气发展有限公司'],
  ['宁波', '宁波杭州湾华润燃气有限公司'],
  ['宁波', '宁海华润燃气有限公司'],
  ['宁波', '宁海县天然气有限公司'],
  ['宁波', '慈溪华润燃气有限公司'],
  ['宁波', '慈溪深燃天然气有限公司'],
  ['宁波', '象山华润燃气有限公司'],
  ['宁波', '宁波新奥燃气有限公司'],
  ['宁波', '宁波大榭开发区燃气有限公司'],
  ['温州', '温州市燃气集团有限公司'],
  ['温州', '乐清中裕燃气有限公司'],
  ['温州', '乐清华润燃气有限公司'],
  ['温州', '平阳县天然气有限公司'],
  ['温州', '平阳县福领天然气有限公司'],
  ['温州', '永嘉县管道燃气经营有限公司'],
  ['温州', '泰顺县天然气有限公司'],
  ['温州', '温州市洞头管道燃气有限公司'],
  ['温州', '温州燃气集团文成有限公司'],
  ['温州', '温州燃气集团龙苍有限公司'],
  ['温州', '瑞安市开源管道燃气有限公司'],
  ['温州', '瑞安新奥燃气有限公司'],
  ['温州', '苍南县中油天然气'],
  ['温州', '温州新奥燃气有限公司'],
  ['温州', '温州中燃'],
  ['温州', '浙江中燃华电能源有限公司'],
  ['温州', '永嘉中燃能源有限公司'],
  ['温州', '温州中燃擎诚立信能源有限公司'],
  ['温州', '温州中燃能源有限公司'],
  ['温州', '温州市中燃华颢燃气有限公司'],
  ['温州', '瑞安新奥燃气发展有限公司'],
  ['嘉兴', '嘉兴市港区天然气有限公司'],
  ['嘉兴', '嘉兴市燃气集团股份有限公司'],
  ['嘉兴', '嘉善县城乡天然气有限责任公司'],
  ['嘉兴', '嘉善嘉港燃气有限公司'],
  ['嘉兴', '平湖市天然气有限公司'],
  ['嘉兴', '平湖独山燃气有限公司'],
  ['嘉兴', '海宁星港燃气有限公司'],
  ['嘉兴', '海盐县天然气有限公司'],
  ['嘉兴', '海盐天泰燃气有限公司'],
  ['嘉兴', '海宁新奥燃气发展有限公司'],
  ['嘉兴', '桐乡港华天然气有限公司'],
  ['嘉兴', '海盐新奥燃气有限公司'],
  ['嘉兴', '嘉兴中燃'],
  ['嘉兴', '海盐中燃能源有限公司'],
  ['湖州', '安吉县管道燃气有限公司'],
  ['湖州', '德清县天然气有限公司'],
  ['湖州', '德清滨海燃气有限公司'],
  ['湖州', '浙江振能天然气有限公司'],
  ['湖州', '长兴华润燃气有限公司'],
  ['湖州', '湖州燃气股份有限公司'],
  ['湖州', '湖州港华燃气有限公司'],
  ['湖州', '湖州南浔新奥燃气有限公司'],
  ['绍兴', '嵊州中石油昆仑燃气(物联网表)'],
  ['绍兴', '嵊州市三界天然气有限公司'],
  ['绍兴', '新昌中石油昆仑燃气有限公司（物联网表）'],
  ['绍兴', '新昌县天然气有限公司'],
  ['绍兴', '新昌县深燃天然气有限公司'],
  ['绍兴', '绍兴市上虞区天然气有限公司'],
  ['绍兴', '绍兴市江滨天然气有限公司'],
  ['绍兴', '绍兴市燃气产业有限公司'],
  ['绍兴', '绍兴柯桥中国轻纺城管道燃气有限公司'],
  ['绍兴', '诸暨余达燃气有限公司'],
  ['绍兴', '诸暨市天然气有限公司'],
  ['绍兴', '绍兴中石油昆仑燃气有限公司'],
  ['金华', '东阳市燃气有限公司'],
  ['金华', '义乌市天然气有限公司'],
  ['金华', '武义华润燃气有限公司'],
  ['金华', '磐安华润燃气有限公司'],
  ['金华', '金华新奥燃气有限公司'],
  ['金华', '永康新奥燃气有限公司'],
  ['金华', '兰溪新奥燃气有限公司'],
  ['金华', '浙江省浦江高峰管道燃气有限公司'],
  ['金华', '金华中燃城市燃气发展有限公司'],
  ['衢州', '常山县天然气有限责任公司'],
  ['衢州', '开化县天然气有限公司'],
  ['衢州', '江山江城燃气'],
  ['衢州', '衢州市能源有限公司'],
  ['衢州', '龙游新奥燃气有限公司'],
  ['衢州', '衢州新奥燃气有限公司'],
  ['衢州', '衢州中燃'],
  ['衢州', '常山中燃城镇燃气有限公司'],
  ['衢州', '常山华侨经济开发区安然燃气有限公司'],
  ['衢州', '常山新奥燃气有限公司'],
  ['舟山', '浙江中裕燃气有限公司'],
  ['舟山', '舟山市蓝焰燃气有限公司'],
  ['舟山', '舟山深能燃气发展有限公司'],
  ['台州', '三门华润燃气有限公司'],
  ['台州', '临海华润燃气有限公司'],
  ['台州', '临海市杜桥管道燃气有限公司'],
  ['台州', '仙居华润燃气有限公司'],
  ['台州', '台州华润燃气有限公司'],
  ['台州', '台州海滨华润燃气有限公司'],
  ['台州', '台州燃气有限公司'],
  ['台州', '天台华润燃气有限公司'],
  ['台州', '温岭市管道燃气有限公司'],
  ['台州', '玉环君安管道天然气有限公司'],
  ['台州', '台州新奥燃气有限公司'],
  ['台州', '台州中油燃气有限公司'],
  ['台州', '台州正方燃气物资有限公司'],
  ['台州', '台州中燃城市燃气发展有限公司'],
  ['丽水', '丽水华润燃气有限公司'],
  ['丽水', '丽水市天然气有限公司'],
  ['丽水', '云和县天然气有限公司'],
  ['丽水', '庆元县天然气有限公司'],
  ['丽水', '景宁畲族自治县天然气有限公司'],
  ['丽水', '缙云县天然气有限公司'],
  ['丽水', '遂昌县天然气有限公司'],
  ['丽水', '青田县天然气有限公司'],
  ['丽水', '龙泉市天然气有限公司'],
  ['丽水', '松阳港华燃气有限公司'],
  ['合肥', '合肥合燃华润燃气有限公司'],
  ['合肥', '合肥中石油昆仑燃气有限公司'],
  ['合肥', '庐江皖能天然气有限公司'],
  ['合肥', '深圳燃气（肥西分公司）'],
  ['合肥', '肥东深燃天然气有限公司'],
  ['合肥', '长丰深燃天然气有限公司'],
  ['合肥', '合肥新奥燃气发展有限公司'],
  ['合肥', '合肥新奥能源发展有限公司'],
  ['合肥', '安徽省安燃燃气有限公司'],
  ['合肥', '巢湖市安燃燃气有限公司'],
  ['合肥', '巢湖槐燃燃气有限公司'],
  ['合肥', '巢湖烔燃燃气有限公司'],
  ['合肥', '安徽中燃新能源有限公司'],
  ['芜湖', '无为中燃城市燃气发展有限公司'],
  ['芜湖', '芜湖湾沚中燃城市燃气发展有限公司'],
  ['芜湖', '芜湖中燃百江燃气有限公司'],
  ['芜湖', '芜湖中燃城市燃气发展有限公司'],
  ['芜湖', '芜湖中燃能源有限公司'],
  ['芜湖', '南陵中燃城市燃气发展有限公司'],
  ['芜湖', '芜湖三山中燃城市燃气发展有限公司'],
  ['芜湖', '无为中燃宏洁城镇燃气发展有限公司'],
  ['芜湖', '无为中燃新时代城市燃气发展有限公司'],
  ['蚌埠', '五河中裕燃气有限公司'],
  ['蚌埠', '皖能新奥天然气固镇分公司'],
  ['蚌埠', '蚌埠新奥燃气发展有限公司'],
  ['蚌埠', '蚌埠众德燃气有限公司'],
  ['淮南', '中石油昆仑淮矿燃气'],
  ['淮南', '凤台中燃城市燃气发展有限公司'],
  ['淮南', '淮南毛集中燃城市燃气发展有限公司'],
  ['淮南', '淮南中燃城市燃气发展有限公司'],
  ['淮南', '寿县中燃城市燃气发展有限公司'],
  ['淮南', '寿县中燃城镇燃气有限公司'],
  ['马鞍山', '和县皖能天然气有限公司'],
  ['马鞍山', '当涂县港华燃气有限公司'],
  ['马鞍山', '马鞍山博望港华燃气'],
  ['马鞍山', '马鞍山市港华燃气有限公司（银行代缴）'],
  ['马鞍山', '马鞍山安燃燃气有限公司'],
  ['马鞍山', '含山新奥燃气有限公司'],
  ['淮北', '淮北华润燃气有限公司'],
  ['铜陵', '铜陵港华燃气有限公司（银行代收）'],
  ['铜陵', '铜陵中燃百江燃气有限公司'],
  ['安庆', '安庆港华燃气有限公司'],
  ['安庆', '宿松徽商长城能源有限公司'],
  ['安庆', '潜山深燃天然气有限公司'],
  ['安庆', '太湖中燃城市燃气发展有限公司'],
  ['安庆', '安庆皖江港华燃气有限公司'],
  ['黄山', '黟县深燃天然气有限公司'],
  ['黄山', '徽州港华燃气有限公司'],
  ['黄山', '黄山港华燃气有限公司'],
  ['黄山', '太平港华燃气有限公司'],
  ['黄山', '祁门中燃城市燃气发展有限公司'],
  ['滁州', '定远华润川油燃气有限公司'],
  ['滁州', '定远县深燃天然气有限公司'],
  ['滁州', '明光深燃天然气有限公司'],
  ['滁州', '滁州新奥苏滁燃气有限公司'],
  ['滁州', '滁州新奥燃气有限公司'],
  ['滁州', '滁州中石油昆仑燃气有限公司'],
  ['滁州', '凤阳新奥燃气有限公司'],
  ['滁州', '天长新奥燃气有限公司'],
  ['滁州', '全椒新奥燃气有限公司'],
  ['滁州', '来安新奥燃气有限公司'],
  ['阜阳', '临泉国祯燃气有限公司'],
  ['阜阳', '安徽国祯金鹰燃气有限公司'],
  ['阜阳', '皖能新奥天然气颍上分公司'],
  ['阜阳', '阜阳华润燃气有限公司'],
  ['阜阳', '阜阳国祯燃气有限公司'],
  ['阜阳', '阜阳国祯燃气有限公司阜南天然气站'],
  ['阜阳', '阜阳国祯燃气有限公司颍上天然气站'],
  ['阜阳', '安徽国志能源有限公司'],
  ['阜阳', '界首市新奥阜康天然气利用有限责任公司'],
  ['宿州', '宿州华润燃气有限公司'],
  ['宿州', '宿州皖能天然气有限公司'],
  ['宿州', '泗县中裕燃气有限公司'],
  ['宿州', '灵璧华润燃气有限公司'],
  ['宿州', '砀山华润燃气有限公司'],
  ['宿州', '怀仁中燃能源发展有限公司'],
  ['宿州', '泗县中燃城市燃气发展有限公司'],
  ['宿州', '宿州中燃城市燃气发展有限公司'],
  ['六安', '六安华燃天然气'],
  ['六安', '舒城皖能天然气有限公司'],
  ['六安', '金寨华润燃气有限公司'],
  ['六安', '霍山皖能天然气有限公司'],
  ['六安', '六安新奥燃气有限公司'],
  ['六安', '舒城中石油昆仑燃气'],
  ['六安', '霍邱中燃城市燃气发展有限公司'],
  ['六安', '霍山中燃百江能源有限公司'],
  ['六安', '霍山中燃城市燃气发展有限公司'],
  ['六安', '六安新城新奥能源发展有限公司'],
  ['亳州', '蒙城县海特燃气有限公司'],
  ['亳州', '亳州新奥燃气有限公司'],
  ['亳州', '蒙城中燃城镇燃气有限公司'],
  ['池州', '东至华润燃气有限公司'],
  ['池州', '池州市港华燃气有限公司（银行代缴）'],
  ['池州', '池州皖能天然气有限公司'],
  ['池州', '石台华润燃气有限公司'],
  ['池州', '青阳港华燃气有限公司'],
  ['池州', '池州前江燃气有限公司'],
  ['宣城', '宁国安顺燃气有限公司'],
  ['宣城', '安徽省皖能港华天然气有限公司'],
  ['宣城', '广德皖能天然气有限公司'],
  ['宣城', '旌德华润燃气有限公司'],
  ['宣城', '泾县皖能港华燃气有限公司'],
  ['宣城', '郎溪新奥燃气有限公司'],
  ['宣城', '宁国新奥燃气有限公司'],
  ['宣城', '泾县新奥燃气有限公司'],
  ['宣城', '宣城市合众天然气管网有限公司'],
  ['宣城', '广德新奥燃气有限公司'],
  ['宣城', '宣城新奥燃气股份有限公司'],
  ['宣城', '广德新奥燃气有限公司誓节分公司'],
  ['宣城', '宣城新奥宣燃燃气有限公司'],
  ['福州', '平潭华润燃气有限公司'],
  ['福州', '永泰华润燃气有限公司'],
  ['福州', '福州华润燃气有限公司'],
  ['福州', '福州安然居管道燃气有限公司'],
  ['福州', '福州开发区润能天然气有限公司'],
  ['福州', '福清华润燃气有限公司'],
  ['福州', '罗源华润燃气有限公司'],
  ['福州', '连江华润燃气有限公司'],
  ['福州', '长乐华润燃气有限公司'],
  ['福州', '闽侯华润燃气有限公司'],
  ['福州', '福州福铁安然燃气有限公司'],
  ['福州', '福州开发区安然燃气有限公司'],
  ['福州', '罗源安然管道燃气有限公司'],
  ['福州', '闽清广安天然气有限公司'],
  ['福州', '长乐安然燃气有限公司'],
  ['厦门', '厦门市华润燃气费'],
  ['三明', '长安燃气有限公司'],
  ['三明', '大田安然燃气有限公司'],
  ['三明', '建宁中燃城市燃气发展有限公司'],
  ['三明', '将乐县安然燃气有限公司'],
  ['三明', '清流中燃城市燃气发展有限公司'],
  ['三明', '沙县安然燃气有限公司'],
  ['三明', '尤溪中燃城市燃气发展有限公司'],
  ['三明', '三明中燃城市燃气发展有限公司'],
  ['三明', '泰宁中燃城市燃气发展有限公司'],
  ['泉州', '南安市燃气有限公司'],
  ['泉州', '晋江新奥燃气有限公司'],
  ['泉州', '泉州市燃气有限公司'],
  ['漳州', '漳州市古雷华润燃气有限公司'],
  ['漳州', '龙海安然燃气有限公司'],
  ['漳州', '漳浦安然燃气有限公司'],
  ['漳州', '漳州安然燃气有限公司华安分公司'],
  ['漳州', '漳州安然燃气有限公司平和分公司'],
  ['漳州', '漳州安然燃气有限公司云霄分公司'],
  ['漳州', '漳州安然燃气有限公司长泰分公司'],
  ['漳州', '漳州安然燃气有限公司招商局漳州开发区分公司'],
  ['漳州', '漳州安然燃气有限公司诏安分公司'],
  ['漳州', '漳州安然燃气有限公司'],
  ['漳州', '漳州安然燃气有限公司角美分公司'],
  ['南平', '建瓯华润燃气有限公司'],
  ['南平', '建阳华润燃气有限公司'],
  ['南平', '武夷山华润燃气有限公司'],
  ['南平', '浦城华润燃气有限公司'],
  ['南平', '邵武中裕燃气有限公司'],
  ['龙岩', '上杭昆润天然气有限公司'],
  ['龙岩', '漳平昆润天然气有限公司'],
  ['龙岩', '龙岩华润燃气有限公司'],
  ['龙岩', '长汀港华燃气有限公司'],
  ['龙岩', '福建省武平县中明天然气有限公司十方分公司'],
  ['龙岩', '福建省武平县中明天然气有限公司岩前分公司'],
  ['龙岩', '龙岩安燃燃气有限公司'],
  ['龙岩', '龙岩市昌宁燃气有限公司'],
  ['龙岩', '龙岩市永定区昌宁城市燃气发展有限公司'],
  ['龙岩', '龙岩新奥燃气有限公司'],
  ['南昌', '南昌市燃气集团有限公司'],
  ['南昌', '安义中油燃气有限责任公司燃气费'],
  ['南昌', '江西天然气赣江能源有限公司'],
  ['南昌', '南昌中燃城市燃气发展有限公司'],
  ['景德镇', '乐平华润燃气有限公司'],
  ['景德镇', '景德镇华润燃气有限公司'],
  ['景德镇', '景德镇深燃天然气有限公司'],
  ['景德镇', '浮梁华润燃气有限公司'],
  ['萍乡', '江西天然气莲花有限公司'],
  ['萍乡', '萍乡港华燃气有限公司'],
  ['萍乡', '萍乡新奥长丰燃气有限公司'],
  ['九江', '九江县深燃天然气有限公司'],
  ['九江', '九江国发天然气有限公司'],
  ['九江', '九江深燃天然气有限公司'],
  ['九江', '九江湖口深燃天然气有限公司'],
  ['九江', '九江鄱湖深燃能源有限公司'],
  ['九江', '彭泽县天然气有限公司'],
  ['九江', '江西国发天然气开发有限公司'],
  ['九江', '江西天然气庐山西海有限公司'],
  ['九江', '江西天然气都昌有限公司'],
  ['九江', '修水港华燃气有限公司'],
  ['九江', '德安港华燃气有限公司'],
  ['九江', '永修港华燃气有限公司'],
  ['九江', '共青城港华燃气有限公司'],
  ['九江', '庐山港华燃气有限公司'],
  ['新余', '分宜县顺民天然气有限公司'],
  ['新余', '新余燃气有限公司'],
  ['鹰潭', '贵溪华润燃气有限公司'],
  ['鹰潭', '鹰潭华润燃气有限公司'],
  ['鹰潭', '鹰潭华润燃气有限公司余江分公司'],
  ['赣州', '上犹深燃天然气有限公司'],
  ['赣州', '于都县海特燃气有限公司'],
  ['赣州', '会昌县会源燃气有限公司'],
  ['赣州', '全南创通天然气有限公司'],
  ['赣州', '兴国县家欢天然气有限公司'],
  ['赣州', '宁都县城乡燃气有限责任公司'],
  ['赣州', '安远县圣邦燃气有限责任公司'],
  ['赣州', '定南县中能燃气有限公司'],
  ['赣州', '崇义深燃天然气有限公司'],
  ['赣州', '江西天然气瑞金红都能源有限公司'],
  ['赣州', '瑞金深燃天然气有限公司'],
  ['赣州', '石城县海特燃气有限公司'],
  ['赣州', '赣州市南康区深燃清洁能源有限公司'],
  ['赣州', '赣州市赣县区深燃天然气有限公司'],
  ['赣州', '赣州深燃天然气有限公司'],
  ['赣州', '龙南深燃天然气有限公司'],
  ['赣州', '上犹中燃城镇燃气有限公司'],
  ['赣州', '信丰中燃城市燃气发展有限公司'],
  ['吉安', '吉安华润燃气有限公司'],
  ['吉安', '吉安县华润燃气有限公司'],
  ['吉安', '吉水华润燃气有限公司'],
  ['吉安', '新干县海特燃气有限公司'],
  ['吉安', '永丰华润燃气有限公司'],
  ['吉安', '江西天然气万安有限公司'],
  ['吉安', '江西天然气井冈山有限公司'],
  ['吉安', '江西天然气永新有限公司'],
  ['吉安', '江西遂川天然气有限公司'],
  ['吉安', '泰和华润燃气有限公司'],
  ['宜春', '上高县顺民天然气有限公司'],
  ['宜春', '丰城港华燃气有限公司'],
  ['宜春', '江西深燃天然气有限公司'],
  ['宜春', '江西翊烽燃气有限公司'],
  ['宜春', '深圳燃气（宜春分公司）'],
  ['宜春', '靖安中油燃气有限责任公司'],
  ['宜春', '高安泰达燃气有限公司'],
  ['宜春', '樟树港华燃气有限公司'],
  ['宜春', '宜春中燃城镇燃气有限公司'],
  ['抚州', '抚州华润燃气有限公司'],
  ['抚州', '抚州深燃天然气有限公司'],
  ['抚州', '江西天然气资溪两山能源有限公司'],
  ['抚州', '江西天然气黎川有限公司'],
  ['抚州', '南城中燃康盛城市燃气发展有限公司'],
  ['抚州', '宜黄县中燃城市燃气发展有限公司'],
  ['抚州', '南丰县中气天然气有限公司'],
  ['上饶', '上饶市大通燃气工程有限公司'],
  ['上饶', '万年县天然气有限公司'],
  ['上饶', '余干县天然气有限公司'],
  ['上饶', '德兴市天然气有限公司'],
  ['上饶', '江西天然气清山能源有限公司'],
  ['上饶', '江西天然气鄱阳有限公司'],
  ['上饶', '江西弋阳长燃燃气有限公司'],
  ['上饶', '江西昌江燃气有限公司'],
  ['上饶', '江西省铅山深燃天然气有限公司'],
  ['上饶', '玉山县利泰天然气有限公司'],
  ['上饶', '上饶市新奥燃气有限公司'],
  ['上饶', '婺源县中燃天然气有限公司永平镇分公司'],
  ['上饶', '横峰中石油昆仑燃气有限公司'],
  ['济南', '山东港华燃气集团'],
  ['济南', '山东港华燃气集团起步区燃气有限公司'],
  ['济南', '济南华润燃气有限公司'],
  ['济南', '济南济华燃气有限公司（长清区）'],
  ['济南', '济南平阴港华燃气有限公司'],
  ['济南', '山东金捷燃气'],
  ['济南', '济南金捷能源有限责任公司'],
  ['济南', '商河奥德能源有限公司'],
  ['济南', '济南奥德燃气有限公司'],
  ['济南', '济南市莱芜新奥燃气有限公司'],
  ['青岛', '泰能天然气有限公司（工商户充值）'],
  ['青岛', '泰能天然气有限公司（民用户充值）'],
  ['青岛', '青岛平度泰能燃气有限公司'],
  ['青岛', '青岛泰达燃气有限公司'],
  ['青岛', '青岛胶州滨海燃气有限公司'],
  ['青岛', '青岛能源华润燃气有限公司'],
  ['青岛', '青岛西海岸实华天然气'],
  ['青岛', '青岛中即港华燃气有限公司'],
  ['青岛', '青岛新奥能源有限公司'],
  ['青岛', '青岛新奥胶南燃气有限公司'],
  ['青岛', '青岛新奥燃气有限公司'],
  ['青岛', '青岛新奥胶城燃气有限公司'],
  ['青岛', '青岛新奥新城燃气有限公司'],
  ['青岛', '青岛东亿港华燃气有限公司'],
  ['青岛', '青岛中燃宏洁能源发展有限公司'],
  ['青岛', '青岛中燃宏胜能源发展有限公司'],
  ['青岛', '青岛城阳新奥清洁能源销售有限公司'],
  ['淄博', '桓台华润燃气有限公司'],
  ['淄博', '淄博华润燃气有限公司'],
  ['淄博', '淄博国能燃气有限公司'],
  ['淄博', '淄博市煤气有限公司'],
  ['淄博', '淄博津滨燃气有限公司'],
  ['淄博', '高青华润燃气有限公司'],
  ['枣庄', '枣庄华润燃气有限公司'],
  ['枣庄', '枣庄华润燃气有限责任公司峄城分公司'],
  ['枣庄', '枣庄华润燃气有限责任公司薛城分公司'],
  ['枣庄', '枣庄华润高新分公司'],
  ['枣庄', '枣庄山亭华润燃气有限公司'],
  ['枣庄', '滕州华润燃气有限公司'],
  ['枣庄', '枣庄中燃能源发展有限公司'],
  ['枣庄', '枣庄奥德新能源有限公司'],
  ['枣庄', '枣庄奥通新能源有限公司'],
  ['枣庄', '枣庄长虹新能源有限公司'],
  ['东营', '东营华润燃气有限公司'],
  ['东营', '东营市金源管道天然气有限公司'],
  ['东营', '东营市鲁辰燃气有限责任公司'],
  ['东营', '利津辛河天然气技术服务有限公司'],
  ['东营', '东营中燃能源有限公司'],
  ['烟台', '招远滨海燃气有限公司'],
  ['烟台', '烟台新奥燃气发展有限公司'],
  ['烟台', '莱州华润燃气有限公司'],
  ['烟台', '蓬莱市渤海管道燃气有限公司'],
  ['烟台', '龙口港华燃气有限公司'],
  ['烟台', '莱阳新奥燃气有限公司'],
  ['烟台', '海阳市天然气有限公司'],
  ['烟台', '海阳中燃能源发展有限公司'],
  ['烟台', '栖霞中燃能源发展有限公司'],
  ['烟台', '烟台中燃能源发展有限公司'],
  ['烟台', '莱阳港华燃气有限公司'],
  ['烟台', '招远新奥玲珑燃气有限公司'],
  ['潍坊', '安丘华润燃气有限公司'],
  ['潍坊', '寿光市宝力隆燃气集团有限公司'],
  ['潍坊', '昌乐泰达燃气有限公司'],
  ['潍坊', '潍坊亿燃天然气有限公司'],
  ['潍坊', '潍坊华润燃气有限公司'],
  ['潍坊', '潍坊市燃气集团有限公司'],
  ['潍坊', '潍坊港华燃气有限公司'],
  ['潍坊', '潍坊高新华润燃气有限公司'],
  ['潍坊', '青州华润燃气有限公司'],
  ['潍坊', '青州峱山华润燃气有限公司'],
  ['潍坊', '诸城新奥燃气有限公司'],
  ['潍坊', '昌乐新奥燃气有限公司'],
  ['潍坊', '青州中燃能源发展有限公司'],
  ['潍坊', '潍坊中凯清洁能源技术有限公司'],
  ['潍坊', '潍坊中燃百江能源有限公司'],
  ['潍坊', '山东鲁鸿天然气有限公司（昌乐）'],
  ['潍坊', '寿光新奥天然气利用有限公司台头分公司'],
  ['济宁', '兖州华润燃气有限公司'],
  ['济宁', '山东鸿奥燃气有限公司（物联网表）'],
  ['济宁', '微山奥德燃气有限公司（物联网表）'],
  ['济宁', '济宁华润燃气有限公司'],
  ['济宁', '济宁华润高新燃气有限公司'],
  ['济宁', '济宁奥德燃气有限公司（物联网表）'],
  ['济宁', '济宁潜能燃气有限公司'],
  ['济宁', '济宁经济开发区华润燃气有限公司'],
  ['济宁', '邹城华润燃气有限公司'],
  ['济宁', '邹城奥德能源有限公司（物联网表）'],
  ['济宁', '金乡县潜能燃气有限公司'],
  ['济宁', '鱼台华润燃气有限公司'],
  ['济宁', '邹城昆仑燃气公司'],
  ['济宁', '济宁曲阜新区富弘燃气有限公司'],
  ['济宁', '济宁市中燃百江能源有限公司'],
  ['济宁', '嘉祥中燃清洁能源有限公司'],
  ['济宁', '曲阜富华燃气有限公司'],
  ['济宁', '泗水富地燃气有限公司'],
  ['济宁', '山东鸿奥燃气有限公司'],
  ['济宁', '微山奥德燃气有限公司'],
  ['济宁', '梁山奥德燃气有限公司'],
  ['济宁', '泗水奥德燃气有限公司'],
  ['济宁', '济宁奥德燃气有限公司'],
  ['济宁', '邹城奥德能源有限公司'],
  ['泰安', '安泰燃气'],
  ['泰安', '泰安泰山港华燃气有限公司'],
  ['泰安', '新泰昆仑燃气'],
  ['泰安', '泰安中石油昆仑燃气'],
  ['泰安', '宁阳中燃城市燃气发展有限公司'],
  ['泰安', '宁阳鸿奥燃气有限公司'],
  ['泰安', '泰安奥德能源有限公司'],
  ['泰安', '泰安新奥燃气有限公司'],
  ['泰安', '宁阳金鸿天然气有限公司'],
  ['威海', '北燃山东天然气荣成有限公司'],
  ['威海', '乳山中燃能源发展有限公司'],
  ['日照', '五莲一达燃气有限公司'],
  ['日照', '山东一达能源集团'],
  ['日照', '日照岚山中油一达燃气有限公司'],
  ['日照', '日照滨海燃气有限公司'],
  ['日照', '莒县一达燃气'],
  ['日照', '日照新奥燃气有限公司'],
  ['日照', '莒县奥德燃气有限公司'],
  ['临沂', '临沂中裕燃气有限公司（物联网表）'],
  ['临沂', '临沂中裕燃气有限公司（覆盖临沂兰山区）'],
  ['临沂', '临沂中裕能源有限公司（物联网表）'],
  ['临沂', '临沂中裕能源（覆盖经济开发区）'],
  ['临沂', '临沂华润燃气有限公司'],
  ['临沂', '沂水滨海燃气有限公司'],
  ['临沂', '莒南中油一达燃气有限公司'],
  ['临沂', '临沂市兰山区奥德燃气有限公司'],
  ['临沂', '临沂市罗庄区奥德燃气有限公司'],
  ['临沂', '临沂经济开发区奥德燃气有限公司'],
  ['临沂', '临沂长虹燃气有限公司'],
  ['临沂', '临沂鸿奥燃气有限公司'],
  ['临沂', '临沭奥德燃气有限公司'],
  ['临沂', '平邑奥德燃气有限公司'],
  ['临沂', '莒南奥德燃气有限公司'],
  ['临沂', '郯城奥德燃气有限公司'],
  ['临沂', '莒南奥德燃气有限公司(大店)'],
  ['临沂', '临沂新奥能源发展有限公司'],
  ['德州', '夏津海天博远燃气有限公司'],
  ['德州', '德州滨海燃气有限公司'],
  ['德州', '禹城华润燃气有限公司'],
  ['德州', '齐河华润燃气有限公司'],
  ['德州', '乐陵中石油昆仑燃气有限公司'],
  ['德州', '齐河中石油昆仑燃气有限公司'],
  ['德州', '乐陵中燃城市燃气发展有限公司'],
  ['德州', '禹城中燃泰维能源发展有限公司'],
  ['德州', '夏津奥德燃气有限公司'],
  ['德州', '宁津嘉和盛燃气有限公司'],
  ['德州', '平原奥德能源有限公司'],
  ['德州', '庆云鸿奥能源有限公司'],
  ['德州', '武城奥德能源有限公司'],
  ['德州', '禹城奥德能源有限公司'],
  ['德州', '齐河奥德能源有限公司'],
  ['聊城', '茌平信发燃气有限公司'],
  ['聊城', '聊城新奥燃气有限公司'],
  ['聊城', '聊城市东昌府区新奥能源有限公司'],
  ['聊城', '聊城开发区金奥能源有限公司高新区分公司'],
  ['聊城', '聊城开发区金奥能源有限公司'],
  ['聊城', '聊城金捷燃气有限公司'],
  ['聊城', '莘县中石油昆仑燃气有限公司'],
  ['聊城', '高唐中燃能源发展有限公司'],
  ['聊城', '冠县中燃能源发展有限公司'],
  ['聊城', '聊城厚德燃气有限公司'],
  ['聊城', '莘县中燃能源发展有限公司'],
  ['聊城', '冠县奥德燃气有限公司'],
  ['聊城', '聊城奥德能源有限公司'],
  ['滨州', '山东伟润燃气有限公司'],
  ['滨州', '山东新洁能燃气集团有限公司'],
  ['滨州', '山东绿州燃气有限公司'],
  ['滨州', '惠民县圣豪燃气有限公司'],
  ['滨州', '无棣县燃气供气有限公司'],
  ['滨州', '沾化中油燃气有限责任公司'],
  ['滨州', '滨州中油燃气有限责任公司'],
  ['滨州', '滨州中油燃气滨北有限责任公司'],
  ['滨州', '滨州中油燃气高新有限责任公司'],
  ['滨州', '滨州市中海燃气有限公司'],
  ['滨州', '滨州泰达燃气有限公司'],
  ['滨州', '邹平中油燃气有限责任公司'],
  ['滨州', '邹平嘉睿燃气有限公司'],
  ['滨州', '邹平圣豪燃气有限公司'],
  ['滨州', '阳信中石油昆仑燃气有限公司'],
  ['滨州', '沾化新奥燃气有限公司'],
  ['滨州', '邹平新奥燃气有限公司'],
  ['菏泽', '东明万吉天然气实业有限公司'],
  ['菏泽', '单县中天燃气'],
  ['菏泽', '天伦曹县中天燃气'],
  ['菏泽', '山东单县天龙燃气'],
  ['菏泽', '成武县潜能燃气有限公司'],
  ['菏泽', '菏泽中石油昆鹏天然气利用有限公司'],
  ['菏泽', '菏泽市嘉宁燃气有限公司'],
  ['菏泽', '菏泽市广菏天然气有限公司'],
  ['菏泽', '单县中燃能源发展有限公司'],
  ['菏泽', '东明宏昊燃气有限公司'],
  ['菏泽', '郓城县祥生天然气有限公司'],
  ['菏泽', '郓城中燃能源发展有限公司'],
  ['菏泽', '东明鸿奥燃气有限公司'],
  ['菏泽', '单县鸿奥燃气有限公司'],
  ['菏泽', '成武鸿奥燃气有限公司'],
  ['菏泽', '菏泽牡丹奥德能源有限公司'],
  ['菏泽', '鄄城鸿奥燃气有限公司'],
  ['菏泽', '菏泽中燃能源发展有限公司'],
  ['菏泽', '菏泽中石油昆仑燃气有限公司'],
  ['郑州', '中牟县燃气有限公司'],
  ['郑州', '巩义市华鑫清洁能源有限公司'],
  ['郑州', '巩义市燃气有限公司'],
  ['郑州', '新密中裕燃气有限公司'],
  ['郑州', '新郑华润燃气有限公司'],
  ['郑州', '新郑蓝天燃气有限公司'],
  ['郑州', '新郑蓝天燃气有限公司薛店分公司'],
  ['郑州', '新郑蓝天燃气有限公司辛店分公司'],
  ['郑州', '河南怡诚大有燃气有限公司'],
  ['郑州', '登封华润燃气有限公司'],
  ['郑州', '荥阳市燃气有限公司'],
  ['郑州', '郑州东部华润燃气有限公司'],
  ['郑州', '郑州东部华润燃气有限公司(华润银行)'],
  ['郑州', '郑州华润燃气股份有限公司'],
  ['郑州', '郑州市上街区天伦燃气有限公司'],
  ['郑州', '郑州航空港兴港燃气有限公司'],
  ['郑州', '郑州航空港华润燃气有限公司'],
  ['郑州', '新郑昆仑燃气'],
  ['郑州', '巩义中石油昆仑燃气有限公司'],
  ['郑州', '新郑中石油昆仑燃气有限公司'],
  ['郑州', '巩义中燃能源发展有限公司'],
  ['开封', '兰考昆仑燃气有限公司'],
  ['开封', '开封和源燃气有限公司'],
  ['开封', '开封西纳天然气有限公司兰考分公司'],
  ['开封', '杞县华兴天然气有限公司'],
  ['开封', '通许华润燃气有限公司'],
  ['开封', '开封新奥燃气有限公司'],
  ['开封', '开封新奥中原燃气有限公司'],
  ['开封', '杞县昆仑能源天然气有限公司'],
  ['开封', '开封中燃能源发展有限公司'],
  ['开封', '杞县中燃能源发展有限公司'],
  ['开封', '尉氏中燃能源发展有限公司'],
  ['洛阳', '偃师中裕燃气有限公司'],
  ['洛阳', '嵩县天伦燃气'],
  ['洛阳', '洛宁华润燃气有限公司'],
  ['洛阳', '洛阳新奥华油燃气有限公司'],
  ['洛阳', '伊川中石油昆仑燃气有限公司'],
  ['洛阳', '新安新奥燃气有限公司'],
  ['洛阳', '巩义新奥燃气有限公司'],
  ['洛阳', '洛阳洛玻集团源通能源有限公司'],
  ['洛阳', '洛宁县中燃宏洁能源发展有限公司'],
  ['洛阳', '洛阳中燃能源发展有限公司'],
  ['洛阳', '孟津中燃能源发展有限公司'],
  ['洛阳', '洛宁中石油昆仑燃气有限公司'],
  ['洛阳', '伊川新奥燃气有限公司'],
  ['洛阳', '洛阳市吉利区新奥燃气有限公司'],
  ['洛阳', '汝阳县新奥燃气有限公司'],
  ['洛阳', '栾川新奥燃气有限公司'],
  ['平顶山', '平顶山燃气有限责任公司'],
  ['平顶山', '平顶山燃气有限责任公司（物联表）'],
  ['平顶山', '汝州新奥燃气有限公司'],
  ['平顶山', '鲁山中燃宏洁能源发展有限公司'],
  ['安阳', '内黄华润燃气有限公司'],
  ['安阳', '安阳华润燃气有限公司'],
  ['安阳', '安阳华润燃气有限公司新区分公司'],
  ['安阳', '安阳县华润燃气有限公司'],
  ['安阳', '汤阴华润燃气有限公司'],
  ['安阳', '滑县华润燃气有限公司'],
  ['安阳', '安阳中燃宏洁能源发展有限公司'],
  ['安阳', '滑县中燃能源发展有限公司'],
  ['安阳', '内黄中燃能源发展有限公司'],
  ['安阳', '汤阴中燃能源发展有限公司'],
  ['鹤壁', '天伦燃气集团'],
  ['鹤壁', '浚县华润燃气有限公司'],
  ['鹤壁', '淇县中燃能源发展有限公司'],
  ['鹤壁', '淇县天然气有限公司'],
  ['新乡', '原阳县中裕燃气有限公司'],
  ['新乡', '新乡县欣鹏燃气有限公司'],
  ['新乡', '新乡市东升燃气热力有限公司'],
  ['新乡', '欣鹏燃气物联网表缴费'],
  ['新乡', '河南丽华燃气有限公司'],
  ['新乡', '河南蓝天新长燃气有限公司'],
  ['新乡', '河南蓝天新长燃气有限公司封丘分公'],
  ['新乡', '河南蓝天新长燃气有限公司（延津）'],
  ['新乡', '获嘉县金鹏燃气有限责任公司'],
  ['新乡', '获嘉县金鹏燃气物联网表缴费'],
  ['新乡', '辉县中裕燃气公司（物联网表）'],
  ['新乡', '辉县市中裕燃气有限公司'],
  ['新乡', '延津新奥燃气有限公司'],
  ['新乡', '新乡新奥新泉燃气有限公司'],
  ['新乡', '辉县市新奥燃气有限公司'],
  ['新乡', '新乡新奥燃气有限公司'],
  ['新乡', '卫辉新奥燃气有限公司'],
  ['新乡', '卫辉中燃能源发展有限公司'],
  ['新乡', '新乡中燃能源发展有限公司'],
  ['新乡', '新乡中燃能源发展有限公司辉县分公司'],
  ['新乡', '新乡中燃能源发展有限公司长垣分公司'],
  ['新乡', '延津中燃能源发展有限公司'],
  ['新乡', '长垣中燃能源发展有限公司'],
  ['新乡', '河南省中原天然气开发有限公司辉县市分公司'],
  ['新乡', '卫辉市中原天然气开发有限公司'],
  ['新乡', '新乡县新奥能源发展有限公司'],
  ['焦作', '修武中裕燃气发展有限公司'],
  ['焦作', '孟州中裕燃气有限公司'],
  ['焦作', '武陟中裕燃气有限公司'],
  ['焦作', '沁阳中裕燃气有限公司'],
  ['焦作', '温县中裕燃气有限公司'],
  ['焦作', '温县中裕燃气有限公司（物联网表）'],
  ['焦作', '焦作中裕燃气有限公司'],
  ['焦作', '博爱中石油昆仑燃气有限公司'],
  ['焦作', '温县中燃能源发展有限公司'],
  ['焦作', '博爱县中燃能源发展有限公司'],
  ['焦作', '焦作市中燃宏洁能源发展有限公司'],
  ['焦作', '博爱东方燃气有限责任公司'],
  ['濮阳', '南乐华润燃气有限公司'],
  ['濮阳', '台前惠民燃气有限公司'],
  ['濮阳', '濮阳中裕燃气有限公司'],
  ['濮阳', '濮阳中裕能源有限公司'],
  ['濮阳', '濮阳华润燃气有限公司'],
  ['濮阳', '濮阳华润燃气濮北分公司'],
  ['濮阳', '濮阳县博远天然气有限公司'],
  ['濮阳', '濮阳市华龙区华隆天然气有限公司'],
  ['濮阳', '濮阳市天伦燃气有限公司'],
  ['濮阳', '濮阳市长城燃气有限责任公司'],
  ['濮阳', '濮阳通用绿能天然气有限公司'],
  ['濮阳', '范县中燃能源发展有限公司'],
  ['濮阳', '濮阳县中燃能源发展有限公司'],
  ['许昌', '许昌市天伦燃气有限公司'],
  ['许昌', '长葛蓝天新能源有限公司'],
  ['许昌', '鄢陵中燃能源发展有限公司'],
  ['漯河', '漯河中裕燃气有限公司'],
  ['漯河', '漯河中燃能源发展有限公司'],
  ['三门峡', '河南省煤气集团国龙燃气有限公司'],
  ['三门峡', '三门峡中裕燃气有限公司'],
  ['三门峡', '三门峡中裕燃气有限公司陕县分公司'],
  ['三门峡', '义马市管道煤气有限责任公司'],
  ['南阳', '南召华润燃气有限公司'],
  ['南阳', '南阳华润燃气有限公司'],
  ['南阳', '南阳华润燃气有限公司官庄工区分公司'],
  ['南阳', '南阳市蓝天管道燃气有限公司'],
  ['南阳', '南阳豫能中原石油天然气有限公司'],
  ['南阳', '南阳龙成天然气有限责任公司'],
  ['南阳', '唐河华嘉盛燃气有限公司'],
  ['南阳', '新野县天伦燃气有限公司'],
  ['南阳', '方城华润燃气有限公司'],
  ['南阳', '淅川县龙成天然气有限责任公司'],
  ['南阳', '社旗县源鑫能源利用有限公司'],
  ['南阳', '邓州华润燃气有限公司'],
  ['南阳', '镇平华润燃气有限公司'],
  ['南阳', '邓州市中燃宏洁能源发展有限公司'],
  ['南阳', '南阳中燃宏洁能源发展有限公司'],
  ['商丘', '华润燃气(夏邑)有限公司'],
  ['商丘', '华润燃气（睢县）有限公司'],
  ['商丘', '商丘盛泰燃气有限公司'],
  ['商丘', '柘城县丽华燃气有限公司'],
  ['商丘', '柘城县华燃天然气有限公司'],
  ['商丘', '永城中裕燃气有限公司'],
  ['商丘', '河南绿源燃气有限公司民权分公司'],
  ['商丘', '睢县中天燃气有限公司'],
  ['商丘', '睢县中天燃气有限公司（秦川物联网表）'],
  ['商丘', '商丘新奥燃气有限公司'],
  ['商丘', '宁陵县中燃能源发展有限公司'],
  ['商丘', '商丘中燃创基能源发展有限公司'],
  ['商丘', '商丘中燃能源发展有限公司'],
  ['商丘', '宁陵奥德燃气有限公司'],
  ['信阳', '固始中燃城镇燃气有限公司'],
  ['信阳', '光山中燃城镇燃气有限公司'],
  ['信阳', '潢川县中燃城镇燃气发展有限公司'],
  ['信阳', '罗山县中燃城镇燃气发展有限公司'],
  ['信阳', '商城中燃能源发展有限公司'],
  ['信阳', '息县中燃能源发展有限公司'],
  ['信阳', '信阳富地燃气有限公司'],
  ['周口', '周口市天然气有限公司'],
  ['周口', '商水博能燃气有限公司'],
  ['周口', '太康县潜能天然气有限公司'],
  ['周口', '沈丘县汇鑫天然气有限公司'],
  ['周口', '淮阳博能燃气有限公司'],
  ['周口', '西华县天然气有限公司'],
  ['周口', '郸城县天然气有限公司'],
  ['周口', '项城市天然气有限公司'],
  ['周口', '鹿邑县天然气有限公司'],
  ['周口', '太康县中燃能源发展有限公司'],
  ['驻马店', '上蔡博能燃气有限公司'],
  ['驻马店', '西平凯达燃气有限公司'],
  ['驻马店', '豫南燃气上蔡分公司燃气费'],
  ['驻马店', '豫南燃气平舆分公司燃气费'],
  ['驻马店', '豫南燃气新蔡分公司燃气费'],
  ['驻马店', '豫南燃气正阳分公司燃气费'],
  ['驻马店', '豫南燃气汝南分公司燃气费'],
  ['驻马店', '豫南燃气泌阳分公司燃气费'],
  ['驻马店', '豫南燃气确山分公司燃气费'],
  ['驻马店', '豫南燃气遂平分公司燃气费'],
  ['驻马店', '豫南燃气驻马店分公司燃气费'],
  ['驻马店', '西平县中燃能源发展有限公司'],
  ['驻马店', '驻马店中燃能源发展有限公司'],
  ['驻马店', '中石油昆仑燃气有限公司平舆分公司'],
  ['武汉', '武汉市燃气集团有限公司'],
  ['武汉', '武汉东方中油燃气有限公司'],
  ['武汉', '武汉华润燃气有限公司长江新区分公司'],
  ['武汉', '武汉华润燃气有限公司黄陂分公司'],
  ['武汉', '武汉市车都天然气有限公司'],
  ['武汉', '武汉新洲华润燃气有限公司'],
  ['武汉', '武汉江夏华润燃气有限公司'],
  ['武汉', '武钢华润燃气(武汉)有限公司'],
  ['武汉', '武钢江南中燃燃气有限公司'],
  ['武汉', '武汉昆仑燃气'],
  ['武汉', '武汉中燃'],
  ['武汉', '武汉中燃热力有限公司青山分公司'],
  ['武汉', '武汉中燃热力有限公司江东分公司'],
  ['武汉', '武汉中燃热力有限公司'],
  ['武汉', '武汉中燃城市燃气发展有限公司'],
  ['武汉', '武汉武煤百江燃气有限公司'],
  ['武汉', '武汉市汉阳中燃宜居热力有限公司'],
  ['武汉', '武汉江夏中燃热力有限公司'],
  ['武汉', '武汉江东中燃城市燃气发展有限公司'],
  ['武汉', '武汉江北中燃城市燃气发展有限公司'],
  ['武汉', '武汉汉西中燃热力有限公司'],
  ['武汉', '武汉东西湖区中燃热力有限公司'],
  ['武汉', '湖北中燃清洁能源投资有限公司'],
  ['武汉', '武汉洪山中燃热力有限公司'],
  ['武汉', '武汉青山中燃暖居热力有限公司'],
  ['武汉', '武汉中石油昆仑管道燃气有限公司'],
  ['武汉', '武汉东湖中石油昆仑燃气有限公司'],
  ['黄石', '大冶华润燃气有限公司'],
  ['黄石', '阳新县华川天然气有限公司'],
  ['黄石', '黄石昆仑城投燃气'],
  ['黄石', '黄石中燃'],
  ['黄石', '黄石中燃液化天然气有限公司'],
  ['黄石', '黄石中燃热力有限公司'],
  ['黄石', '黄石中燃清洁能源有限公司'],
  ['十堰', '十堰中石油昆仑燃气有限公司'],
  ['十堰', '十堰中燃'],
  ['十堰', '十堰武当山特区中燃城市燃气发展有限公司'],
  ['十堰', '十堰市郧阳中燃城市燃气发展有限公司'],
  ['十堰', '十堰东风中燃城市燃气发展有限公司'],
  ['十堰', '郧西中燃新捷城市燃气发展有限公司'],
  ['宜昌', '宜都深燃天然气有限公司'],
  ['宜昌', '枝江市天然气有限责任公司'],
  ['宜昌', '秭归科力生天然气有限公司'],
  ['宜昌', '长阳深燃天然气有限公司'],
  ['宜昌', '宜昌中燃城市燃气发展有限公司'],
  ['宜昌', '宜昌夷陵中燃燃气有限公司'],
  ['宜昌', '宜昌中燃'],
  ['宜昌', '秭归中燃城市燃气发展有限公司'],
  ['宜昌', '枝江中燃清洁能源有限公司'],
  ['宜昌', '远安中燃城市燃气发展有限公司歇马分公司'],
  ['宜昌', '远安中燃城市燃气发展有限公司'],
  ['宜昌', '当阳中燃城市燃气发展有限公司'],
  ['宜昌', '兴山新捷天然气有限公司'],
  ['襄阳', '保康县天然气有限公司'],
  ['襄阳', '南漳华润燃气有限公司'],
  ['襄阳', '宜城华润燃气有限公司'],
  ['襄阳', '枣阳华润燃气有限公司'],
  ['襄阳', '襄阳华润燃气有限公司'],
  ['襄阳', '襄阳华润燃气有限公司襄州分公司'],
  ['襄阳', '谷城华润燃气有限公司'],
  ['襄阳', '襄阳中燃'],
  ['襄阳', '襄阳中燃清洁能源有限公司'],
  ['襄阳', '襄阳中燃百江蓝缘能源有限公司'],
  ['鄂州', '武汉葛华燃气有限公司'],
  ['鄂州', '湖北华硕燃气发展有限公司'],
  ['鄂州', '鄂州市安泰天然气有限责任公司'],
  ['鄂州', '鄂州中石油昆仑燃气有限公司'],
  ['鄂州', '鄂州中燃'],
  ['鄂州', '湖北富地富江能源科技有限公司'],
  ['荆门', '京山华润燃气有限公司'],
  ['荆门', '沙洋华润燃气有限公司'],
  ['荆门', '钟祥华润燃气有限公司'],
  ['荆门', '荆门中石油昆仑燃气有限公司'],
  ['孝感', '大悟嘉旭天然气有限公司'],
  ['孝感', '孝昌嘉旭天然气有限公司'],
  ['孝感', '安陆嘉旭天然气有限公司'],
  ['孝感', '孝感中燃'],
  ['孝感', '中燃清洁能源云梦危险品运输有限公司'],
  ['孝感', '云梦中燃城市燃气发展有限公司'],
  ['孝感', '应城中燃城市燃气发展有限公司'],
  ['孝感', '孝感中亚城市燃气发展有限公司'],
  ['孝感', '汉川中燃城市燃气发展有限公司'],
  ['孝感', '大悟中燃城市燃气发展有限公司'],
  ['荆州', '江陵华润燃气有限公司'],
  ['荆州', '监利天然气（金卡物联表）'],
  ['荆州', '石首市天然气有限公司'],
  ['荆州', '荆州天然气公司（先锋物联表）'],
  ['荆州', '荆州天然气公司（金卡物联表）'],
  ['荆州', '荆州市津江天然气有限公司（卡表）'],
  ['荆州', '荆州市津江天然气有限公司（普表）'],
  ['荆州', '荆州中燃'],
  ['荆州', '松滋中燃热力有限公司'],
  ['荆州', '松滋中燃城市燃气发展有限公司'],
  ['荆州', '荆州中燃热力有限公司'],
  ['荆州', '洪湖中燃城市燃气发展有限公司'],
  ['黄冈', '武穴梅川赛洛天然气有限公司'],
  ['黄冈', '红安华润燃气有限公司'],
  ['黄冈', '罗田中燃城市燃气有限公司'],
  ['黄冈', '麻城市天然气发展有限公司'],
  ['黄冈', '黄冈齐安中燃天然气有限公司'],
  ['黄冈', '黄梅中燃城市燃气发展有限公司'],
  ['黄冈', '黄梅惠民天然气有限公司'],
  ['黄冈', '黄冈中燃'],
  ['黄冈', '英山中燃城市燃气发展有限公司'],
  ['黄冈', '浠水赛洛天然气有限公司'],
  ['黄冈', '团风中燃城市燃气发展有限公司'],
  ['黄冈', '蕲春县西恩基天然气有限公司'],
  ['黄冈', '蕲春赛洛天然气有限公司'],
  ['黄冈', '黄梅中燃热力有限公司'],
  ['黄冈', '黄冈赛洛天然气有限公司英山分公司'],
  ['黄冈', '黄冈赛洛天然气有限公司团风分公司'],
  ['黄冈', '黄州赛洛天然气有限公司'],
  ['黄冈', '龙感湖中燃城市燃气发展有限公司'],
  ['黄冈', '武穴赛洛天然气有限公司'],
  ['黄冈', '武穴中燃城市燃气发展有限公司'],
  ['咸宁', '咸宁华润城投燃气有限公司'],
  ['咸宁', '嘉鱼华润燃气有限公司'],
  ['咸宁', '赤壁华润燃气有限公司'],
  ['咸宁', '通城天然气有限公司'],
  ['咸宁', '咸宁中燃'],
  ['咸宁', '咸宁中燃热力有限公司'],
  ['咸宁', '咸宁中燃城镇燃气有限公司'],
  ['咸宁', '崇阳中燃城市燃气发展有限公司'],
  ['咸宁', '咸宁中石油昆仑燃气有限公司'],
  ['随州', '广水中环天然气发展有限公司'],
  ['随州', '随县政泰天然气有限公司'],
  ['随州', '随州中燃'],
  ['随州', '随州中燃热力有限公司'],
  ['随州', '随州中燃城市燃气发展有限公司'],
  ['长沙', '浏阳滨海燃气有限公司'],
  ['长沙', '长沙华润燃气有限公司'],
  ['长沙', '长沙中燃百江能源有限公司'],
  ['长沙', '长沙中燃宜居能源有限公司'],
  ['长沙', '长沙新奥燃气有限公司'],
  ['株洲', '株洲瑞华燃气有限公司'],
  ['株洲', '株洲金城燃气发展有限公司'],
  ['株洲', '株洲新奥燃气发展有限公司'],
  ['株洲', '炎陵中燃城镇燃气发展有限公司'],
  ['株洲', '攸县中燃城市燃气发展有限公司'],
  ['株洲', '株洲渌口中燃城镇燃气发展有限公司'],
  ['株洲', '株洲中燃热力有限公司'],
  ['株洲', '株洲中燃铁达能源有限公司'],
  ['株洲', '醴陵新奥燃气有限公司'],
  ['湘潭', '湘乡光大燃气有限公司'],
  ['湘潭', '湘潭新奥燃气发展有限公司'],
  ['湘潭', '湘潭县中石油昆仑燃气有限公司'],
  ['湘潭', '韶山中石油昆仑燃气有限公司'],
  ['湘潭', '湘潭中燃百江能源有限公司'],
  ['湘潭', '湘潭中燃江南燃气发展有限公司'],
  ['衡阳', '衡阳市天然气有限责任公司'],
  ['衡阳', '衡山中石油昆仑燃气有限公司'],
  ['衡阳', '衡东中石油昆仑燃气有限公司'],
  ['衡阳', '衡阳中燃百江能源有限公司'],
  ['衡阳', '衡阳中燃能源有限公司'],
  ['衡阳', '祁东中燃城市燃气发展有限公司'],
  ['邵阳', '城步新和兴天然气有限公司'],
  ['邵阳', '武冈深燃天然气有限公司'],
  ['邵阳', '洞口森博燃气'],
  ['邵阳', '洞口鑫三和燃气'],
  ['邵阳', '邵东深燃天然气有限公司'],
  ['邵阳', '邵东鑫昆燃气'],
  ['邵阳', '邵阳县瑞华燃气有限公司'],
  ['邵阳', '邵阳市燃气公司'],
  ['邵阳', '隆回县华燃天然气有限公司'],
  ['邵阳', '邵东宏安中燃能源有限公司'],
  ['岳阳', '岳阳华润燃气有限公司'],
  ['岳阳', '岳阳华润燃气有限公司临港分公司'],
  ['岳阳', '岳阳华润燃气有限公司临湘分公司'],
  ['岳阳', '岳阳华润燃气有限公司云溪分公司'],
  ['岳阳', '岳阳华润燃气有限公司岳阳县分公司'],
  ['岳阳', '平江华润燃气有限公司'],
  ['常德', '安乡县九申燃气有限公司'],
  ['常德', '津市长燃燃气有限公司'],
  ['常德', '湖南九申燃气集团股份有限公司'],
  ['常德', '常德中石油昆仑燃气'],
  ['常德', '常德中燃百江能源有限公司'],
  ['张家界', '张家界市中燃城市燃气发展有限公司'],
  ['益阳', '益阳瑞华天然气有限公司'],
  ['益阳', '益阳瑞华燃气有限公司'],
  ['益阳', '安化中燃城市燃气有限公司'],
  ['益阳', '益阳百江能源实业有限公司'],
  ['益阳', '益阳南县中燃城市燃气发展有限公司'],
  ['益阳', '益阳中燃城市燃气发展有限公司'],
  ['郴州', '临武县金煌天然气有限公司'],
  ['郴州', '嘉禾县金煌管道燃气有限公司'],
  ['郴州', '宜章华润燃气有限公司'],
  ['郴州', '湖南桂阳金煌管道燃气有限公司'],
  ['郴州', '资兴华润燃气有限公司'],
  ['郴州', '郴州华润燃气有限公司'],
  ['郴州', '郴州市金煌管道燃气有限公司'],
  ['郴州', '郴州中燃百江能源有限公司'],
  ['永州', '东安华润城投燃气有限公司'],
  ['永州', '宁远华润燃气有限公司'],
  ['永州', '永州回龙圩管理区瑞华燃气有限公司'],
  ['永州', '江永瑞华燃气有限公司'],
  ['永州', '湘投燃气（永州）有限公司'],
  ['永州', '祁阳华润燃气有限公司'],
  ['永州', '道县华润新晨燃气有限公司'],
  ['永州', '永州新奥燃气有限公司'],
  ['怀化', '溆浦巨能天然气'],
  ['怀化', '辰溪森泰燃气有限公司'],
  ['怀化', '怀化中燃能源发展有限公司'],
  ['怀化', '芷江中燃城市燃气有限公司'],
  ['怀化', '怀化新奥燃气有限公司'],
  ['娄底', '冷水江华润燃气有限公司'],
  ['娄底', '双峰华润燃气有限公司'],
  ['娄底', '娄底华润燃气有限公司'],
  ['娄底', '涟源华润燃气有限公司'],
  ['娄底', '湖南新康燃气有限公司'],
  ['娄底', '涟源市稳安燃气充装供应有限公司'],
  ['广州', '广州燃气集团有限公司'],
  ['广州', '广州港华燃气有限公司'],
  ['广州', '东永港华燃气有限公司'],
  ['广州', '广州永和燃气有限公司'],
  ['广州', '广州番禺新奥燃气有限公司'],
  ['广州', '广州南沙新奥燃气有限公司'],
  ['广州', '广州华凯石油燃气有限公司'],
  ['广州', '广州新奥燃气有限公司'],
  ['广州', '广州中燃城市燃气发展有限公司'],
  ['广州', '广州白云新奥燃气发展有限公司'],
  ['韶关', '乐昌市安顺达管道天然气'],
  ['韶关', '韶关神州燃气有限公司'],
  ['韶关', '韶关港华燃气有限公司'],
  ['韶关', '韶关乳源中燃康源能源发展有限公司'],
  ['韶关', '韶关中燃百江能源有限公司'],
  ['深圳', '深圳市燃气集团股份有限公司'],
  ['深圳', '中燃宝电气深圳有限公司'],
  ['珠海', '珠海港兴管道天然气有限公司燃气费'],
  ['珠海', '珠海港泰管道燃气有限公司'],
  ['汕头', '汕头市华润新奥燃气有限公司'],
  ['汕头', '汕头市潮阳区民安管道燃气有限公司'],
  ['汕头', '汕头市澄海燃气'],
  ['汕头', '汕头潮南华润燃气有限公司'],
  ['汕头', '汕头潮阳华润燃气有限公司'],
  ['佛山', '佛山市南海燃气发展有限公司'],
  ['佛山', '佛燃股份禅城燃气分公司'],
  ['佛山', '佛山市三水燃气有限公司'],
  ['佛山', '佛山市顺德区燃气有限公司'],
  ['佛山', '佛山市高明燃气有限公司'],
  ['佛山', '佛山市华来燃气有限公司'],
  ['佛山', '佛山中燃华南能源有限公司'],
  ['江门', '开平华润燃气有限公司'],
  ['江门', '江门华润燃气有限公司'],
  ['江门', '江门新会华润燃气有限公司'],
  ['江门', '鹤山华润燃气有限公司'],
  ['江门', '江门中燃城镇燃气有限公司'],
  ['湛江', '徐闻华润燃气有限公司'],
  ['湛江', '遂溪华润燃气有限公司'],
  ['湛江', '廉江新奥燃气有限公司'],
  ['湛江', '雷州新奥燃气有限公司'],
  ['茂名', '高州华润燃气有限公司'],
  ['茂名', '茂名中燃城市燃气发展有限公司'],
  ['肇庆', '肇庆新奥燃气有限公司'],
  ['肇庆', '肇庆中燃城镇燃气有限公司'],
  ['肇庆', '封开新奥燃气有限公司'],
  ['惠州', '惠州大亚湾华润燃气有限公司'],
  ['惠州', '惠州市城市燃气发展有限公司'],
  ['惠州', '惠阳光能管道燃气有限公司'],
  ['惠州', '龙门华润燃气有限公司'],
  ['惠州', '惠东中燃燃气发展有限公司'],
  ['梅州', '兴宁华润燃气有限公司'],
  ['梅州', '梅州华润毅嘉燃气有限公司'],
  ['梅州', '梅州市梅县区中燃城市燃气发展有限公司'],
  ['梅州', '梅州中燃城市燃气发展有限公司'],
  ['梅州', '梅州中燃城市燃气发展有限公司蕉华分公司'],
  ['梅州', '梅州中燃城市燃气发展有限公司畲江分公司'],
  ['汕尾', '海丰深燃天然气有限公司'],
  ['汕尾', '深圳市深汕特别合作区深燃天然气有限公司'],
  ['汕尾', '陆丰华润燃气有限公司'],
  ['汕尾', '汕尾中燃城市燃气发展有限公司'],
  ['河源', '和平华润燃气有限公司'],
  ['河源', '河源华润燃气有限公司'],
  ['河源', '龙川华润燃气有限公司'],
  ['阳江', '华润燃气阳江高新有限公司'],
  ['阳江', '阳江华润燃气有限公司'],
  ['清远', '英德华润燃气有限公司'],
  ['清远', '阳山华润燃气有限公司'],
  ['清远', '清远港华燃气有限公司'],
  ['清远', '连南瑶族自治县金达燃气有限公司'],
  ['清远', '连州市天平燃气有限公司'],
  ['清远', '清远普华能源钢瓶检测有限公司'],
  ['清远', '清远蛇口普华能源有限公司'],
  ['清远', '清远石角中燃百江普华能源有限公司'],
  ['清远', '清远市清新区中燃百江普华能源有限公司'],
  ['清远', '清远源潭普华能源有限公司'],
  ['东莞', '东莞新奥燃气有限公司'],
  ['中山', '中山东凤华润燃气有限公司'],
  ['中山', '中山东升华润燃气有限公司'],
  ['中山', '中山华润燃气有限公司'],
  ['中山', '中山华润燃气有限公司南部分公司'],
  ['中山', '中山港华燃气有限公司'],
  ['揭阳', '中海油（揭阳）城市燃气销售有限公司'],
  ['揭阳', '揭阳中燃城市燃气发展有限公司'],
  ['云浮', '新兴中燃城市燃气发展有限公司'],
  ['云浮', '云浮中燃城市燃气发展有限公司'],
  ['云浮', '罗定新奥燃气有限公司'],
  ['云浮', '云浮新奥燃气有限公司'],
  ['南宁', '南宁华润燃气有限公司'],
  ['南宁', '南宁神州燃气有限公司'],
  ['南宁', '宾阳润桂燃气发展有限公司'],
  ['南宁', '南宁中燃'],
  ['南宁', '马山奥德燃气有限公司'],
  ['柳州', '广西鹿寨天伦燃气'],
  ['柳州', '柳州东城燃气发展有限公司'],
  ['柳州', '柳州中燃城市燃气发展有限公司'],
  ['柳州', '柳州中燃'],
  ['柳州', '广西中油能源有限公司柳州分公司'],
  ['桂林', '阳朔新奥燃气有限公司'],
  ['桂林', '桂林新奥燃气有限公司灵川分公司'],
  ['桂林', '桂林新奥燃气有限公司'],
  ['梧州', '梧州深燃天然气有限公司'],
  ['梧州', '梧州中燃'],
  ['梧州', '岑溪市恒兴天然气有限公司'],
  ['北海', '北海市管道燃气有限公司'],
  ['北海', '广西北部湾新奥燃气发展有限公司'],
  ['防城港', '防城港中燃'],
  ['防城港', '防城港中燃城市燃气发展有限公司'],
  ['防城港', '广西中油能源有限公司'],
  ['钦州', '钦州中燃'],
  ['钦州', '钦州中油燃气有限公司'],
  ['钦州', '钦州中燃城市燃气发展有限公司'],
  ['贵港', '贵港中燃'],
  ['贵港', '广西桂平帝恒管道燃气投资有限公司'],
  ['贵港', '贵港新奥燃气有限公司'],
  ['玉林', '玉林中燃'],
  ['玉林', '陆川中燃城市燃气发展有限公司'],
  ['玉林', '博白中燃城市燃气发展有限公司'],
  ['玉林', '玉林中燃城市燃气发展有限公司'],
  ['百色', '百色中燃'],
  ['百色', '那坡中燃城市燃气发展有限公司'],
  ['百色', '百色中燃城市燃气发展有限公司'],
  ['百色', '隆林奥德燃气有限公司'],
  ['百色', '靖西奥德燃气有限公司'],
  ['贺州', '贺州华润燃气有限公司'],
  ['贺州', '钟山港华燃气有限公司'],
  ['河池', '广西都安国立燃气有限公司'],
  ['河池', '都安国立燃气有限公司地苏分公司'],
  ['河池', '都安国立燃气有限公司澄江分公司'],
  ['河池', '都安国立燃气有限公司高岭分公司'],
  ['河池', '河池中燃'],
  ['河池', '河池中燃城市燃气发展有限公司'],
  ['河池', '广西罗城中燃城市燃气发展有限公司'],
  ['河池', '大化中燃城市燃气发展有限公司'],
  ['来宾', '来宾中燃'],
  ['来宾', '来宾中燃城市燃气发展有限公司'],
  ['崇左', '崇左中燃'],
  ['崇左', '天等中燃城市燃气发展有限公司'],
  ['崇左', '大新奥德能源有限公司'],
  ['崇左', '崇左中燃城市燃气发展有限公司'],
  ['海口', '中海油（海南）燃气有限公司'],
  ['海口', '海南民生管道燃气有限公司'],
  ['海口', '海南中燃能源发展有限公司'],
  ['儋州', '中海油（海南）燃气有限公司'],
  ['儋州', '海南中石油昆仑港华燃气有限公司儋州分公司'],
  ['成都', '四川环宇通达能源开发有限责任公司'],
  ['成都', '四川省明圣天然气有限责任公司'],
  ['成都', '四川省金堂县天伦燃气有限公司'],
  ['成都', '四川空港燃气有限公司'],
  ['成都', '四川联发天然气有限责任公司'],
  ['成都', '崇州市东部天然气有限公司（秦川）'],
  ['成都', '崇州市天然气有限公司'],
  ['成都', '川港燃气有限责任公司成都分公司'],
  ['成都', '彭州华润燃气有限公司'],
  ['成都', '彭州川港燃气'],
  ['成都', '成都世纪源通燃气有限责任公司'],
  ['成都', '成都东景燃气有限责任公司'],
  ['成都', '成都东部新区华油天然气有限公司'],
  ['成都', '成都中能能源开发有限公司'],
  ['成都', '成都台商投资区天然气开发有限公司'],
  ['成都', '成都天府新区中天洋燃气有限公司'],
  ['成都', '成都天府新区华天兴能燃气公司'],
  ['成都', '成都市双流区兴能天然气有限责任公司'],
  ['成都', '成都市温江区兴能燃气'],
  ['成都', '成都成天天然气有限公司'],
  ['成都', '成都成燃凯能燃气有限公司'],
  ['成都', '成都成燃华新燃气有限公司'],
  ['成都', '成都成燃唐昌燃气有限公司'],
  ['成都', '成都成燃大丰燃气有限公司'],
  ['成都', '成都成燃威达燃气有限公司'],
  ['成都', '成都成燃新创燃气有限公司'],
  ['成都', '成都成燃新安燃气有限公司'],
  ['成都', '成都成燃新繁燃气有限公司'],
  ['成都', '成都燃气集团股份有限公司'],
  ['成都', '成都简州新城华港燃气有限责任公司'],
  ['成都', '成都荣和天然气有限责任公司'],
  ['成都', '新津川港燃气有限公司'],
  ['成都', '蒲江县成佳天然气开发有限责任公司'],
  ['成都', '邛崃市天然气有限公司'],
  ['成都', '郫都区兴能天然气公司'],
  ['成都', '都江堰市集能燃气有限公司'],
  ['成都', '青白江区博能燃气'],
  ['成都', '龙泉驿华油兴能天然气'],
  ['成都', '成都新都港华燃气有限公司'],
  ['成都', '大邑港华燃气有限公司'],
  ['成都', '新津港华燃气有限公司'],
  ['成都', '简阳港华燃气有限公司'],
  ['成都', '四川能投中燃燃气发展有限公司'],
  ['自贡', '四川洪鑫燃气集团有限公司'],
  ['自贡', '四川省汇升燃气投资有限公司富顺分公司'],
  ['自贡', '富顺县天然气有限责任公司'],
  ['自贡', '川港燃气自贡分公司'],
  ['自贡', '自贡市东部燃气有限责任公司'],
  ['自贡', '自贡市众利天然气有限责任公司'],
  ['自贡', '自贡市华鑫燃气有限责任公司'],
  ['自贡', '自贡市回龙天然气销售有限公司'],
  ['自贡', '自贡市庆林燃气有限公司'],
  ['自贡', '自贡市燃气有限责任公司'],
  ['自贡', '自贡市通航燃气有限责任公司'],
  ['自贡', '自贡西部燃气有限责任公司'],
  ['自贡', '荣县鼎新天然气有限公司'],
  ['攀枝花', '攀枝花华润燃气有限公司'],
  ['攀枝花', '攀枝花富临燃气有限公司'],
  ['攀枝花', '攀枝花川港燃气有限公司'],
  ['泸州', '创发管道天然气站'],
  ['泸州', '叙永县汇升燃气有限公司'],
  ['泸州', '古蔺县巨能天然气有限公司'],
  ['泸州', '四川鑫华瑞能源有限公司'],
  ['泸州', '四川陆升天然气有限公司'],
  ['泸州', '泸县华油天然气有限公司'],
  ['泸州', '泸州华润兴泸燃气有限公司'],
  ['泸州', '泸州川油天然气有限公司'],
  ['泸州', '泸州纳溪兴燃燃气有限公司'],
  ['泸州', '自贡市回龙天然气销售有限公司'],
  ['德阳', '什邡华润燃气有限公司'],
  ['德阳', '广汉中天洋燃气有限公司'],
  ['德阳', '广汉市城市燃气有限公司'],
  ['德阳', '广汉深燃天然气有限公司'],
  ['德阳', '德阳华润燃气有限公司'],
  ['德阳', '德阳市华能燃气有限责任公司'],
  ['德阳', '德阳市旌能天然气有限公司'],
  ['德阳', '罗江兴能燃气'],
  ['德阳', '中江港华燃气有限公司'],
  ['德阳', '绵竹港华燃气有限公司'],
  ['德阳', '绵竹玉泉港华燃气有限公司'],
  ['绵阳', '四川天新燃气'],
  ['绵阳', '绵阳中恺天然气有限公司'],
  ['绵阳', '绵阳兴绵燃气有限责任公司'],
  ['绵阳', '绵阳港华（三台）燃气有限公司'],
  ['绵阳', '绵阳河清港华燃气有限公司'],
  ['广元', '广元市天然气剑阁分公司'],
  ['广元', '广元市天然气旺苍分公司'],
  ['广元', '广元市天然气昭化分公司'],
  ['广元', '广元市天然气有限责任公司'],
  ['广元', '广元市天然气朝天分公司'],
  ['广元', '广元市天然气经开区分公司'],
  ['广元', '广元市天然气青川分公司'],
  ['遂宁', '中石油大英燃气有限责任公司'],
  ['遂宁', '华润万通燃气公司安居分公司'],
  ['遂宁', '四川华润万通燃气股份有限公司'],
  ['遂宁', '四川宏源燃气股份有限公司物联网表'],
  ['遂宁', '四川宏源燃气股份有限公司（普表）'],
  ['遂宁', '四川省龙祥燃气有限公司'],
  ['遂宁', '射洪县力源燃气有限责任公司'],
  ['遂宁', '川港燃气遂宁分公司'],
  ['遂宁', '蓬溪县全通天然气有限公司'],
  ['遂宁', '遂宁兴港燃气有限责任公司'],
  ['遂宁', '遂宁市明龙天然气有限公司'],
  ['遂宁', '蓬溪港华燃气有限公司'],
  ['内江', '内江华润燃气有限公司'],
  ['内江', '内江沱江华润燃气有限公司'],
  ['内江', '四川内江盛云天然气开发有限公司'],
  ['内江', '四川威东能源开发有限责任公司'],
  ['内江', '四川省汇升燃气投资有限公司富顺分公司'],
  ['内江', '威远旭东燃气'],
  ['内江', '川港燃气自贡分公司'],
  ['内江', '资中华润燃气有限公司'],
  ['内江', '资中县旅投能源发展有限公司'],
  ['内江', '资中聚银天然气'],
  ['内江', '隆昌华润燃气有限公司'],
  ['内江', '威远港华燃气有限公司'],
  ['乐山', '乐山峨沙天然气'],
  ['乐山', '乐山电力-燃气费'],
  ['乐山', '四川乐华燃气有限责任公司'],
  ['乐山', '新顺通天然气沐川燃气公司'],
  ['乐山', '夹江港华燃气有限公司'],
  ['南充', '中油南充燃气有限责任公司'],
  ['南充', '南充嘉能天然气有限责任公司'],
  ['南充', '南充瑞博天然气有限公司西充管理站'],
  ['南充', '南充经开燃气公司'],
  ['南充', '南部县万达天然气永庆天然气管理站'],
  ['南充', '南部县万达天然气流马管理站'],
  ['南充', '南部县天然气有限责任公司'],
  ['南充', '四川省宏盛燃气小元供气站'],
  ['南充', '四川省宏盛燃气有限公司兴盛供气站'],
  ['南充', '四川省宏盛燃气有限公司永红供气站'],
  ['南充', '四川省宏盛燃气有限公司老鸦供气站'],
  ['南充', '四川省宏盛燃气花罐供气站'],
  ['南充', '四川省远宏利民天然气有限公司'],
  ['南充', '四川省阆中市柏垭天然气管理站'],
  ['眉山', '四川省丹棱县天然气有限责任公司'],
  ['眉山', '四川省洪雅县天然气有限公司'],
  ['眉山', '四川省眉山天然气有限责任公司'],
  ['眉山', '眉山华润燃气有限公司'],
  ['眉山', '眉山市兴能天然气有限公司'],
  ['眉山', '眉山市诺舟天然气有限责任公司'],
  ['眉山', '眉山青神华龙天然气有限责任公司'],
  ['眉山', '眉山市彭山港华燃气有限公司'],
  ['宜宾', '宜宾中气天然气有限责任公司'],
  ['宜宾', '宜宾华润燃气有限公司'],
  ['宜宾', '宜宾南溪明安天然气有限责任公司'],
  ['宜宾', '宜宾天康燃气有限公司'],
  ['宜宾', '宜宾天然气发展有限公司'],
  ['宜宾', '泸州川油天然气有限公司'],
  ['宜宾', '筠连县三鼎天然气有限责任公司'],
  ['宜宾', '长宁县三鼎天然气有限责任公司'],
  ['宜宾', '高县三鼎天然气有限责任公司'],
  ['广安', '华蓥市天然气有限责任公司'],
  ['广安', '岳池港华燃气有限公司'],
  ['广安', '邻水县渝邻燃气有限责任公司'],
  ['达州', '万源华润燃气有限公司'],
  ['达州', '万源市佳通天然气有限公司白沙经营'],
  ['达州', '万源市佳通天然气有限公司石塘经营'],
  ['达州', '万源市佳通天然气有限公司罗文经营'],
  ['达州', '万源市佳通天然气有限公司青花经营'],
  ['达州', '中石油达州天燃气'],
  ['达州', '大竹华润燃气有限公司'],
  ['达州', '大竹天康燃气有限公司'],
  ['达州', '宣汉县佳通天然气有限公司'],
  ['达州', '开江华润燃气有限公司'],
  ['达州', '开江县莉丰天然气有限责任公司'],
  ['达州', '渠县华润燃气有限责任公司'],
  ['达州', '渠县天康燃气有限公司'],
  ['达州', '达州华润燃气有限公司'],
  ['达州', '达州市恒贯燃气有限公司双河供气站'],
  ['达州', '达州市罗江燃气发展有限责任公司'],
  ['达州', '达州深燃天然气销售有限公司'],
  ['雅安', '雅安大兴天然气有限责任公司'],
  ['雅安', '雅安市环宇天然气有限公司'],
  ['雅安', '雅安市鑫能天然气有限公司'],
  ['巴中', '巴中东燃天然气有限公司'],
  ['巴中', '巴中市兴圣天然气有限责任公司'],
  ['巴中', '巴中欣恒天然气有限责任公司'],
  ['巴中', '平昌县正道燃气有限公司'],
  ['巴中', '通江华润燃气有限公司'],
  ['巴中', '平昌港华燃气有限公司'],
  ['资阳', '安岳华润燃气有限公司'],
  ['资阳', '资阳港华燃气有限公司'],
  ['资阳', '乐至港华燃气有限公司'],
  ['贵阳', '贵州燃气集团股份有限公司'],
  ['贵阳', '清镇华润燃气有限公司'],
  ['贵阳', '百江西南燃气有限公司'],
  ['六盘水', '贵州燃气集团股份有限公司'],
  ['遵义', '贵州燃气集团股份有限公司'],
  ['遵义', '余庆县神州燃气有限公司'],
  ['遵义', '务川自治县新兴燃气有限公司'],
  ['遵义', '赤水川港燃气有限公司'],
  ['遵义', '赤水市华燊燃气有限公司'],
  ['遵义', '遵义百江燃气有限公司'],
  ['安顺', '贵州燃气集团股份有限公司'],
  ['安顺', '贵州神州燃气有限公司'],
  ['安顺', '贵州莲花天然气有限公司'],
  ['毕节', '贵州燃气集团股份有限公司'],
  ['昆明', '安宁蓝焰燃气有限公司'],
  ['昆明', '宜良华润燃气有限公司'],
  ['昆明', '寻甸华润燃气有限公司'],
  ['昆明', '昆明东川华润燃气有限公司'],
  ['昆明', '昆明煤气安宁分公司'],
  ['昆明', '昆明煤气海口分公司'],
  ['昆明', '昆明煤气（集团）控股有限公司'],
  ['昆明', '晋宁华润燃气有限公司'],
  ['昆明', '石林深燃巨鹏天然气有限公司'],
  ['昆明', '禄劝华润燃气有限公司'],
  ['昆明', '五华中燃城市燃气发展有限公司'],
  ['昆明', '云南百江燃气有限公司'],
  ['昆明', '云南昆煤中燃能源发展有限公司'],
  ['昆明', '云南中燃微管网能源有限公司'],
  ['昆明', '云南中石油昆仑燃气有限公司昆明分公司'],
  ['昆明', '嵩明中石油昆仑燃气有限公司'],
  ['昆明', '安宁中石油昆仑燃气有限公司'],
  ['曲靖', '会泽县大通天然气有限公司'],
  ['玉溪', '玉溪深燃巨鹏天然气有限公司'],
  ['玉溪', '云南百江燃气有限公司玉溪分公司'],
  ['玉溪', '玉溪中石油昆仑燃气有限公司'],
  ['保山', '保山能海车用天然气有限公司'],
  ['保山', '保山中燃城市燃气发展有限公司'],
  ['保山', '腾冲中石油昆仑燃气有限公司'],
  ['保山', '保山中石油昆仑燃气有限公司'],
  ['丽江', '云南百江燃气有限公司丽江分公司'],
  ['丽江', '丽江中石油昆仑燃气有限公司'],
  ['普洱', '普洱宁洱华润燃气有限公司'],
  ['临沧', '临沧深燃巨鹏天然气有限公司'],
  ['临沧', '云县华硕天然气有限公司'],
  ['临沧', '云县华硕巨鹏天然气有限公司'],
  ['临沧', '凤庆华硕天然气有限公司'],
  ['拉萨', '拉萨市暖心燃气热力有限责任公司'],
  ['铜川', '铜川市天然气有限公司'],
  ['宝鸡', '宝鸡中燃'],
  ['宝鸡', '宝鸡中燃蔡家坡燃气发展有限公司'],
  ['宝鸡', '宝鸡中燃陈仓燃气发展有限公司'],
  ['宝鸡', '宝鸡中燃城市燃气发展有限公司'],
  ['咸阳', '乾县宏远天然气有限公司'],
  ['咸阳', '咸阳市天然气有限公司'],
  ['咸阳', '淳化宏远天燃气'],
  ['咸阳', '礼泉宏远天然气有限公司'],
  ['咸阳', '陕西城市燃气限公司秦汉新城分公司'],
  ['咸阳', '三原延长中燃能源发展有限公司'],
  ['咸阳', '武功县中燃能源发展有限公司'],
  ['咸阳', '咸阳中燃百江能源有限公司'],
  ['咸阳', '三原中石油昆仑华通燃气有限公司'],
  ['渭南', '华阴市瑞寰天然气有限公司'],
  ['渭南', '潼关县新能源天然气有限责任公司'],
  ['渭南', '蒲城县中天洋天然气有限责任公司'],
  ['渭南', '大荔县中燃能源发展有限公司'],
  ['渭南', '合阳县中燃能源发展有限公司'],
  ['渭南', '渭南中燃城市燃气发展有限公司'],
  ['延安', '黄陵县天然气有限责任公司'],
  ['延安', '延安燃气有限责任公司'],
  ['延安', '富县延长中燃能源发展有限公司'],
  ['榆林', '佳县宏远天然气有限责任公司'],
  ['榆林', '吴堡县长兴天然气'],
  ['榆林', '米脂县长兴天然气有限责任公司'],
  ['安康', '安康市逸华天然气有限公司'],
  ['兰州', '甘肃昆仑燃气有限公司'],
  ['兰州', '鑫源天然气'],
  ['兰州', '甘肃中燃百江能源有限公司'],
  ['兰州', '兰州市中燃朝日能源有限公司'],
  ['金昌', '金昌中石油昆仑燃气有限公司'],
  ['白银', '白银市天然气有限公司'],
  ['白银', '靖远县金地燃气'],
  ['白银', '白银中石油昆仑燃气有限公司'],
  ['天水', '天水盛鑫天然气有限公司'],
  ['天水', '张家川回族自治县中源燃气有限责任'],
  ['天水', '清水县国梦能源投资公司'],
  ['天水', '甘肃瑞寰昊川燃气有限公司'],
  ['天水', '秦安县天然气有限公司'],
  ['武威', '武威新凯腾燃气公司'],
  ['张掖', '山丹丰聚能源科技有限公司'],
  ['张掖', '高台华燊燃气有限公司'],
  ['平凉', '崇信聚能燃气开发有限公司'],
  ['平凉', '平凉利通天然气有限公司'],
  ['平凉', '华亭中燃城市燃气发展有限公司'],
  ['酒泉', '敦煌市天然气有限责任公司'],
  ['庆阳', '庆阳鸿燃天然气有限公司'],
  ['陇南', '西和县成昌天然气有限责任公司'],
  ['西宁', '西宁华润燃气有限公司'],
  ['海东', '海东华润燃气有限公司'],
  ['海东', '海东平安华润燃气有限公司'],
  ['银川', '宁夏哈纳斯燃气集团有限公司'],
  ['银川', '银川金坤燃气'],
  ['固原', '经纬新能源'],
  ['中卫', '宁夏深中天然气开发有限公司'],
  ['克拉玛依', '新疆天北能源有限责任公司'],
  ['哈密', '哈密洪通燃气有限公司'],
  ['西安', '蓝天县城燃天然气有限公司'],
  ['西安', '西安华润燃气有限公司'],
  ['西安', '西安秦华燃气集团有限公司'],
  ['西安', '西安市长安天然气有限责任公司'],
  ['西安', '陕西延长中燃能源发展有限公司'],
  ['西安', '西安中燃百江德高能源有限公司'],
  ['西安', '西安中燃城市燃气发展有限公司'],
  ['西安', '周至延长中燃能源发展有限公司'],
];

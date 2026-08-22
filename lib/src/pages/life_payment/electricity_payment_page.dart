import 'dart:async' show unawaited, StreamSubscription;
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:azlistview_all_platforms/azlistview_all_platforms.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list_for_us/scrollable_positioned_list_for_us.dart';
import 'package:tencent_cloud_chat_demo/src/pages/life_payment/life_payment_location_service.dart';
import 'package:tencent_cloud_chat_demo/src/pages/life_payment/life_payment_city_index_bar.dart';
import 'package:tencent_cloud_chat_demo/src/pages/life_payment/life_payment_theme.dart';
import 'package:tencent_cloud_chat_demo/src/pages/life_payment/life_payment_errors.dart';
import 'package:tencent_cloud_chat_demo/src/pages/life_payment/life_payment_repository.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/wallet_repository.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/widgets/pay_method_sheet.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/widgets/pay_password_prompt.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_responsive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/life_payment_order_update_message.dart';
import 'package:tencent_cloud_chat_demo/utils/dio_error_message.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:uuid/uuid.dart';

const String _electricAccountRecordsKey =
    'life_payment_electric_account_records';

const List<WalletPayMethodDto> _electricPayMethods = [
  WalletPayMethodDto(
    id: '99',
    coin: '99?',
    net: '平台余额',
    bal: '可用',
    fiat: '≈¥0.00',
    balMinor: 0,
    scale: 2,
    color: Color(0xFF1677FF),
    badgeColor: Color(0xFF1677FF),
    badge: '99',
    platformCoin: true,
  ),
  WalletPayMethodDto(
    id: 'USDT',
    coin: 'USDT',
    net: '数字资产',
    bal: '可用',
    fiat: '≈¥0.00',
    balMinor: 0,
    scale: 6,
    color: Color(0xFF26A17B),
    badgeColor: Color(0xFF26A17B),
    badge: 'T',
  ),
];

/// 电费缴费页：城市与缴费单位仅来自用户提供的城市清单。
class ElectricityPaymentPage extends StatefulWidget {
  const ElectricityPaymentPage({
    super.key,
    this.locationData,
  });

  final LifePaymentLocationData? locationData;

  @override
  State<ElectricityPaymentPage> createState() => _ElectricityPaymentPageState();
}

class _ElectricityPaymentPageState extends State<ElectricityPaymentPage> {
  final TextEditingController _accountController = TextEditingController();
  final LifePaymentRepository _repo = LifePaymentRepository();
  bool _submitting = false;
  String _progressText = '';
  String? _refreshingAccountNo;
  String _payMethodId = '99';
  final List<_ElectricAccountRecord> _accountRecords = [];
  late ElectricityCityProvider _selectedCity;
  late bool _isSupportedCity;
  StreamSubscription<LifePaymentOrderUpdateEvent>? _orderUpdateSub;
  String? _watchingOrderNo;

  /// 自动轮询：2 秒一次，最多 90 次（约 3 分钟），对齐 API 文档建议上限。
  static const int _queryPollMaxAttempts = 90;
  static const Duration _queryPollInterval = Duration(seconds: 2);

  /// 手动刷新：若首次仍是 running，再短轮询 15 次（约 30 秒）。
  static const int _queryRefreshExtraAttempts = 15;

  @override
  void initState() {
    super.initState();
    _loadAccountRecords();
    _orderUpdateSub =
        LifePaymentOrderUpdateBus.instance.stream.listen(_onOrderUpdatePush);
    final matched = ElectricityCityCatalog.matchLocation(widget.locationData);
    _isSupportedCity = matched != null;
    _selectedCity = matched ??
        ElectricityCityProvider(
          city: ElectricityCityCatalog.locationLabel(widget.locationData),
          provider: '请选择支持缴费城市',
          initial: '#',
          searchKey: '',
        );
  }

  @override
  void dispose() {
    _orderUpdateSub?.cancel();
    _accountController.dispose();
    super.dispose();
  }

  Future<void> _onOrderUpdatePush(LifePaymentOrderUpdateEvent event) async {
    if (!mounted) return;
    if (_watchingOrderNo == null || event.orderNo != _watchingOrderNo) return;
    try {
      final order = await _repo.getOrder(event.orderNo);
      if (!mounted || _watchingOrderNo != event.orderNo) return;
      final status = order.orderStatus.trim().toLowerCase();
      final tip = order.message.isNotEmpty
          ? order.message
          : (event.message.isNotEmpty ? event.message : '订单状态：$status');
      if (status == 'success' ||
          status == 'failed' ||
          status == 'cancelled' ||
          status == 'need_manual') {
        _watchingOrderNo = null;
        ToastUtils.toast(tip);
      }
    } catch (_) {
      // 推送触发的刷新失败不打扰用户，REST 仍可后续再查
    }
  }

  bool get _isHangzhou => _isSupportedCity && _selectedCity.city == '杭州';

  String get _accountHint {
    if (!_isSupportedCity) return '请选择支持缴费城市';
    if (_selectedCity.city == '北京' || _selectedCity.city == '杭州') {
      return '请输入13位户号';
    }
    return '请输入户号';
  }

  String get _accountTip {
    if (!_isSupportedCity) {
      return '当前定位城市暂未开通电费缴费，请点击右上角城市名称选择支持城市。';
    }
    if (_selectedCity.city == '杭州') {
      return '浙江电力户号由原10位升级至13位，请在原10位户号前增加“330”。若户号为13位，请直接输入。';
    }
    if (_selectedCity.city == '北京') {
      return '北京电力户号由原10位升级至13位，请在原10位户号前增加“110”。若户号为13位，请直接输入。';
    }
    return '请按照${_selectedCity.provider}提供的户号规则输入。';
  }

  Future<void> _selectCity() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final city = await Navigator.of(context).push<ElectricityCityProvider>(
      MaterialPageRoute(
        builder: (_) => ElectricityCitySelectionPage(
          selectedCity: _selectedCity.city,
          locationLabel:
              ElectricityCityCatalog.locationLabel(widget.locationData),
        ),
      ),
    );
    if (!mounted || city == null) return;
    setState(() {
      _selectedCity = city;
      _isSupportedCity = true;
      _accountController.clear();
    });
    await _loadProviderFromBackend(city.city);
  }

  Future<void> _loadProviderFromBackend(String cityName) async {
    setState(() => _submitting = true);
    try {
      final providers = await _repo.getProviders(
        serviceType: 'electric',
        cityName: cityName,
        pageSize: 100,
      );
      if (!mounted) return;
      final enabled = providers.where((item) => item.enabled).toList();
      if (enabled.isEmpty) {
        ToastUtils.toast('$cityName暂未开通电费缴费单位');
        return;
      }
      final selected =
          enabled.length == 1 ? enabled.first : await _chooseProvider(enabled);
      if (!mounted || selected == null) return;
      setState(() {
        _selectedCity = ElectricityCityProvider(
          city: selected.cityName.isNotEmpty ? selected.cityName : cityName,
          provider: selected.providerName,
          initial: cityName.isNotEmpty
              ? cityName.characters.first.toUpperCase()
              : '#',
          searchKey: '$cityName${selected.providerName}',
          cityCode: selected.cityCode,
          providerCode: selected.providerCode,
        );
      });
    } catch (e) {
      if (mounted) ToastUtils.toast('获取缴费单位失败：$e');
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _progressText = '';
        });
      }
    }
  }

  Future<LifePaymentProviderItem?> _chooseProvider(
    List<LifePaymentProviderItem> providers,
  ) {
    return showModalBottomSheet<LifePaymentProviderItem>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: providers.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = providers[index];
              return ListTile(
                title: Text(item.providerName),
                subtitle:
                    item.providerCode.isEmpty ? null : Text(item.providerCode),
                onTap: () => Navigator.of(context).pop(item),
              );
            },
          ),
        );
      },
    );
  }

  void _showAccountHelp() {
    if (!_isSupportedCity) {
      ToastUtils.toast('请先选择支持缴费的城市');
      return;
    }
    ToastUtils.toast('请向${_selectedCity.provider}查询户号获取方式');
  }

  Future<void> _loadAccountRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_electricAccountRecordsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final records = decoded
          .whereType<Map>()
          .map((item) => _ElectricAccountRecord.fromJson(
                Map<String, Object?>.from(item),
              ))
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _accountRecords
          ..clear()
          ..addAll(records);
      });
    } catch (_) {
      await prefs.remove(_electricAccountRecordsKey);
    }
  }

  Future<void> _saveAccountRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _electricAccountRecordsKey,
      jsonEncode(_accountRecords.map((item) => item.toJson()).toList()),
    );
  }

  void _upsertAccountRecord(_ElectricAccountRecord record) {
    final index = _accountRecords.indexWhere(
      (item) => item.accountNo == record.accountNo,
    );
    setState(() {
      if (index >= 0) {
        _accountRecords[index] = record;
      } else {
        _accountRecords.insert(0, record);
      }
    });
    unawaited(_saveAccountRecords());
  }

  void _updateAccountRecord(
    String accountNo, {
    String? status,
    String? statusText,
    String? cityName,
    String? providerName,
    String? userAddress,
    String? accountBalance,
    String? queryNo,
    String? receipt,
    String? queryStatus,
    String? pluginStatus,
    String? suggestAmount,
  }) {
    final index =
        _accountRecords.indexWhere((item) => item.accountNo == accountNo);
    if (index < 0) return;
    final old = _accountRecords[index];
    setState(() {
      _accountRecords[index] = old.copyWith(
        status: status,
        statusText: statusText,
        cityName: cityName,
        providerName: providerName,
        userAddress: userAddress,
        accountBalance: accountBalance,
        queryNo: queryNo,
        receipt: receipt,
        queryStatus: queryStatus,
        pluginStatus: pluginStatus,
        suggestAmount: suggestAmount,
      );
    });
    unawaited(_saveAccountRecords());
  }

  /// 把接口/插件回传的真实字段合并进本地户号卡片（有值才覆盖，避免冲掉已有数据）。
  void _mergeQueryIntoRecord(String accountNo, UtilityQueryResult query) {
    _updateAccountRecord(
      accountNo,
      cityName: query.cityName.isNotEmpty ? query.cityName : null,
      providerName: query.providerName.isNotEmpty ? query.providerName : null,
      userAddress: query.userAddress.isNotEmpty ? query.userAddress : null,
      accountBalance:
          query.accountBalance.isNotEmpty ? query.accountBalance : null,
      queryNo: query.queryNo.isNotEmpty ? query.queryNo : null,
      receipt: query.receipt.isNotEmpty ? query.receipt : null,
      queryStatus: query.queryStatus.isNotEmpty ? query.queryStatus : null,
      pluginStatus: query.pluginStatus.isNotEmpty ? query.pluginStatus : null,
      suggestAmount:
          query.suggestAmount.isNotEmpty ? query.suggestAmount : null,
    );
  }

  /// 轮询查询结果；[maxAttempts] 可覆盖默认次数（手动刷新用更短窗口）。
  /// 单次网络抖动不终止轮询（对齐手机充值页 _pollOrderStatus 策略）。
  Future<UtilityQueryResult> _pollUtilityQuery(
    String queryNo, {
    int? maxAttempts,
    UtilityQueryResult? initial,
    String? mergeAccountNo,
    void Function(int attempt)? onAttempt,
  }) async {
    final limit = maxAttempts ?? _queryPollMaxAttempts;
    var query = initial ?? _runningQueryPlaceholder(queryNo);
    for (var i = 0; i < limit; i++) {
      if (!mounted) return query;
      try {
        query = await _repo.getUtilityQuery(queryNo);
        if (mergeAccountNo != null && mergeAccountNo.isNotEmpty) {
          _mergeQueryIntoRecord(mergeAccountNo, query);
        }
      } catch (_) {
        // 单次请求失败不中断，下一轮继续拉
      }
      if (query.queryStatus == 'query_success' ||
          query.queryStatus == 'query_failed' ||
          query.queryStatus == 'expired' ||
          _isUtilityQuerySuccessful(query)) {
        return query;
      }
      onAttempt?.call(i + 1);
      if (mounted) {
        setState(() => _progressText = '正在查询户号（${i + 1}/$limit）');
      }
      await Future<void>.delayed(_queryPollInterval);
    }
    return query;
  }

  UtilityQueryResult _runningQueryPlaceholder(String queryNo) {
    return UtilityQueryResult(
      queryNo: queryNo,
      serviceType: 'electric',
      queryStatus: 'running',
      pluginStatus: '',
      cityName: '',
      cityCode: '',
      providerName: '',
      providerCode: '',
      accountNo: '',
      userAddress: '',
      accountBalance: '',
      receipt: '',
      expiredAt: '',
    );
  }

  String _friendlyRequestError(Object error) {
    return LifePaymentErrors.userMessage(error, fallbackAction: '请求');
  }

  /// 创建订单失败时优先透出后端返回的业务原因（400 的 message），
  /// 并附带 detail.field 指明具体非法字段；通用文案兜底，
  /// 避免只弹「Http status error [400]」这种技术噪音。
  String _orderCreateErrorText(Object error) {
    final mapped = LifePaymentErrors.userMessage(error, fallbackAction: '创建订单');
    if (error is! DioError) return mapped;
    final data = error.response?.data;
    if (data is! Map) return mapped;
    final detail = data['detail'];
    String detailText = '';
    if (detail is Map && detail.isNotEmpty) {
      final field = detail['field']?.toString().trim() ?? '';
      detailText = field.isNotEmpty ? field : detail.toString();
    } else if (detail != null && detail.toString().trim().isNotEmpty) {
      detailText = detail.toString().trim();
    }
    if (detailText.isEmpty) return mapped;
    return '$mapped（字段：$detailText）';
  }

  /// 后端拒单原因是否指向「查询单失效」，命中则需要重新发起户号查询。
  bool _looksLikeQueryExpired(String message) {
    final lower = message.toLowerCase();
    return message.contains('过期') ||
        message.contains('失效') ||
        message.contains('查询单') ||
        lower.contains('expired') ||
        lower.contains('query_no') ||
        lower.contains('query not found');
  }

  bool _isNetworkRequestError(Object error) {
    return DioErrorMessage.isNetworkRelated(error);
  }

  /// 判定户号查询是否已成功。
  /// 后端有时 receipt/plugin_status 已更新，但 query_status 仍为空或滞后，不能只认单一字段。
  bool _isUtilityQuerySuccessful(UtilityQueryResult query) {
    final status = query.queryStatus.trim().toLowerCase();
    if (status == 'query_success' ||
        status == 'confirmed' ||
        status == 'success') {
      return true;
    }
    final plugin = query.pluginStatus.trim().toLowerCase();
    if (plugin == 'query_success' || plugin == 'success') {
      return true;
    }
    final receipt = query.receipt;
    if (receipt.contains('查询成功') || receipt.contains('query_success')) {
      return true;
    }
    if (query.userAddress.isNotEmpty) {
      return true;
    }
    if (query.accountBalance.isNotEmpty &&
        !query.accountBalance.contains('暂未查询')) {
      return true;
    }
    return false;
  }

  void _reportQueryRequestError(
    String accountNo, {
    required Object error,
    required String action,
  }) {
    final network = _isNetworkRequestError(error);
    final message =
        network ? '网络不稳定，请稍后再点刷新' : '$action失败：${_friendlyRequestError(error)}';
    _updateAccountRecord(
      accountNo,
      status: network ? 'running' : 'failed',
      statusText: message,
    );
    if (mounted) {
      ToastUtils.toast(network ? '网络连接超时，请稍后再试' : message);
    }
  }

  UtilityQueryResult _queryFromRecord(_ElectricAccountRecord record) {
    // 只按城市匹配目录：后端回传的单位名（如「国网湖北电力有限公司」）
    // 与本地目录（「国网湖北省电力公司」）可能不一致，单位名以记录为准
    final matched = ElectricityCityCatalog.all.where(
      (item) => item.city == record.cityName,
    );
    final city = matched.isNotEmpty ? matched.first : _selectedCity;
    return UtilityQueryResult(
      queryNo: record.queryNo,
      serviceType: 'electric',
      queryStatus:
          record.queryStatus.isNotEmpty ? record.queryStatus : 'query_success',
      pluginStatus: record.pluginStatus,
      cityName: record.cityName.isNotEmpty ? record.cityName : city.city,
      cityCode: city.cityCode,
      providerName:
          record.providerName.isNotEmpty ? record.providerName : city.provider,
      providerCode: city.providerCode,
      accountNo: record.accountNo,
      userAddress: record.userAddress,
      accountBalance: record.accountBalance,
      receipt: record.receipt,
      expiredAt: '',
      suggestAmount: record.suggestAmount,
    );
  }

  /// 查询单过期后重新发起一次户号查询，复用原卡片展示进度。
  Future<void> _requeryRecord(_ElectricAccountRecord record) async {
    if (_refreshingAccountNo == record.accountNo) return;
    setState(() => _refreshingAccountNo = record.accountNo);
    final source = _queryFromRecord(record);
    _updateAccountRecord(
      record.accountNo,
      status: 'running',
      statusText: '查询已过期，正在重新查询...',
    );
    try {
      var query = await _repo.createUtilityQuery(
        serviceType: 'electric',
        cityName: source.cityName,
        cityCode: source.cityCode,
        providerName: source.providerName,
        providerCode: source.providerCode,
        accountNo: record.accountNo,
      );
      _updateAccountRecord(record.accountNo, queryNo: query.queryNo);
      query = await _pollUtilityQuery(
        query.queryNo,
        initial: query,
        mergeAccountNo: record.accountNo,
      );
      await _handleQueryOutcome(record.accountNo, query, offerPayDialog: false);
      if (mounted && _isUtilityQuerySuccessful(query)) {
        ToastUtils.toast('户号已重新查询，请再次点击卡片缴费');
      }
    } catch (e) {
      _reportQueryRequestError(record.accountNo, error: e, action: '重新查询');
    } finally {
      if (mounted) setState(() => _refreshingAccountNo = null);
    }
  }

  Future<void> _onAccountRecordTap(_ElectricAccountRecord record) async {
    if (record.status != 'success') return;
    if (record.queryNo.isEmpty) {
      ToastUtils.toast('查询单号缺失，请重新绑定');
      return;
    }
    final amount = await _showElectricRechargeAmountSheet(record);
    if (!mounted || amount == null || amount.trim().isEmpty) return;
    await _submitElectricOrder(_queryFromRecord(record), amount.trim());
  }

  Future<void> _handleQueryOutcome(
    String accountNo,
    UtilityQueryResult query, {
    bool offerPayDialog = false,
  }) async {
    if (!mounted) return;
    _mergeQueryIntoRecord(accountNo, query);

    if (_isUtilityQuerySuccessful(query)) {
      _updateAccountRecord(
        accountNo,
        status: 'success',
        statusText: '',
      );
      if (mounted) setState(() => _progressText = '');
      if (offerPayDialog) {
        final amount = await _showElectricRechargeAmountSheet(
          _accountRecords.firstWhere(
            (item) => item.accountNo == accountNo,
            orElse: () => _ElectricAccountRecord(
              cityName: query.cityName,
              providerName: query.providerName,
              accountNo: accountNo,
              status: 'success',
              statusText: '',
              createdAt: DateTime.now(),
              userAddress: query.userAddress,
              accountBalance: query.accountBalance,
              queryNo: query.queryNo,
              receipt: query.receipt,
              queryStatus: query.queryStatus,
              pluginStatus: query.pluginStatus,
            ),
          ),
        );
        if (!mounted || amount == null || amount.trim().isEmpty) return;
        await _submitElectricOrder(query, amount.trim());
      }
      return;
    }
    if (query.queryStatus == 'running' ||
        query.queryStatus == 'ready' ||
        query.queryStatus.isEmpty) {
      _updateAccountRecord(
        accountNo,
        status: 'running',
        statusText: '查询处理中，可点击刷新查看结果',
      );
      ToastUtils.toast('查询仍在进行，请稍后点击刷新');
      return;
    }
    final failText = query.receipt.isNotEmpty && !query.receipt.contains('查询成功')
        ? query.receipt
        : '户号查询失败：${query.queryStatus}';
    _updateAccountRecord(accountNo, status: 'failed', statusText: failText);
    ToastUtils.toast(failText);
  }

  Future<void> _refreshQueryResult(_ElectricAccountRecord record) async {
    if (record.queryNo.isEmpty) {
      ToastUtils.toast('没有查询单号，请重新绑定户号');
      return;
    }
    if (_refreshingAccountNo == record.accountNo) return;

    setState(() => _refreshingAccountNo = record.accountNo);
    _updateAccountRecord(
      record.accountNo,
      status: 'running',
      statusText: '正在刷新查询结果...',
    );
    try {
      final query = await _pollUtilityQuery(
        record.queryNo,
        maxAttempts: _queryRefreshExtraAttempts,
        mergeAccountNo: record.accountNo,
        onAttempt: (_) {
          if (!mounted) return;
          _updateAccountRecord(
            record.accountNo,
            status: 'running',
            statusText: '正在刷新查询结果...',
          );
        },
      );
      await _handleQueryOutcome(record.accountNo, query, offerPayDialog: false);
    } catch (e) {
      _reportQueryRequestError(record.accountNo, error: e, action: '刷新');
    } finally {
      if (mounted) setState(() => _refreshingAccountNo = null);
    }
  }

  Future<void> _bindAccount() async {
    if (_submitting) return;
    if (!_isSupportedCity) {
      ToastUtils.toast('请先选择支持缴费的城市');
      return;
    }
    final account = _accountController.text.trim();
    if (account.isEmpty) {
      ToastUtils.toast('请输入户号');
      return;
    }
    _upsertAccountRecord(_ElectricAccountRecord(
      cityName: _selectedCity.city,
      providerName: _selectedCity.provider,
      accountNo: account,
      status: 'running',
      statusText: '首次绑定需要约 1 分钟，请稍候',
      createdAt: DateTime.now(),
    ));
    setState(() {
      _submitting = true;
      _progressText = '首次绑定约 1 分钟';
    });
    ToastUtils.toast('首次绑定需要约 1 分钟，请不要重复提交');
    try {
      var query = await _repo.createUtilityQuery(
        serviceType: 'electric',
        cityName: _selectedCity.city,
        cityCode: _selectedCity.cityCode,
        providerName: _selectedCity.provider,
        providerCode: _selectedCity.providerCode,
        accountNo: account,
      );
      _updateAccountRecord(account, queryNo: query.queryNo);
      query = await _pollUtilityQuery(
        query.queryNo,
        initial: query,
        mergeAccountNo: account,
        onAttempt: (_) {
          if (!mounted) return;
          _updateAccountRecord(
            account,
            status: 'running',
            statusText: _progressText.isEmpty ? '正在查询户号' : _progressText,
          );
        },
      );
      await _handleQueryOutcome(account, query);
    } catch (e) {
      _reportQueryRequestError(account, error: e, action: '电费查询');
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _progressText = '';
        });
      }
    }
  }

  static const List<int> _electricAmountPresetsFallback = [
    50,
    100,
    200,
    300,
    500
  ];

  Future<String?> _showElectricRechargeAmountSheet(
    _ElectricAccountRecord record,
  ) async {
    var presets = List<int>.from(_electricAmountPresetsFallback);
    var allowCustom = true;
    try {
      final options = await _repo.getUtilityAmountOptions(
        serviceType: 'electric',
        providerCode: _selectedCity.providerCode,
      );
      if (options.items.isNotEmpty) {
        presets = options.items.map((e) => e.amount).toList(growable: false);
      }
      allowCustom = options.allowCustomAmount;
    } catch (_) {
      // 面额接口失败时回退本地预设
    }
    if (!mounted) return null;
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: LifePaymentTheme.sheetBg(
        Theme.of(context).brightness == Brightness.dark,
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: _ElectricRechargeAmountSheet(
            record: record,
            amountPresets: presets,
            allowCustomAmount: allowCustom,
            suggestAmountYuan: record.suggestAmountYuan,
          ),
        );
      },
    );
  }

  WalletPayMethodDto get _selectedPayMethod => _electricPayMethods.firstWhere(
        (item) => item.id == _payMethodId,
        orElse: () => _electricPayMethods.first,
      );

  Future<WalletPayMethodDto?> _showPaymentMethodPicker() {
    return showModalBottomSheet<WalletPayMethodDto>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.38),
      builder: (_) => WalletPayMethodSheet(
        items: _electricPayMethods,
        sel: _selectedPayMethod,
      ),
    );
  }

  Future<void> _submitElectricOrder(
    UtilityQueryResult query,
    String amount,
  ) async {
    final method = _selectedPayMethod;
    LifePaymentOrderResult? createdOrder;
    var queryExpired = false;
    final paid = await PayPasswordPrompt.show(
      context,
      title: '电费缴费',
      amountText: amount,
      amountCoin: '元',
      payText: method.coin,
      payCoinCode: method.id,
      walletSubtitle: method.net,
      onChangePayMethod: () async {
        final selected = await _showPaymentMethodPicker();
        if (selected == null) return null;
        if (mounted) setState(() => _payMethodId = selected.id);
        return PayMethodDisplay(
          amountText: amount,
          amountCoin: '元',
          payText: selected.coin,
          payCoinCode: selected.id,
          walletSubtitle: selected.net,
        );
      },
      onSubmit: (pwd) async {
        try {
          createdOrder = await _repo.createUtilityOrder(
            // uuid 防撞单：毫秒时间戳在多设备/快速重试下存在撞 client_order_id 风险
            clientOrderId: 'electric-${const Uuid().v4()}',
            queryNo: query.queryNo,
            serviceType: 'electric',
            cityName:
                query.cityName.isEmpty ? _selectedCity.city : query.cityName,
            cityCode: query.cityCode.isEmpty
                ? _selectedCity.cityCode
                : query.cityCode,
            providerName: query.providerName.isEmpty
                ? _selectedCity.provider
                : query.providerName,
            providerCode: query.providerCode.isEmpty
                ? _selectedCity.providerCode
                : query.providerCode,
            accountNo: query.accountNo.isEmpty
                ? _accountController.text.trim()
                : query.accountNo,
            confirmedUserAddress: query.userAddress,
            amount: amount,
            payMethod: _payMethodId,
            payPassword: pwd,
          );
          return null;
        } catch (e) {
          final reason = _orderCreateErrorText(e);
          if (_looksLikeQueryExpired(reason)) {
            queryExpired = true;
            return '户号查询已过期，稍后将自动重新查询';
          }
          return '创建电费订单失败：$reason';
        }
      },
    );
    if (!mounted) return;
    if (queryExpired) {
      final index = _accountRecords.indexWhere(
        (item) =>
            item.accountNo == query.accountNo || item.queryNo == query.queryNo,
      );
      if (index >= 0) {
        unawaited(_requeryRecord(_accountRecords[index]));
      }
      return;
    }
    if (paid == true && createdOrder != null) {
      _watchingOrderNo = createdOrder!.orderNo;
      ToastUtils.toast(
          createdOrder!.message.isNotEmpty ? createdOrder!.message : '电费订单已提交');
    }
  }

  Future<void> _confirmUnbindAccount(_ElectricAccountRecord record) async {
    final confirmed = await AppDialog.confirm(
      title: '解除绑定',
      message: '确认解绑户号 ${record.accountNo} 吗？',
      cancelText: '取消',
      confirmText: '确认',
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      _accountRecords.removeWhere((item) => item.accountNo == record.accountNo);
    });
    unawaited(_saveAccountRecords());
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
                          _ElectricityPaymentForm(
                            city: _selectedCity,
                            accountController: _accountController,
                            accountHint: _accountHint,
                            accountTip: _accountTip,
                            isHangzhou: _isHangzhou,
                            isSupportedCity: _isSupportedCity,
                            radius: radius,
                            titleSize: titleSize,
                            citySize: citySize,
                            onCityTap: _selectCity,
                            onHelpTap: _showAccountHelp,
                            onAccountChanged: (_) => setState(() {}),
                          ),
                          SizedBox(height: horizontal),
                          _ElectricAccountRecordList(
                            records: _accountRecords,
                            radius: radius,
                            titleSize: titleSize,
                            refreshingAccountNo: _refreshingAccountNo,
                            onTap: _onAccountRecordTap,
                            onUnbind: _confirmUnbindAccount,
                            onRefresh: _refreshQueryResult,
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
                          onPressed: _submitting ||
                                  !_isSupportedCity ||
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
                          child: const Text('绑定户号'),
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

class _ElectricAccountRecord {
  const _ElectricAccountRecord({
    required this.cityName,
    required this.providerName,
    required this.accountNo,
    required this.status,
    required this.statusText,
    required this.createdAt,
    this.userAddress = '',
    this.accountBalance = '',
    this.queryNo = '',
    this.receipt = '',
    this.queryStatus = '',
    this.pluginStatus = '',
    this.suggestAmount = '',
  });

  final String cityName;
  final String providerName;
  final String accountNo;
  final String status;
  final String statusText;
  final DateTime createdAt;
  final String userAddress;
  final String accountBalance;
  final String queryNo;
  final String receipt;
  final String queryStatus;
  final String pluginStatus;
  final String suggestAmount;

  int? get suggestAmountYuan {
    final raw = suggestAmount.trim();
    if (raw.isEmpty) return null;
    final asNum = num.tryParse(raw);
    if (asNum == null || asNum <= 0) return null;
    return asNum.round();
  }

  factory _ElectricAccountRecord.fromJson(Map<String, Object?> json) {
    return _ElectricAccountRecord(
      cityName: json['city_name']?.toString() ?? '',
      providerName: json['provider_name']?.toString() ?? '',
      accountNo: json['account_no']?.toString() ?? '',
      status: json['status']?.toString() ?? 'running',
      statusText: json['status_text']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      userAddress: json['user_address']?.toString() ?? '',
      accountBalance: json['account_balance']?.toString() ?? '',
      queryNo: json['query_no']?.toString() ?? '',
      receipt: json['receipt']?.toString() ?? '',
      queryStatus: json['query_status']?.toString() ?? '',
      pluginStatus: json['plugin_status']?.toString() ?? '',
      suggestAmount: json['suggest_amount']?.toString() ?? '',
    );
  }

  Map<String, Object?> toJson() {
    return {
      'city_name': cityName,
      'provider_name': providerName,
      'account_no': accountNo,
      'status': status,
      'status_text': statusText,
      'created_at': createdAt.toIso8601String(),
      'user_address': userAddress,
      'account_balance': accountBalance,
      'query_no': queryNo,
      'receipt': receipt,
      'query_status': queryStatus,
      'plugin_status': pluginStatus,
      'suggest_amount': suggestAmount,
    };
  }

  _ElectricAccountRecord copyWith({
    String? status,
    String? statusText,
    String? cityName,
    String? providerName,
    String? userAddress,
    String? accountBalance,
    String? queryNo,
    String? receipt,
    String? queryStatus,
    String? pluginStatus,
    String? suggestAmount,
  }) {
    return _ElectricAccountRecord(
      cityName: cityName ?? this.cityName,
      providerName: providerName ?? this.providerName,
      accountNo: accountNo,
      status: status ?? this.status,
      statusText: statusText ?? this.statusText,
      createdAt: createdAt,
      userAddress: userAddress ?? this.userAddress,
      accountBalance: accountBalance ?? this.accountBalance,
      queryNo: queryNo ?? this.queryNo,
      receipt: receipt ?? this.receipt,
      queryStatus: queryStatus ?? this.queryStatus,
      pluginStatus: pluginStatus ?? this.pluginStatus,
      suggestAmount: suggestAmount ?? this.suggestAmount,
    );
  }
}

class _ElectricAccountRecordList extends StatelessWidget {
  const _ElectricAccountRecordList({
    required this.records,
    required this.radius,
    required this.titleSize,
    required this.refreshingAccountNo,
    required this.onTap,
    required this.onUnbind,
    required this.onRefresh,
  });

  final List<_ElectricAccountRecord> records;
  final double radius;
  final double titleSize;
  final String? refreshingAccountNo;
  final ValueChanged<_ElectricAccountRecord> onTap;
  final ValueChanged<_ElectricAccountRecord> onUnbind;
  final ValueChanged<_ElectricAccountRecord> onRefresh;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(radius * 0.72),
      decoration: BoxDecoration(
        color: LifePaymentTheme.formCard(dark),
        borderRadius: BorderRadius.circular(radius * 0.72),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.35 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '我的电费户号',
            style: TextStyle(
              color: LifePaymentTheme.text(dark),
              fontSize: titleSize * 0.72,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: radius * 0.20),
          Text(
            '首次绑定需要约 1 分钟，完成后会显示地址和余额/欠费状态',
            style: TextStyle(
              color: LifePaymentTheme.subText(dark),
              fontSize: titleSize * 0.46,
              height: 1.35,
            ),
          ),
          SizedBox(height: radius * 0.54),
          if (records.isEmpty)
            Text(
              '暂无绑定户号',
              style: TextStyle(
                color: LifePaymentTheme.formHint(dark),
                fontSize: titleSize * 0.52,
              ),
            )
          else
            ...records.map((item) => _ElectricAccountRecordTile(
                  record: item,
                  radius: radius,
                  titleSize: titleSize,
                  refreshing: refreshingAccountNo == item.accountNo,
                  onTap: onTap,
                  onUnbind: onUnbind,
                  onRefresh: onRefresh,
                )),
        ],
      ),
    );
  }
}

class _ElectricAccountRecordTile extends StatelessWidget {
  const _ElectricAccountRecordTile({
    required this.record,
    required this.radius,
    required this.titleSize,
    required this.refreshing,
    required this.onTap,
    required this.onUnbind,
    required this.onRefresh,
  });

  final _ElectricAccountRecord record;
  final double radius;
  final double titleSize;
  final bool refreshing;
  final ValueChanged<_ElectricAccountRecord> onTap;
  final ValueChanged<_ElectricAccountRecord> onUnbind;
  final ValueChanged<_ElectricAccountRecord> onRefresh;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final running = record.status == 'running';
    final failed = record.status == 'failed';
    final bound = record.status == 'success';
    final badgeColor = failed
        ? const Color(0xFFFF4D4F)
        : running
            ? const Color(0xFFFAAD14)
            : const Color(0xFF1E7BF2);
    final hintColor = LifePaymentTheme.subText(dark);
    return Container(
      margin: EdgeInsets.only(bottom: radius * 0.42),
      decoration: BoxDecoration(
        color: LifePaymentTheme.selectedSoft(dark),
        borderRadius: BorderRadius.circular(radius * 0.44),
        border: Border.all(
          color: bound
              ? LifePaymentTheme.brandBlue
              : LifePaymentTheme.hairline(dark),
          width: bound ? 1.2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius * 0.44),
          onTap: bound ? () => onTap(record) : null,
          child: Padding(
            padding: EdgeInsets.all(radius * 0.52),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        record.accountNo,
                        style: TextStyle(
                          color: LifePaymentTheme.text(dark),
                          fontSize: titleSize * 0.62,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: radius * 0.34,
                        vertical: radius * 0.14,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        running
                            ? '查询中'
                            : failed
                                ? '失败'
                                : '已绑定',
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: titleSize * 0.42,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: radius * 0.20),
                if (record.cityName.isNotEmpty ||
                    record.providerName.isNotEmpty)
                  _ElectricRecordInfoLine(
                    label: '缴费单位',
                    value: [
                      if (record.cityName.isNotEmpty) record.cityName,
                      if (record.providerName.isNotEmpty) record.providerName,
                    ].join(' · '),
                    titleSize: titleSize,
                  ),
                _ElectricRecordInfoLine(
                  label: '户号',
                  value: record.accountNo,
                  titleSize: titleSize,
                ),
                if (record.userAddress.isNotEmpty)
                  _ElectricRecordInfoLine(
                    label: '住址',
                    value: record.userAddress,
                    titleSize: titleSize,
                  ),
                if (record.accountBalance.isNotEmpty)
                  _ElectricRecordInfoLine(
                    label: '余额/欠费',
                    value: record.accountBalance,
                    titleSize: titleSize,
                    emphasize: true,
                  ),
                if (record.statusText.isNotEmpty && !bound) ...[
                  SizedBox(height: radius * 0.12),
                  Text(
                    record.statusText,
                    style: TextStyle(
                      color: hintColor,
                      fontSize: titleSize * 0.44,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
                SizedBox(height: radius * 0.28),
                Row(
                  children: [
                    if (record.queryNo.isNotEmpty && (running || failed))
                      TextButton.icon(
                        onPressed: refreshing ? null : () => onRefresh(record),
                        icon: refreshing
                            ? SizedBox(
                                width: titleSize * 0.42,
                                height: titleSize * 0.42,
                                child: const CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : Icon(Icons.refresh, size: titleSize * 0.48),
                        label: Text(
                          refreshing ? '刷新中...' : '刷新状态',
                          style: TextStyle(fontSize: titleSize * 0.46),
                        ),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => onUnbind(record),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF1E7BF2),
                        padding: EdgeInsets.symmetric(
                          horizontal: radius * 0.12,
                          vertical: radius * 0.08,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        '解除绑定',
                        style: TextStyle(fontSize: titleSize * 0.46),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ElectricRechargeAmountSheet extends StatefulWidget {
  const _ElectricRechargeAmountSheet({
    required this.record,
    required this.amountPresets,
    required this.allowCustomAmount,
    this.suggestAmountYuan,
  });

  final _ElectricAccountRecord record;
  final List<int> amountPresets;
  final bool allowCustomAmount;
  final int? suggestAmountYuan;

  @override
  State<_ElectricRechargeAmountSheet> createState() =>
      _ElectricRechargeAmountSheetState();
}

class _ElectricRechargeAmountSheetState
    extends State<_ElectricRechargeAmountSheet> {
  late final TextEditingController _amountController;
  int? _selectedPreset;

  @override
  void initState() {
    super.initState();
    final suggest = widget.suggestAmountYuan;
    if (suggest != null && widget.amountPresets.contains(suggest)) {
      _selectedPreset = suggest;
    } else if (suggest != null && widget.allowCustomAmount) {
      _selectedPreset = null;
    } else if (widget.amountPresets.contains(50)) {
      _selectedPreset = 50;
    } else if (widget.amountPresets.isNotEmpty) {
      _selectedPreset = widget.amountPresets.first;
    }
    final initial = suggest != null &&
            (widget.allowCustomAmount || widget.amountPresets.contains(suggest))
        ? suggest
        : _selectedPreset;
    _amountController = TextEditingController(
      text: initial?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _pickPreset(int amount) {
    setState(() {
      _selectedPreset = amount;
      _amountController.text = amount.toString();
    });
  }

  void _submit() {
    final amount = _amountController.text.trim();
    if (amount.isEmpty) {
      ToastUtils.toast('请输入缴费金额');
      return;
    }
    final parsed = int.tryParse(amount);
    if (parsed == null || parsed <= 0) {
      ToastUtils.toast('请输入有效的整元金额');
      return;
    }
    if (!widget.allowCustomAmount && !widget.amountPresets.contains(parsed)) {
      ToastUtils.toast('请选择可用面额');
      return;
    }
    Navigator.of(context).pop(parsed.toString());
  }

  @override
  Widget build(BuildContext context) {
    const brandBlue = Color(0xFF1E7BF2);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bodyText = LifePaymentTheme.text(dark);
    final subText = LifePaymentTheme.subText(dark);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '电费缴费',
            style: TextStyle(
              color: bodyText,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '户号 ${widget.record.accountNo}',
            style: TextStyle(color: subText, fontSize: 14),
          ),
          if (widget.record.accountBalance.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.record.accountBalance,
              style: TextStyle(
                color: bodyText,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            '选择缴费金额',
            style: TextStyle(
              color: bodyText,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.1,
            children: [
              for (final amount in widget.amountPresets)
                _ElectricAmountTile(
                  label: '$amount元',
                  selected: _selectedPreset == amount,
                  onTap: () => _pickPreset(amount),
                ),
            ],
          ),
          if (widget.allowCustomAmount) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) {
                final parsed = int.tryParse(value.trim());
                setState(() {
                  _selectedPreset =
                      parsed != null && widget.amountPresets.contains(parsed)
                          ? parsed
                          : null;
                });
              },
              decoration: InputDecoration(
                hintText: '其他金额（整数）',
                suffixText: '元',
                filled: true,
                fillColor: LifePaymentTheme.searchFill(dark),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: brandBlue,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              child: const Text(
                '立即缴费',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ElectricAmountTile extends StatelessWidget {
  const _ElectricAmountTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    const brandBlue = LifePaymentTheme.brandBlue;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            color: LifePaymentTheme.formCard(dark),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? brandBlue
                  : LifePaymentTheme.amountTileBorder(dark),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? brandBlue : LifePaymentTheme.text(dark),
                fontSize: 16,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ElectricRecordInfoLine extends StatelessWidget {
  const _ElectricRecordInfoLine({
    required this.label,
    required this.value,
    required this.titleSize,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final double titleSize;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      color: LifePaymentTheme.subText(
          Theme.of(context).brightness == Brightness.dark),
      fontSize: titleSize * 0.44,
    );
    final valueStyle = TextStyle(
      color: emphasize
          ? LifePaymentTheme.text(
              Theme.of(context).brightness == Brightness.dark)
          : LifePaymentTheme.subText(
              Theme.of(context).brightness == Brightness.dark),
      fontSize: emphasize ? titleSize * 0.48 : titleSize * 0.44,
      fontWeight: emphasize ? FontWeight.w600 : FontWeight.w400,
      height: 1.35,
    );
    return Padding(
      padding: EdgeInsets.only(top: titleSize * 0.10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label：',
            style: labelStyle,
            softWrap: false,
          ),
          Expanded(
            child: Text(
              value,
              style: valueStyle,
            ),
          ),
        ],
      ),
    );
  }
}

class _ElectricityPaymentForm extends StatelessWidget {
  const _ElectricityPaymentForm({
    required this.city,
    required this.accountController,
    required this.accountHint,
    required this.accountTip,
    required this.isHangzhou,
    required this.isSupportedCity,
    required this.radius,
    required this.titleSize,
    required this.citySize,
    required this.onCityTap,
    required this.onHelpTap,
    required this.onAccountChanged,
  });

  final ElectricityCityProvider city;
  final TextEditingController accountController;
  final String accountHint;
  final String accountTip;
  final bool isHangzhou;
  final bool isSupportedCity;
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
        // 白色内容区四周保留同一套响应式蓝色边距：底边与左右边一致。
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
                    Icons.bolt_rounded,
                    color: const Color(0xFFFFBE42),
                    size: citySize * 0.93,
                  ),
                ),
                SizedBox(width: radius * 0.48),
                Text(
                  '电费',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: citySize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Semantics(
                  button: true,
                  label: '选择城市，当前${city.city}',
                  child: InkWell(
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
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * 0.30,
                            ),
                            child: Text(
                              city.city,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: citySize,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(width: radius * 0.10),
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            color: Colors.white,
                            size: citySize * 1.12,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: radius * 0.65),
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
                              city.provider,
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: accountController,
                          enabled: isSupportedCity,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(24),
                          ],
                          onChanged: onAccountChanged,
                          style: TextStyle(
                            color: LifePaymentTheme.formValue(dark),
                            fontSize: providerSize * 0.90,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: radius * 0.28,
                            ),
                            hintText: accountHint,
                            hintStyle: TextStyle(
                              color: LifePaymentTheme.formHint(dark),
                              fontSize: providerSize * 0.90,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                      if (!isHangzhou) ...[
                        SizedBox(width: radius * 0.24),
                        TextButton(
                          onPressed: onHelpTap,
                          style: TextButton.styleFrom(
                            foregroundColor: brandBlue,
                            backgroundColor: const Color(0xFFF0F8FF),
                            padding: EdgeInsets.symmetric(
                              horizontal: radius * 0.48,
                              vertical: radius * 0.34,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(radius * 0.34),
                            ),
                          ),
                          child: Text(
                            '查看获取方式',
                            style: TextStyle(
                              fontSize: labelSize * 0.92,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (isHangzhou) ...[
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
                  SizedBox(height: radius * 0.62),
                  Text(
                    accountTip,
                    style: TextStyle(
                      color: const Color(0xFFC3C7CD),
                      fontSize: labelSize * 0.82,
                      height: 1.5,
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

class ElectricityCitySelectionPage extends StatefulWidget {
  const ElectricityCitySelectionPage({
    super.key,
    required this.selectedCity,
    this.locationLabel,
  });

  final String selectedCity;
  final String? locationLabel;

  @override
  State<ElectricityCitySelectionPage> createState() =>
      _ElectricityCitySelectionPageState();
}

class _ElectricityCitySelectionPageState
    extends State<ElectricityCitySelectionPage> {
  final TextEditingController _searchController = TextEditingController();
  final ItemScrollController _itemScrollController = ItemScrollController();
  String _query = '';

  static const _hotCities = [
    '杭州',
    '北京',
    '南京',
    '苏州',
    '武汉',
    '西安',
    '福州',
    '青岛',
    '济南',
    '沈阳',
    '太原',
    '长春',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ElectricityCityProvider> get _filteredCities {
    final normalized =
        _query.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (normalized.isEmpty) return ElectricityCityCatalog.all;
    return ElectricityCityCatalog.all.where((item) {
      return item.city.contains(_query.trim()) ||
          item.searchKey.contains(normalized);
    }).toList();
  }

  List<LifePaymentCityIndexItem<Object?>> _buildIndexItems({
    required List<ElectricityCityProvider> cities,
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
    List<LifePaymentCityIndexItem<Object?>> items,
  ) {
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

  void _pick(ElectricityCityProvider city) {
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
                      hintText: '输入城市名、拼音或字母查询',
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
                                  return _ElectricityCityHeaderBlock(
                                    dark: dark,
                                    locationLabel: widget.locationLabel,
                                    selectedCity: widget.selectedCity,
                                    hotCities: _hotCities,
                                    horizontal: horizontal,
                                    sectionSize: sectionSize,
                                    onPick: _pick,
                                  );
                                }
                                final city =
                                    item.data as ElectricityCityProvider;
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
                                    _CityListTile(
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

class _ElectricityCityHeaderBlock extends StatelessWidget {
  const _ElectricityCityHeaderBlock({
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
  final ValueChanged<ElectricityCityProvider> onPick;

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
          child: _LocationCityChip(
            dark: dark,
            city: locationLabel,
            onTap: locationLabel == null ||
                    ElectricityCityCatalog.byCity(locationLabel!) == null
                ? null
                : () {
                    final item = ElectricityCityCatalog.byCity(locationLabel!);
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
        _HotCityGrid(
          dark: dark,
          cities: hotCities
              .map(ElectricityCityCatalog.byCity)
              .whereType<ElectricityCityProvider>()
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

class _LocationCityChip extends StatelessWidget {
  const _LocationCityChip({
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

class _HotCityGrid extends StatelessWidget {
  const _HotCityGrid({
    required this.dark,
    required this.cities,
    required this.selectedCity,
    required this.onPick,
    required this.labelSize,
  });

  final bool dark;
  final List<ElectricityCityProvider> cities;
  final String selectedCity;
  final ValueChanged<ElectricityCityProvider> onPick;
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

class _CityListTile extends StatelessWidget {
  const _CityListTile({
    required this.dark,
    required this.city,
    required this.selected,
    required this.onTap,
    required this.fontSize,
  });

  final bool dark;
  final ElectricityCityProvider city;
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

class ElectricityCityProvider {
  const ElectricityCityProvider({
    required this.city,
    required this.provider,
    required this.initial,
    required this.searchKey,
    this.cityCode = '',
    this.providerCode = '',
  });

  final String city;
  final String provider;
  final String initial;
  final String searchKey;
  final String cityCode;
  final String providerCode;
}

class ElectricityCityCatalog {
  ElectricityCityCatalog._();

  static const all = <ElectricityCityProvider>[
    ElectricityCityProvider(
      city: '北京',
      provider: '国网北京市电力公司',
      initial: 'B',
      searchKey: '北京beijingb',
    ),
    ElectricityCityProvider(
      city: '石家庄',
      provider: '国网河北省电力有限公司',
      initial: 'S',
      searchKey: '石家庄shijiazhuangs',
    ),
    ElectricityCityProvider(
      city: '唐山',
      provider: '国网冀北电力有限公司',
      initial: 'T',
      searchKey: '唐山tangshant',
    ),
    ElectricityCityProvider(
      city: '秦皇岛',
      provider: '国网冀北电力有限公司',
      initial: 'Q',
      searchKey: '秦皇岛qinhuangdaoq',
    ),
    ElectricityCityProvider(
      city: '邢台',
      provider: '国网河北省电力有限公司',
      initial: 'X',
      searchKey: '邢台xingtaix',
    ),
    ElectricityCityProvider(
      city: '张家口',
      provider: '国网冀北电力有限公司',
      initial: 'Z',
      searchKey: '张家口zhangjiakouz',
    ),
    ElectricityCityProvider(
      city: '承德',
      provider: '国网冀北电力有限公司',
      initial: 'C',
      searchKey: '承德chengdec',
    ),
    ElectricityCityProvider(
      city: '沧州',
      provider: '国网河北省电力有限公司',
      initial: 'C',
      searchKey: '沧州cangzhouc',
    ),
    ElectricityCityProvider(
      city: '廊坊',
      provider: '国网冀北电力有限公司',
      initial: 'L',
      searchKey: '廊坊langfangl',
    ),
    ElectricityCityProvider(
      city: '衡水',
      provider: '国网河北省电力有限公司',
      initial: 'H',
      searchKey: '衡水hengshuih',
    ),
    ElectricityCityProvider(
      city: '太原',
      provider: '国网山西省电力公司',
      initial: 'T',
      searchKey: '太原taiyuant',
    ),
    ElectricityCityProvider(
      city: '大同',
      provider: '国网山西省电力公司',
      initial: 'D',
      searchKey: '大同datongd',
    ),
    ElectricityCityProvider(
      city: '阳泉',
      provider: '国网山西省电力公司',
      initial: 'Y',
      searchKey: '阳泉yangquany',
    ),
    ElectricityCityProvider(
      city: '长治',
      provider: '国网山西省电力公司',
      initial: 'C',
      searchKey: '长治changzhic',
    ),
    ElectricityCityProvider(
      city: '晋城',
      provider: '国网山西省电力公司',
      initial: 'J',
      searchKey: '晋城jinchengj',
    ),
    ElectricityCityProvider(
      city: '朔州',
      provider: '国网山西省电力公司',
      initial: 'S',
      searchKey: '朔州shuozhous',
    ),
    ElectricityCityProvider(
      city: '晋中',
      provider: '国网山西省电力公司',
      initial: 'J',
      searchKey: '晋中jinzhongj',
    ),
    ElectricityCityProvider(
      city: '运城',
      provider: '国网山西省电力公司',
      initial: 'Y',
      searchKey: '运城yunchengy',
    ),
    ElectricityCityProvider(
      city: '忻州',
      provider: '国网山西省电力公司',
      initial: 'X',
      searchKey: '忻州xinzhoux',
    ),
    ElectricityCityProvider(
      city: '临汾',
      provider: '国网山西省电力公司',
      initial: 'L',
      searchKey: '临汾linfenl',
    ),
    ElectricityCityProvider(
      city: '吕梁',
      provider: '国网山西省电力公司',
      initial: 'L',
      searchKey: '吕梁luliangl',
    ),
    ElectricityCityProvider(
      city: '呼和浩特',
      provider: '内蒙古电力（集团）有限责任公司',
      initial: 'H',
      searchKey: '呼和浩特huhehaoteh',
    ),
    ElectricityCityProvider(
      city: '包头',
      provider: '内蒙古电力（集团）有限责任公司',
      initial: 'B',
      searchKey: '包头baotoub',
    ),
    ElectricityCityProvider(
      city: '乌海',
      provider: '内蒙古电力（集团）有限责任公司',
      initial: 'W',
      searchKey: '乌海wuhaiw',
    ),
    ElectricityCityProvider(
      city: '赤峰',
      provider: '国网内蒙古东部电力有限公司',
      initial: 'C',
      searchKey: '赤峰chifengc',
    ),
    ElectricityCityProvider(
      city: '通辽',
      provider: '国网内蒙古东部电力有限公司',
      initial: 'T',
      searchKey: '通辽tongliaot',
    ),
    ElectricityCityProvider(
      city: '鄂尔多斯',
      provider: '内蒙古电力（集团）有限责任公司',
      initial: 'E',
      searchKey: '鄂尔多斯eerduosie',
    ),
    ElectricityCityProvider(
      city: '呼伦贝尔',
      provider: '国网内蒙古东部电力有限公司',
      initial: 'H',
      searchKey: '呼伦贝尔hulunbeierh',
    ),
    ElectricityCityProvider(
      city: '巴彦淖尔',
      provider: '内蒙古电力（集团）有限责任公司',
      initial: 'B',
      searchKey: '巴彦淖尔bayannaoerb',
    ),
    ElectricityCityProvider(
      city: '乌兰察布',
      provider: '内蒙古电力（集团）有限责任公司',
      initial: 'W',
      searchKey: '乌兰察布wulanchabuw',
    ),
    ElectricityCityProvider(
      city: '沈阳',
      provider: '国网辽宁省电力有限公司',
      initial: 'S',
      searchKey: '沈阳chenyangs',
    ),
    ElectricityCityProvider(
      city: '鞍山',
      provider: '国网辽宁省电力有限公司',
      initial: 'A',
      searchKey: '鞍山anshana',
    ),
    ElectricityCityProvider(
      city: '抚顺',
      provider: '国网辽宁省电力有限公司',
      initial: 'F',
      searchKey: '抚顺fushunf',
    ),
    ElectricityCityProvider(
      city: '本溪',
      provider: '国网辽宁省电力有限公司',
      initial: 'B',
      searchKey: '本溪benxib',
    ),
    ElectricityCityProvider(
      city: '丹东',
      provider: '国网辽宁省电力有限公司',
      initial: 'D',
      searchKey: '丹东dandongd',
    ),
    ElectricityCityProvider(
      city: '锦州',
      provider: '国网辽宁省电力有限公司',
      initial: 'J',
      searchKey: '锦州jinzhouj',
    ),
    ElectricityCityProvider(
      city: '营口',
      provider: '国网辽宁省电力有限公司',
      initial: 'Y',
      searchKey: '营口yingkouy',
    ),
    ElectricityCityProvider(
      city: '阜新',
      provider: '国网辽宁省电力有限公司',
      initial: 'F',
      searchKey: '阜新fuxinf',
    ),
    ElectricityCityProvider(
      city: '辽阳',
      provider: '国网辽宁省电力有限公司',
      initial: 'L',
      searchKey: '辽阳liaoyangl',
    ),
    ElectricityCityProvider(
      city: '盘锦',
      provider: '国网辽宁省电力有限公司',
      initial: 'P',
      searchKey: '盘锦panjinp',
    ),
    ElectricityCityProvider(
      city: '铁岭',
      provider: '国网辽宁省电力有限公司',
      initial: 'T',
      searchKey: '铁岭tielingt',
    ),
    ElectricityCityProvider(
      city: '朝阳',
      provider: '国网辽宁省电力有限公司',
      initial: 'C',
      searchKey: '朝阳zhaoyangc',
    ),
    ElectricityCityProvider(
      city: '葫芦岛',
      provider: '国网辽宁省电力有限公司',
      initial: 'H',
      searchKey: '葫芦岛huludaoh',
    ),
    ElectricityCityProvider(
      city: '长春',
      provider: '国网吉林省电力有限公司',
      initial: 'C',
      searchKey: '长春changchunc',
    ),
    ElectricityCityProvider(
      city: '吉林',
      provider: '国网吉林省电力有限公司',
      initial: 'J',
      searchKey: '吉林jilinj',
    ),
    ElectricityCityProvider(
      city: '四平',
      provider: '国网吉林省电力有限公司',
      initial: 'S',
      searchKey: '四平sipings',
    ),
    ElectricityCityProvider(
      city: '辽源',
      provider: '国网吉林省电力有限公司',
      initial: 'L',
      searchKey: '辽源liaoyuanl',
    ),
    ElectricityCityProvider(
      city: '通化',
      provider: '国网吉林省电力有限公司',
      initial: 'T',
      searchKey: '通化tonghuat',
    ),
    ElectricityCityProvider(
      city: '白山',
      provider: '国网吉林省电力有限公司',
      initial: 'B',
      searchKey: '白山baishanb',
    ),
    ElectricityCityProvider(
      city: '松原',
      provider: '国网吉林省电力有限公司',
      initial: 'S',
      searchKey: '松原songyuans',
    ),
    ElectricityCityProvider(
      city: '白城',
      provider: '国网吉林省电力有限公司',
      initial: 'B',
      searchKey: '白城baichengb',
    ),
    ElectricityCityProvider(
      city: '哈尔滨',
      provider: '国网黑龙江电力有限公司',
      initial: 'H',
      searchKey: '哈尔滨haerbinh',
    ),
    ElectricityCityProvider(
      city: '齐齐哈尔',
      provider: '国网黑龙江电力有限公司',
      initial: 'Q',
      searchKey: '齐齐哈尔qiqihaerq',
    ),
    ElectricityCityProvider(
      city: '鸡西',
      provider: '国网黑龙江电力有限公司',
      initial: 'J',
      searchKey: '鸡西jixij',
    ),
    ElectricityCityProvider(
      city: '鹤岗',
      provider: '国网黑龙江电力有限公司',
      initial: 'H',
      searchKey: '鹤岗hegangh',
    ),
    ElectricityCityProvider(
      city: '双鸭山',
      provider: '国网黑龙江电力有限公司',
      initial: 'S',
      searchKey: '双鸭山shuangyashans',
    ),
    ElectricityCityProvider(
      city: '大庆',
      provider: '国网黑龙江电力有限公司',
      initial: 'D',
      searchKey: '大庆daqingd',
    ),
    ElectricityCityProvider(
      city: '伊春',
      provider: '国网黑龙江电力有限公司',
      initial: 'Y',
      searchKey: '伊春yichuny',
    ),
    ElectricityCityProvider(
      city: '佳木斯',
      provider: '国网黑龙江电力有限公司',
      initial: 'J',
      searchKey: '佳木斯jiamusij',
    ),
    ElectricityCityProvider(
      city: '七台河',
      provider: '国网黑龙江电力有限公司',
      initial: 'Q',
      searchKey: '七台河qitaiheq',
    ),
    ElectricityCityProvider(
      city: '牡丹江',
      provider: '国网黑龙江电力有限公司',
      initial: 'M',
      searchKey: '牡丹江mudanjiangm',
    ),
    ElectricityCityProvider(
      city: '黑河',
      provider: '国网黑龙江电力有限公司',
      initial: 'H',
      searchKey: '黑河heiheh',
    ),
    ElectricityCityProvider(
      city: '绥化',
      provider: '国网黑龙江电力有限公司',
      initial: 'S',
      searchKey: '绥化suihuas',
    ),
    ElectricityCityProvider(
      city: '南京',
      provider: '国网江苏省电力有限公司',
      initial: 'N',
      searchKey: '南京nanjingn',
    ),
    ElectricityCityProvider(
      city: '无锡',
      provider: '国网江苏省电力有限公司',
      initial: 'W',
      searchKey: '无锡wuxiw',
    ),
    ElectricityCityProvider(
      city: '徐州',
      provider: '国网江苏省电力有限公司',
      initial: 'X',
      searchKey: '徐州xuzhoux',
    ),
    ElectricityCityProvider(
      city: '常州',
      provider: '国网江苏省电力有限公司',
      initial: 'C',
      searchKey: '常州changzhouc',
    ),
    ElectricityCityProvider(
      city: '苏州',
      provider: '国网江苏省电力有限公司',
      initial: 'S',
      searchKey: '苏州suzhous',
    ),
    ElectricityCityProvider(
      city: '南通',
      provider: '国网江苏省电力有限公司',
      initial: 'N',
      searchKey: '南通nantongn',
    ),
    ElectricityCityProvider(
      city: '连云港',
      provider: '国网江苏省电力有限公司',
      initial: 'L',
      searchKey: '连云港lianyungangl',
    ),
    ElectricityCityProvider(
      city: '淮安',
      provider: '国网江苏省电力有限公司',
      initial: 'H',
      searchKey: '淮安huaianh',
    ),
    ElectricityCityProvider(
      city: '盐城',
      provider: '国网江苏省电力有限公司',
      initial: 'Y',
      searchKey: '盐城yanchengy',
    ),
    ElectricityCityProvider(
      city: '扬州',
      provider: '国网江苏省电力有限公司',
      initial: 'Y',
      searchKey: '扬州yangzhouy',
    ),
    ElectricityCityProvider(
      city: '镇江',
      provider: '国网江苏省电力有限公司',
      initial: 'Z',
      searchKey: '镇江zhenjiangz',
    ),
    ElectricityCityProvider(
      city: '泰州',
      provider: '国网江苏省电力有限公司',
      initial: 'T',
      searchKey: '泰州taizhout',
    ),
    ElectricityCityProvider(
      city: '宿迁',
      provider: '国网江苏省电力有限公司',
      initial: 'S',
      searchKey: '宿迁suqians',
    ),
    ElectricityCityProvider(
      city: '杭州',
      provider: '国网浙江省电力公司',
      initial: 'H',
      searchKey: '杭州hangzhouh',
    ),
    ElectricityCityProvider(
      city: '宁波',
      provider: '国网浙江省电力公司',
      initial: 'N',
      searchKey: '宁波zhubon',
    ),
    ElectricityCityProvider(
      city: '嘉兴',
      provider: '国网浙江省电力公司',
      initial: 'J',
      searchKey: '嘉兴jiaxingj',
    ),
    ElectricityCityProvider(
      city: '绍兴',
      provider: '国网浙江省电力公司',
      initial: 'S',
      searchKey: '绍兴shaoxings',
    ),
    ElectricityCityProvider(
      city: '金华',
      provider: '国网浙江省电力公司',
      initial: 'J',
      searchKey: '金华jinhuaj',
    ),
    ElectricityCityProvider(
      city: '衢州',
      provider: '国网浙江省电力公司',
      initial: 'Z',
      searchKey: '衢州quzhouz',
    ),
    ElectricityCityProvider(
      city: '舟山',
      provider: '国网浙江省电力公司',
      initial: 'Z',
      searchKey: '舟山zhoushanz',
    ),
    ElectricityCityProvider(
      city: '台州',
      provider: '国网浙江省电力公司',
      initial: 'T',
      searchKey: '台州taizhout',
    ),
    ElectricityCityProvider(
      city: '丽水',
      provider: '国网浙江省电力公司',
      initial: 'L',
      searchKey: '丽水lishuil',
    ),
    ElectricityCityProvider(
      city: '合肥',
      provider: '国网安徽省电力公司',
      initial: 'H',
      searchKey: '合肥hefeih',
    ),
    ElectricityCityProvider(
      city: '芜湖',
      provider: '国网安徽省电力公司',
      initial: 'W',
      searchKey: '芜湖wuhuw',
    ),
    ElectricityCityProvider(
      city: '蚌埠',
      provider: '国网安徽省电力公司',
      initial: 'B',
      searchKey: '蚌埠bangbub',
    ),
    ElectricityCityProvider(
      city: '淮南',
      provider: '国网安徽省电力公司',
      initial: 'H',
      searchKey: '淮南huainanh',
    ),
    ElectricityCityProvider(
      city: '马鞍山',
      provider: '国网安徽省电力公司',
      initial: 'M',
      searchKey: '马鞍山maanshanm',
    ),
    ElectricityCityProvider(
      city: '淮北',
      provider: '国网安徽省电力公司',
      initial: 'H',
      searchKey: '淮北huaibeih',
    ),
    ElectricityCityProvider(
      city: '铜陵',
      provider: '国网安徽省电力公司',
      initial: 'T',
      searchKey: '铜陵tonglingt',
    ),
    ElectricityCityProvider(
      city: '安庆',
      provider: '国网安徽省电力公司',
      initial: 'A',
      searchKey: '安庆anqinga',
    ),
    ElectricityCityProvider(
      city: '黄山',
      provider: '国网安徽省电力公司',
      initial: 'H',
      searchKey: '黄山huangshanh',
    ),
    ElectricityCityProvider(
      city: '滁州',
      provider: '国网安徽省电力公司',
      initial: 'C',
      searchKey: '滁州chuzhouc',
    ),
    ElectricityCityProvider(
      city: '阜阳',
      provider: '国网安徽省电力公司',
      initial: 'F',
      searchKey: '阜阳fuyangf',
    ),
    ElectricityCityProvider(
      city: '宿州',
      provider: '国网安徽省电力公司',
      initial: 'S',
      searchKey: '宿州suzhous',
    ),
    ElectricityCityProvider(
      city: '亳州',
      provider: '国网安徽省电力公司',
      initial: 'Z',
      searchKey: '亳州bozhouz',
    ),
    ElectricityCityProvider(
      city: '池州',
      provider: '国网安徽省电力公司',
      initial: 'C',
      searchKey: '池州chizhouc',
    ),
    ElectricityCityProvider(
      city: '宣城',
      provider: '国网安徽省电力公司',
      initial: 'X',
      searchKey: '宣城xuanchengx',
    ),
    ElectricityCityProvider(
      city: '福州',
      provider: '国网福建省电力有限公司',
      initial: 'F',
      searchKey: '福州fuzhouf',
    ),
    ElectricityCityProvider(
      city: '厦门',
      provider: '国网福建省电力有限公司',
      initial: 'X',
      searchKey: '厦门shamenx',
    ),
    ElectricityCityProvider(
      city: '莆田',
      provider: '国网福建省电力有限公司',
      initial: 'P',
      searchKey: '莆田futianp',
    ),
    ElectricityCityProvider(
      city: '三明',
      provider: '国网福建省电力有限公司',
      initial: 'S',
      searchKey: '三明sanmings',
    ),
    ElectricityCityProvider(
      city: '泉州',
      provider: '国网福建省电力有限公司',
      initial: 'Q',
      searchKey: '泉州quanzhouq',
    ),
    ElectricityCityProvider(
      city: '南平',
      provider: '国网福建省电力有限公司',
      initial: 'N',
      searchKey: '南平nanpingn',
    ),
    ElectricityCityProvider(
      city: '龙岩',
      provider: '国网福建省电力有限公司',
      initial: 'L',
      searchKey: '龙岩longyanl',
    ),
    ElectricityCityProvider(
      city: '宁德',
      provider: '国网福建省电力有限公司',
      initial: 'N',
      searchKey: '宁德zhuden',
    ),
    ElectricityCityProvider(
      city: '南昌',
      provider: '国网江西省电力公司',
      initial: 'N',
      searchKey: '南昌nanchangn',
    ),
    ElectricityCityProvider(
      city: '景德镇',
      provider: '国网江西省电力公司',
      initial: 'J',
      searchKey: '景德镇jingdezhenj',
    ),
    ElectricityCityProvider(
      city: '萍乡',
      provider: '国网江西省电力公司',
      initial: 'P',
      searchKey: '萍乡pingxiangp',
    ),
    ElectricityCityProvider(
      city: '九江',
      provider: '国网江西省电力公司',
      initial: 'J',
      searchKey: '九江jiujiangj',
    ),
    ElectricityCityProvider(
      city: '新余',
      provider: '国网江西省电力公司',
      initial: 'X',
      searchKey: '新余xinyux',
    ),
    ElectricityCityProvider(
      city: '鹰潭',
      provider: '国网江西省电力公司',
      initial: 'Y',
      searchKey: '鹰潭yingtany',
    ),
    ElectricityCityProvider(
      city: '赣州',
      provider: '国网江西省电力公司',
      initial: 'G',
      searchKey: '赣州ganzhoug',
    ),
    ElectricityCityProvider(
      city: '吉安',
      provider: '国网江西省电力公司',
      initial: 'J',
      searchKey: '吉安jianj',
    ),
    ElectricityCityProvider(
      city: '宜春',
      provider: '国网江西省电力公司',
      initial: 'Y',
      searchKey: '宜春yichuny',
    ),
    ElectricityCityProvider(
      city: '抚州',
      provider: '国网江西省电力公司',
      initial: 'F',
      searchKey: '抚州fuzhouf',
    ),
    ElectricityCityProvider(
      city: '上饶',
      provider: '国网江西省电力公司',
      initial: 'S',
      searchKey: '上饶shangraos',
    ),
    ElectricityCityProvider(
      city: '济南',
      provider: '国网山东省电力公司',
      initial: 'J',
      searchKey: '济南jinanj',
    ),
    ElectricityCityProvider(
      city: '青岛',
      provider: '国网山东省电力公司',
      initial: 'Q',
      searchKey: '青岛qingdaoq',
    ),
    ElectricityCityProvider(
      city: '淄博',
      provider: '国网山东省电力公司',
      initial: 'Z',
      searchKey: '淄博ziboz',
    ),
    ElectricityCityProvider(
      city: '枣庄',
      provider: '国网山东省电力公司',
      initial: 'Z',
      searchKey: '枣庄zaozhuangz',
    ),
    ElectricityCityProvider(
      city: '烟台',
      provider: '国网山东省电力公司',
      initial: 'Y',
      searchKey: '烟台yantaiy',
    ),
    ElectricityCityProvider(
      city: '潍坊',
      provider: '国网山东省电力公司',
      initial: 'W',
      searchKey: '潍坊weifangw',
    ),
    ElectricityCityProvider(
      city: '济宁',
      provider: '国网山东省电力公司',
      initial: 'J',
      searchKey: '济宁jizhuj',
    ),
    ElectricityCityProvider(
      city: '泰安',
      provider: '国网山东省电力公司',
      initial: 'T',
      searchKey: '泰安taiant',
    ),
    ElectricityCityProvider(
      city: '威海',
      provider: '国网山东省电力公司',
      initial: 'W',
      searchKey: '威海weihaiw',
    ),
    ElectricityCityProvider(
      city: '日照',
      provider: '国网山东省电力公司',
      initial: 'R',
      searchKey: '日照rizhaor',
    ),
    ElectricityCityProvider(
      city: '临沂',
      provider: '国网山东省电力公司',
      initial: 'L',
      searchKey: '临沂linyil',
    ),
    ElectricityCityProvider(
      city: '德州',
      provider: '国网山东省电力公司',
      initial: 'D',
      searchKey: '德州dezhoud',
    ),
    ElectricityCityProvider(
      city: '聊城',
      provider: '国网山东省电力公司',
      initial: 'L',
      searchKey: '聊城liaochengl',
    ),
    ElectricityCityProvider(
      city: '滨州',
      provider: '国网山东省电力公司',
      initial: 'B',
      searchKey: '滨州binzhoub',
    ),
    ElectricityCityProvider(
      city: '菏泽',
      provider: '国网山东省电力公司',
      initial: 'H',
      searchKey: '菏泽hezeh',
    ),
    ElectricityCityProvider(
      city: '开封',
      provider: '国网河南省电力公司',
      initial: 'K',
      searchKey: '开封kaifengk',
    ),
    ElectricityCityProvider(
      city: '平顶山',
      provider: '国网河南省电力公司',
      initial: 'P',
      searchKey: '平顶山pingdingshanp',
    ),
    ElectricityCityProvider(
      city: '安阳',
      provider: '国网河南省电力公司',
      initial: 'A',
      searchKey: '安阳anyanga',
    ),
    ElectricityCityProvider(
      city: '鹤壁',
      provider: '国网河南省电力公司',
      initial: 'H',
      searchKey: '鹤壁hebih',
    ),
    ElectricityCityProvider(
      city: '新乡',
      provider: '国网河南省电力公司',
      initial: 'X',
      searchKey: '新乡xinxiangx',
    ),
    ElectricityCityProvider(
      city: '焦作',
      provider: '国网河南省电力公司',
      initial: 'J',
      searchKey: '焦作jiaozuoj',
    ),
    ElectricityCityProvider(
      city: '濮阳',
      provider: '国网河南省电力公司',
      initial: 'Z',
      searchKey: '濮阳puyangz',
    ),
    ElectricityCityProvider(
      city: '许昌',
      provider: '国网河南省电力公司',
      initial: 'X',
      searchKey: '许昌xuchangx',
    ),
    ElectricityCityProvider(
      city: '漯河',
      provider: '国网河南省电力公司',
      initial: 'Z',
      searchKey: '漯河leihez',
    ),
    ElectricityCityProvider(
      city: '三门峡',
      provider: '国网河南省电力公司',
      initial: 'S',
      searchKey: '三门峡sanmenxias',
    ),
    ElectricityCityProvider(
      city: '南阳',
      provider: '国网河南省电力公司',
      initial: 'N',
      searchKey: '南阳nanyangn',
    ),
    ElectricityCityProvider(
      city: '商丘',
      provider: '国网河南省电力公司',
      initial: 'S',
      searchKey: '商丘shangqius',
    ),
    ElectricityCityProvider(
      city: '信阳',
      provider: '国网河南省电力公司',
      initial: 'X',
      searchKey: '信阳xinyangx',
    ),
    ElectricityCityProvider(
      city: '周口',
      provider: '国网河南省电力公司',
      initial: 'Z',
      searchKey: '周口zhoukouz',
    ),
    ElectricityCityProvider(
      city: '驻马店',
      provider: '国网河南省电力公司',
      initial: 'Z',
      searchKey: '驻马店zhumadianz',
    ),
    ElectricityCityProvider(
      city: '武汉',
      provider: '国网湖北省电力公司',
      initial: 'W',
      searchKey: '武汉wuyiw',
    ),
    ElectricityCityProvider(
      city: '黄石',
      provider: '国网湖北省电力公司',
      initial: 'H',
      searchKey: '黄石huangshih',
    ),
    ElectricityCityProvider(
      city: '十堰',
      provider: '国网湖北省电力公司',
      initial: 'S',
      searchKey: '十堰shiyans',
    ),
    ElectricityCityProvider(
      city: '宜昌',
      provider: '国网湖北省电力公司',
      initial: 'Y',
      searchKey: '宜昌yichangy',
    ),
    ElectricityCityProvider(
      city: '襄阳',
      provider: '国网湖北省电力公司',
      initial: 'X',
      searchKey: '襄阳xiangyangx',
    ),
    ElectricityCityProvider(
      city: '鄂州',
      provider: '国网湖北省电力公司',
      initial: 'E',
      searchKey: '鄂州ezhoue',
    ),
    ElectricityCityProvider(
      city: '荆门',
      provider: '国网湖北省电力公司',
      initial: 'J',
      searchKey: '荆门jingmenj',
    ),
    ElectricityCityProvider(
      city: '孝感',
      provider: '国网湖北省电力公司',
      initial: 'X',
      searchKey: '孝感xiaoganx',
    ),
    ElectricityCityProvider(
      city: '荆州',
      provider: '国网湖北省电力公司',
      initial: 'J',
      searchKey: '荆州jingzhouj',
    ),
    ElectricityCityProvider(
      city: '咸宁',
      provider: '国网湖北省电力公司',
      initial: 'X',
      searchKey: '咸宁xianzhux',
    ),
    ElectricityCityProvider(
      city: '随州',
      provider: '国网湖北省电力公司',
      initial: 'S',
      searchKey: '随州suizhous',
    ),
    ElectricityCityProvider(
      city: '株洲',
      provider: '国网湖南省电力公司',
      initial: 'Z',
      searchKey: '株洲zhuzhouz',
    ),
    ElectricityCityProvider(
      city: '湘潭',
      provider: '国网湖南省电力公司',
      initial: 'X',
      searchKey: '湘潭xiangtanx',
    ),
    ElectricityCityProvider(
      city: '衡阳',
      provider: '国网湖南省电力公司',
      initial: 'H',
      searchKey: '衡阳hengyangh',
    ),
    ElectricityCityProvider(
      city: '邵阳',
      provider: '国网湖南省电力公司',
      initial: 'S',
      searchKey: '邵阳shaoyangs',
    ),
    ElectricityCityProvider(
      city: '岳阳',
      provider: '国网湖南省电力公司',
      initial: 'Y',
      searchKey: '岳阳yueyangy',
    ),
    ElectricityCityProvider(
      city: '常德',
      provider: '国网湖南省电力公司',
      initial: 'C',
      searchKey: '常德changdec',
    ),
    ElectricityCityProvider(
      city: '张家界',
      provider: '国网湖南省电力公司',
      initial: 'Z',
      searchKey: '张家界zhangjiajiez',
    ),
    ElectricityCityProvider(
      city: '益阳',
      provider: '国网湖南省电力公司',
      initial: 'Y',
      searchKey: '益阳yiyangy',
    ),
    ElectricityCityProvider(
      city: '怀化',
      provider: '国网湖南省电力公司',
      initial: 'H',
      searchKey: '怀化huaihuah',
    ),
    ElectricityCityProvider(
      city: '自贡',
      provider: '国网四川省电力公司',
      initial: 'Z',
      searchKey: '自贡zigongz',
    ),
    ElectricityCityProvider(
      city: '攀枝花',
      provider: '国网四川省电力公司',
      initial: 'P',
      searchKey: '攀枝花panzhihuap',
    ),
    ElectricityCityProvider(
      city: '德阳',
      provider: '国网四川省电力公司',
      initial: 'D',
      searchKey: '德阳deyangd',
    ),
    ElectricityCityProvider(
      city: '南充',
      provider: '国网四川省电力公司',
      initial: 'N',
      searchKey: '南充nanchongn',
    ),
    ElectricityCityProvider(
      city: '眉山',
      provider: '国网四川省电力公司',
      initial: 'M',
      searchKey: '眉山meishanm',
    ),
    ElectricityCityProvider(
      city: '雅安',
      provider: '国网四川省电力公司',
      initial: 'Y',
      searchKey: '雅安yaany',
    ),
    ElectricityCityProvider(
      city: '巴中',
      provider: '国网四川省电力公司',
      initial: 'B',
      searchKey: '巴中bazhongb',
    ),
    ElectricityCityProvider(
      city: '资阳',
      provider: '国网四川省电力公司',
      initial: 'Z',
      searchKey: '资阳ziyangz',
    ),
    ElectricityCityProvider(
      city: '保山',
      provider: '云南保山电力股份有限公司',
      initial: 'B',
      searchKey: '保山baoshanb',
    ),
    ElectricityCityProvider(
      city: '拉萨',
      provider: '国网西藏电力有限公司',
      initial: 'L',
      searchKey: '拉萨lasal',
    ),
    ElectricityCityProvider(
      city: '日喀则',
      provider: '国网西藏电力有限公司',
      initial: 'R',
      searchKey: '日喀则rikezer',
    ),
    ElectricityCityProvider(
      city: '昌都',
      provider: '国网西藏电力有限公司',
      initial: 'C',
      searchKey: '昌都changduc',
    ),
    ElectricityCityProvider(
      city: '林芝',
      provider: '国网西藏电力有限公司',
      initial: 'L',
      searchKey: '林芝linzhil',
    ),
    ElectricityCityProvider(
      city: '山南',
      provider: '国网西藏电力有限公司',
      initial: 'S',
      searchKey: '山南shannans',
    ),
    ElectricityCityProvider(
      city: '那曲',
      provider: '国网西藏电力有限公司',
      initial: 'N',
      searchKey: '那曲naqun',
    ),
    ElectricityCityProvider(
      city: '铜川',
      provider: '国网陕西省电力有限公司',
      initial: 'T',
      searchKey: '铜川tongchuant',
    ),
    ElectricityCityProvider(
      city: '宝鸡',
      provider: '国网陕西省电力有限公司',
      initial: 'B',
      searchKey: '宝鸡baojib',
    ),
    ElectricityCityProvider(
      city: '渭南',
      provider: '国网陕西省电力有限公司',
      initial: 'W',
      searchKey: '渭南weinanw',
    ),
    ElectricityCityProvider(
      city: '延安',
      provider: '国网陕西省电力有限公司',
      initial: 'Y',
      searchKey: '延安yanany',
    ),
    ElectricityCityProvider(
      city: '汉中',
      provider: '国网陕西省电力有限公司',
      initial: 'H',
      searchKey: '汉中yizhongh',
    ),
    ElectricityCityProvider(
      city: '榆林',
      provider: '国网陕西省电力有限公司',
      initial: 'Y',
      searchKey: '榆林yuliny',
    ),
    ElectricityCityProvider(
      city: '安康',
      provider: '国网陕西省电力有限公司',
      initial: 'A',
      searchKey: '安康ankanga',
    ),
    ElectricityCityProvider(
      city: '商洛',
      provider: '国网陕西省电力有限公司',
      initial: 'S',
      searchKey: '商洛shangluos',
    ),
    ElectricityCityProvider(
      city: '兰州',
      provider: '国网甘肃省电力公司',
      initial: 'L',
      searchKey: '兰州lanzhoul',
    ),
    ElectricityCityProvider(
      city: '嘉峪关',
      provider: '国网甘肃省电力公司',
      initial: 'J',
      searchKey: '嘉峪关jiayuguanj',
    ),
    ElectricityCityProvider(
      city: '金昌',
      provider: '国网甘肃省电力公司',
      initial: 'J',
      searchKey: '金昌jinchangj',
    ),
    ElectricityCityProvider(
      city: '白银',
      provider: '国网甘肃省电力公司',
      initial: 'B',
      searchKey: '白银baiyinb',
    ),
    ElectricityCityProvider(
      city: '天水',
      provider: '国网甘肃省电力公司',
      initial: 'T',
      searchKey: '天水tianshuit',
    ),
    ElectricityCityProvider(
      city: '武威',
      provider: '国网甘肃省电力公司',
      initial: 'W',
      searchKey: '武威wuweiw',
    ),
    ElectricityCityProvider(
      city: '张掖',
      provider: '国网甘肃省电力公司',
      initial: 'Z',
      searchKey: '张掖zhangyiz',
    ),
    ElectricityCityProvider(
      city: '平凉',
      provider: '国网甘肃省电力公司',
      initial: 'P',
      searchKey: '平凉pingliangp',
    ),
    ElectricityCityProvider(
      city: '酒泉',
      provider: '国网甘肃省电力公司',
      initial: 'J',
      searchKey: '酒泉jiuquanj',
    ),
    ElectricityCityProvider(
      city: '庆阳',
      provider: '国网甘肃省电力公司',
      initial: 'Q',
      searchKey: '庆阳qingyangq',
    ),
    ElectricityCityProvider(
      city: '定西',
      provider: '国网甘肃省电力公司',
      initial: 'D',
      searchKey: '定西dingxid',
    ),
    ElectricityCityProvider(
      city: '陇南',
      provider: '国网甘肃省电力公司',
      initial: 'L',
      searchKey: '陇南longnanl',
    ),
    ElectricityCityProvider(
      city: '西宁',
      provider: '国网青海省电力公司',
      initial: 'X',
      searchKey: '西宁xizhux',
    ),
    ElectricityCityProvider(
      city: '海东',
      provider: '国网青海省电力公司',
      initial: 'H',
      searchKey: '海东haidongh',
    ),
    ElectricityCityProvider(
      city: '银川',
      provider: '国网宁夏电力公司',
      initial: 'Y',
      searchKey: '银川yinchuany',
    ),
    ElectricityCityProvider(
      city: '石嘴山',
      provider: '国网宁夏电力公司',
      initial: 'S',
      searchKey: '石嘴山shizuishans',
    ),
    ElectricityCityProvider(
      city: '吴忠',
      provider: '国网宁夏电力公司',
      initial: 'W',
      searchKey: '吴忠wuzhongw',
    ),
    ElectricityCityProvider(
      city: '固原',
      provider: '国网宁夏电力公司',
      initial: 'G',
      searchKey: '固原guyuang',
    ),
    ElectricityCityProvider(
      city: '中卫',
      provider: '国网宁夏电力公司',
      initial: 'Z',
      searchKey: '中卫zhongweiz',
    ),
    ElectricityCityProvider(
      city: '乌鲁木齐',
      provider: '国网新疆电力公司',
      initial: 'W',
      searchKey: '乌鲁木齐wulumuqiw',
    ),
    ElectricityCityProvider(
      city: '克拉玛依',
      provider: '国网新疆电力公司',
      initial: 'K',
      searchKey: '克拉玛依kelamayik',
    ),
    ElectricityCityProvider(
      city: '吐鲁番',
      provider: '国网新疆电力公司',
      initial: 'T',
      searchKey: '吐鲁番tulufant',
    ),
    ElectricityCityProvider(
      city: '哈密',
      provider: '国网新疆电力公司',
      initial: 'H',
      searchKey: '哈密hamih',
    ),
    ElectricityCityProvider(
      city: '西安',
      provider: '国网陕西省电力有限公司',
      initial: 'X',
      searchKey: '西安xianx',
    ),
  ];

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

  static ElectricityCityProvider? byCity(String city) {
    final normalized = _normalizeCity(city);
    for (final item in all) {
      if (item.city == normalized) return item;
    }
    return null;
  }

  /// 城市选择页“你所在的地区”始终优先展示清单中的中文城市名。
  /// 部分 Android 机型即使请求中文逆地理编码，仍会返回 Beijing / Hangzhou
  /// 等英文 locality；这里基于清单自带的拼音检索词再兜底一次。
  static String locationLabel(LifePaymentLocationData? data) {
    if (data == null) return '选择城市';
    final matched = matchLocation(data);
    if (matched != null) return matched.city;

    final locality = data.locality?.trim() ?? '';
    if (locality.isNotEmpty) return _localizeKnownLocation(locality);
    final display = data.displayLabel.trim();
    return display.isEmpty ? '选择城市' : _localizeKnownLocation(display);
  }

  static ElectricityCityProvider? matchLocation(LifePaymentLocationData? data) {
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
      for (final item in all) {
        if (normalized.contains(item.city) || raw.contains(item.city)) {
          return item;
        }
      }

      // city.searchKey 已包含城市拼音，例：北京 -> beijingb。
      // 所以无需再维护另一份英文城市表，也能将 Beijing 转为 北京。
      final latinKey = _normalizeLatinLocation(raw);
      if (latinKey.length >= 3) {
        for (final item in all) {
          if (item.searchKey.toLowerCase().contains(latinKey)) {
            return item;
          }
        }
      }
    }
    return null;
  }

  static String _localizeKnownLocation(String raw) {
    final key = _normalizeLatinLocation(raw);
    const aliases = <String, String>{
      'phnompenh': '金边',
      'jinbian': '金边',
      'vealsbov': '金边',
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

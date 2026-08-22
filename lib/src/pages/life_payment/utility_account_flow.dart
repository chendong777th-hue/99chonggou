import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/pages/life_payment/life_payment_theme.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/pages/life_payment/life_payment_repository.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/wallet_repository.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/widgets/pay_method_sheet.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/widgets/pay_password_prompt.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/utils/dio_error_message.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:uuid/uuid.dart';

/// 水/燃气等 utility 缴费服务的差异配置；流程逻辑全部共享，
/// 与电费页（electricity_payment_page.dart）保持同一套绑定状态机。
class UtilityServiceSpec {
  const UtilityServiceSpec({
    required this.serviceType,
    required this.serviceLabel,
    required this.accountLabel,
    required this.prefsKey,
    required this.brandColor,
  });

  /// 后端 service_type：water / gas（对齐队列契约）。
  final String serviceType;

  /// 展示名：水费 / 燃气费。
  final String serviceLabel;

  /// 各类生活缴费统一采用「户号」叫法，避免同一页面出现不同术语。
  final String accountLabel;

  /// 本地绑定记录的 SharedPreferences key（按服务隔离）。
  final String prefsKey;

  final Color brandColor;
}

const UtilityServiceSpec kWaterServiceSpec = UtilityServiceSpec(
  serviceType: 'water',
  serviceLabel: '水费',
  accountLabel: '户号',
  prefsKey: 'life_payment_water_account_records',
  brandColor: Color(0xFF1E7BF2),
);

const UtilityServiceSpec kGasServiceSpec = UtilityServiceSpec(
  serviceType: 'gas',
  serviceLabel: '燃气费',
  accountLabel: '户号',
  prefsKey: 'life_payment_gas_account_records',
  // 与电费的户号卡片、底部主按钮、金额面板保持同一视觉体系；
  // 燃气仅替换业务文案，不额外引入橙色状态/边框样式。
  brandColor: Color(0xFF1E7BF2),
);

/// 缴费支付方式（99 币 / USDT），与电费页口径一致；
/// 余额展示由支付弹窗内实时拉取，这里只是入口占位。
const List<WalletPayMethodDto> kUtilityPayMethods = [
  WalletPayMethodDto(
    id: '99',
    coin: '99币',
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

/// 本地绑定的户号卡片记录（结构与电费页 _ElectricAccountRecord 一致，
/// 便于后续三个服务统一收敛到本文件）。
class UtilityAccountRecord {
  const UtilityAccountRecord({
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
    this.cityCode = '',
    this.providerCode = '',
  });

  final String cityName;
  final String providerName;
  final String accountNo;

  /// running / success / failed（本地展示状态，非后端字段）。
  final String status;
  final String statusText;
  final DateTime createdAt;
  final String userAddress;
  final String accountBalance;
  final String queryNo;
  final String receipt;
  final String queryStatus;
  final String pluginStatus;
  final String cityCode;
  final String providerCode;

  factory UtilityAccountRecord.fromJson(Map<String, Object?> json) {
    return UtilityAccountRecord(
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
      cityCode: json['city_code']?.toString() ?? '',
      providerCode: json['provider_code']?.toString() ?? '',
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
      'city_code': cityCode,
      'provider_code': providerCode,
    };
  }

  UtilityAccountRecord copyWith({
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
    String? cityCode,
    String? providerCode,
  }) {
    return UtilityAccountRecord(
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
      cityCode: cityCode ?? this.cityCode,
      providerCode: providerCode ?? this.providerCode,
    );
  }
}

/// 水/燃气缴费页共享的「绑定 → 查询轮询 → 确认金额 → 支付下单」流程。
///
/// 状态机与电费页完全一致：
/// running（查询中，插件真机执行约 1 分钟）→ success（已绑定，可点卡片缴费）
/// / failed（可刷新重试）；查询单过期时自动重新发起查询。
mixin UtilityAccountFlowMixin<T extends StatefulWidget> on State<T> {
  final LifePaymentRepository utilityRepo = LifePaymentRepository();
  final List<UtilityAccountRecord> accountRecords = [];

  bool utilitySubmitting = false;
  String utilityProgressText = '';
  String? refreshingAccountNo;
  String utilityPayMethodId = '99';

  /// 自动轮询：2 秒一次，最多 90 次（约 3 分钟），对齐电费页与 API 文档建议上限。
  static const int _queryPollMaxAttempts = 90;
  static const Duration _queryPollInterval = Duration(seconds: 2);

  /// 手动刷新：短轮询 15 次（约 30 秒）。
  static const int _queryRefreshExtraAttempts = 15;

  static const List<int> _amountPresets = [50, 100, 200, 300, 500];

  /// 下单后轮询订单：每 2 秒一次、最长 5 分钟（与客户端对接文档一致）。
  static const int _orderPollMaxAttempts = 150;
  static const Duration _orderPollInterval = Duration(seconds: 2);

  /// 页面需提供的服务配置与当前所选城市/单位。
  UtilityServiceSpec get utilitySpec;
  String get utilityCityName;
  String get utilityCityCode;
  String get utilityProviderName;
  String get utilityProviderCode;

  // ---------- 本地记录持久化 ----------

  Future<void> loadUtilityAccountRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(utilitySpec.prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final records = decoded
          .whereType<Map>()
          .map((item) => UtilityAccountRecord.fromJson(
                Map<String, Object?>.from(item),
              ))
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        accountRecords
          ..clear()
          ..addAll(records);
      });
      // 插件查询可能在 App 离开页面后才完成；仅保存 running 状态而不补拉，
      // 会让已在支付宝侧绑定成功的户号永远显示为「查询中」。
      // 页面恢复时按 query_no 同步一次真实结果，再把 success/地址/余额持久化。
      for (final record in records) {
        if (record.status == 'running' && record.queryNo.isNotEmpty) {
          unawaited(refreshUtilityQueryResult(record));
        }
      }
    } catch (_) {
      await prefs.remove(utilitySpec.prefsKey);
    }
  }

  Future<void> _saveAccountRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      utilitySpec.prefsKey,
      jsonEncode(accountRecords.map((item) => item.toJson()).toList()),
    );
  }

  void _upsertAccountRecord(UtilityAccountRecord record) {
    final index = accountRecords.indexWhere(
      (item) => item.accountNo == record.accountNo,
    );
    setState(() {
      if (index >= 0) {
        accountRecords[index] = record;
      } else {
        accountRecords.insert(0, record);
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
    String? cityCode,
    String? providerCode,
  }) {
    final index =
        accountRecords.indexWhere((item) => item.accountNo == accountNo);
    if (index < 0) return;
    final old = accountRecords[index];
    setState(() {
      accountRecords[index] = old.copyWith(
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
        cityCode: cityCode,
        providerCode: providerCode,
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
      cityCode: query.cityCode.isNotEmpty ? query.cityCode : null,
      providerCode: query.providerCode.isNotEmpty ? query.providerCode : null,
    );
  }

  // ---------- 查询轮询 ----------

  /// 轮询查询结果；单次网络抖动不终止轮询（对齐话费/电费页策略）。
  Future<UtilityQueryResult> _pollUtilityQuery(
    String queryNo, {
    int? maxAttempts,
    UtilityQueryResult? initial,
    String? mergeAccountNo,
  }) async {
    final limit = maxAttempts ?? _queryPollMaxAttempts;
    var query = initial ?? _runningQueryPlaceholder(queryNo);
    for (var i = 0; i < limit; i++) {
      if (!mounted) return query;
      try {
        query = await utilityRepo.getUtilityQuery(queryNo);
        if (mergeAccountNo != null && mergeAccountNo.isNotEmpty) {
          _mergeQueryIntoRecord(mergeAccountNo, query);
        }
      } catch (_) {
        // 单次请求失败不中断，下一轮继续拉
      }
      if (query.queryStatus == 'query_failed' ||
          query.queryStatus == 'expired' ||
          _isUtilityQuerySuccessful(query)) {
        return query;
      }
      if (mounted) {
        setState(() => utilityProgressText =
            '正在查询${utilitySpec.accountLabel}（${i + 1}/$limit）');
      }
      await Future<void>.delayed(_queryPollInterval);
    }
    return query;
  }

  UtilityQueryResult _runningQueryPlaceholder(String queryNo) {
    return UtilityQueryResult(
      queryNo: queryNo,
      serviceType: utilitySpec.serviceType,
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
    if (query.receipt.contains('查询成功') ||
        query.receipt.contains('query_success')) {
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

  // ---------- 错误文案 ----------

  String _friendlyRequestError(Object error) => DioErrorMessage.forApp(error);

  bool _isNetworkRequestError(Object error) =>
      DioErrorMessage.isNetworkRelated(error);

  /// 创建订单失败时优先透出后端返回的业务原因（400 的 message），
  /// 并附带 detail.field 指明具体非法字段；通用文案兜底。
  String _orderCreateErrorText(Object error) {
    if (error is DioError) {
      final data = error.response?.data;
      if (data is Map) {
        String pickMessage(Map map) {
          for (final key in const ['message', 'msg', 'error']) {
            final value = map[key]?.toString().trim() ?? '';
            if (value.isNotEmpty) return value;
          }
          return '';
        }

        String pickDetail(Map map) {
          final detail = map['detail'];
          if (detail is Map && detail.isNotEmpty) {
            final field = detail['field']?.toString().trim() ?? '';
            return field.isNotEmpty ? field : detail.toString();
          }
          if (detail != null && detail.toString().trim().isNotEmpty) {
            return detail.toString().trim();
          }
          return '';
        }

        var message = pickMessage(data);
        var detail = pickDetail(data);
        final inner = data['data'];
        if (inner is Map) {
          if (message.isEmpty) message = pickMessage(inner);
          if (detail.isEmpty) detail = pickDetail(inner);
        }
        if (message.isEmpty && data['code'] != null) {
          message = data['code'].toString().trim();
        }
        if (message.isNotEmpty) {
          return detail.isEmpty ? message : '$message（字段：$detail）';
        }
      }
    }
    return DioErrorMessage.forApp(error);
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

  // ---------- 绑定 / 刷新 / 重新查询 ----------

  Future<void> bindUtilityAccount(String accountNo) async {
    if (utilitySubmitting) return;
    final account = accountNo.trim();
    if (account.isEmpty) {
      ToastUtils.toast('请输入${utilitySpec.accountLabel}');
      return;
    }
    _upsertAccountRecord(UtilityAccountRecord(
      cityName: utilityCityName,
      providerName: utilityProviderName,
      accountNo: account,
      status: 'running',
      statusText: '首次绑定需要约 1 分钟，请稍候',
      createdAt: DateTime.now(),
      cityCode: utilityCityCode,
      providerCode: utilityProviderCode,
    ));
    setState(() {
      utilitySubmitting = true;
      utilityProgressText = '首次绑定约 1 分钟';
    });
    ToastUtils.toast('首次绑定需要约 1 分钟，请不要重复提交');
    try {
      var query = await utilityRepo.createUtilityQuery(
        serviceType: utilitySpec.serviceType,
        cityName: utilityCityName,
        cityCode: utilityCityCode,
        providerName: utilityProviderName,
        providerCode: utilityProviderCode,
        accountNo: account,
      );
      _updateAccountRecord(account, queryNo: query.queryNo);
      query = await _pollUtilityQuery(
        query.queryNo,
        initial: query,
        mergeAccountNo: account,
      );
      await _handleQueryOutcome(account, query);
    } catch (e) {
      _reportQueryRequestError(
        account,
        error: e,
        action: '${utilitySpec.serviceLabel}查询',
      );
    } finally {
      if (mounted) {
        setState(() {
          utilitySubmitting = false;
          utilityProgressText = '';
        });
      }
    }
  }

  Future<void> _handleQueryOutcome(
    String accountNo,
    UtilityQueryResult query,
  ) async {
    if (!mounted) return;
    _mergeQueryIntoRecord(accountNo, query);

    if (_isUtilityQuerySuccessful(query)) {
      _updateAccountRecord(accountNo, status: 'success', statusText: '');
      if (mounted) setState(() => utilityProgressText = '');
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
        : '${utilitySpec.accountLabel}查询失败：${query.queryStatus}';
    _updateAccountRecord(accountNo, status: 'failed', statusText: failText);
    ToastUtils.toast(failText);
  }

  Future<void> refreshUtilityQueryResult(UtilityAccountRecord record) async {
    if (record.queryNo.isEmpty) {
      ToastUtils.toast('没有查询单号，请重新绑定${utilitySpec.accountLabel}');
      return;
    }
    if (refreshingAccountNo == record.accountNo) return;

    setState(() => refreshingAccountNo = record.accountNo);
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
      );
      await _handleQueryOutcome(record.accountNo, query);
    } catch (e) {
      _reportQueryRequestError(record.accountNo, error: e, action: '刷新');
    } finally {
      if (mounted) setState(() => refreshingAccountNo = null);
    }
  }

  /// 查询单过期后重新发起一次户号查询，复用原卡片展示进度。
  Future<void> requeryUtilityRecord(UtilityAccountRecord record) async {
    if (refreshingAccountNo == record.accountNo) return;
    setState(() => refreshingAccountNo = record.accountNo);
    _updateAccountRecord(
      record.accountNo,
      status: 'running',
      statusText: '查询已过期，正在重新查询...',
    );
    try {
      var query = await utilityRepo.createUtilityQuery(
        serviceType: utilitySpec.serviceType,
        cityName:
            record.cityName.isNotEmpty ? record.cityName : utilityCityName,
        cityCode:
            record.cityCode.isNotEmpty ? record.cityCode : utilityCityCode,
        providerName: record.providerName.isNotEmpty
            ? record.providerName
            : utilityProviderName,
        providerCode: record.providerCode.isNotEmpty
            ? record.providerCode
            : utilityProviderCode,
        accountNo: record.accountNo,
      );
      _updateAccountRecord(record.accountNo, queryNo: query.queryNo);
      query = await _pollUtilityQuery(
        query.queryNo,
        initial: query,
        mergeAccountNo: record.accountNo,
      );
      await _handleQueryOutcome(record.accountNo, query);
      if (mounted && _isUtilityQuerySuccessful(query)) {
        ToastUtils.toast('已重新查询，请再次点击卡片缴费');
      }
    } catch (e) {
      _reportQueryRequestError(record.accountNo, error: e, action: '重新查询');
    } finally {
      if (mounted) setState(() => refreshingAccountNo = null);
    }
  }

  Future<void> confirmUnbindUtilityAccount(UtilityAccountRecord record) async {
    final confirmed = await AppDialog.confirm(
      title: '解除绑定',
      message: '确认解绑${utilitySpec.accountLabel} ${record.accountNo} 吗？',
      cancelText: '取消',
      confirmText: '确认',
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      accountRecords.removeWhere((item) => item.accountNo == record.accountNo);
    });
    unawaited(_saveAccountRecords());
  }

  // ---------- 缴费下单 ----------

  Future<void> onUtilityRecordTap(UtilityAccountRecord record) async {
    if (record.status != 'success') return;
    if (record.queryNo.isEmpty) {
      ToastUtils.toast('查询单号缺失，请重新绑定');
      return;
    }
    final amount = await _showUtilityAmountSheet(record);
    if (!mounted || amount == null || amount.trim().isEmpty) return;
    await _submitUtilityOrder(record, amount.trim());
  }

  Future<String?> _showUtilityAmountSheet(UtilityAccountRecord record) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: LifePaymentTheme.sheetBg(
          Theme.of(context).brightness == Brightness.dark),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: UtilityRechargeAmountSheet(
            spec: utilitySpec,
            record: record,
            amountPresets: _amountPresets,
          ),
        );
      },
    );
  }

  WalletPayMethodDto get _selectedPayMethod => kUtilityPayMethods.firstWhere(
        (item) => item.id == utilityPayMethodId,
        orElse: () => kUtilityPayMethods.first,
      );

  Future<WalletPayMethodDto?> _showPaymentMethodPicker() {
    return showModalBottomSheet<WalletPayMethodDto>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.38),
      builder: (_) => WalletPayMethodSheet(
        items: kUtilityPayMethods,
        sel: _selectedPayMethod,
      ),
    );
  }

  /// 订单失败时立刻请求撤销，服务端会把预扣平台余额释放为 refunded。
  /// 不尝试取消已到支付宝收银台的订单，避免和人工付款产生竞态。
  Future<void> _pollUtilityOrder(String orderNo) async {
    for (var i = 0; i < _orderPollMaxAttempts; i++) {
      await Future<void>.delayed(_orderPollInterval);
      if (!mounted) return;
      try {
        final order = await utilityRepo.getOrder(orderNo);
        final status = order.orderStatus.trim().toLowerCase();
        final pluginStatus = order.pluginStatus.trim().toLowerCase();

        if (status == 'success') {
          ToastUtils.toast('${utilitySpec.serviceLabel}缴费成功');
          return;
        }
        if (status == 'failed') {
          await _cancelFailedUtilityOrder(order);
          return;
        }
        if (status == 'cancelled' || order.platformPayStatus == 'refunded') {
          ToastUtils.toast('${utilitySpec.serviceLabel}订单已取消，余额已退回');
          return;
        }
        if (status == 'cashier_confirm' ||
            pluginStatus == 'cashier_confirm' ||
            pluginStatus == 'ready_to_pay') {
          ToastUtils.toast('已到支付宝付款确认页，请完成付款或稍后查看订单');
          return;
        }
      } catch (_) {
        // 瞬时网络失败不结束轮询；下一轮重新查询状态。
      }
    }
    if (mounted) {
      ToastUtils.toast('订单仍在处理中，可稍后在缴费记录中查看');
    }
  }

  Future<void> _cancelFailedUtilityOrder(LifePaymentOrderResult order) async {
    try {
      final cancelled = await utilityRepo.cancelOrder(
        orderNo: order.orderNo,
        reason: '插件执行失败，自动释放预扣余额',
      );
      if (!mounted) return;
      if (cancelled.platformPayStatus == 'refunded' ||
          cancelled.orderStatus == 'cancelled') {
        ToastUtils.toast('${utilitySpec.serviceLabel}失败，余额已退回');
      } else {
        ToastUtils.toast(
          cancelled.message.isNotEmpty
              ? cancelled.message
              : '${utilitySpec.serviceLabel}失败，请稍后查看退款状态',
        );
      }
    } catch (error) {
      if (!mounted) return;
      // 取消被服务端拒绝（如并发进入 cashier_confirm）时，不误导用户声称已退款。
      ToastUtils.toast('缴费失败，自动退款申请未完成：${_friendlyRequestError(error)}');
    }
  }

  Future<void> _submitUtilityOrder(
    UtilityAccountRecord record,
    String amount,
  ) async {
    final method = _selectedPayMethod;
    LifePaymentOrderResult? createdOrder;
    var queryExpired = false;
    final paid = await PayPasswordPrompt.show(
      context,
      title: '${utilitySpec.serviceLabel}缴费',
      amountText: amount,
      amountCoin: '元',
      payText: method.coin,
      payCoinCode: method.id,
      walletSubtitle: method.net,
      onChangePayMethod: () async {
        final selected = await _showPaymentMethodPicker();
        if (selected == null) return null;
        if (mounted) setState(() => utilityPayMethodId = selected.id);
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
          createdOrder = await utilityRepo.createUtilityOrder(
            // uuid 防撞单：毫秒时间戳在多设备/快速重试下存在撞 client_order_id 风险
            clientOrderId: '${utilitySpec.serviceType}-${const Uuid().v4()}',
            queryNo: record.queryNo,
            serviceType: utilitySpec.serviceType,
            cityName:
                record.cityName.isNotEmpty ? record.cityName : utilityCityName,
            cityCode:
                record.cityCode.isNotEmpty ? record.cityCode : utilityCityCode,
            providerName: record.providerName.isNotEmpty
                ? record.providerName
                : utilityProviderName,
            providerCode: record.providerCode.isNotEmpty
                ? record.providerCode
                : utilityProviderCode,
            accountNo: record.accountNo,
            confirmedUserAddress: record.userAddress,
            amount: amount,
            payMethod: utilityPayMethodId,
            payPassword: pwd,
          );
          return null;
        } catch (e) {
          final reason = _orderCreateErrorText(e);
          if (_looksLikeQueryExpired(reason)) {
            queryExpired = true;
            return '${utilitySpec.accountLabel}查询已过期，稍后将自动重新查询';
          }
          return '创建${utilitySpec.serviceLabel}订单失败：$reason';
        }
      },
    );
    if (!mounted) return;
    if (queryExpired) {
      unawaited(requeryUtilityRecord(record));
      return;
    }
    if (paid == true && createdOrder != null) {
      ToastUtils.toast(createdOrder!.message.isNotEmpty
          ? createdOrder!.message
          : '${utilitySpec.serviceLabel}订单已提交');
      unawaited(_pollUtilityOrder(createdOrder!.orderNo));
    }
  }
}

// ---------- 共享 UI：绑定记录列表 / 卡片 / 金额面板 ----------

class UtilityAccountRecordList extends StatelessWidget {
  const UtilityAccountRecordList({
    super.key,
    required this.spec,
    required this.records,
    required this.radius,
    required this.titleSize,
    required this.refreshingAccountNo,
    required this.onTap,
    required this.onUnbind,
    required this.onRefresh,
  });

  final UtilityServiceSpec spec;
  final List<UtilityAccountRecord> records;
  final double radius;
  final double titleSize;
  final String? refreshingAccountNo;
  final ValueChanged<UtilityAccountRecord> onTap;
  final ValueChanged<UtilityAccountRecord> onUnbind;
  final ValueChanged<UtilityAccountRecord> onRefresh;

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
            '我的${spec.serviceLabel}${spec.accountLabel}',
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
              '暂无绑定${spec.accountLabel}',
              style: TextStyle(
                color: LifePaymentTheme.formHint(dark),
                fontSize: titleSize * 0.52,
              ),
            )
          else
            ...records.map((item) => _UtilityAccountRecordTile(
                  spec: spec,
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

class _UtilityAccountRecordTile extends StatelessWidget {
  const _UtilityAccountRecordTile({
    required this.spec,
    required this.record,
    required this.radius,
    required this.titleSize,
    required this.refreshing,
    required this.onTap,
    required this.onUnbind,
    required this.onRefresh,
  });

  final UtilityServiceSpec spec;
  final UtilityAccountRecord record;
  final double radius;
  final double titleSize;
  final bool refreshing;
  final ValueChanged<UtilityAccountRecord> onTap;
  final ValueChanged<UtilityAccountRecord> onUnbind;
  final ValueChanged<UtilityAccountRecord> onRefresh;

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
            : spec.brandColor;
    final hintColor = LifePaymentTheme.subText(dark);
    return Container(
      margin: EdgeInsets.only(bottom: radius * 0.42),
      decoration: BoxDecoration(
        color: LifePaymentTheme.selectedSoft(dark),
        borderRadius: BorderRadius.circular(radius * 0.44),
        border: Border.all(
          color: bound ? spec.brandColor : LifePaymentTheme.hairline(dark),
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
                  _UtilityRecordInfoLine(
                    label: '缴费单位',
                    value: [
                      if (record.cityName.isNotEmpty) record.cityName,
                      if (record.providerName.isNotEmpty) record.providerName,
                    ].join(' · '),
                    titleSize: titleSize,
                  ),
                _UtilityRecordInfoLine(
                  label: spec.accountLabel,
                  value: record.accountNo,
                  titleSize: titleSize,
                ),
                if (record.userAddress.isNotEmpty)
                  _UtilityRecordInfoLine(
                    label: '住址',
                    value: record.userAddress,
                    titleSize: titleSize,
                  ),
                if (record.accountBalance.isNotEmpty)
                  _UtilityRecordInfoLine(
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
                        foregroundColor: spec.brandColor,
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

class _UtilityRecordInfoLine extends StatelessWidget {
  const _UtilityRecordInfoLine({
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
      color: const Color(0xFF8A9099),
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

class UtilityRechargeAmountSheet extends StatefulWidget {
  const UtilityRechargeAmountSheet({
    super.key,
    required this.spec,
    required this.record,
    required this.amountPresets,
  });

  final UtilityServiceSpec spec;
  final UtilityAccountRecord record;
  final List<int> amountPresets;

  @override
  State<UtilityRechargeAmountSheet> createState() =>
      _UtilityRechargeAmountSheetState();
}

class _UtilityRechargeAmountSheetState
    extends State<UtilityRechargeAmountSheet> {
  late final TextEditingController _amountController;
  int? _selectedPreset;

  @override
  void initState() {
    super.initState();
    _selectedPreset = widget.amountPresets.contains(50) ? 50 : null;
    _amountController = TextEditingController(
      text: _selectedPreset?.toString() ?? '',
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
    Navigator.of(context).pop(amount);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bodyText = LifePaymentTheme.text(dark);
    final subText = LifePaymentTheme.subText(dark);
    final brand = widget.spec.brandColor;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${widget.spec.serviceLabel}缴费',
            style: TextStyle(
              color: bodyText,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.spec.accountLabel} ${widget.record.accountNo}',
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
                _UtilityAmountTile(
                  label: '$amount元',
                  brandColor: brand,
                  selected: _selectedPreset == amount,
                  onTap: () => _pickPreset(amount),
                ),
            ],
          ),
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
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: brand,
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

class _UtilityAmountTile extends StatelessWidget {
  const _UtilityAmountTile({
    required this.label,
    required this.brandColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color brandColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
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
                  ? brandColor
                  : LifePaymentTheme.amountTileBorder(dark),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? brandColor : const Color(0xFF595959),
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

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/ui/utils/adaptive_modal.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_chat_i18n_tool/language_json/strings.g.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_demo/src/api/wallet_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/wallet_time.dart';
import 'package:tencent_cloud_chat_demo/src/services/red_packet_sender_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_display_name.dart';

import '../red_packet/red_packet_flow_launcher.dart';
import '../transfer_detail_screen.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_empty_state.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/widgets/platform_coin_icon.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/widgets/wallet_page_colors.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';

import 'wallet_record_controller.dart';
import 'wallet_record_detail_screen.dart';
import 'wallet_record_models.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';


String walletRecordNormalizeCoin(String coin) {
  final raw = coin.trim();
  if (raw.isEmpty) return raw;
  if (raw == '元' || raw.toUpperCase() == '99') return '99';
  return raw.toUpperCase();
}

DateTime? _parseWalletRecordTime(String raw) => parseWalletApiTimeToLocal(raw);

enum _HistoryDatePreset { all, week, month, threeMonths, year }

DateTimeRange _historyRangeForPreset(_HistoryDatePreset preset) {
  final now = DateTime.now();
  final end = DateTime(now.year, now.month, now.day);
  final DateTime start;
  switch (preset) {
    case _HistoryDatePreset.all:
      start = DateTime(2000, 1, 1);
      break;
    case _HistoryDatePreset.week:
      start = end.subtract(const Duration(days: 6));
      break;
    case _HistoryDatePreset.month:
      start = DateTime(end.year, end.month - 1, end.day);
      break;
    case _HistoryDatePreset.threeMonths:
      start = DateTime(end.year, end.month - 3, end.day);
      break;
    case _HistoryDatePreset.year:
      start = DateTime(end.year - 1, end.month, end.day);
      break;
  }
  return DateTimeRange(start: start, end: end);
}

String _historyDatePresetLabel(_HistoryDatePreset preset) {
  switch (preset) {
    case _HistoryDatePreset.all:
      return AppI18n.current.t(
        zhHans: '全部',
        zhHant: '全部',
        en: 'All',
        ja: 'すべて',
        ko: '전체',
      );
    case _HistoryDatePreset.week:
      return AppI18n.current.t(
        zhHans: '一周',
        zhHant: '一週',
        en: '1 Week',
        ja: '1週間',
        ko: '1주',
      );
    case _HistoryDatePreset.month:
      return AppI18n.current.t(
        zhHans: '一月',
        zhHant: '一月',
        en: '1 Month',
        ja: '1ヶ月',
        ko: '1개월',
      );
    case _HistoryDatePreset.threeMonths:
      return AppI18n.current.t(
        zhHans: '三月',
        zhHant: '三月',
        en: '3 Months',
        ja: '3ヶ月',
        ko: '3개월',
      );
    case _HistoryDatePreset.year:
      return AppI18n.current.t(
        zhHans: '一年',
        zhHant: '一年',
        en: '1 Year',
        ja: '1年',
        ko: '1년',
      );
  }
}

class WalletRecordScreen extends StatefulWidget {
  /// 进入页面时预选币种（如 `USDT`、`99`）；为空则默认「全部币种」。
  final String? initialCoin;

  const WalletRecordScreen({
    super.key,
    this.initialCoin,
  });

  @override
  State<WalletRecordScreen> createState() => _WalletRecordScreenState();
}

class _WalletRecordScreenState extends State<WalletRecordScreen> {
  late final WalletRecordController ctl;
  late String _selectedCoin;
  late _HistoryDatePreset _selectedPreset;
  late DateTimeRange _selectedRange;
  final Map<String, String> _userNameMap = <String, String>{};
  final Set<String> _requestedUserIds = <String>{};
  final Map<String, String> _redPacketSenderNameMap = <String, String>{};
  final Map<String, String> _redPacketSenderAvatarMap = <String, String>{};
  final Set<String> _requestedRedPacketIds = <String>{};

  String _allCoinsLabel() => AppI18n.current.t(
        zhHans: '全部币种',
        zhHant: '全部幣種',
        en: 'All Tokens',
        ja: 'すべての通貨',
        ko: '전체 코인',
      );

  @override
  void initState() {
    super.initState();
    _selectedCoin = _allCoinsLabel();
    _selectedPreset = _HistoryDatePreset.week;
    _selectedRange = _historyRangeForPreset(_selectedPreset);
    final initial = widget.initialCoin?.trim();
    if (initial != null && initial.isNotEmpty && initial != _allCoinsLabel()) {
      _selectedCoin = walletRecordNormalizeCoin(initial);
    }
    ctl = WalletRecordController()..load();
    RedPacketSenderRefreshBus.instance.revision
        .addListener(_onRedPacketSenderRefresh);
  }

  @override
  void dispose() {
    RedPacketSenderRefreshBus.instance.revision
        .removeListener(_onRedPacketSenderRefresh);
    ctl.dispose();
    super.dispose();
  }

  void _onRedPacketSenderRefresh() {
    if (!mounted) return;
    ctl.load();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final cs = WalletPageColors.of(context);
    final appBar = WalletAppBarColors.of(context);

    return AnimatedBuilder(
      animation: ctl,
      builder: (_, __) {
        return wrapWalletPage(
          context,
          Scaffold(
            backgroundColor: cs.bg,
            appBar: AppBar(
              centerTitle: true,
              elevation: 0,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              backgroundColor: appBar.background,
              foregroundColor: appBar.title,
              systemOverlayStyle: walletPageOverlayStyle(context),
              leadingWidth: 54,
              title: Text(
                i18n.t(
                  zhHans: '历史',
                  zhHant: '歷史',
                  en: 'History',
                  ja: '履歴',
                  ko: '기록',
                ),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: appBar.title,
                ),
              ),
              actions: [
                IconButton(
                  onPressed: _pickFilter,
                  icon: Icon(
                    Icons.tune_rounded,
                    color: appBar.icon,
                    size: 24,
                  ),
                ),
                SizedBox(width: 10.w),
              ],
            ),
            body: SafeArea(
              top: false,
              bottom: false,
              child: _buildBody(cs),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickFilter() async {
    final selected = await showAdaptiveModalSheet<HistoryRecordFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HistoryFilterSheet(selected: ctl.filter),
    );
    if (!mounted || selected == null) return;
    ctl.setFilter(selected);
    final options = _coinOptions;
    if (_selectedCoin != _allCoinsLabel() && !options.contains(_selectedCoin)) {
      setState(() {
        _selectedCoin = _allCoinsLabel();
      });
    }
  }

  String _normalizeCoinText(String coin) => walletRecordNormalizeCoin(coin);

  List<String> get _coinOptions {
    final out = <String>{_allCoinsLabel()};
    for (final item in ctl.list) {
      final coin = _normalizeCoinText(item.coin);
      if (coin.isNotEmpty) out.add(coin);
    }
    return out.toList();
  }

  List<WalletRecordDto> get _filteredList {
    return ctl.list.where((item) {
      final coinMatch = _selectedCoin == _allCoinsLabel() ||
          _normalizeCoinText(item.coin) == _selectedCoin;
      if (!coinMatch) return false;
      final time = _parseWalletRecordTime(item.time);
      if (time == null) return false;
      final day = DateTime(time.year, time.month, time.day);
      return !day.isBefore(_selectedRange.start) &&
          !day.isAfter(_selectedRange.end);
    }).toList();
  }

  Future<void> _pickCoin() async {
    final selected = await showAdaptiveModalSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CoinPickerSheet(
        options: _coinOptions,
        selectedCoin: _selectedCoin,
        allCoinsLabel: _coinOptions.first,
      ),
    );
    if (!mounted || selected == null || selected == _selectedCoin) return;
    setState(() {
      _selectedCoin = selected;
    });
  }

  Future<void> _pickDatePreset() async {
    final i18n = AppI18n.of(context);
    final selected = await AppDialog.actionSheet<_HistoryDatePreset>(
      title: i18n.t(
        zhHans: '选择时间范围',
        zhHant: '選擇時間範圍',
        en: 'Select Date Range',
        ja: '期間を選択',
        ko: '기간 선택',
      ),
      cancelText: i18n.t(
        zhHans: '取消',
        zhHant: '取消',
        en: 'Cancel',
        ja: 'キャンセル',
        ko: '취소',
      ),
      actions: [
        for (final preset in _HistoryDatePreset.values)
          AppActionSheetItem(
            text: _historyDatePresetLabel(preset),
            value: preset,
          ),
      ],
    );
    if (!mounted || selected == null || selected == _selectedPreset) return;
    setState(() {
      _selectedPreset = selected;
      _selectedRange = _historyRangeForPreset(selected);
    });
  }

  Widget _buildBody(WalletPageColors cs) {
    if (ctl.loading) {
      return Center(
        child: CircularProgressIndicator(color: cs.blue),
      );
    }
    if (ctl.err.isNotEmpty) {
      return _ErrorBox(text: ctl.err, onRetry: ctl.load);
    }
    final list = _filteredList;
    if (list.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _ensureUserNames(list);
          _ensureRedPacketSenderNames(list);
        }
      });
    }
    final body = list.isEmpty
        ? AppEmptyState(
            message: AppI18n.of(context).t(
              zhHans: '暂无记录',
              zhHant: '暫無記錄',
              en: 'No records',
              ja: '記録はありません',
              ko: '기록이 없습니다',
            ),
          )
        : ListView(
            padding: EdgeInsets.fromLTRB(24.w, 18.h, 24.w, 54.h),
            children: _buildGroupedChildren(list),
          );
    return Column(
      children: [
        _HistoryExtraFilterBar(
          coinText: _selectedCoin,
          dateRangeText: _dateRangeText,
          onCoinTap: _pickCoin,
          onDateTap: _pickDatePreset,
        ),
        Expanded(child: body),
      ],
    );
  }

  String get _dateRangeText => _historyDatePresetLabel(_selectedPreset);

  String _displayUserName(String userId) {
    final id = userId.trim();
    if (id.isEmpty) return '--';
    final name = _userNameMap[id]?.trim() ?? '';
    if (name.isNotEmpty && name != id) {
      return name;
    }
    final fromStore = FriendDisplayName.resolveC2C(userId: id).trim();
    if (fromStore.isNotEmpty && fromStore != id) {
      return fromStore;
    }
    return name.isNotEmpty ? name : id;
  }

  String _displayRedPacketSenderName(WalletRecordDto item) {
    final payer = item.payer.trim();
    if (payer.isNotEmpty) return _displayUserName(payer);
    final orderId =
        item.serverOrderId.isNotEmpty ? item.serverOrderId : item.orderNo;
    final name = _redPacketSenderNameMap[orderId]?.trim() ?? '';
    return name.isNotEmpty ? name : '--';
  }

  Future<void> _ensureUserNames(List<WalletRecordDto> items) async {
    final ids = <String>{};
    for (final item in items) {
      if (item.isInternalReceive ||
          item.isInternalTransfer ||
          item.isRedPacketReceive ||
          item.isGroupTransfer) {
        final payer = item.payer.trim();
        if (payer.isNotEmpty) ids.add(payer);
      }
      if (item.isInternalTransfer ||
          item.isInternalReceive ||
          item.isGroupTransfer) {
        final payee = item.payee.trim();
        if (payee.isNotEmpty) ids.add(payee);
      }
    }
    final needLoad = ids.where((e) => !_requestedUserIds.contains(e)).toList();
    if (needLoad.isEmpty) return;
    _requestedUserIds.addAll(needLoad);
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getUsersInfo(
        userIDList: needLoad,
      );
      final users = result.data ?? <V2TimUserFullInfo>[];
      if (!mounted) return;
      setState(() {
        for (final user in users) {
          final id = user.userID?.trim() ?? '';
          if (id.isEmpty) continue;
          final nick = user.nickName?.trim() ?? '';
          if (nick.isNotEmpty) {
            _userNameMap[id] = nick;
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _ensureRedPacketSenderNames(List<WalletRecordDto> items) async {
    final orderIds = <String>{};
    for (final item in items) {
      if (!item.isRedPacketReceive || item.payer.trim().isNotEmpty) continue;
      final orderId =
          item.serverOrderId.isNotEmpty ? item.serverOrderId : item.orderNo;
      if (orderId.isNotEmpty) orderIds.add(orderId);
    }
    final needLoad =
        orderIds.where((e) => !_requestedRedPacketIds.contains(e)).toList();
    if (needLoad.isEmpty) return;
    _requestedRedPacketIds.addAll(needLoad);
    final senderNames = <String, String>{};
    final senderAvatars = <String, String>{};
    final userNames = <String, String>{};
    for (final orderId in needLoad) {
      try {
        final order = await WalletApi.instance.getRedPacketOrder(orderId);
        final data = Map<String, dynamic>.from(order.data);
        final senderUserId = data['senderUserId']?.toString().trim() ?? '';
        final senderNick = data['senderNick']?.toString().trim() ?? '';
        final senderName = senderNick.isNotEmpty
            ? senderNick
            : (senderUserId.isNotEmpty ? senderUserId : '');
        if (senderName.isNotEmpty) {
          senderNames[orderId] = senderName;
        }
        final senderAvatar = _firstNonEmptyText([
          data['senderAvatar'],
          data['senderAvatarUrl'],
          data['senderFaceUrl'],
          data['avatarUrl'],
          data['faceUrl'],
        ]);
        if (senderAvatar.isNotEmpty) {
          senderAvatars[orderId] = senderAvatar;
        }
        if (senderUserId.isNotEmpty && senderNick.isNotEmpty) {
          userNames[senderUserId] = senderNick;
        }
      } catch (_) {}
    }
    if (!mounted ||
        (senderNames.isEmpty && senderAvatars.isEmpty && userNames.isEmpty)) {
      return;
    }
    setState(() {
      _redPacketSenderNameMap.addAll(senderNames);
      _redPacketSenderAvatarMap.addAll(senderAvatars);
      _userNameMap.addAll(userNames);
    });
  }

  String _formatTransferDetailTime(WalletRecordDto item) {
    final rawCreated = item.createdAt.trim();
    final raw = rawCreated.isNotEmpty ? rawCreated : item.time.trim();
    final parsed = _parseWalletRecordTime(raw);
    if (parsed == null) {
      return raw.isEmpty ? '--' : raw;
    }
    final locale = LocaleSettings.currentLocale;
    final tag = locale.languageTag;
    final lang = tag.startsWith('zh')
        ? 'zh_CN'
        : locale == AppLocale.ja
            ? 'ja'
            : locale == AppLocale.ko
                ? 'ko'
                : 'en';
    final pattern = tag.startsWith('en')
        ? 'yyyy-MM-dd HH:mm'
        : locale == AppLocale.ja
            ? 'yyyy/MM/dd HH:mm'
            : locale == AppLocale.ko
                ? 'yyyy.MM.dd HH:mm'
                : 'yyyy-MM-dd HH:mm';
    return DateFormat(pattern, lang).format(parsed);
  }

  void _openRecordDetail(WalletRecordDto item) {
    // 群转账底座虽是红包表，详情走转账页，不进红包详情、不展示祝福语。
    if (item.isGroupTransfer) {
      final timeText = _formatTransferDetailTime(item);
      Navigator.of(context).push(
        AppMaterialPageRoute(
          builder: (_) => TransferDetailScreen(
            isOutgoing: item.isRedPacketSend,
            isGroupTransfer: true,
            amount: item.amount,
            coin: item.coin,
            currency: item.coin,
            memo: null,
            senderName: item.isRedPacketReceive
                ? _displayRedPacketSenderName(item)
                : _displayUserName(item.payer),
            receiverName: _displayUserName(item.payee),
            senderUserId: item.payer,
            receiverUserId: item.payee,
            transferTime: timeText,
            receiveTime: timeText,
          ),
        ),
      );
      return;
    }
    if (item.isRedPacketSend || item.isRedPacketReceive) {
      final orderId =
          item.serverOrderId.isNotEmpty ? item.serverOrderId : item.orderNo;
      if (orderId.isNotEmpty) {
        Navigator.of(context).push(
          AppMaterialPageRoute(
            builder: (_) => RedPacketFlowLauncher.buildOverlayPage(
              orderId: orderId,
              packetType: item.rpType.trim(),
              senderName: item.isRedPacketReceive
                  ? _displayRedPacketSenderName(item)
                  : _displayUserName(item.payer),
              senderAvatar: _redPacketSenderAvatarMap[orderId]?.trim() ?? '',
              greeting: item.memo.trim().isNotEmpty
                  ? item.memo.trim()
                  : item.rpMsg.trim(),
              autoClaim: false,
              showOpenAnimation: false,
            ),
          ),
        );
        return;
      }
    }
    if (item.isInternalTransfer || item.isInternalReceive) {
      final timeText = _formatTransferDetailTime(item);
      final memo = item.memo.trim();
      Navigator.of(context).push(
        AppMaterialPageRoute(
          builder: (_) => TransferDetailScreen(
            isOutgoing: item.isInternalTransfer,
            amount: item.amount,
            coin: item.coin,
            currency: item.coin,
            memo: memo.isNotEmpty ? memo : null,
            senderName: _displayUserName(item.payer),
            receiverName: _displayUserName(item.payee),
            senderUserId: item.payer,
            receiverUserId: item.payee,
            transferTime: timeText,
            receiveTime: timeText,
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      AppMaterialPageRoute(
        builder: (_) => WalletRecordDetailScreen(item: item),
      ),
    );
  }

  String _firstNonEmptyText(List<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != 'null') {
        return text;
      }
    }
    return '';
  }

  List<Widget> _buildGroupedChildren(List<WalletRecordDto> list) {
    final cs = WalletPageColors.of(context);
    final children = <Widget>[];
    String? currentKey;
    for (final item in list) {
      final time = _parseWalletRecordTime(item.time);
      final key = time == null
          ? AppI18n.current.t(
              zhHans: '未知日期',
              zhHant: '未知日期',
              en: 'Unknown Date',
              ja: '日付不明',
              ko: '알 수 없는 날짜',
            )
          : '${time.year}-${time.month}-${time.day}';
      if (currentKey != key) {
        currentKey = key;
        children.add(
          Padding(
            padding: EdgeInsets.fromLTRB(
              6.w,
              children.isEmpty ? 0 : 24.h,
              6.w,
              15.h,
            ),
            child: Text(
              time == null
                  ? AppI18n.of(context).t(
                      zhHans: '未知日期',
                      zhHant: '未知日期',
                      en: 'Unknown Date',
                      ja: '日付不明',
                      ko: '알 수 없는 날짜',
                    )
                  : DateFormat(
                      LocaleSettings.currentLocale.languageTag.startsWith('en')
                          ? 'MMM dd'
                          : LocaleSettings.currentLocale == AppLocale.ja
                              ? 'MM/dd'
                              : LocaleSettings.currentLocale == AppLocale.ko
                                  ? 'MM.dd'
                                  : 'MM月dd日',
                      LocaleSettings.currentLocale.languageTag.startsWith('zh')
                          ? 'zh_CN'
                          : LocaleSettings.currentLocale == AppLocale.ja
                              ? 'ja'
                              : LocaleSettings.currentLocale == AppLocale.ko
                                  ? 'ko'
                                  : 'en',
                    ).format(time),
              style: TextStyle(
                fontSize: 25.5.sp,
                fontWeight: FontWeight.w700,
                color: cs.subText,
              ),
            ),
          ),
        );
      }
      children.add(
        Padding(
          padding: EdgeInsets.only(bottom: 18.h),
          child: _RecordCard(
            item: item,
            onTap: () => _openRecordDetail(item),
            resolveUserName: _displayUserName,
            resolveRedPacketSenderName: _displayRedPacketSenderName,
          ),
        ),
      );
    }
    return children;
  }
}

class _RecordCard extends StatelessWidget {
  final WalletRecordDto item;
  final VoidCallback onTap;
  final String Function(String userId) resolveUserName;
  final String Function(WalletRecordDto item) resolveRedPacketSenderName;

  const _RecordCard({
    required this.item,
    required this.onTap,
    required this.resolveUserName,
    required this.resolveRedPacketSenderName,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final cs = WalletPageColors.of(context);
    final amtColor = _amountColor(cs);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.rCard.r),
      child: Container(
        padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 24.h),
        decoration: BoxDecoration(
          color: cs.card,
          borderRadius: BorderRadius.circular(AppTokens.rCard.r),
          border: Border.all(color: cs.line, width: 0.5),
        ),
        child: Row(
          children: [
            _CoinIcon(item: item),
            SizedBox(width: 21.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _displayTitle(i18n),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 27.sp,
                            color: cs.text,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                        ),
                      ),
                      if (_tagText != null) ...[
                        SizedBox(width: 12.w),
                        _HistoryTag(text: _tagText!),
                      ],
                    ],
                  ),
                  SizedBox(height: 9.h),
                  Text(
                    _subLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 21.sp,
                      color: cs.subText,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 18.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _amountText,
                      style: TextStyle(
                        fontSize: 27.sp,
                        color: amtColor,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    if (_showPlatformCoinLogo) ...[
                      SizedBox(width: 8.w),
                      PlatformCoinIcon(size: 27.w, imageScale: 1.28),
                    ],
                  ],
                ),
                SizedBox(height: 9.h),
                Text(
                  _statusText,
                  style: TextStyle(
                    fontSize: 21.sp,
                    color: _statusColor(cs),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _displayTime {
    final parsed = _parseWalletRecordTime(item.time);
    if (parsed == null) {
      final raw = item.time.trim();
      return raw.isEmpty ? '--' : raw;
    }
    final locale = LocaleSettings.currentLocale;
    final tag = locale.languageTag;
    final lang = tag.startsWith('zh')
        ? 'zh_CN'
        : locale == AppLocale.ja
            ? 'ja'
            : locale == AppLocale.ko
                ? 'ko'
                : 'en';
    final pattern = tag.startsWith('en')
        ? 'yyyy-MM-dd HH:mm'
        : locale == AppLocale.ja
            ? 'yyyy/MM/dd HH:mm'
            : locale == AppLocale.ko
                ? 'yyyy.MM.dd HH:mm'
                : 'yyyy-MM-dd HH:mm';
    return DateFormat(pattern, lang).format(parsed);
  }

  String get _subLine {
    final i18n = AppI18n.current;
    if (item.isInternalReceive) {
      return _userActionText(
        prefix: i18n.t(
          zhHans: '来自',
          zhHant: '來自',
          en: 'From ',
          ja: '',
          ko: '',
        ),
        userId: item.payer,
        suffix: i18n.t(
          zhHans: '的转账',
          zhHant: '的轉帳',
          en: '\'s transfer',
          ja: ' からの送金',
          ko: '님의 송금',
        ),
      );
    }
    if (item.isInternalTransfer) {
      return _userActionText(
        prefix: i18n.t(
          zhHans: '发给',
          zhHant: '發給',
          en: 'Sent to ',
          ja: '',
          ko: '',
        ),
        userId: item.payee,
        suffix: i18n.t(
          zhHans: '的转账',
          zhHant: '的轉帳',
          en: '',
          ja: ' への送金',
          ko: '님에게 송금',
        ),
      );
    }
    // 群转账不展示祝福语，改为收款人/发起人摘要。
    if (item.isGroupTransfer) {
      if (item.isRedPacketReceive) {
        return _userActionText(
          prefix: i18n.t(
            zhHans: '来自',
            zhHant: '來自',
            en: 'From ',
            ja: '',
            ko: '',
          ),
          userId: item.payer,
          suffix: i18n.t(
            zhHans: '的群转账',
            zhHant: '的群轉帳',
            en: '\'s group transfer',
            ja: ' からのグループ送金',
            ko: '님의 그룹 이체',
          ),
        );
      }
      return _userActionText(
        prefix: i18n.t(
          zhHans: '转账给',
          zhHant: '轉帳給',
          en: 'To ',
          ja: '',
          ko: '',
        ),
        userId: item.payee,
        suffix: '',
      );
    }
    if (item.isRedPacketReceive) {
      final name = resolveRedPacketSenderName(item).trim();
      if (name.isEmpty || name == '--') return '--';
      return i18n.format(
        zhHans: '来自{name}的红包',
        zhHant: '來自{name}的紅包',
        en: 'Red packet from {name}',
        ja: '{name} からの紅包',
        ko: '{name}님의 레드패킷',
        vars: {'name': _shortText(name)},
      );
    }
    String label;
    String value;
    if (item.isChainDeposit) {
      label = i18n.t(
        zhHans: '发起方',
        zhHant: '發起方',
        en: 'Sender',
        ja: '送信元',
        ko: '보낸 사람',
      );
      value = item.payer;
    } else if (item.isChainWithdraw) {
      label = i18n.t(
        zhHans: '收款地址',
        zhHant: '收款地址',
        en: 'Receiving Address',
        ja: '受取アドレス',
        ko: '수령 주소',
      );
      value = item.addr.isNotEmpty ? item.addr : item.payee;
    } else if (item.isInternalReceive) {
      label = i18n.t(
        zhHans: '发起方',
        zhHant: '發起方',
        en: 'Sender',
        ja: '送信元',
        ko: '보낸 사람',
      );
      value = item.payer;
    } else if (item.isInternalTransfer) {
      label = i18n.t(
        zhHans: '收款方',
        zhHant: '收款方',
        en: 'Recipient',
        ja: '受取人',
        ko: '받는 사람',
      );
      value = item.payee;
    } else if (item.isRedPacketSend) {
      // 群转账不应走到这里（上方已拦截）；普通发红包才显示祝福语。
      label = i18n.t(
        zhHans: '祝福语',
        zhHant: '祝福語',
        en: 'Message',
        ja: 'メッセージ',
        ko: '메시지',
      );
      value = item.memo;
    } else if (item.isRedPacketReceive) {
      label = i18n.t(
        zhHans: '发起方',
        zhHant: '發起方',
        en: 'Sender',
        ja: '送信元',
        ko: '보낸 사람',
      );
      value = item.payer;
    } else if (item.isRedPacketRefund) {
      label = i18n.t(
        zhHans: '退款说明',
        zhHant: '退款說明',
        en: 'Refund Note',
        ja: '返金説明',
        ko: '환불 안내',
      );
      value = item.memo;
    } else {
      label = i18n.t(
        zhHans: '时间',
        zhHant: '時間',
        en: 'Time',
        ja: '時間',
        ko: '시간',
      );
      value = _displayTime;
    }
    final text = value.trim().isEmpty ? '--' : _shortText(value.trim());
    return '$label $text';
  }

  String get _statusText {
    if (item.isRedPacketSend && item.status == WalletRecordStatus.pending) {
      return AppI18n.current.t(
        zhHans: '领取中',
        zhHant: '領取中',
        en: 'Claiming',
        ja: '受取中',
        ko: '수령 중',
      );
    }
    return item.status.txt;
  }

  String _userActionText({
    required String prefix,
    required String userId,
    required String suffix,
  }) {
    final name = resolveUserName(userId).trim();
    if (name.isEmpty || name == '--') return '--';
    return '$prefix${_shortText(name)}$suffix';
  }

  String? get _tagText {
    final net = item.network.trim();
    if (net.isNotEmpty &&
        net != '--' &&
        net != 'TRC20' &&
        net != '平台' &&
        net != '平台内' &&
        net != '平台内红包') {
      return net;
    }
    if (item.isRedPacketRefund) {
      return AppI18n.current.t(
        zhHans: '退款',
        zhHant: '退款',
        en: 'Refund',
        ja: '返金',
        ko: '환불',
      );
    }
    return null;
  }

  String _displayTitle(AppI18n i18n) {
    if (item.isChainDeposit) {
      return i18n.t(
        zhHans: '链上充值',
        zhHant: '鏈上充值',
        en: 'On-chain Deposit',
        ja: 'オンチェーン入金',
        ko: '온체인 입금',
      );
    }
    if (item.isChainWithdraw) {
      return i18n.t(
        zhHans: '提现',
        zhHant: '提現',
        en: 'Withdrawal',
        ja: '出金',
        ko: '출금',
      );
    }
    if (item.isInternalTransfer) {
      return i18n.t(
        zhHans: '发起转账',
        zhHant: '發起轉帳',
        en: 'Transfer Sent',
        ja: '送金',
        ko: '보낸 송금',
      );
    }
    if (item.isInternalReceive) {
      return i18n.t(
        zhHans: '收到转账',
        zhHant: '收到轉帳',
        en: 'Transfer Received',
        ja: '受け取った送金',
        ko: '받은 송금',
      );
    }
    if (item.isRedPacketReceive) {
      if (item.rpType.trim().toUpperCase() == 'GROUP_TRANSFER') {
        return i18n.t(
          zhHans: '群转账',
          zhHant: '群轉帳',
          en: 'Group Transfer',
          ja: 'グループ送金',
          ko: '그룹 이체',
        );
      }
      return i18n.t(
        zhHans: '领取红包',
        zhHant: '領取紅包',
        en: 'Red Packet Claimed',
        ja: '紅包を受け取り',
        ko: '레드패킷 수령',
      );
    }
    if (item.isRedPacketRefund) {
      return i18n.t(
        zhHans: '红包退回',
        zhHant: '紅包退回',
        en: 'Red Packet Refunded',
        ja: '紅包返金',
        ko: '레드패킷 환불',
      );
    }
    if (item.isRedPacketSend) {
      if (item.rpType.trim().toUpperCase() == 'GROUP_TRANSFER') {
        return i18n.t(
          zhHans: '群转账',
          zhHant: '群轉帳',
          en: 'Group Transfer',
          ja: 'グループ送金',
          ko: '그룹 이체',
        );
      }
      return i18n.t(
        zhHans: '发红包',
        zhHant: '發紅包',
        en: 'Red Packet Sent',
        ja: '紅包を送信',
        ko: '레드패킷 발송',
      );
    }
    if (item.isSwap) {
      return i18n.t(
        zhHans: '闪兑',
        zhHant: '閃兌',
        en: 'Swap',
        ja: 'スワップ',
        ko: '스왑',
      );
    }
    return item.title;
  }

  String _shortText(String value) {
    if (value.length <= 18) return value;
    return '${value.substring(0, 4)}****${value.substring(value.length - 4)}';
  }

  Color _amountColor(WalletPageColors cs) {
    // 深色主题下沿用深蓝色会与卡片背景对比不足，金额看起来像消失。
    // 使用高亮蓝，保证收入/支出金额在两种主题下都有足够对比度。
    if (item.income) return cs.dark ? const Color(0xFF63B3FF) : cs.blue;
    if (item.type == WalletRecordType.redPacket) {
      return cs.warningText;
    }
    return cs.dark ? const Color(0xFF63B3FF) : cs.blue;
  }

  Color _statusColor(WalletPageColors cs) {
    switch (item.status) {
      case WalletRecordStatus.success:
        return AppTokens.success;
      case WalletRecordStatus.pending:
        return cs.warningText;
      case WalletRecordStatus.failed:
        return cs.red;
    }
  }

  bool get _showPlatformCoinLogo {
    final upper = item.coin.trim().toUpperCase();
    return upper == '99' || item.coin.trim() == '元';
  }

  String get _amountText {
    final sign = item.income ? '+' : '-';
    final base = '$sign${item.amount}';
    if (_showPlatformCoinLogo) return base;
    return '$base ${item.coin}';
  }
}

class _HistoryFilterSheet extends StatelessWidget {
  final HistoryRecordFilter selected;

  const _HistoryFilterSheet({
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final items = HistoryRecordFilter.values
        .where((e) => e != HistoryRecordFilter.transferRefund)
        .toList();
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final cs = WalletPageColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      padding: EdgeInsets.fromLTRB(24.w, 22.h, 24.w, 28.h + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i18n.t(
              zhHans: '选择类型',
              zhHant: '選擇類型',
              en: 'Select Type',
              ja: '種類を選択',
              ko: '유형 선택',
            ),
            style: TextStyle(
              fontSize: 23.sp,
              fontWeight: FontWeight.w700,
              color: cs.text,
            ),
          ),
          SizedBox(height: 20.h),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 12.h,
              childAspectRatio: 2.15,
            ),
            itemBuilder: (_, i) {
              final item = items[i];
              final active = item == selected;
              return GestureDetector(
                onTap: () => Navigator.of(context).pop(item),
                child: Container(
                  alignment: Alignment.center,
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: active ? cs.filterActiveBg : cs.filterInactiveBg,
                    borderRadius: BorderRadius.circular(14.r),
                    border: active
                        ? Border.all(color: cs.filterActiveBorder, width: 1.5)
                        : Border.all(
                            color: cs.line.withValues(alpha: 0.55),
                            width: 1,
                          ),
                  ),
                  child: Text(
                    item.txt,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20.sp,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color:
                          active ? cs.filterActiveText : cs.filterInactiveText,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HistoryTag extends StatelessWidget {
  final String text;

  const _HistoryTag({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final cs = WalletPageColors.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.5.h),
      decoration: BoxDecoration(
        color: cs.tagBg,
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(
          color: cs.tagBorder,
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16.5.sp,
          fontWeight: FontWeight.w500,
          color: cs.tagTextColor,
        ),
      ),
    );
  }
}

class _HistoryExtraFilterBar extends StatelessWidget {
  final String coinText;
  final String dateRangeText;
  final VoidCallback onCoinTap;
  final VoidCallback onDateTap;

  const _HistoryExtraFilterBar({
    required this.coinText,
    required this.dateRangeText,
    required this.onCoinTap,
    required this.onDateTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = WalletPageColors.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(36.w, 27.h, 36.w, 9.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: onCoinTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 66.h,
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              decoration: BoxDecoration(
                color: cs.filterInactiveBg,
                borderRadius: BorderRadius.circular(33.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    coinText,
                    style: TextStyle(
                      fontSize: 27.sp,
                      fontWeight: FontWeight.w500,
                      color: cs.filterInactiveText,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 42.sp,
                    color: cs.subText,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 18.w),
          const Spacer(),
          GestureDetector(
            onTap: onDateTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 66.h,
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              decoration: BoxDecoration(
                color: cs.filterInactiveBg,
                borderRadius: BorderRadius.circular(33.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dateRangeText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 27.sp,
                      fontWeight: FontWeight.w500,
                      color: cs.filterInactiveText,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 42.sp,
                    color: cs.subText,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoinPickerSheet extends StatefulWidget {
  final List<String> options;
  final String selectedCoin;
  final String allCoinsLabel;

  const _CoinPickerSheet({
    required this.options,
    required this.selectedCoin,
    required this.allCoinsLabel,
  });

  @override
  State<_CoinPickerSheet> createState() => _CoinPickerSheetState();
}

class _CoinPickerSheetState extends State<_CoinPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<String> get _filteredCoins {
    final keyword = _query.trim().toUpperCase();
    final list = widget.options.where((e) => e != widget.allCoinsLabel);
    if (keyword.isEmpty) return list.toList();
    return list.where((e) => e.toUpperCase().contains(keyword)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = WalletPageColors.of(context);
    final i18n = AppI18n.of(context);
    return FractionallySizedBox(
      heightFactor: 0.4,
      child: Container(
        decoration: BoxDecoration(
          color: cs.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(39.r)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              SizedBox(height: 15.h),
              Container(
                width: 111.w,
                height: 9.h,
                decoration: BoxDecoration(
                  color: cs.line,
                  borderRadius: BorderRadius.circular(99.r),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(30.w, 27.h, 30.w, 12.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        i18n.t(
                          zhHans: '选择币种',
                          zhHant: '選擇幣種',
                          en: 'Select Token',
                          ja: '通貨を選択',
                          ko: '코인 선택',
                        ),
                        style: TextStyle(
                          fontSize: 31.5.sp,
                          fontWeight: FontWeight.w600,
                          color: cs.text,
                        ),
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(30.r),
                      onTap: () => Navigator.of(context).pop(),
                      child: Padding(
                        padding: EdgeInsets.all(6.w),
                        child: Icon(
                          Icons.close_rounded,
                          size: 39.sp,
                          color: cs.subText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(30.w, 15.h, 30.w, 18.h),
                child: Container(
                  height: 78.h,
                  decoration: BoxDecoration(
                    color: cs.inputFill,
                    borderRadius: BorderRadius.circular(21.r),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    cursorColor: cs.inputCursor,
                    style: TextStyle(
                      fontSize: 25.5.sp,
                      color: cs.text,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 36.sp,
                        color: cs.subText,
                      ),
                      hintText: i18n.t(
                        zhHans: '搜索',
                        zhHant: '搜尋',
                        en: 'Search',
                        ja: '検索',
                        ko: '검색',
                      ),
                      hintStyle: TextStyle(
                        fontSize: 25.5.sp,
                        color: cs.inputHint,
                      ),
                      contentPadding: EdgeInsets.symmetric(vertical: 21.h),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(30.w, 9.h, 30.w, 24.h),
                  children: [
                    _CoinSheetRow(
                      title: widget.allCoinsLabel,
                      selected: widget.selectedCoin == widget.allCoinsLabel,
                      onTap: () =>
                          Navigator.of(context).pop(widget.allCoinsLabel),
                    ),
                    ..._filteredCoins.map(
                      (coin) => _CoinSheetRow(
                        title: coin,
                        selected: coin == widget.selectedCoin,
                        icon: _CoinSheetIcon(coin: coin),
                        onTap: () => Navigator.of(context).pop(coin),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoinSheetRow extends StatelessWidget {
  final String title;
  final bool selected;
  final Widget? icon;
  final VoidCallback onTap;

  const _CoinSheetRow({
    required this.title,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = WalletPageColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(21.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 22.5.h),
        child: Row(
          children: [
            if (icon != null) ...[
              icon!,
              SizedBox(width: 24.w),
            ],
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 27.sp,
                  fontWeight: FontWeight.w500,
                  color: cs.text,
                ),
              ),
            ),
            if (selected)
              Icon(
                Icons.check_rounded,
                color: cs.blue,
              ),
          ],
        ),
      ),
    );
  }
}

class _CoinSheetIcon extends StatelessWidget {
  final String coin;

  const _CoinSheetIcon({
    required this.coin,
  });

  @override
  Widget build(BuildContext context) {
    final item = WalletRecordDto(
      id: '',
      type: WalletRecordType.all,
      status: WalletRecordStatus.success,
      title: '',
      subTitle: '',
      amount: '',
      coin: coin,
      income: true,
      network: '',
      fee: '',
      payer: '',
      payee: '',
      addr: '',
      hash: '',
      block: '',
      time: '',
      orderNo: '',
      memo: '',
    );
    return _CoinIcon(item: item);
  }
}

class _CoinIcon extends StatelessWidget {
  final WalletRecordDto item;

  const _CoinIcon({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final upper = item.coin.trim().toUpperCase();
    final rawCoin = item.coin.trim();
    final size = 75.w;
    Widget child;
    if (upper == 'TRX') {
      child = SizedBox(
        width: size,
        height: size,
        child: SvgPicture.string(
          _tronLogoSvg,
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      );
    } else if (upper == 'USDT') {
      child = Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xFF26A17B),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: CustomPaint(
          size: Size(size * 0.62, size * 0.62),
          painter: _UsdtCoinPainter(),
        ),
      );
    } else if (upper == 'BTC') {
      child = Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xFFF7931A),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          '₿',
          style: TextStyle(
            fontSize: 40.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1,
          ),
        ),
      );
    } else if (upper == 'ETH') {
      child = Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xFFF1F2F6),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: CustomPaint(
          size: Size(size * 0.56, size * 0.56),
          painter: _EthCoinPainter(),
        ),
      );
    } else if (upper == 'XRP') {
      child = Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xFF232531),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: CustomPaint(
          size: Size(size * 0.60, size * 0.60),
          painter: _XrpCoinPainter(),
        ),
      );
    } else if (upper == 'SOL') {
      child = Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C28),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: CustomPaint(
          size: Size(size * 0.68, size * 0.68),
          painter: _SolCoinPainter(),
        ),
      );
    } else if (upper == '99' || rawCoin == '元') {
      child = PlatformCoinIcon(size: size);
    } else {
      child = Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xFF5B8CFF),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          upper.isEmpty ? '?' : upper.substring(0, 1),
          style: TextStyle(
            fontSize: 33.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1,
          ),
        ),
      );
    }
    return SizedBox(width: size, height: size, child: child);
  }
}

class _UsdtCoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.08
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.08, h * 0.12, w * 0.84, h * 0.16),
        Radius.circular(w * 0.02),
      ),
      fill,
    );

    final stem = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.41, h * 0.12, w * 0.18, h * 0.76),
      Radius.circular(w * 0.02),
    );
    canvas.drawRRect(stem, fill);

    final oval = Rect.fromCenter(
      center: Offset(w / 2, h * 0.53),
      width: w * 0.92,
      height: h * 0.28,
    );
    canvas.drawArc(oval, 0.06, 6.16, false, stroke);

    final cover = Paint()
      ..color = const Color(0xFF26A17B)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(w * 0.35, h * 0.43, w * 0.30, h * 0.13),
      cover,
    );
    canvas.drawRRect(stem, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EthCoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final top = Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w * 0.18, h * 0.52)
      ..lineTo(w / 2, h * 0.72)
      ..lineTo(w * 0.82, h * 0.52)
      ..close();
    final bottom = Path()
      ..moveTo(w / 2, h)
      ..lineTo(w * 0.18, h * 0.60)
      ..lineTo(w / 2, h * 0.78)
      ..lineTo(w * 0.82, h * 0.60)
      ..close();
    canvas.drawPath(top, Paint()..color = const Color(0xFF8C8FA3));
    canvas.drawPath(
      Path()
        ..moveTo(w / 2, 0)
        ..lineTo(w * 0.82, h * 0.52)
        ..lineTo(w / 2, h * 0.72)
        ..close(),
      Paint()..color = const Color(0xFFB7BACC),
    );
    canvas.drawPath(bottom, Paint()..color = const Color(0xFF9CA0B3));
    canvas.drawPath(
      Path()
        ..moveTo(w / 2, h)
        ..lineTo(w * 0.82, h * 0.60)
        ..lineTo(w / 2, h * 0.78)
        ..close(),
      Paint()..color = const Color(0xFFD1D4E0),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _XrpCoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round;
    final top = Path()
      ..moveTo(size.width * 0.12, size.height * 0.22)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.46,
        size.width * 0.50,
        size.height * 0.46,
      )
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.46,
        size.width * 0.88,
        size.height * 0.22,
      );
    final bottom = Path()
      ..moveTo(size.width * 0.12, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.54,
        size.width * 0.50,
        size.height * 0.54,
      )
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.54,
        size.width * 0.88,
        size.height * 0.78,
      );
    canvas.drawPath(top, paint);
    canvas.drawPath(bottom, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SolCoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      const Color(0xFF14F195),
      const Color(0xFF80ECFF),
      const Color(0xFF9945FF),
    ];
    final barHeight = size.height * 0.18;
    final gap = size.height * 0.12;

    void drawBar(double top, Color color, double dx) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(dx, top, size.width - dx * 2, barHeight),
        Radius.circular(barHeight / 2),
      );
      final path = Path()
        ..addRRect(rect)
        ..transform(Matrix4.skewX(-0.35).storage);
      canvas.drawPath(path, Paint()..color = color);
    }

    drawBar(0, colors[0], size.width * 0.16);
    drawBar(barHeight + gap, colors[1], size.width * 0.08);
    drawBar((barHeight + gap) * 2, colors[2], size.width * 0.16);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

const String _tronLogoSvg = '''
<svg viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <path d="M512.85 511.04m-447.5 0a447.5 447.5 0 1 0 895 0 447.5 447.5 0 1 0-895 0Z" fill="#D80917"/>
  <path d="M477.1 787.2c-0.84 0-1.71-0.05-2.55-0.18a18.645 18.645 0 0 1-15.04-12.25L277.69 259.74c-2.31-6.56-0.78-13.86 3.97-18.94s11.96-7.12 18.63-5.23l366.29 102.15c2.37 0.66 4.63 1.8 6.56 3.35l68.87 54.7c7.76 6.15 9.36 17.3 3.64 25.36L492.32 779.31a18.628 18.628 0 0 1-15.22 7.89zM324.8 281.12l157.87 447.25L705 414.01l-52.08-41.37-328.12-91.52z" fill="#FFFFFF"/>
  <path d="M477.13 787.2c-0.69 0-1.35-0.04-2.04-0.11-10.23-1.11-17.63-10.31-16.53-20.54l27.42-253.89c1.09-10.27 10.6-17.48 20.54-16.53 10.23 1.11 17.63 10.31 16.53 20.54l-27.42 253.89c-1.02 9.55-9.1 16.64-18.5 16.64z" fill="#FFFFFF"/>
  <path d="M504.52 533.31c-4.73 0-9.47-1.78-13.11-5.37-7.32-7.25-7.39-19.05-0.15-26.38L648.3 342.57c7.25-7.32 19.05-7.39 26.37-0.16 7.32 7.25 7.39 19.05 0.15 26.38L517.77 527.77a18.59 18.59 0 0 1-13.25 5.54z" fill="#FFFFFF"/>
  <path d="M504.52 533.31c-7.03 0-13.77-4.01-16.93-10.83-4.3-9.34-0.22-20.43 9.1-24.75l225.9-104.28c9.4-4.32 20.43-0.24 24.76 9.12 4.3 9.34 0.22 20.43-9.1 24.75L512.35 531.6a18.857 18.857 0 0 1-7.83 1.71z" fill="#FFFFFF"/>
  <path d="M507.21 536.55c-5.46 0-10.85-2.39-14.53-6.99L280.73 265.19c-6.45-8.03-5.15-19.76 2.9-26.2 8.01-6.41 19.79-5.12 26.2 2.9l211.91 264.37c6.45 8.03 5.17 19.76-2.88 26.2a18.563 18.563 0 0 1-11.65 4.09z" fill="#FFFFFF"/>
</svg>
''';

class _ErrorBox extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;

  const _ErrorBox({
    required this.text,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = WalletPageColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 14.sp,
              color: cs.subText,
            ),
          ),
          SizedBox(height: 10.h),
          TextButton(
            onPressed: onRetry,
            child: Text(
              AppI18n.of(context).t(
                zhHans: '重试',
                zhHant: '重試',
                en: 'Retry',
                ja: '再試行',
                ko: '다시 시도',
              ),
              style: TextStyle(color: cs.blue),
            ),
          ),
        ],
      ),
    );
  }
}

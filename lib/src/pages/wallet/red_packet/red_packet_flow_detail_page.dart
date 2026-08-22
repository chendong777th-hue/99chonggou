import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/api/wallet_amount.dart';
import 'package:tencent_cloud_chat_demo/src/api/wallet_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/wallet_time.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/wallet_error_mapper.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/widgets/wallet_page_colors.dart';
import 'package:tencent_cloud_chat_demo/src/provider/login_user_Info.dart';
import 'package:tencent_cloud_chat_demo/src/services/red_packet_claim_notice_sender.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';

import 'lucky_red_packet_detail_page.dart';
import 'red_packet_detail_pop_result.dart';
import 'red_packet_open_flow_page.dart';
import 'widgets/red_packet_detail_app_bar.dart';

/// 红包详情（对接钱包 API），按类型展示普通/拼手气详情页。
class RedPacketProjectDetailPage extends StatefulWidget {
  const RedPacketProjectDetailPage({
    super.key,
    required this.orderId,
    required this.packetType,
    this.senderName = '',
    this.senderAvatar = '',
    this.greeting = '',
    this.amountText = '',
    this.autoClaim = true,
    this.seedPacket = const {},
  });

  final String orderId;
  final String packetType;
  final String senderName;
  final String senderAvatar;
  final String greeting;
  final String amountText;
  final bool autoClaim;

  /// 聊天消息里的本地字段，订单详情接口失败时用于兜底展示。
  final Map<String, dynamic> seedPacket;

  @override
  State<RedPacketProjectDetailPage> createState() =>
      _RedPacketProjectDetailPageState();
}

class _RedPacketProjectDetailPageState extends State<RedPacketProjectDetailPage> {
  bool _loading = true;
  bool _claimed = false;
  bool _claimsLoaded = false;
  String _error = '';
  String _senderProfileAvatar = '';
  Map<String, dynamic> _packet = const {};
  RedPacketClaimStateDto? _claimState;
  List<Map<String, dynamic>> _claims = const [];
  List<_ResolvedClaim> _resolvedClaims = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final orderId = widget.orderId.trim();
    if (orderId.isEmpty) {
      setState(() {
        _loading = false;
        _error = '红包信息不存在';
      });
      return;
    }

    if (mounted && (!_loading || _error.isNotEmpty)) {
      setState(() {
        _loading = true;
        _error = '';
      });
    }

    RedPacketClaimStateDto? claimState;
    Map<String, dynamic>? packet;
    Object? orderError;
    List<Map<String, dynamic>> claims = _claims;
    List<_ResolvedClaim> resolvedClaims = _resolvedClaims;
    var claimsLoaded = _claimsLoaded;
    var senderProfileAvatar = _senderProfileAvatar;

    try {
      claimState = await WalletApi.instance.getRedPacketClaimState(orderId);
    } catch (_) {}

    var claimSucceeded = false;
    if (widget.autoClaim && !_claimed && (claimState?.canOpen ?? false)) {
      _claimed = true;
      try {
        await WalletApi.instance.claimRedPacket(orderId: orderId);
        claimState = await WalletApi.instance.getRedPacketClaimState(orderId);
        claimSucceeded = claimState.received;
      } catch (_) {
        try {
          claimState = await WalletApi.instance.getRedPacketClaimState(orderId);
          claimSucceeded = claimState.received;
        } catch (_) {}
      }
    }

    try {
      final order = await WalletApi.instance.getRedPacketOrder(orderId);
      packet = Map<String, dynamic>.from(order.data);
    } catch (e) {
      orderError = e;
    }

    // 未参与领取的旁观者：订单详情接口可能因权限失败，用消息种子 + claim-state 兜底。
    packet ??= _buildFallbackPacket(claimState);

    // 领取灰字：等订单/种子齐后再发，避免 senderName 空落成占位。
    if (claimSucceeded && packet != null) {
      _packet = packet;
      _scheduleClaimNoticeSend(
        orderId: orderId,
        claimState: claimState,
      );
    }

    if (packet != null) {
      senderProfileAvatar = await _fetchSenderAvatar(packet);
    }

    final embeddedClaims = _claimsFromPacket(packet);
    try {
      claims = await WalletApi.instance.getRedPacketClaims(orderId);
      if (claims.isEmpty && embeddedClaims.isNotEmpty) {
        claims = embeddedClaims;
      }
      resolvedClaims = await _buildResolvedClaims(claims);
      claimsLoaded = true;
    } catch (_) {
      // /claims 失败时回退订单详情里内嵌的领取列表。
      if (embeddedClaims.isNotEmpty) {
        claims = embeddedClaims;
        resolvedClaims = await _buildResolvedClaims(claims);
        claimsLoaded = true;
      } else {
        claims = _claims;
        resolvedClaims = _resolvedClaims;
        claimsLoaded = false;
      }
    }

    if (!mounted) return;

    if (packet == null) {
      setState(() {
        _loading = false;
        _error = _orderLoadErrorMessage(orderError);
      });
      return;
    }

    setState(() {
      _claimState = claimState;
      _packet = packet!;
      _claims = claims;
      _resolvedClaims = resolvedClaims;
      _senderProfileAvatar = senderProfileAvatar;
      _claimsLoaded = claimsLoaded;
      _loading = false;
      _error = '';
    });
  }

  void _scheduleClaimNoticeSend({
    required String orderId,
    required RedPacketClaimStateDto? claimState,
  }) {
    final seed = widget.seedPacket;
    final groupId = seed['chatGroupId']?.toString().trim() ?? '';
    final peerUserId = seed['chatPeerUserId']?.toString().trim() ?? '';
    if (groupId.isEmpty && peerUserId.isEmpty) {
      return;
    }
    final finished = claimState == null
        ? false
        : (claimState.remainingCount <= 0 ||
            claimState.depleted ||
            claimState.packetStatus == 'FINISHED' ||
            claimState.packetStatus == 'COMPLETED' ||
            claimState.packetStatus == 'FULLY_CLAIMED');
    String claimerName = '';
    try {
      final login = Provider.of<LoginUserInfo>(context, listen: false);
      claimerName = (login.loginUserInfo.nickName ?? '').trim();
    } catch (_) {}
    final senderName = _firstNonEmpty([
      widget.senderName,
      _packet['senderName'],
      _packet['senderNickname'],
      _packet['senderNickName'],
      seed['senderName'],
      seed['senderNickname'],
      seed['senderNickName'],
    ]);
    final senderUserId = _firstNonEmpty([
      _packet['senderUserId'],
      _packet['senderId'],
      _packet['fromUserId'],
      _packet['ownerUserId'],
      seed['senderUserId'],
      seed['senderId'],
      seed['fromUserId'],
      seed['ownerUserId'],
    ]);
    // 仍无昵称时用 userId 进 payload；展示层不会再落成「好友」。
    final resolvedSenderName =
        senderName.isNotEmpty ? senderName : senderUserId;
    unawaited(
      RedPacketClaimNoticeSender.instance.sendAfterClaim(
        packetId: orderId,
        groupId: groupId,
        peerUserId: peerUserId,
        showFinishedSuffix: finished,
        claimerName: claimerName,
        senderUserId: senderUserId,
        senderName: resolvedSenderName,
      ),
    );
  }

  Map<String, dynamic>? _buildFallbackPacket(RedPacketClaimStateDto? claimState) {
    final seed = widget.seedPacket;
    final hasSeed = seed.isNotEmpty ||
        widget.packetType.trim().isNotEmpty ||
        widget.greeting.trim().isNotEmpty ||
        widget.senderName.trim().isNotEmpty ||
        claimState != null;
    if (!hasSeed) return null;

    final packet = <String, dynamic>{
      ...seed,
      if (widget.packetType.trim().isNotEmpty)
        'packetType': widget.packetType.trim(),
      if (widget.greeting.trim().isNotEmpty) 'greeting': widget.greeting.trim(),
      if (widget.senderName.trim().isNotEmpty)
        'senderName': widget.senderName.trim(),
      if (widget.senderAvatar.trim().isNotEmpty)
        'senderAvatar': widget.senderAvatar.trim(),
    };

    if (claimState != null) {
      if (claimState.packetStatus.isNotEmpty) {
        packet['status'] = claimState.packetStatus;
      }
      packet['remainingCount'] = claimState.remainingCount;
    }

    final status = packet['status']?.toString().trim() ?? '';
    if (status.isEmpty) {
      if (claimState?.depleted == true) {
        packet['status'] = 'COMPLETED';
      } else if (claimState?.received == true) {
        packet['status'] = 'COMPLETED';
      } else {
        packet['status'] = 'ACTIVE';
      }
    }

    return packet;
  }

  String _orderLoadErrorMessage(Object? error) {
    if (error != null) {
      final mapped = WalletErrorMapper.map(error, action: 'load');
      final code = mapped.code.toUpperCase();
      if (code == 'FORBIDDEN' ||
          code.contains('FORBIDDEN') ||
          code.contains('PERMISSION') ||
          code.contains('NOT_ALLOWED') ||
          code.contains('NO_ACCESS')) {
        return AppI18n.of(context).t(
          zhHans: '无权查看该红包详情',
          zhHant: '無權查看該紅包詳情',
          en: 'You cannot view this red packet.',
          ja: 'この红包の詳細を表示する権限がありません。',
          ko: '이 레드패킷 상세를 볼 권한이 없습니다.',
        );
      }
      final message = mapped.userMessage.trim();
      if (message.isNotEmpty) return message;
    }
    return AppI18n.of(context).t(
      zhHans: '红包详情加载失败',
      zhHant: '紅包詳情載入失敗',
      en: 'Failed to load red packet details.',
      ja: '紅包詳細の読み込みに失敗しました。',
      ko: '레드패킷 상세 정보를 불러오지 못했습니다.',
    );
  }

  String get _packetStatus {
    return _packet['status']?.toString().trim().toUpperCase() ?? '';
  }

  bool get _hasRemainingBalance {
    final remaining =
        _claimState?.remainingCount ?? _asInt(_packet['remainingCount']);
    return remaining > 0;
  }

  bool get _didCurrentUserClaim {
    final ownUserId =
        context.read<LoginUserInfo>().loginUserInfo.userID?.trim() ?? '';
    if (ownUserId.isEmpty) return false;
    return _claims.any(
      (item) => item['userId']?.toString().trim() == ownUserId,
    );
  }

  RedPacketDetailPopResult? _buildPopResult() {
    if (_packet.isEmpty) return null;
    final status = _packetStatus;
    if (status == 'EXPIRED') {
      return RedPacketDetailPopResult(
        status: 'expired',
        claimed: _didCurrentUserClaim,
      );
    }
    if (status == 'REFUNDED') {
      return RedPacketDetailPopResult(
        status: 'refunded',
        claimed: _didCurrentUserClaim,
      );
    }
    if (_didCurrentUserClaim) {
      return const RedPacketDetailPopResult(status: 'claimed', claimed: true);
    }
    if (!_hasRemainingBalance) {
      return const RedPacketDetailPopResult(status: 'finished', claimed: false);
    }
    return const RedPacketDetailPopResult(status: 'pending', claimed: false);
  }

  bool _popping = false;

  void _popWithResult() {
    if (!mounted || _popping) return;
    // PopScope(canPop: false) 时 maybePop 不会出栈，需在此处强制 pop 并带回结果。
    _popping = true;
    Navigator.of(context).pop(_buildPopResult());
  }

  /// 返回键 / 系统返回统一走 maybePop，由 PopScope 注入详情结果。
  void _requestPop() {
    if (!mounted || _popping) return;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _popping) return;
        _popWithResult();
      },
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    final cs = WalletPageColors.of(context);
    if (_loading) {
      return wrapWalletPage(
        context,
        Scaffold(
          backgroundColor: cs.bg,
          appBar: buildRedPacketDetailAppBar(context, onBack: _requestPop),
          body: Center(
            child: CircularProgressIndicator(color: cs.blue),
          ),
        ),
      );
    }
    if (_error.isNotEmpty) {
      return wrapWalletPage(
        context,
        Scaffold(
          backgroundColor: cs.bg,
          appBar: buildRedPacketDetailAppBar(context, onBack: _requestPop),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: cs.subText,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _load,
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final packetType = _firstNonEmpty([
      widget.packetType,
      _packet['packetType'],
    ]);
    if (_shouldShowOpenedAmountPage(packetType)) {
      return RedPacketOpenedPreviewPage(
        data: _normalDetailData(packetType),
        onBack: _requestPop,
      );
    }
    return LuckyRedPacketDetailPage(
      data: _luckyDetailData(packetType),
      onBack: _requestPop,
    );
  }

  bool _isDepletedForCurrentViewer() {
    if (_shouldShowClaimedAmount) return false;
    final claimState = _claimState;
    if (claimState != null) {
      if (claimState.received || _didCurrentUserClaim) return false;
      if (claimState.depleted) return true;
    }
    final total = _totalCount;
    return total > 0 && !_hasRemainingBalance;
  }

  bool get _shouldShowClaimedAmount {
    final amount = _claimState?.myClaimAmount;
    if (amount != null && amount > 0) return true;
    if (_claimState?.received ?? false) return true;
    return _didCurrentUserClaim;
  }

  bool _shouldShowOpenedAmountPage(String packetType) {
    if (!_shouldShowClaimedAmount) return false;
    switch (packetType.toUpperCase()) {
      case 'EXCLUSIVE':
      case 'NORMAL_C2C':
      case 'NORMAL':
        return true;
      default:
        return false;
    }
  }

  String _statusHint() {
    final i18n = AppI18n.of(context);
    final claimState = _claimState;
    if (_isDepletedForCurrentViewer()) {
      final status = claimState?.packetStatus.isNotEmpty == true
          ? claimState!.packetStatus
          : _packetStatus;
      if (status == 'EXPIRED') {
        return i18n.t(
          zhHans: '红包已过期',
          zhHant: '紅包已過期',
          en: 'Red packet expired',
          ja: '紅包は期限切れです',
          ko: '홍바오 만료됨',
        );
      }
      return i18n.t(
        zhHans: '红包已领完',
        zhHant: '紅包已領完',
        en: 'Red packet fully claimed',
        ja: '紅包はすべて受取済みです',
        ko: '홍바오 모두 수령됨',
      );
    }
    if (claimState == null) {
      return _statusTip(i18n, _packetStatus);
    }
    if (claimState.received || _didCurrentUserClaim) {
      return i18n.t(
        zhHans: '红包已领取',
        zhHant: '紅包已領取',
        en: 'Red packet claimed',
        ja: '紅包は受取済みです',
        ko: '홍바오 수령 완료',
      );
    }
    if (claimState.empty) {
      if (claimState.packetStatus == 'EXPIRED') {
        return i18n.t(
          zhHans: '红包已过期',
          zhHant: '紅包已過期',
          en: 'Red packet expired',
          ja: '紅包は期限切れです',
          ko: '홍바오 만료됨',
        );
      }
      return i18n.t(
        zhHans: '红包已领完',
        zhHant: '紅包已領完',
        en: 'Red packet fully claimed',
        ja: '紅包はすべて受取済みです',
        ko: '홍바오 모두 수령됨',
      );
    }
    return _statusTip(i18n, _packetStatus);
  }

  String _statusTip(AppI18n i18n, String status) {
    switch (status) {
      case 'EXPIRED':
        return i18n.t(
          zhHans: '红包已过期',
          zhHant: '紅包已過期',
          en: 'Red packet expired',
          ja: '紅包は期限切れです',
          ko: '홍바오 만료됨',
        );
      case 'REFUNDED':
        return i18n.t(
          zhHans: '红包已退款',
          zhHant: '紅包已退款',
          en: 'Red packet refunded',
          ja: '紅包は返金済みです',
          ko: '홍바오 환불됨',
        );
      case 'COMPLETED':
      case 'CREDITED':
        return i18n.t(
          zhHans: '红包已领取',
          zhHant: '紅包已領取',
          en: 'Red packet claimed',
          ja: '紅包は受取済みです',
          ko: '홍바오 수령 완료',
        );
      default:
        return i18n.t(
          zhHans: '查看领取详情',
          zhHant: '查看領取詳情',
          en: 'View claim details',
          ja: '受取詳細を見る',
          ko: '수령 내역 보기',
        );
    }
  }

  RedPacketOpenPreviewData _normalDetailData(String packetType) {
    return RedPacketOpenPreviewData(
      orderId: widget.orderId,
      packetType: packetType,
      senderName: _senderName,
      senderAvatar: _senderAvatar,
      greeting: _greeting,
      amountText: _displayAmount,
      currency: _currency,
      autoClaim: false,
    );
  }

  LuckyRedPacketDetailData _luckyDetailData(String packetType) {
    final currency = _currency;
    final claimedCount = _claimedCount;
    final totalCount = _totalCount;
    final totalAmount = _asInt(_packet['totalAmount'] ?? _packet['amount']);
    final claimedAmount = _claimedAmountMinor(totalAmount, claimedCount, totalCount);
    return LuckyRedPacketDetailData(
      orderId: widget.orderId,
      packetType: packetType,
      senderName: _senderName,
      senderAvatar: _senderAvatar,
      greeting: _greeting,
      amountText: _displayAmount,
      claimedCount: claimedCount,
      totalCount: totalCount,
      claimedAmountText: _formatAmount(currency, claimedAmount),
      totalAmountText: _formatAmount(currency, totalAmount),
      currency: currency,
      allClaimed: totalCount > 0 && claimedCount >= totalCount,
      claims: _claimRows(currency),
      statusHint: _shouldShowClaimedAmount ? '' : _statusHint(),
      claimsLoaded: _claimsLoaded,
    );
  }

  /// 已领金额：优先列表汇总；列表失败时用订单字段，领完则等于总额。
  int _claimedAmountMinor(int totalAmount, int claimedCount, int totalCount) {
    final fromClaims = _claims.fold<int>(
      0,
      (sum, item) => sum + _asInt(item['amount']),
    );
    if (fromClaims > 0) return fromClaims;

    final explicit = _asInt(
      _packet['claimedAmount'] ??
          _packet['claimedTotal'] ??
          _packet['receivedAmount'],
    );
    if (explicit > 0) return explicit;

    if (_packet.containsKey('remainingAmount')) {
      final remainingAmount = _asInt(_packet['remainingAmount']);
      if (totalAmount > 0 && remainingAmount >= 0) {
        return math.max(0, totalAmount - remainingAmount);
      }
    }

    if (totalAmount > 0 && totalCount > 0 && claimedCount >= totalCount) {
      return totalAmount;
    }
    return 0;
  }

  List<Map<String, dynamic>> _claimsFromPacket(Map<String, dynamic>? packet) {
    if (packet == null) return const [];
    final raw = packet['claims'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<LuckyRedPacketClaimPreviewData> _claimRows(String currency) {
    final claimedCount = _claimedCount;
    final totalCount = _totalCount;
    final allClaimed = totalCount > 0 && claimedCount >= totalCount;
    final unit = walletDisplayCoin(currency);
    final unitSuffix =
        isWalletPlatformCurrency(currency) ? unit : ' $unit';
    return _resolvedClaims
        .map(
          (item) => LuckyRedPacketClaimPreviewData(
            avatarUrl: item.avatar,
            name: item.name,
            time: formatWalletApiClaimListTime(item.createdAt),
            amountText: '${_formatAmount(currency, item.amount)}$unitSuffix',
            bestLuck: allClaimed && item.bestLuck,
          ),
        )
        .toList();
  }

  Future<String> _fetchSenderAvatar(Map<String, dynamic> packet) async {
    final direct = _firstNonEmpty([
      widget.senderAvatar,
      packet['senderAvatar'],
      packet['senderAvatarUrl'],
      packet['senderFaceUrl'],
      packet['avatarUrl'],
      packet['faceUrl'],
    ]);
    if (direct.isNotEmpty) {
      return direct;
    }

    final senderUserId = _firstNonEmpty([
      packet['senderUserId'],
      packet['senderId'],
      packet['userId'],
    ]);
    if (senderUserId.isEmpty) {
      return '';
    }

    try {
      final res = await TencentImSDKPlugin.v2TIMManager.getUsersInfo(
        userIDList: [senderUserId],
      );
      final user = res.data?.isNotEmpty == true ? res.data!.first : null;
      return user?.faceUrl?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<List<_ResolvedClaim>> _buildResolvedClaims(
    List<Map<String, dynamic>> rawClaims,
  ) async {
    final ids = <String>{};
    for (final item in rawClaims) {
      final userId = item['userId']?.toString().trim() ?? '';
      if (userId.isNotEmpty) {
        ids.add(userId);
      }
    }

    final profileMap = <String, V2TimUserFullInfo>{};
    if (ids.isNotEmpty) {
      try {
        final res = await TencentImSDKPlugin.v2TIMManager.getUsersInfo(
          userIDList: ids.toList(),
        );
        final list = res.data ?? <V2TimUserFullInfo>[];
        for (final item in list) {
          final userId = item.userID?.trim() ?? '';
          if (userId.isNotEmpty) {
            profileMap[userId] = item;
          }
        }
      } catch (_) {}
    }

    final claims = rawClaims
        .map((item) => _ResolvedClaim.fromMap(item, profileMap))
        .toList()
      ..sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

    if (claims.isNotEmpty) {
      var bestIndex = 0;
      for (var i = 1; i < claims.length; i++) {
        if (claims[i].amount > claims[bestIndex].amount) {
          bestIndex = i;
        }
      }
      claims[bestIndex] = claims[bestIndex].copyWith(bestLuck: true);
    }
    return claims;
  }

  String get _senderName {
    return _firstNonEmpty([
      widget.senderName,
      _packet['senderName'],
      _packet['senderNickname'],
      _packet['senderNickName'],
      _packet['senderUserId'],
      _packet['senderId'],
    ]);
  }

  String get _senderAvatar {
    return _firstNonEmpty([
      widget.senderAvatar,
      _senderProfileAvatar,
      _packet['senderAvatar'],
      _packet['senderAvatarUrl'],
      _packet['senderFaceUrl'],
      _packet['avatarUrl'],
      _packet['faceUrl'],
    ]);
  }

  String get _greeting {
    return _firstNonEmpty([
      widget.greeting,
      _packet['greeting'],
      _packet['msg'],
    ]);
  }

  String get _currency {
    return _firstNonEmpty([
      _packet['currency'],
      _packet['coin'],
      WalletCurrency.platform,
    ]);
  }

  String get _displayAmount {
    if (!_shouldShowClaimedAmount) return '';

    final claimedAmount = _claimState?.myClaimAmount;
    if (claimedAmount != null && claimedAmount > 0) {
      return _formatAmount(_currency, claimedAmount);
    }

    final ownUserId =
        context.read<LoginUserInfo>().loginUserInfo.userID?.trim() ?? '';
    if (ownUserId.isNotEmpty) {
      for (final item in _claims) {
        if (item['userId']?.toString().trim() == ownUserId) {
          final amount = _asInt(item['amount']);
          if (amount > 0) {
            return _formatAmount(_currency, amount);
          }
        }
      }
    }

    return widget.amountText.trim();
  }

  int get _totalCount {
    return _asInt(_packet['packetCount'] ?? _packet['count'] ?? _packet['cnt']);
  }

  int get _claimedCount {
    final total = _totalCount;

    if (_claimsLoaded) {
      return _claims.length;
    }

    final explicit = _asInt(_packet['claimedCount']);
    if (explicit > 0) {
      return total > 0 ? math.min(explicit, total) : explicit;
    }

    final status = _packetStatus;
    if (status != 'REFUNDED' && status != 'EXPIRED') {
      final remaining =
          _claimState?.remainingCount ?? _asInt(_packet['remainingCount']);
      if (total > 0 && remaining >= 0) {
        return math.max(0, total - remaining);
      }
    }

    return _claims.length;
  }

  String _firstNonEmpty(List<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _formatAmount(String currency, int minor) {
    if (minor <= 0) return '0.00';
    return formatWalletAmount(currency, minor);
  }

  int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}

class _ResolvedClaim {
  const _ResolvedClaim({
    required this.avatar,
    required this.name,
    required this.amount,
    required this.createdAt,
    this.bestLuck = false,
  });

  final String avatar;
  final String name;
  final int amount;
  final DateTime? createdAt;
  final bool bestLuck;

  _ResolvedClaim copyWith({bool? bestLuck}) {
    return _ResolvedClaim(
      avatar: avatar,
      name: name,
      amount: amount,
      createdAt: createdAt,
      bestLuck: bestLuck ?? this.bestLuck,
    );
  }

  factory _ResolvedClaim.fromMap(
    Map<String, dynamic> map,
    Map<String, V2TimUserFullInfo> profileMap,
  ) {
    final userId = map['userId']?.toString().trim() ?? '';
    final profile = profileMap[userId];
    final nick = profile?.nickName?.trim() ?? '';
    final avatar = [
      profile?.faceUrl?.trim() ?? '',
      map['avatarUrl']?.toString().trim() ?? '',
      map['faceUrl']?.toString().trim() ?? '',
      map['avatar']?.toString().trim() ?? '',
    ].firstWhere(
      (item) => item.isNotEmpty,
      orElse: () => '',
    );
    final fallbackName = [
      map['name']?.toString().trim() ?? '',
      map['nickName']?.toString().trim() ?? '',
      map['nickname']?.toString().trim() ?? '',
      map['userName']?.toString().trim() ?? '',
      userId,
    ].firstWhere(
      (item) => item.isNotEmpty,
      orElse: () => AppI18n.current.t(
        zhHans: '未知用户',
        zhHant: '未知用戶',
        en: 'Unknown user',
        ja: '不明なユーザー',
        ko: '알 수 없는 사용자',
      ),
    );
    return _ResolvedClaim(
      avatar: avatar,
      name: nick.isNotEmpty ? nick : fallbackName,
      amount: _resolvedClaimAmount(map['amount']),
      createdAt: parseWalletApiClaimTime(map),
    );
  }
}

int _resolvedClaimAmount(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}
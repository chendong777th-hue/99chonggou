import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';

import '../order/wallet_card_im_sender.dart';
import '../order/wallet_card_replay_guard.dart';
import '../order/wallet_order.dart';
import '../order/wallet_order_checker.dart';
import '../order/wallet_order_events.dart';
import '../order/wallet_order_service.dart';
import '../transfer_party_name_resolver.dart';
import '../wallet_default_pay_currency_store.dart';
import '../wallet_repository.dart';
import '../wallet_repository_provider.dart';
import '../wallet_store.dart';
import 'red_packet_member.dart';
import 'red_packet_models.dart';

/// 红包祝福语最大字数（含中文、英文、数字等，按 [String.length] 计）。
const int kRedPacketBlessingMaxLength = 10;

class RedPacketController extends ChangeNotifier {
  static const int _maxPacketCount = 500;

  final WalletRepository _repo;
  final WalletOrderChecker _checker;
  final WalletOrderService _orderSvc;

  RedPacketController({
    WalletRepository? repo,
    WalletOrderChecker? checker,
    WalletOrderService? orderSvc,
  })  : _repo = repo ?? createWalletRepository(),
        _checker = checker ?? const WalletOrderChecker(),
        _orderSvc = orderSvc ?? WalletOrderService();

  static String _defaultBlessing() => AppI18n.current.t(
        zhHans: '恭喜发财，大吉大利',
        zhHant: '恭喜發財，大吉大利',
        en: 'Best wishes and good fortune.',
        ja: 'ご多幸をお祈りします。',
        ko: '행운과 복이 함께하시길 바랍니다.',
      );

  List<WalletPayMethodDto> pays = <WalletPayMethodDto>[];
  WalletPayMethodDto pay = WalletPayMethodDto.empty;
  bool payLoading = false;

  Future<void> loadPayMethods() async {
    if (payLoading) return;
    final preferredId = await WalletDefaultPayCurrencyStore.readId();
    final cached = WalletStore.instance.cachedPayMethods;
    if (cached != null && cached.isNotEmpty) {
      pays = List<WalletPayMethodDto>.from(cached);
      pay = _pickDefaultPay(pays, preferredId);
      notifyListeners();
    }
    payLoading = true;
    notifyListeners();
    try {
      final methods = await WalletStore.instance.getPayMethods(repo: _repo);
      pays = List<WalletPayMethodDto>.from(methods);
      pay = pays.isNotEmpty
          ? _pickDefaultPay(pays, preferredId)
          : WalletPayMethodDto.empty;
    } catch (_) {
      pays = <WalletPayMethodDto>[];
      pay = WalletPayMethodDto.empty;
    } finally {
      payLoading = false;
      if (!_dead) notifyListeners();
    }
  }

  WalletPayMethodDto _pickDefaultPay(
    List<WalletPayMethodDto> list,
    String? preferredId,
  ) {
    return WalletDefaultPayCurrencyStore.pick(
      items: list,
      idOf: (e) => e.id,
      enabledOf: (e) => e.enabled,
      preferredId: preferredId,
    );
  }

  RpType type = RpType.lucky;
  WalletOrderState state = WalletOrderState.idle;
  String cnt = '';
  String amt = '';
  String msg = '';
  String err = '';
  String receiverName = '';
  String receiverId = '';
  String receiverAvatar = '';
  String convId = '';
  String groupNum = '';
  String orderId = '';
  String clientOrderId = '';
  bool isGroup = false;
  WalletOrderResult? lastResult;

  bool _dead = false;

  RpFlow get flow {
    switch (state) {
      case WalletOrderState.submitting:
        return RpFlow.loading;
      case WalletOrderState.accepted:
      case WalletOrderState.pending:
      case WalletOrderState.unknown:
        return RpFlow.pending;
      case WalletOrderState.success:
        return RpFlow.success;
      case WalletOrderState.failed:
        return RpFlow.failed;
      default:
        return RpFlow.none;
    }
  }

  int get cntNum => int.tryParse(cnt.trim()) ?? 0;
  int? get maxGroupNum {
    final raw = groupNum.trim();
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  bool get isBusy => state == WalletOrderState.submitting;

  int? get amountMinor =>
      _checker.amountMinor(raw: amt, coin: pay.coin, scale: pay.scale);

  int get totalMinor {
    final minor = amountMinor ?? 0;
    switch (type) {
      case RpType.lucky:
        return minor;
      case RpType.normal:
        return minor * cntNum;
      case RpType.exclusive:
        return minor;
    }
  }

  String get amountText =>
      WalletAmount.parse(amt, coin: pay.coin, scale: pay.scale)?.text ?? amt;
  String get totalText => WalletAmount.formatMinor(totalMinor, pay.scale);

  /// 展示用总金额：至少保留 2 位小数（如 1 -> 1.00），仅用于 UI。
  String get totalDisplayText =>
      WalletAmount.formatDisplay(totalMinor, pay.scale);
  String get actualPayText {
    final amount =
        '${WalletAmount.formatMinor(totalMinor, pay.scale)} ${pay.coin}';
    if (pay.feeMinor <= 0) return amount;
    final feeCoin = pay.feeCoin.isEmpty ? pay.coin : pay.feeCoin;
    if (feeCoin == pay.coin) {
      return '${WalletAmount.formatMinor(totalMinor + pay.feeMinor, pay.scale)} ${pay.coin}';
    }
    return '$amount + ${WalletAmount.formatMinor(pay.feeMinor, pay.feeScale)} $feeCoin';
  }

  bool get canPay => check() == null && state == WalletOrderState.idle;

  void setType(RpType v) {
    if (type == v) return;
    if (!isGroup && v != RpType.normal) return;

    type = v;
    if (v == RpType.exclusive) {
      cnt = '';
      if (isSelfUserId(receiverId)) {
        receiverId = '';
        receiverName = '';
        receiverAvatar = '';
      }
    } else if (!isGroup) {
      cnt = '1';
    }
    notifyListeners();
  }

  void setCnt(String v) {
    final next = v.trim();
    if (cnt == next) return;
    cnt = next;
    notifyListeners();
  }

  void setAmt(String v) {
    final next = v.trim();
    if (amt == next) return;
    amt = next;
    notifyListeners();
  }

  String get effectiveMsg {
    final value = msg.trim();
    return value.isEmpty ? _defaultBlessing() : value;
  }

  void setMsg(String v) {
    var next = v.replaceAll(RegExp(r'[\n\r\t]'), ' ').trim();
    if (next.length > kRedPacketBlessingMaxLength) {
      next = next.substring(0, kRedPacketBlessingMaxLength);
    }
    if (msg == next) return;
    msg = next;
    notifyListeners();
  }

  void setPay(WalletPayMethodDto v) {
    if (pay.id == v.id) return;
    pay = v;
    notifyListeners();
  }

  void setChatInfo({
    required String conversationId,
    bool group = false,
    String userId = '',
    String name = '',
    String avatar = '',
  }) {
    convId = conversationId;
    isGroup = group;

    if (!group) {
      type = RpType.normal;
      receiverId = userId.trim();
      receiverName = name.trim();
      receiverAvatar = avatar.trim();
      cnt = '1';
    } else {
      receiverId = '';
      receiverName = '';
      receiverAvatar = '';
    }

    notifyListeners();
  }

  void setGroupCount(int count) {
    if (count <= 0) return;
    groupNum = count.toString();
    notifyListeners();
  }

  static String currentUserId() =>
      ContactSocialCacheStore.safeLoginUserId();

  static bool isSelfUserId(String userId) {
    final selfId = currentUserId();
    final id = userId.trim();
    return selfId.isNotEmpty && id.isNotEmpty && id == selfId;
  }

  void setReceiver(RedPacketMember v) {
    if (type == RpType.exclusive && isSelfUserId(v.userId)) {
      return;
    }
    if (receiverId == v.userId &&
        receiverName == v.name &&
        receiverAvatar == v.avatar) {
      unawaited(_enrichReceiverAvatar(v.userId, v.avatar));
      unawaited(_enrichReceiverNickname(v.userId));
      return;
    }
    receiverId = v.userId;
    receiverName = TransferPartyNameResolver.nicknameOf(
      userId: v.userId,
      nickHint: v.name,
    );
    if (receiverName.isEmpty) {
      receiverName = v.name;
    }
    receiverAvatar = UserAvatarHelper.usableAvatarOrEmpty(v.avatar);
    notifyListeners();
    unawaited(_enrichReceiverAvatar(v.userId, v.avatar));
    unawaited(_enrichReceiverNickname(v.userId));
  }

  Future<void> _enrichReceiverNickname(String userId) async {
    final nick = await TransferPartyNameResolver.resolveNickname(
      userId: userId,
      nickHint: receiverName,
    );
    if (nick.isEmpty || nick == receiverName) {
      return;
    }
    receiverName = nick;
    notifyListeners();
  }

  Future<void> _enrichReceiverAvatar(String userId, String fallback) async {
    final id = userId.trim();
    if (id.isEmpty) return;
    final resolved = await UserAvatarHelper.resolveChatPeerFaceUrl(
      peerUserId: id,
      messageFaceUrl: fallback,
    );
    final next = UserAvatarHelper.usableAvatarOrEmpty(resolved);
    if (next.isEmpty || next == receiverAvatar) return;
    receiverAvatar = next;
    notifyListeners();
  }

  String? check() {
    if (!isGroup && type != RpType.normal) {
      return AppI18n.current.t(
        zhHans: '单聊仅支持普通红包',
        zhHant: '單聊僅支援普通紅包',
        en: 'Only regular red packets are supported in one-to-one chats.',
        ja: '個別チャットでは通常の紅包のみ利用できます。',
        ko: '개인 채팅에서는 일반 레드패킷만 지원됩니다.',
      );
    }
    if (!pay.enabled) {
      return AppI18n.current.t(
        zhHans: '当前付款方式不可用',
        zhHant: '目前付款方式不可用',
        en: 'The current payment method is unavailable.',
        ja: '現在の支払い方法は利用できません。',
        ko: '현재 결제 수단을 사용할 수 없습니다.',
      );
    }

    if (isGroup && (type == RpType.lucky || type == RpType.normal)) {
      final countErr = _checker.checkCount(raw: cnt, max: maxGroupNum);
      if (countErr != WalletOrderErr.none) {
        if (countErr == WalletOrderErr.groupNotReady) {
          return AppI18n.current.t(
            zhHans: '群成员信息未加载，请稍后重试',
            zhHant: '群成員資訊尚未載入，請稍後再試',
            en: 'Group member information is still loading. Please try again later.',
            ja: 'グループメンバー情報を読み込み中です。しばらくしてからもう一度お試しください。',
            ko: '그룹 멤버 정보를 불러오는 중입니다. 잠시 후 다시 시도해 주세요.',
          );
        }
        if (countErr == WalletOrderErr.countOverLimit) {
          return AppI18n.current.t(
            zhHans: '红包个数不能超过群人数',
            zhHant: '紅包個數不能超過群人數',
            en: 'The number of red packets cannot exceed the number of group members.',
            ja: '紅包の個数はグループ人数を超えることはできません。',
            ko: '레드패킷 개수는 그룹 인원 수를 초과할 수 없습니다.',
          );
        }
        return AppI18n.current.t(
          zhHans: '请输入红包个数',
          zhHant: '請輸入紅包個數',
          en: 'Enter the number of red packets.',
          ja: '紅包の個数を入力してください。',
          ko: '레드패킷 개수를 입력해 주세요.',
        );
      }
    }

    if (isGroup && type == RpType.exclusive && receiverId.trim().isEmpty) {
      return AppI18n.current.t(
        zhHans: '请选择接收人',
        zhHant: '請選擇接收人',
        en: 'Select a recipient.',
        ja: '受取人を選択してください。',
        ko: '수령인을 선택해 주세요.',
      );
    }

    if (isGroup &&
        type == RpType.exclusive &&
        isSelfUserId(receiverId)) {
      return AppI18n.current.t(
        zhHans: '专属红包不能发给自己',
        zhHant: '專屬紅包不能發給自己',
        en: 'Exclusive red packets cannot be sent to yourself.',
        ja: '専用お年玉は自分に送れません。',
        ko: '전용 레드패킷은 본인에게 보낼 수 없습니다.',
      );
    }

    if (amt.trim().isEmpty) return WalletOrderErr.emptyAmount.text;

    final minor = amountMinor;
    if (minor == null) return WalletOrderErr.invalidAmount.text;
    if (minor <= 0) return WalletOrderErr.invalidAmount.text;

    final dot = amt.trim().indexOf('.');
    if (dot >= 0 && amt.trim().length - dot - 1 > pay.scale) {
      return WalletOrderErr.invalidPrecision.text;
    }

    if ((type == RpType.lucky || type == RpType.normal) &&
        cntNum > _maxPacketCount) {
      return AppI18n.current.format(
        zhHans: '红包个数不能超过 {count}',
        zhHant: '紅包個數不能超過 {count}',
        en: 'The number of red packets cannot exceed {count}.',
        ja: '紅包の個数は {count} 個を超えることはできません。',
        ko: '레드패킷 개수는 {count}개를 초과할 수 없습니다.',
        vars: {'count': _maxPacketCount.toString()},
      );
    }

    final maxTotalMinor = 100000 * _pow10(pay.scale);
    if (type == RpType.normal &&
        cntNum > 0 &&
        minor > maxTotalMinor ~/ cntNum) {
      return AppI18n.current.t(
        zhHans: '红包总金额超过限制',
        zhHant: '紅包總金額超過限制',
        en: 'The total red packet amount exceeds the limit.',
        ja: '紅包の合計金額が上限を超えています。',
        ko: '레드패킷 총액이 제한을 초과했습니다.',
      );
    }
    if (totalMinor > maxTotalMinor) {
      return AppI18n.current.t(
        zhHans: '红包总金额超过限制',
        zhHant: '紅包總金額超過限制',
        en: 'The total red packet amount exceeds the limit.',
        ja: '紅包の合計金額が上限を超えています。',
        ko: '레드패킷 총액이 제한을 초과했습니다.',
      );
    }

    if (type == RpType.lucky) {
      final minEach =
          WalletAmount.parseStrict('0.01', coin: pay.coin, scale: pay.scale)
                  ?.minor ??
              1;
      if (totalMinor < cntNum * minEach) {
        return AppI18n.current.t(
          zhHans: '总金额不能低于红包个数最小金额',
          zhHant: '總金額不能低於紅包個數的最小金額要求',
          en: 'The total amount cannot be lower than the minimum required for the number of red packets.',
          ja: '合計金額は、紅包個数に対する最低金額を下回ることはできません。',
          ko: '총 금액은 레드패킷 개수에 따른 최소 금액보다 낮을 수 없습니다.',
        );
      }
    }

    final balErr = _checker.checkPayBalance(
      amountMinor: totalMinor,
      amountBalanceMinor: pay.balMinor,
      coin: pay.coin,
      feeMinor: pay.feeMinor,
      feeCoin: pay.feeCoin,
      feeBalanceMinor: pay.feeBalanceMinor,
    );
    if (balErr != WalletOrderErr.none) return balErr.text;
    return null;
  }

  int _pow10(int n) {
    var v = 1;
    for (var i = 0; i < n; i++) {
      v *= 10;
    }
    return v;
  }

  Future<List<RedPacketMember>> loadMembers({bool excludeSelf = false}) async {
    final members =
        await WalletStore.instance.getMembers(convId, repo: _repo);
    final named = members.map((member) {
      final nick = TransferPartyNameResolver.nicknameOf(
        userId: member.userId,
        nickHint: member.name,
      );
      return RedPacketMember(
        userId: member.userId,
        name: nick.isNotEmpty ? nick : member.userId,
        avatar: member.avatar,
        qq: member.qq,
      );
    }).toList(growable: false);
    if (!excludeSelf) return named;
    return named
        .where((member) => !isSelfUserId(member.userId))
        .toList(growable: false);
  }

  String startOrder() {
    clientOrderId = _orderSvc.start('red_packet');
    return clientOrderId;
  }

  void cancelOrderIfIdle() {
    _orderSvc.cancel();
    if (state == WalletOrderState.idle) clientOrderId = '';
  }

  Future<String?> submit(String pwd) async {
    if (state == WalletOrderState.submitting) {
      return WalletOrderErr.duplicateSubmit.text;
    }

    final msg = check();
    if (msg != null) return msg;

    final minor = amountMinor;
    if (minor == null) return WalletOrderErr.invalidAmount.text;
    final clientId = clientOrderId.isEmpty ? startOrder() : clientOrderId;

    state = WalletOrderState.submitting;
    err = '';
    notifyListeners();

    final draft = WalletOrderDraft(
      clientOrderId: clientId,
      type: WalletOrderType.redPacket,
      amountText: totalText,
      amountMinor: totalMinor,
      coin: pay.coin,
      network: pay.net,
      feeMinor: pay.feeMinor,
      feeCoin: pay.feeCoin,
      feeScale: pay.feeScale,
      feeBalanceMinor: pay.feeBalanceMinor,
      receiverId: receiverId,
      receiverName: receiverName,
      memo: effectiveMsg,
      createdAt: DateTime.now().toIso8601String(),
      conversationId: convId,
      businessType: 'wallet_red_packet',
    );

    final ret = await _orderSvc.run(draft, (id) {
      return _repo.sendRedPacket(
        WalletRedPacketReq(
          clientOrderId: id,
          convId: convId,
          isGroup: isGroup,
          rpType: type.name,
          cnt: type == RpType.exclusive ? '1' : cnt,
          amt: amountText,
          amountMinor: minor.toString(),
          totalAmt: totalText,
          totalMinor: totalMinor.toString(),
          coin: pay.coin,
          payId: pay.id,
          net: pay.net,
          pwd: pwd,
          msg: effectiveMsg,
          toUserId: receiverId,
        ),
      );
    });

    if (_dead) return '页面已关闭';
    lastResult = ret;

    if (!ret.ok) {
      state = WalletOrderState.idle;
      err = ret.msg.isEmpty ? ret.err.text : ret.msg;
      notifyListeners();
      return err;
    }

    orderId = ret.orderId;
    final sentClientOrderId =
        ret.clientOrderId.isNotEmpty ? ret.clientOrderId : clientOrderId;
    state = (ret.state == WalletOrderState.accepted ||
            ret.state == WalletOrderState.pending ||
            ret.state == WalletOrderState.unknown)
        ? ret.state
        : WalletOrderState.success;
    clientOrderId = '';
    WalletOrderEvents.notifyRecord();
    if (_shouldReloadBalance(state)) {
      WalletOrderEvents.notifyBalance();
    }
    await _notifyChatCard(ret, sentClientOrderId);
    notifyListeners();
    return null;
  }

  Future<void> _notifyChatCard(
    WalletOrderResult ret,
    String sentClientOrderId,
  ) async {
    if (convId.trim().isEmpty) {
      debugPrint(
        'wallet-card skip empty-conv after REST orderId=${ret.orderId} '
        'clientOrderId=$sentClientOrderId',
      );
      return;
    }

    await WalletCardReplayGuard.instance.rememberRestSuccess(
      orderId: ret.orderId,
      clientOrderId: sentClientOrderId,
    );

    var exclusiveName = receiverName;
    if (type == RpType.exclusive) {
      final resolved = await TransferPartyNameResolver.resolveNickname(
        userId: receiverId,
        nickHint: receiverName,
      );
      if (resolved.isNotEmpty) {
        exclusiveName = resolved;
        receiverName = resolved;
      }
    }

    await WalletCardImSender.instance.sendAfterRest({
      'type': 'wallet_red_packet',
      'sendSource': 'payment',
      'orderId': ret.orderId,
      'clientOrderId': sentClientOrderId,
      'conversationId': convId,
      'isGroup': isGroup,
      'currency': pay.id,
      'amount': totalMinor,
      'status': _chatCardStatus(ret.state),
      'greeting': effectiveMsg,
      'packetType': redPacketPacketTypeCode(type, isGroup: isGroup),
      if (type == RpType.exclusive) ...{
        'packetCount': '1',
        'receiverId': receiverId,
        'receiverName': exclusiveName,
        'receiverAvatar': receiverAvatar,
        'toUserId': receiverId,
        'toUserName': exclusiveName,
        'toUserAvatar': receiverAvatar,
      } else if (cnt.trim().isNotEmpty)
        'packetCount': cnt.trim(),
    });
  }

  bool _shouldReloadBalance(WalletOrderState state) {
    return state == WalletOrderState.success ||
        state == WalletOrderState.accepted ||
        state == WalletOrderState.pending ||
        state == WalletOrderState.unknown;
  }

  String _chatCardStatus(WalletOrderState state) {
    switch (state) {
      case WalletOrderState.success:
        return 'success';
      case WalletOrderState.failed:
      case WalletOrderState.expired:
      case WalletOrderState.cancelled:
      case WalletOrderState.refunded:
        return 'failed';
      case WalletOrderState.accepted:
      case WalletOrderState.pending:
      case WalletOrderState.unknown:
      case WalletOrderState.submitting:
      case WalletOrderState.confirming:
      case WalletOrderState.password:
      case WalletOrderState.created:
      case WalletOrderState.idle:
        return 'pending';
    }
  }

  void hideFlow() {
    if (state == WalletOrderState.accepted ||
        state == WalletOrderState.pending ||
        state == WalletOrderState.unknown ||
        state == WalletOrderState.success ||
        state == WalletOrderState.failed) {
      state = WalletOrderState.idle;
      clientOrderId = '';
      err = '';
      notifyListeners();
    }
  }

  RpForm toForm() {
    return RpForm(type: type, cnt: cnt, amt: amt, msg: msg, pay: pay);
  }

  @override
  void dispose() {
    _dead = true;
    super.dispose();
  }

}

import 'dart:async' show unawaited;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/api/sangong_admin_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/sangong_game_http.dart';
import 'package:tencent_cloud_chat_demo/src/api/sangong_settings_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/sangong_admin_models.dart';
import 'package:tencent_cloud_chat_demo/src/models/sangong_game_settings.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/utils/sangong_admin_error_message.dart';
import 'package:tencent_cloud_chat_demo/src/utils/sangong_admin_operator_label.dart';
import 'package:tencent_cloud_chat_demo/src/utils/sangong_quick_setup_banker_input.dart';
import 'package:tencent_cloud_chat_demo/utils/dio_error_message.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';

/// 特权用户在他人资料页使用的三公管理面板。
class UserProfileGameAdminPanel extends StatefulWidget {
  const UserProfileGameAdminPanel({
    super.key,
    required this.targetUserId,
    required this.displayName,
    this.embedded = false,
  });

  final String targetUserId;
  final String displayName;

  /// 嵌入父级卡片时不再单独铺底色，避免加好友页等场景双层卡片。
  final bool embedded;

  @override
  State<UserProfileGameAdminPanel> createState() =>
      _UserProfileGameAdminPanelState();
}

class _UserProfileGameAdminPanelState extends State<UserProfileGameAdminPanel> {
  static const double _captionFontSize = 15;
  static const double _actionFontSize = 15;
  static const double _inputFontSize = 17;
  static const double _hintFontSize = 16;
  static const double _summaryFontSize = 15;
  static const double _captionLineHeight = 20;
  static const double _summaryBlockHeight = 40;
  static const Color _pointsAmountColor = AppColors.primaryRed;

  late final TextEditingController _pointsInputController;
  late final TextEditingController _bankerInputController;
  late final TextEditingController _jointAmountInputController;
  late final FocusNode _pointsFocusNode;
  late final FocusNode _bankerFocusNode;
  late final FocusNode _jointFocusNode;

  bool _loading = true;
  bool _submitting = false;
  String? _loadError;

  int _currentPoints = 0;
  int? _targetInternalUserId;
  SangongUserGroupInfo _userGroup = const SangongUserGroupInfo();

  SangongAdminSession _session = const SangongAdminSession();
  SangongGameSettings _settings = SangongGameSettings.defaults();

  double _apiSharePercent = 0;
  double _previewSharePercent = 0;

  @override
  void initState() {
    super.initState();
    _pointsInputController = TextEditingController();
    _bankerInputController = TextEditingController();
    _jointAmountInputController = TextEditingController();
    _pointsFocusNode = FocusNode();
    _bankerFocusNode = FocusNode();
    _jointFocusNode = FocusNode();
    _jointAmountInputController.addListener(_onJointAmountChanged);
    _bankerInputController.addListener(_onBankerInputChanged);
    unawaited(_loadAll());
  }

  @override
  void dispose() {
    _jointAmountInputController.removeListener(_onJointAmountChanged);
    _bankerInputController.removeListener(_onBankerInputChanged);
    _pointsInputController.dispose();
    _bankerInputController.dispose();
    _jointAmountInputController.dispose();
    _pointsFocusNode.dispose();
    _bankerFocusNode.dispose();
    _jointFocusNode.dispose();
    super.dispose();
  }

  String get _imUserId => widget.targetUserId.trim();

  String get _displayName {
    final name = widget.displayName.trim();
    return name.isNotEmpty ? name : _imUserId;
  }

  SangongAdminRound? get _round => _session.round;

  int get _doorCount => _settings.doorCount.clamp(2, 10);

  bool get _bankerInputFilled => _bankerInputController.text.trim().isNotEmpty;

  bool get _isTargetCoBankMember {
    final member = _round?.coBank.memberForImUserId(_imUserId);
    if (member != null) {
      return true;
    }
    final userId = _targetInternalUserId;
    if (userId != null && userId > 0) {
      return _round?.coBank.memberForUserId(userId) != null;
    }
    return false;
  }

  double get _displaySharePercent {
    final inputAmount =
        int.tryParse(_jointAmountInputController.text.trim()) ?? 0;
    if (inputAmount > 0) {
      return _previewSharePercent;
    }
    return _apiSharePercent;
  }

  double _calcPreviewSharePercent(int amount) {
    final poolTotal = _round?.coBank.poolTotal ?? 0;
    if (amount <= 0) {
      return _apiSharePercent;
    }
    final base = poolTotal + amount;
    if (base <= 0) {
      return 0;
    }
    final percent = (amount * 100) / base;
    return double.parse(percent.toStringAsFixed(2));
  }

  void _onJointAmountChanged() {
    final amount = int.tryParse(_jointAmountInputController.text.trim()) ?? 0;
    final percent = _calcPreviewSharePercent(amount);
    if (percent != _previewSharePercent) {
      setState(() => _previewSharePercent = percent);
    }
  }

  void _onBankerInputChanged() {
    setState(() {});
  }

  void _applySession(SangongAdminSession session) {
    _session = session;
    SangongCoBankMember? member =
        session.round?.coBank.memberForImUserId(_imUserId);
    final userId = _targetInternalUserId;
    if (member == null && userId != null) {
      member = session.round?.coBank.memberForUserId(userId);
    }
    _apiSharePercent = member?.sharePercent ?? 0;
    _previewSharePercent = _apiSharePercent;
  }

  Future<void> _loadAll({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }

    if (!SangongGameHttp.hasAuth) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = _i18n(
          zhHans: '请先登录',
          zhHant: '請先登入',
          en: 'Please sign in first',
        );
      });
      return;
    }
    final tenantReady = await SangongAdminApi.instance.ensureTenantSelected();
    if (!tenantReady) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = _i18n(
          zhHans: '请先进入游戏群以确定租户',
          zhHant: '請先進入遊戲群以確定租戶',
          en: 'Open a game group to select tenant',
        );
      });
      return;
    }

    SangongGameSettings settings = SangongGameSettings.defaults();
    SangongAdminSession session = const SangongAdminSession();
    SangongAdminUserReport? report;
    String? adminError;

    try {
      settings = await SangongSettingsApi.instance.fetch();
    } catch (error) {
      adminError ??= DioErrorMessage.forApp(error);
    }

    try {
      session = await SangongAdminApi.instance.fetchSession();
    } catch (error) {
      adminError ??= _formatAdminLoadError(error);
    }

    try {
      report = await SangongAdminApi.instance.findUserReport(_imUserId);
    } catch (error) {
      adminError ??= _formatAdminLoadError(error);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _applySession(session);
      _settings = settings;
      _currentPoints = report?.balance ?? 0;
      _targetInternalUserId = report?.userId;
      _userGroup = report?.group ?? const SangongUserGroupInfo();
      _loading = false;
      _loadError = adminError;
    });
  }

  String _formatAdminLoadError(Object error) {
    if (error is DioError) {
      final status = error.response?.statusCode;
      if (status == 401) {
        return _i18n(
          zhHans: '登录已失效，请重新登录',
          zhHant: '登入已失效，請重新登入',
          en: 'Session expired, please sign in again',
        );
      }
      if (status == 403) {
        return _i18n(
          zhHans: '需要有效的游戏特权',
          zhHant: '需要有效的遊戲特權',
          en: 'Game privilege required',
        );
      }
    }
    return DioErrorMessage.forApp(error);
  }

  String _bankerSummaryText() {
    final bankerDoor = _round?.bankerDoor;
    final limit = _round?.bankerLimit;
    final limitLabel = limit != null && limit > 0 ? '限额$limit' : '不限额';
    if (bankerDoor != null && bankerDoor >= 1) {
      return '庄$bankerDoor门 $limitLabel';
    }
    return '庄 $limitLabel';
  }

  String? _validateAssignBanker(int door) {
    if (door < 1 || door > _doorCount) {
      return _i18n(
        zhHans: '庄门需在 1～$_doorCount 之间',
        zhHant: '莊門需在 1～$_doorCount 之間',
        en: 'Door must be between 1 and $_doorCount',
      );
    }
    return null;
  }

  String _coBankMembersSummaryText() {
    final coBank = _round?.coBank;
    final poolTotal = coBank?.poolTotal ?? 0;
    final members = coBank?.members ?? const [];
    if (members.isEmpty) {
      return '庄池：$poolTotal · 合庄庄家:【$_displayName】0.00%';
    }
    final parts = members
        .map(
          (m) =>
              '【${m.nickname.trim().isNotEmpty ? m.nickname.trim() : m.userId}】${formatSangongSharePercent(m.sharePercent)}%',
        )
        .toList();
    return '庄池：$poolTotal · 合庄庄家: ${parts.join('，')}';
  }

  int? _readAmount(TextEditingController controller) {
    return int.tryParse(controller.text.trim());
  }

  Future<void> _runSubmit(
    Future<void> Function() action, {
    String Function(Object error)? formatError,
  }) async {
    if (_submitting) {
      return;
    }
    setState(() => _submitting = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        final message = formatError != null
            ? formatError(error)
            : DioErrorMessage.forApp(error);
        ToastUtils.toast(message);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String get _operatorLabel => resolveSangongAdminOperatorLabel();

  Future<void> _onCredit() async {
    final amount = _readAmount(_pointsInputController);
    if (amount == null || amount <= 0) {
      ToastUtils.toast(_i18n(zhHans: '请输入有效金额', zhHant: '請輸入有效金額', en: 'Enter a valid amount'));
      return;
    }
    await _runSubmit(() async {
      final result = await SangongAdminApi.instance.credit(
        imUserId: _imUserId,
        amount: amount,
        operator: _operatorLabel,
      );
      if (!mounted) return;
      setState(() {
        _currentPoints = result.balance;
        _userGroup = result.group;
        _pointsInputController.clear();
      });
    });
  }

  String? _validateDebitByBankerRole() {
    final round = _round;
    if (round == null || round.id <= 0 || round.isRoundClosed) {
      return null;
    }
    final isBanker = round.bankerImUserId.trim() == _imUserId;
    if (!isBanker && !_isTargetCoBankMember) {
      return null;
    }
    final period = round.periodNo;
    if (period > 0) {
      return _i18n(
        zhHans: '第 $period 期庄/合庄对局未结算，暂不可下分',
        zhHant: '第 $period 期莊/合莊對局未結算，暫不可下分',
        en: 'Unsettled banker/co-bank round (period $period). Debit blocked',
      );
    }
    return _i18n(
      zhHans: '当前有未结算的庄/合庄对局，暂不可下分',
      zhHant: '當前有未結算的莊/合莊對局，暫不可下分',
      en: 'Unsettled banker/co-bank round. Debit blocked',
    );
  }

  Future<void> _onDebit() async {
    final amount = _readAmount(_pointsInputController);
    if (amount == null || amount <= 0) {
      ToastUtils.toast(_i18n(zhHans: '请输入有效金额', zhHant: '請輸入有效金額', en: 'Enter a valid amount'));
      return;
    }
    if (amount > _currentPoints) {
      ToastUtils.toast(
        _i18n(
          zhHans: '余额不足，无法下分（当前可下分 $_currentPoints）',
          zhHant: '餘額不足，無法下分（當前可下分 $_currentPoints）',
          en: 'Insufficient balance for debit (available: $_currentPoints)',
        ),
      );
      return;
    }
    final bankerBlock = _validateDebitByBankerRole();
    if (bankerBlock != null) {
      ToastUtils.toast(bankerBlock);
      return;
    }
    await _runSubmit(
      () async {
        final result = await SangongAdminApi.instance.debit(
          imUserId: _imUserId,
          amount: amount,
          operator: _operatorLabel,
        );
        if (!mounted) return;
        setState(() {
          _currentPoints = result.balance;
          _userGroup = result.group;
          _pointsInputController.clear();
        });
      },
      formatError: SangongAdminErrorMessage.fromDebit,
    );
  }

  Future<void> _onSetGroup() async {
    final group = _pointsInputController.text.trim();
    if (group.isEmpty) {
      ToastUtils.toast(_i18n(zhHans: '请输入分组编号', zhHant: '請輸入分組編號', en: 'Enter group code'));
      return;
    }
    await _runSubmit(() async {
      final result = await SangongAdminApi.instance.setUserGroup(
        imUserId: _imUserId,
        group: group,
      );
      if (!mounted) return;
      setState(() {
        _currentPoints = result.balance;
        _userGroup = result.group;
        _pointsInputController.clear();
      });
    });
  }

  Future<void> _onAssignBanker() async {
    final parsed = parseSangongBankerSetupText(_bankerInputController.text);
    final door = parsed.door;
    if (door == null) {
      ToastUtils.toast(
        _i18n(
          zhHans: '请输入庄门（如 2 或 2.5000）',
          zhHant: '請輸入莊門（如 2 或 2.5000）',
          en: 'Enter door (e.g. 2 or 2.5000)',
        ),
      );
      return;
    }
    final validationError = _validateAssignBanker(door);
    if (validationError != null) {
      ToastUtils.toast(validationError);
      return;
    }
    final limit = parsed.hasExplicitLimit ? parsed.limit : null;
    await _runSubmit(() async {
      final session = await SangongAdminApi.instance.assignBanker(
        imUserId: _imUserId,
        door: door,
        limit: limit,
        nickname: _displayName,
      );
      if (!mounted) return;
      setState(() {
        _applySession(session);
        _bankerInputController.clear();
      });
    });
  }

  Future<void> _onSetBankerLimit() async {
    final parsed = parseSangongBankerSetupText(_bankerInputController.text);
    int? door;
    int? limit;

    if (parsed.hasExplicitLimit) {
      door = parsed.door;
      limit = parsed.limit;
    } else if (parsed.door != null) {
      door = _round?.bankerDoor;
      limit = parsed.door;
    }

    if (door == null || door < 1) {
      ToastUtils.toast(
        _i18n(
          zhHans: '请先定庄或输入「庄门.限额」',
          zhHant: '請先定莊或輸入「莊門.限額」',
          en: 'Assign banker first or enter door.limit',
        ),
      );
      return;
    }
    if (limit == null || limit < 0) {
      ToastUtils.toast(
        _i18n(
          zhHans: '请输入有效展示限额',
          zhHant: '請輸入有效展示限額',
          en: 'Enter a valid display limit',
        ),
      );
      return;
    }
    final validationError = _validateAssignBanker(door);
    if (validationError != null) {
      ToastUtils.toast(validationError);
      return;
    }
    await _runSubmit(() async {
      final session = await SangongAdminApi.instance.assignBanker(
        imUserId: _imUserId,
        door: door!,
        limit: limit,
        nickname: _displayName,
      );
      if (!mounted) return;
      setState(() {
        _applySession(session);
        _bankerInputController.clear();
      });
    });
  }

  Future<void> _onSendBanker() async {
    await _runSubmit(() async {
      await SangongAdminApi.instance.sendBankerNotification();
    });
  }

  Future<void> _onSendCoBank() async {
    await _runSubmit(() async {
      await SangongAdminApi.instance.sendCoBankNotification();
    });
  }

  Future<void> _onRemoveCoBank() async {
    final userId = _targetInternalUserId;
    if (userId == null || userId <= 0) {
      ToastUtils.toast(
        _i18n(
          zhHans: '未找到该用户游戏账号',
          zhHant: '未找到該用戶遊戲帳號',
          en: 'Game user not found',
        ),
      );
      return;
    }
    if (!_isTargetCoBankMember) {
      ToastUtils.toast(
        _i18n(
          zhHans: '该用户未合庄',
          zhHant: '該用戶未合莊',
          en: 'User is not a co-banker',
        ),
      );
      return;
    }
    await _runSubmit(() async {
      final session = await SangongAdminApi.instance.removeCoBank(
        userId: userId,
      );
      if (!mounted) return;
      setState(() {
        _applySession(session);
        _jointAmountInputController.clear();
      });
    });
  }

  Future<void> _onAddCoBank() async {
    final roundId = _round?.id;
    final userId = _targetInternalUserId;
    if (roundId == null || roundId <= 0) {
      ToastUtils.toast(_i18n(zhHans: '当前无有效局', zhHant: '當前無有效局', en: 'No active round'));
      return;
    }
    if (userId == null || userId <= 0) {
      ToastUtils.toast(_i18n(zhHans: '未找到该用户游戏账号', zhHant: '未找到該用戶遊戲帳號', en: 'Game user not found'));
      return;
    }
    final amount = _readAmount(_jointAmountInputController);
    if (amount == null || amount <= 0) {
      ToastUtils.toast(_i18n(zhHans: '请输入合庄金额', zhHant: '請輸入合莊金額', en: 'Enter co-bank amount'));
      return;
    }
    await _runSubmit(() async {
      final session = await SangongAdminApi.instance.addCoBank(
        roundId: roundId,
        userId: userId,
        amount: amount,
      );
      if (!mounted) return;
      setState(() {
        _applySession(session);
        _jointAmountInputController.clear();
      });
    });
  }

  String _i18n({
    required String zhHans,
    String? zhHant,
    String? en,
    String? ja,
    String? ko,
  }) {
    return AppI18n.of(context).t(
      zhHans: zhHans,
      zhHant: zhHant ?? zhHans,
      en: en ?? zhHans,
      ja: ja ?? zhHans,
      ko: ko ?? zhHans,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final isDark =
        Provider.of<DefaultThemeData>(context).currentThemeType ==
            ThemeType.dark;
    final primary = theme.primaryColor ?? AppColors.primaryBlue;
    final cardColor =
        theme.conversationItemBgColor ?? AppColors.card(dark: isDark);
    final inputFill =
        isDark ? const Color(0xFF2A2D33) : const Color(0xFFF3F4F6);
    final borderColor = AppColors.line(dark: isDark);
    final labelColor = primary;
    final bodyColor = theme.darkTextColor ?? AppColors.text(dark: isDark);
    final mutedActionColor =
        theme.weakTextColor ?? AppColors.subText(dark: isDark);
    final disabled = _loading || _submitting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_loadError != null && !_loading) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(widget.embedded ? 12 : 16, 0, 12, 0),
            child: Column(
              children: [
                Text(
                  _loadError!,
                  style: TextStyle(
                    color: AppColors.subText(dark: isDark),
                    fontSize: _captionFontSize,
                  ),
                  textAlign: TextAlign.center,
                ),
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: () => unawaited(_loadAll()),
                    child: Text(
                      _i18n(zhHans: '重试', zhHant: '重試', en: 'Retry'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        _buildPanelBody(
          primary: primary,
          inputFill: inputFill,
          borderColor: borderColor,
          labelColor: labelColor,
          bodyColor: bodyColor,
          mutedActionColor: mutedActionColor,
          cardColor: cardColor,
          disabled: disabled,
          dataLoading: _loading,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required Widget child,
    required Color cardColor,
    required Color borderColor,
    required bool isDark,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.embedded ? 12 : 16,
        0,
        widget.embedded ? 12 : 16,
        8,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? borderColor.withValues(alpha: 0.55)
                : AppColors.lightLine.withValues(alpha: 0.65),
            width: 0.5,
          ),
          boxShadow: widget.embedded
              ? const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: child,
        ),
      ),
    );
  }

  Widget _buildPanelBody({
    required Color primary,
    required Color inputFill,
    required Color borderColor,
    required Color labelColor,
    required Color bodyColor,
    required Color mutedActionColor,
    required Color cardColor,
    required bool disabled,
    required bool dataLoading,
    required bool isDark,
  }) {
    final skeletonColor = borderColor.withValues(alpha: isDark ? 0.55 : 0.85);
    final groupLabel = _userGroup.displayLabel;
    final pointsCaptionKey = groupLabel.isNotEmpty
        ? '当前积分 $_currentPoints · 分组 $groupLabel'
        : '当前积分 $_currentPoints';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionCard(
          cardColor: cardColor,
          borderColor: borderColor,
          isDark: isDark,
          child: _buildCompactBlock(
            caption: _captionOrSkeleton(
              text: pointsCaptionKey,
              color: labelColor,
              loading: dataLoading,
              skeletonColor: skeletonColor,
              spans: [
                TextSpan(
                  text: '当前积分 ',
                  style: TextStyle(
                    color: labelColor,
                    fontSize: _captionFontSize,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                TextSpan(
                  text: '$_currentPoints',
                  style: const TextStyle(
                    color: _pointsAmountColor,
                    fontSize: _captionFontSize,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                if (groupLabel.isNotEmpty)
                  TextSpan(
                    text: ' · 分组 $groupLabel',
                    style: TextStyle(
                      color: labelColor,
                      fontSize: _captionFontSize,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
              ],
            ),
            input: _buildInput(
              controller: _pointsInputController,
              focusNode: _pointsFocusNode,
              fillColor: inputFill,
              borderColor: borderColor,
              enabled: !disabled,
              hintText: '金额',
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _bankerFocusNode.requestFocus(),
            ),
            actions: [
              _CompactAction('上分', primary, disabled ? null : _onCredit),
              _CompactAction('下分', primary, disabled ? null : _onDebit),
              _CompactAction('分组', primary, disabled ? null : _onSetGroup),
            ],
            mutedColor: mutedActionColor,
          ),
        ),
        _buildSectionCard(
          cardColor: cardColor,
          borderColor: borderColor,
          isDark: isDark,
          child: _buildCompactBlock(
            caption: _captionOrSkeleton(
              text: _bankerSummaryText(),
              color: bodyColor,
              loading: dataLoading,
              skeletonColor: skeletonColor,
            ),
            input: _buildInput(
              controller: _bankerInputController,
              focusNode: _bankerFocusNode,
              fillColor: inputFill,
              borderColor: borderColor,
              enabled: !disabled,
              hintText: '庄门.限额',
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _jointFocusNode.requestFocus(),
            ),
            actions: [
              _CompactAction(
                '定庄',
                _bankerInputFilled ? primary : mutedActionColor,
                !disabled && _bankerInputFilled ? _onAssignBanker : null,
              ),
              _CompactAction(
                '限额',
                _bankerInputFilled ? primary : mutedActionColor,
                !disabled && _bankerInputFilled ? _onSetBankerLimit : null,
              ),
              _CompactAction('发送', primary, disabled ? null : _onSendBanker),
            ],
            mutedColor: mutedActionColor,
          ),
        ),
        _buildSectionCard(
          cardColor: cardColor,
          borderColor: borderColor,
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCompactBlock(
                caption: _captionOrSkeleton(
                  text: '合庄占股 ${formatSangongSharePercent(_displaySharePercent)}%',
                  color: bodyColor,
                  loading: dataLoading,
                  skeletonColor: skeletonColor,
                ),
                input: _buildInput(
                  controller: _jointAmountInputController,
                  focusNode: _jointFocusNode,
                  fillColor: inputFill,
                  borderColor: borderColor,
                  enabled: !disabled,
                  hintText: '金额',
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                ),
                actions: [
                  _CompactAction(
                    '设置',
                    mutedActionColor,
                    disabled ? null : _onAddCoBank,
                  ),
                  _CompactAction(
                    '取消合庄',
                    _isTargetCoBankMember ? primary : mutedActionColor,
                    !disabled && _isTargetCoBankMember
                        ? _onRemoveCoBank
                        : null,
                  ),
                  _CompactAction(
                    '发送',
                    primary,
                    disabled ? null : _onSendCoBank,
                  ),
                ],
                mutedColor: mutedActionColor,
              ),
              const SizedBox(height: 8),
              _buildCoBankSummaryLine(
                text: _coBankMembersSummaryText(),
                color: labelColor,
                loading: dataLoading,
                skeletonColor: skeletonColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _captionOrSkeleton({
    required String text,
    required Color color,
    required bool loading,
    required Color skeletonColor,
    List<InlineSpan>? spans,
  }) {
    return SizedBox(
      height: _captionLineHeight,
      width: double.infinity,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.centerLeft,
            fit: StackFit.expand,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        child: loading
            ? _buildSkeletonBar(
                key: const ValueKey('caption_skeleton'),
                width: double.infinity,
                height: 15,
                color: skeletonColor,
              )
            : Align(
                key: ValueKey('caption_$text'),
                alignment: Alignment.centerLeft,
                child: spans != null
                    ? Text.rich(
                        TextSpan(children: spans),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: _captionFontSize,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
              ),
      ),
    );
  }

  Widget _buildCoBankSummaryLine({
    required String text,
    required Color color,
    required bool loading,
    required Color skeletonColor,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: SizedBox(
        height: _summaryBlockHeight,
        width: double.infinity,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              alignment: Alignment.topLeft,
              fit: StackFit.expand,
              children: [
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            );
          },
          child: loading
              ? _buildSkeletonBar(
                  key: const ValueKey('summary_skeleton'),
                  width: double.infinity,
                  height: 15,
                  color: skeletonColor,
                )
              : Text(
                  text,
                  key: ValueKey('summary_$text'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: _summaryFontSize,
                    height: 1.3,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSkeletonBar({
    required double width,
    required double height,
    required Color color,
    Key? key,
  }) {
    return Container(
      key: key,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }

  Widget _buildCompactBlock({
    required Widget caption,
    required Widget input,
    required List<_CompactAction> actions,
    required Color mutedColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        caption,
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: input),
            const SizedBox(width: 10),
            _buildActionGroup(actions: actions, mutedColor: mutedColor),
          ],
        ),
      ],
    );
  }

  Widget _buildActionGroup({
    required List<_CompactAction> actions,
    required Color mutedColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0)
            Container(
              width: 1,
              height: 16,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: mutedColor.withValues(alpha: 0.35),
            ),
          _buildActionLink(actions[i], mutedColor),
        ],
      ],
    );
  }

  Widget _buildActionLink(_CompactAction action, Color mutedColor) {
    final onTap = action.onPressed;
    final color = onTap == null ? mutedColor.withValues(alpha: 0.45) : action.color;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        // 加大热区与间距，降低上分/下分/定庄等相邻按钮误触。
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          action.label,
          style: TextStyle(
            color: color,
            fontSize: _actionFontSize,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required FocusNode focusNode,
    required Color fillColor,
    required Color borderColor,
    bool enabled = true,
    String? hintText,
    bool digitsOnly = true,
    TextInputAction textInputAction = TextInputAction.done,
    ValueChanged<String>? onSubmitted,
  }) {
    final isDark =
        Provider.of<DefaultThemeData>(context).currentThemeType ==
            ThemeType.dark;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      textAlign: TextAlign.right,
      keyboardType: TextInputType.number,
      textInputAction: textInputAction,
      scrollPadding: const EdgeInsets.only(bottom: 120),
      enableSuggestions: false,
      autocorrect: false,
      onSubmitted: onSubmitted,
      inputFormatters: digitsOnly
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      style: TextStyle(
        color: AppColors.text(dark: isDark),
        fontSize: _inputFontSize,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: AppColors.subText(dark: isDark),
          fontSize: _hintFontSize,
          fontWeight: FontWeight.w400,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(
            color: Provider.of<DefaultThemeData>(context).theme.primaryColor ??
                AppColors.primaryBlue,
          ),
        ),
      ),
    );
  }
}

class _CompactAction {
  const _CompactAction(this.label, this.color, this.onPressed);

  final String label;
  final Color color;
  final VoidCallback? onPressed;
}

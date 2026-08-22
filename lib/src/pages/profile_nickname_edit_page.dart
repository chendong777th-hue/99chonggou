import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/api/auth_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/user_api.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:characters/characters.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_remark_policy.dart';
import 'package:tencent_cloud_chat_demo/utils/grapheme_length_limiting_formatter.dart';
import 'package:tencent_cloud_chat_demo/utils/group_name_card_policy.dart';
import 'package:tencent_cloud_chat_demo/utils/nickname_policy.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/utils/user_api_error_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/ui/utils/desktop_modal_layout.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_wide_modal_operation_key.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/wide_popup.dart';

/// 可复用的昵称编辑页（对接 PATCH /me/nickname 与预检接口）。
class ProfileNicknameEditPage extends StatefulWidget {
  const ProfileNicknameEditPage({
    Key? key,
    this.initialNickname = '',
    this.minLength = NicknamePolicy.minLength,
    this.maxLength = NicknamePolicy.maxLength,
    this.title,
    this.hintText,
    this.hintBaseline,
    this.submitLabel,
    this.rulesHint,
    this.onSave,
    this.allowEmpty = false,
    this.prefillBaselineWhenEmpty = false,
    this.treatEmptySubmitAsNoOp = false,
    this.localValidator,
    this.signatureStyleInput = false,
    this.allowLineBreaks = false,
    this.embedded = false,
    this.onFinish,
  }) : super(key: key);

  final String initialNickname;
  final int minLength;
  final int maxLength;
  final String? title;
  final String? hintText;
  /// 输入框为空时优先展示的占位（如原备注名、好友昵称）。
  final String? hintBaseline;
  final String? submitLabel;
  final String? rulesHint;

  /// 非空时走本地校验 + 自定义保存（如群昵称），不走昵称后端接口。
  final Future<bool> Function(String text)? onSave;

  /// 本地保存时是否允许提交空内容（如清空备注）。
  final bool allowEmpty;

  /// 初始内容为空时，是否用 [hintBaseline] 预填输入框（仅展示参考，未改动保存仍为空）。
  final bool prefillBaselineWhenEmpty;

  /// 提交空内容时不保存，直接返回（如未修改昵称/群昵称）。
  final bool treatEmptySubmitAsNoOp;

  /// 本地保存时的校验；为空则使用 [GroupNameCardPolicy]。
  final String? Function(String text)? localValidator;

  /// 与 [ProfileSignatureEditPage] 一致的多行输入区样式（群昵称等）。
  final bool signatureStyleInput;

  /// 是否允许输入换行。好友备注必须为单行。
  final bool allowLineBreaks;

  /// Web / 桌面弹窗内嵌：去掉全屏 AppBar，由外层弹窗标题栏负责关闭。
  final bool embedded;

  /// 嵌入弹窗时结束编辑（保存成功或取消），由外层关闭弹窗并取回结果。
  final ValueChanged<String?>? onFinish;

  static Future<String?> push(
    BuildContext context, {
    String initialNickname = '',
  }) {
    final i18n = AppI18n.of(context);
    final title = i18n.t(
      zhHans: '修改名字',
      zhHant: '修改名字',
      en: 'Edit Name',
      ja: '名前を編集',
      ko: '이름 수정',
    );
    final pageBuilder = ({
      bool embedded = false,
      ValueChanged<String?>? onFinish,
    }) {
      return ProfileNicknameEditPage(
        initialNickname: initialNickname,
        treatEmptySubmitAsNoOp: true,
        title: title,
        embedded: embedded,
        onFinish: onFinish,
      );
    };

    // Web / 宽屏壳：始终弹窗，避免 formFactor 误判成 Mobile 后全屏。
    if (kIsWeb || DesktopModalLayout.isDesktop(context)) {
      return _pushDesktopPopup(
        context,
        title: title,
        height: 260,
        builder: pageBuilder,
      );
    }

    return Navigator.push<String>(
      context,
      AppMaterialPageRoute(
        builder: (context) => pageBuilder(),
      ),
    );
  }

  static Future<String?> pushFriendRemark(
    BuildContext context, {
    required String initialRemark,
    String hintBaseline = '',
    required Future<bool> Function(String remark) onSave,
  }) {
    final i18n = AppI18n.of(context);
    final title = i18n.t(
      zhHans: '修改备注名',
      zhHant: '修改備註名',
      en: 'Edit Remark',
      ja: '備考名を編集',
      ko: '비고 이름 수정',
    );
    final pageBuilder = ({
      bool embedded = false,
      ValueChanged<String?>? onFinish,
    }) {
      return ProfileNicknameEditPage(
        initialNickname: initialRemark,
        hintBaseline: hintBaseline,
        allowEmpty: true,
        prefillBaselineWhenEmpty: true,
        minLength: FriendRemarkPolicy.minLength,
        maxLength: FriendRemarkPolicy.maxLength,
        title: title,
        hintText: i18n.t(
          zhHans: '填写备注名',
          zhHant: '填寫備註名',
          en: 'Enter remark name',
          ja: '備考名を入力',
          ko: '비고 이름 입력',
        ),
        submitLabel: i18n.t(
          zhHans: '确定',
          zhHant: '確定',
          en: 'OK',
          ja: 'OK',
          ko: '확인',
        ),
        rulesHint: i18n.t(
          zhHans: '留空则不设置备注，或输入2-30个字',
          zhHant: '留空則不設置備註，或輸入2-30個字',
          en: 'Leave blank for no remark, or enter 2–30 characters',
          ja: '空欄の場合は備考なし、2〜30文字で入力可',
          ko: '비워두면 비고 없음, 2~30자 입력 가능',
        ),
        signatureStyleInput: false,
        allowLineBreaks: false,
        localValidator: FriendRemarkPolicy.validationMessage,
        onSave: onSave,
        embedded: embedded,
        onFinish: onFinish,
      );
    };

    if (kIsWeb || DesktopModalLayout.isDesktop(context)) {
      return _pushDesktopPopup(
        context,
        title: title,
        height: 260,
        builder: pageBuilder,
      );
    }

    return Navigator.push<String>(
      context,
      AppMaterialPageRoute(
        builder: (context) => pageBuilder(),
      ),
    );
  }

  /// Web / 桌面：居中弹窗编辑，避免全屏铺满。
  static Future<String?> _pushDesktopPopup(
    BuildContext context, {
    required String title,
    double height = 280,
    required ProfileNicknameEditPage Function({
      bool embedded,
      ValueChanged<String?>? onFinish,
    }) builder,
  }) async {
    String? result;
    final size = MediaQuery.sizeOf(context);
    final width = size.width.clamp(400.0, 460.0);
    await TUIKitWidePopup.showPopupWindow(
      operationKey: TUIKitWideModalOperationKey.custom,
      context: context,
      title: title,
      width: width,
      height: height,
      isDarkBackground: false,
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      child: (closeFunc) => builder(
        embedded: true,
        onFinish: (value) {
          result = value;
          closeFunc();
        },
      ),
    );
    return result;
  }

  static Future<String?> pushGroupNameCard(
    BuildContext context, {
    required String initialNameCard,
    String hintBaseline = '',
    required Future<bool> Function(String nameCard) onSave,
  }) {
    final i18n = AppI18n.of(context);
    return Navigator.push<String>(
      context,
      AppMaterialPageRoute(
        builder: (context) => ProfileNicknameEditPage(
          initialNickname: initialNameCard,
          hintBaseline: hintBaseline,
          allowEmpty: true,
          prefillBaselineWhenEmpty: true,
          treatEmptySubmitAsNoOp: true,
          minLength: GroupNameCardPolicy.minLength,
          maxLength: GroupNameCardPolicy.maxLength,
          title: i18n.t(
            zhHans: '修改我的群昵称',
            zhHant: '修改我的群暱稱',
            en: 'Edit My Group Nickname',
            ja: 'グループ内ニックネームを編集',
            ko: '그룹 닉네임 수정',
          ),
          hintText: i18n.t(
            zhHans: '填写群昵称',
            zhHant: '填寫群暱稱',
            en: 'Enter group nickname',
            ja: 'グループニックネームを入力',
            ko: '그룹 닉네임 입력',
          ),
          submitLabel: i18n.t(
            zhHans: '确定',
            zhHant: '確定',
            en: 'OK',
            ja: 'OK',
            ko: '확인',
          ),
          rulesHint: i18n.t(
            zhHans: '留空则不修改，或输入2-20个字',
            zhHant: '留空則不修改，或輸入2-20個字',
            en: 'Leave blank to keep unchanged, or enter 2–20 characters',
            ja: '空欄の場合は変更なし、2〜20文字で入力可',
            ko: '비워두면 변경 없음, 2~20자 입력 가능',
          ),
          signatureStyleInput: true,
          allowLineBreaks: true,
          onSave: onSave,
        ),
      ),
    );
  }

  static Future<String?> pushGroupChatName(
    BuildContext context, {
    required String initialName,
    required Future<bool> Function(String name) onSave,
  }) {
    final i18n = AppI18n.of(context);
    final baseline = initialName.trim();
    return Navigator.push<String>(
      context,
      AppMaterialPageRoute(
        builder: (context) => ProfileNicknameEditPage(
          initialNickname: initialName,
          hintBaseline: baseline,
          allowEmpty: true,
          treatEmptySubmitAsNoOp: true,
          maxLength: 20,
          title: i18n.t(
            zhHans: '群聊名称',
            zhHant: '群聊名稱',
            en: 'Group Name',
            ja: 'グループ名',
            ko: '그룹 이름',
          ),
          hintText: i18n.t(
            zhHans: '请输入群聊名称',
            zhHant: '請輸入群聊名稱',
            en: 'Enter a group name',
            ja: 'グループ名を入力してください',
            ko: '그룹 이름을 입력하세요',
          ),
          submitLabel: i18n.t(
            zhHans: '确定',
            zhHant: '確定',
            en: 'OK',
            ja: 'OK',
            ko: '확인',
          ),
          rulesHint: i18n.t(
            zhHans: '留空则不修改，群聊名称不超过20个字',
            zhHant: '留空則不修改，群聊名稱不超過20個字',
            en: 'Leave blank to keep unchanged; max 20 characters',
            ja: '空欄の場合は変更なし、20文字以内',
            ko: '비워두면 변경 없음, 20자 이내',
          ),
          signatureStyleInput: true,
          allowLineBreaks: true,
          localValidator: _groupChatNameValidationMessage,
          onSave: onSave,
        ),
      ),
    );
  }

  static String? _groupChatNameValidationMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (trimmed.characters.length > 20) {
      return AppI18n.current.t(
        zhHans: '群聊名称不能超过20个字',
        zhHant: '群聊名稱不能超過20個字',
        en: 'Group name cannot exceed 20 characters',
        ja: 'グループ名は20文字以内にしてください',
        ko: '그룹 이름은 20자를 초과할 수 없습니다',
      );
    }
    return null;
  }

  @override
  State<ProfileNicknameEditPage> createState() =>
      _ProfileNicknameEditPageState();
}

class _ProfileNicknameEditPageState extends State<ProfileNicknameEditPage> {
  static const Duration _checkDebounce = Duration(milliseconds: 300);

  bool get _useLocalSave => widget.onSave != null;

  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  Timer? _debounceTimer;
  bool _inputFocused = false;
  bool _loadingProfile = true;
  bool _submitting = false;
  bool _checking = false;

  DateTime? _lastNicknameChangedAt;
  DateTime? _cooldownEndsAt;
  String? _inlineError;
  String? _checkingHint;
  bool _canSubmit = false;
  int _checkSeq = 0;
  late String _currentNickname;

  String _sanitizeInputText(String text) {
    if (widget.allowLineBreaks) {
      return text;
    }
    return text.replaceAll(RegExp(r'[\r\n]+'), '');
  }

  String _initialInputText() {
    final initial = _sanitizeInputText(widget.initialNickname);
    if (initial.trim().isNotEmpty) {
      return initial;
    }
    if (widget.prefillBaselineWhenEmpty) {
      final baseline = widget.hintBaseline?.trim() ?? '';
      if (baseline.isNotEmpty) {
        return baseline;
      }
    }
    return initial;
  }

  String _resolveLocalSubmitText(String text) {
    final trimmed = _sanitizeInputText(text).trim();
    if (widget.prefillBaselineWhenEmpty &&
        _currentNickname.isEmpty &&
        trimmed.isNotEmpty) {
      final baseline = widget.hintBaseline?.trim() ?? '';
      if (baseline.isNotEmpty && trimmed == baseline) {
        return '';
      }
    }
    return trimmed;
  }

  @override
  void initState() {
    super.initState();
    _currentNickname = widget.initialNickname.trim();
    _controller = TextEditingController(text: _initialInputText());
    _controller.addListener(_onTextChanged);
    _focusNode = FocusNode()..addListener(_onFocusChanged);
    if (_useLocalSave) {
      _loadingProfile = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduleCheck(immediate: true);
      });
    } else {
      _loadProfile();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    final focused = _focusNode.hasFocus;
    if (focused != _inputFocused && mounted) {
      setState(() => _inputFocused = focused);
    }
  }

  bool get _showClearButton => _inputEnabled && _inputFocused;

  void _clearInput() {
    _controller.clear();
    _focusNode.requestFocus();
    if (mounted) {
      setState(() {});
    }
    if (!_loadingProfile && (_useLocalSave || _cooldownEndsAt == null)) {
      _scheduleCheck(immediate: true);
    }
  }

  String get _inputHint {
    if (_controller.text.isEmpty) {
      return widget.hintText ?? TIM_t("填写昵称");
    }
    if (_currentNickname.isNotEmpty) {
      return _currentNickname;
    }
    final baseline = widget.hintBaseline?.trim() ?? '';
    if (baseline.isNotEmpty) {
      return baseline;
    }
    return widget.hintText ?? TIM_t("填写昵称");
  }

  Future<void> _loadProfile() async {
    try {
      final me = await AuthApi.instance.fetchMe();
      if (!mounted) return;
      _applyProfile(me);
    } on DioError {
      if (!mounted) return;
      _cooldownEndsAt = null;
      _inlineError = TIM_t("加载失败，请稍后重试");
      _canSubmit = false;
    } catch (_) {
      if (!mounted) return;
      _canSubmit = NicknamePolicy.canEditNow(null);
    } finally {
      if (mounted) {
        setState(() => _loadingProfile = false);
      }
    }
  }

  void _applyProfile(MeResult me) {
    _lastNicknameChangedAt = me.lastNicknameChangedAt;
    _cooldownEndsAt = me.nextNicknameChangeableAt ??
        NicknamePolicy.activeCooldownEnd(me.lastNicknameChangedAt);
    if (_cooldownEndsAt != null &&
        DateTime.now().toUtc().isAfter(_cooldownEndsAt!)) {
      _cooldownEndsAt = null;
    }
    final nickname = me.nickname.trim();
    if (nickname.isNotEmpty) {
      _currentNickname = nickname;
    }
    if (_controller.text.trim().isEmpty) {
      _controller.text = nickname;
    }
    if (_cooldownEndsAt != null) {
      setState(() {
        _inlineError = UserApiErrorMessage.formatCooldownHint(_cooldownEndsAt);
        _checkingHint = null;
        _canSubmit = false;
      });
    } else {
      _scheduleCheck(immediate: true);
    }
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
    if (_loadingProfile || (!_useLocalSave && _cooldownEndsAt != null)) {
      return;
    }
    _scheduleCheck();
  }

  void _scheduleCheck({bool immediate = false}) {
    _debounceTimer?.cancel();
    if (immediate) {
      _runCheck();
      return;
    }
    _debounceTimer = Timer(_checkDebounce, _runCheck);
  }

  bool _isSameAsCurrent(String text) =>
      text.trim() == _currentNickname.trim();

  Future<void> _runCheck() async {
    final seq = ++_checkSeq;
    final text = _controller.text.trim();

    if (_useLocalSave) {
      if (widget.allowEmpty && text.isEmpty) {
        if (!mounted || seq != _checkSeq) return;
        setState(() {
          _checking = false;
          _checkingHint = null;
          _inlineError = null;
          _canSubmit = true;
        });
        return;
      }
      final message = widget.localValidator != null
          ? widget.localValidator!(text)
          : GroupNameCardPolicy.validationMessage(text);
      if (!mounted || seq != _checkSeq) return;
      setState(() {
        _checking = false;
        _checkingHint = null;
        _inlineError = message;
        _canSubmit = message == null;
      });
      return;
    }

    if (text.isEmpty) {
      if (!mounted || seq != _checkSeq) return;
      setState(() {
        _checking = false;
        _checkingHint = null;
        _inlineError = null;
        _canSubmit = widget.treatEmptySubmitAsNoOp;
      });
      return;
    }

    if (_isSameAsCurrent(text)) {
      if (!mounted || seq != _checkSeq) return;
      setState(() {
        _checking = false;
        _checkingHint = null;
        _inlineError = null;
        _canSubmit = false;
      });
      return;
    }

    if (!NicknamePolicy.isLengthValid(text)) {
      if (!mounted || seq != _checkSeq) return;
      setState(() {
        _checking = false;
        _checkingHint = null;
        _inlineError = TIM_t(
          "昵称长度为 ${NicknamePolicy.minLength}-${NicknamePolicy.maxLength} 个字符",
        );
        _canSubmit = false;
      });
      return;
    }

    if (!mounted || seq != _checkSeq) return;
    setState(() {
      _checking = true;
      _checkingHint = TIM_t("校验中...");
      _inlineError = null;
      _canSubmit = false;
    });

    try {
      final result = await UserApi.instance.checkNickname(text);
      if (!mounted || seq != _checkSeq) return;

      final cooldownEnd = NicknamePolicy.resolveCooldownEnd(
        lastNicknameChangedAt: _lastNicknameChangedAt,
        checkNextChangeableAt: result.nextChangeableAt,
        checkReason: result.reason,
      );

      setState(() {
        _checking = false;
        _checkingHint = null;
        _cooldownEndsAt = cooldownEnd;
        if (cooldownEnd != null) {
          _inlineError = UserApiErrorMessage.fromNicknameCheck(
            reason: 'NICKNAME_COOLDOWN',
            nextChangeableAt: cooldownEnd,
          );
          _canSubmit = false;
          return;
        }
        final reasonMessage = UserApiErrorMessage.fromNicknameCheck(
          reason: result.reason,
          nextChangeableAt: result.nextChangeableAt,
        );
        _inlineError =
            reasonMessage.isEmpty ? null : reasonMessage;
        _canSubmit = result.available;
      });
    } on DioError catch (e) {
      if (!mounted || seq != _checkSeq) return;
      setState(() {
        _checking = false;
        _checkingHint = null;
        _inlineError = UserApiErrorMessage.fromNicknameCheckRequest(e);
        _canSubmit = false;
      });
    } catch (e) {
      if (!mounted || seq != _checkSeq) return;
      setState(() {
        _checking = false;
        _checkingHint = null;
        _inlineError = TIM_t("昵称校验失败，请稍后再试");
        _canSubmit = false;
      });
    }
  }

  Future<void> _syncImNickname(String nickname) async {
    final userFullInfo = V2TimUserFullInfo(nickName: nickname);
    await TIMUIKitCore.getInstance().setSelfInfo(userFullInfo: userFullInfo);
  }

  void _finish([String? result]) {
    if (widget.embedded) {
      widget.onFinish?.call(result);
      return;
    }
    if (!mounted) {
      return;
    }
    Navigator.pop(context, result);
  }

  Future<void> _submit() async {
    if (_submitting || !_canSubmit) {
      return;
    }
    if (!_useLocalSave && _cooldownEndsAt != null) {
      return;
    }
    final text = _controller.text.trim();
    final submitText = _useLocalSave ? _resolveLocalSubmitText(text) : text;

    if (_useLocalSave) {
      if (widget.allowEmpty && submitText.isEmpty) {
        if (widget.treatEmptySubmitAsNoOp) {
          _finish();
          return;
        }
      }
      if (!(widget.allowEmpty && submitText.isEmpty)) {
        final message = widget.localValidator != null
            ? widget.localValidator!(submitText)
            : GroupNameCardPolicy.validationMessage(submitText);
        if (message != null) {
          ToastUtils.toast(message);
          return;
        }
      }
      setState(() => _submitting = true);
      try {
        final ok = await widget.onSave!(submitText);
        if (!mounted) return;
        if (ok) {
          _finish(submitText);
        } else {
          ToastUtils.toast(TIM_t("保存失败"));
        }
      } finally {
        if (mounted) {
          setState(() => _submitting = false);
        }
      }
      return;
    }

    if (text.isEmpty) {
      _finish();
      return;
    }

    if (!NicknamePolicy.isLengthValid(text)) {
      ToastUtils.toast(TIM_t(
        "昵称长度为 ${NicknamePolicy.minLength}-${NicknamePolicy.maxLength} 个字符",
      ));
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await UserApi.instance.updateNickname(text);
      final savedNickname = result.nickname.trim().isNotEmpty
          ? result.nickname.trim()
          : text;
      await _syncImNickname(savedNickname);
      if (!mounted) return;
      _finish(savedNickname);
    } on DioError catch (e) {
      if (!mounted) return;
      final message = UserApiErrorMessage.fromNicknameUpdate(e);
      final data = e.response?.data;
      final payload = data is Map ? data : null;
      final next = payload == null
          ? null
          : MeResult.parseIsoDateTime(
              payload['nextChangeableAt'] ?? payload['next_changeable_at'],
            );
      setState(() {
        if (next != null) {
          _cooldownEndsAt = next;
        }
        _inlineError = message;
        _checkingHint = null;
        _canSubmit = false;
      });
    } catch (_) {
      if (mounted) {
        ToastUtils.toast(TIM_t("保存失败"));
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  bool get _inputEnabled =>
      !_loadingProfile && (_useLocalSave || _cooldownEndsAt == null);

  int get _inputCharacterCount => _controller.text.characters.length;

  List<TextInputFormatter> get _inputFormatters => [
        if (!widget.allowLineBreaks)
          FilteringTextInputFormatter.deny(RegExp(r'[\r\n]')),
        GraphemeLengthLimitingTextInputFormatter(widget.maxLength),
      ];

  Widget _buildInputField({
    required String hint,
    required Color inputFill,
    required Color hintColor,
    required Color textColor,
  }) {
    if (widget.signatureStyleInput) {
      return Stack(
        children: [
          Container(
            width: double.infinity,
            constraints: BoxConstraints(
              minHeight: widget.embedded ? 120 : 160,
            ),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: inputFill,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: _inputEnabled,
              inputFormatters: _inputFormatters,
              maxLines: widget.allowLineBreaks
                  ? (widget.embedded ? 4 : 6)
                  : 1,
              minLines: widget.allowLineBreaks
                  ? (widget.embedded ? 3 : 5)
                  : 1,
              style: TextStyle(fontSize: 16, color: textColor, height: 1.4),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(fontSize: 16, color: hintColor),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                filled: true,
                fillColor: inputFill,
                hoverColor: inputFill,
                isCollapsed: true,
                contentPadding: const EdgeInsets.all(4),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (_inputEnabled &&
                    _canSubmit &&
                    !_checking &&
                    !_submitting) {
                  _submit();
                }
              },
            ),
          ),
          if (_showClearButton)
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                onPressed: _clearInput,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                icon: Icon(Icons.cancel, size: 18, color: hintColor),
              ),
            ),
          Positioned(
            right: 8,
            bottom: 8,
            child: Text(
              '$_inputCharacterCount/${widget.maxLength}',
              style: TextStyle(fontSize: 14, color: hintColor),
            ),
          ),
        ],
      );
    }

    return Container(
      height: 48,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: inputFill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: _inputEnabled,
              inputFormatters: _inputFormatters,
              maxLines: 1,
              style: TextStyle(fontSize: 16, color: textColor),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(fontSize: 16, color: hintColor),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                filled: true,
                fillColor: inputFill,
                hoverColor: inputFill,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (_inputEnabled && _canSubmit && !_checking && !_submitting) {
                  _submit();
                }
              },
            ),
          ),
          if (_showClearButton)
            IconButton(
              onPressed: _clearInput,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
              icon: Icon(Icons.cancel, size: 18, color: hintColor),
            ),
          const SizedBox(width: 4),
          Text(
            '$_inputCharacterCount/${widget.maxLength}',
            style: TextStyle(fontSize: 14, color: hintColor),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final pageBackground =
        theme.weakBackgroundColor ?? theme.conversationItemBgColor ?? Colors.white;
    final appBarBackground = theme.appbarBgColor ?? Colors.white;
    final appBarTextColor =
        theme.appbarTextColor ?? theme.darkTextColor ?? Colors.black;
    final appBarIconColor = theme.primaryColor ?? const Color(0xFF1E90FF);
    final inputFill = theme.inputFillColor ?? const Color(0xFFF3F3F4);
    final hintColor = theme.weakTextColor ?? const Color(0xFF999999);
    final textColor = theme.darkTextColor ?? Colors.black;
    final primaryColor = theme.primaryColor ?? const Color(0xFF1E90FF);
    final dividerColor = theme.weakDividerColor ?? const Color(0xFFE5E5E5);
    final errorColor = theme.cautionColor ?? const Color(0xFFFF584C);

    final title = widget.title ?? TIM_t("名字");
    final hint = _inputHint;
    final submitLabel = widget.submitLabel ?? TIM_t("完成");
    final canPressSubmit = _inputEnabled && _canSubmit && !_submitting;
    final showRulesHint = widget.rulesHint != null &&
        widget.rulesHint!.isNotEmpty &&
        (_inlineError == null || _inlineError!.isEmpty);

    final formBody = _loadingProfile
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              widget.embedded ? 16 : 20,
              16,
              widget.embedded ? 16 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInputField(
                  hint: hint,
                  inputFill: widget.embedded ? pageBackground : inputFill,
                  hintColor: hintColor,
                  textColor: textColor,
                ),
                if (showRulesHint) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.rulesHint!,
                    style: TextStyle(fontSize: 13, color: hintColor),
                  ),
                ],
                if (_checkingHint != null && _checkingHint!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _checkingHint!,
                    style: TextStyle(fontSize: 13, color: hintColor),
                  ),
                ],
                if (_inlineError != null && _inlineError!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _inlineError!,
                    style: TextStyle(fontSize: 13, color: errorColor),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: canPressSubmit ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      disabledBackgroundColor:
                          primaryColor.withValues(alpha: 0.5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            submitLabel,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );

    if (widget.embedded) {
      return Material(
        color: pageBackground,
        child: SingleChildScrollView(
          child: formBody,
        ),
      );
    }

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: appBarBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: BackButton(color: appBarIconColor),
        iconTheme: IconThemeData(color: appBarIconColor),
        title: Text(
          title,
          style: TextStyle(
            fontSize: IMDemoConfig.appBarTitleFontSize,
            fontWeight: FontWeight.w600,
            color: appBarTextColor,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(height: 0.5, color: dividerColor),
        ),
      ),
      body: formBody,
    );
  }
}

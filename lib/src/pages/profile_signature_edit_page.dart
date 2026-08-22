import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/ui/utils/desktop_modal_layout.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/utils/utf8_byte_limiting_formatter.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_group_profile_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_wide_modal_operation_key.dart';
import 'package:tencent_cloud_chat_uikit/ui/controller/tim_uikit_profile_controller.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/wide_popup.dart';

/// 可复用的多行文本编辑页（个性签名、群公告等）。
///
/// 通过 [onSave] 注入保存逻辑；保存成功后 `pop` 并返回最新文本。
class ProfileSignatureEditPage extends StatefulWidget {
  const ProfileSignatureEditPage({
    Key? key,
    this.initialSignature = '',
    this.maxLength = 30,
    this.maxBytes,
    this.title,
    this.hintText,
    this.submitLabel,
    required this.onSave,
    this.embedded = false,
    this.onFinish,
  }) : super(key: key);

  final String initialSignature;
  final int maxLength;
  /// 非空时按 UTF-8 字节数限制（如群公告 400 字节）。
  final int? maxBytes;
  final String? title;
  final String? hintText;
  final String? submitLabel;

  /// 返回 `true` 表示保存成功，页面将自动关闭。
  final Future<bool> Function(String text) onSave;

  /// Web / 桌面弹窗内嵌：去掉全屏 AppBar，由外层弹窗标题栏负责关闭。
  final bool embedded;

  final ValueChanged<String?>? onFinish;

  /// 使用 [TIMUIKitProfileController] 保存并打开编辑页。
  static Future<String?> pushWithProfileController(
    BuildContext context, {
    required TIMUIKitProfileController controller,
    String initialSignature = '',
    int maxLength = 30,
  }) {
    final i18n = AppI18n.of(context);
    final title = i18n.t(
      zhHans: '个性签名',
      zhHant: '個性簽名',
      en: 'Bio',
      ja: '自己紹介',
      ko: '상태 메시지',
    );

    ProfileSignatureEditPage pageBuilder({
      bool embedded = false,
      ValueChanged<String?>? onFinish,
    }) {
      return ProfileSignatureEditPage(
        initialSignature: initialSignature,
        maxLength: maxLength,
        title: title,
        embedded: embedded,
        onFinish: onFinish,
        onSave: (signature) async {
          final res = await controller.updateSelfSignature(signature);
          return res.code == 0;
        },
      );
    }

    if (DesktopModalLayout.isDesktop(context)) {
      return _pushDesktopPopup(
        context,
        title: title,
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
    required ProfileSignatureEditPage Function({
      bool embedded,
      ValueChanged<String?>? onFinish,
    }) builder,
  }) async {
    String? result;
    final size = DesktopModalLayout.compact(context);
    await TUIKitWidePopup.showPopupWindow(
      operationKey: TUIKitWideModalOperationKey.custom,
      context: context,
      title: title,
      width: size.width,
      height: size.height,
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

  /// 群公告编辑（腾讯 IM 上限 400 UTF-8 字节）。
  static Future<String?> pushGroupNotice(
    BuildContext context, {
    required TUIGroupProfileModel model,
    String initialNotification = '',
  }) {
    final i18n = AppI18n.of(context);
    return Navigator.push<String>(
      context,
      AppMaterialPageRoute(
        builder: (context) => ProfileSignatureEditPage(
          initialSignature: initialNotification,
          maxBytes: 400,
          title: i18n.t(
            zhHans: '群公告',
            zhHant: '群公告',
            en: 'Group Notice',
            ja: 'グループのお知らせ',
            ko: '그룹 공지',
          ),
          hintText: i18n.t(
            zhHans: '填写群公告',
            zhHant: '填寫群公告',
            en: 'Enter group notice',
            ja: 'グループのお知らせを入力',
            ko: '그룹 공지 입력',
          ),
          onSave: (notification) async {
            final response = await model.setGroupNotification(notification);
            return response?.code == 0;
          },
        ),
      ),
    );
  }

  @override
  State<ProfileSignatureEditPage> createState() =>
      _ProfileSignatureEditPageState();
}

class _ProfileSignatureEditPageState extends State<ProfileSignatureEditPage> {
  late final TextEditingController _controller;
  bool _submitting = false;

  bool get _usesByteLimit => widget.maxBytes != null;

  int get _counterValue => _usesByteLimit
      ? utf8.encode(_controller.text).length
      : _controller.text.length;

  int get _counterMax => widget.maxBytes ?? widget.maxLength;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialSignature);
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final text = _controller.text;
    setState(() => _submitting = true);
    try {
      final ok = await widget.onSave(text);
      if (!mounted) return;
      if (ok) {
        _finish(text);
      } else {
        ToastUtils.toast(AppI18n.current.t(
          zhHans: '保存失败',
          zhHant: '儲存失敗',
          en: 'Failed to save.',
          ja: '保存に失敗しました。',
          ko: '저장에 실패했습니다.',
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _finish([String? result]) {
    if (widget.embedded) {
      widget.onFinish?.call(result);
      return;
    }
    Navigator.pop(context, result);
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

    final i18n = AppI18n.of(context);
    final title = widget.title ??
        i18n.t(
          zhHans: '个性签名',
          zhHant: '個性簽名',
          en: 'Bio',
          ja: '自己紹介',
          ko: '상태 메시지',
        );
    final hint = widget.hintText ??
        i18n.t(
          zhHans: '填写个性签名',
          zhHant: '填寫個性簽名',
          en: 'Enter bio',
          ja: '自己紹介を入力',
          ko: '상태 메시지 입력',
        );
    final submitLabel = widget.submitLabel ??
        i18n.t(
          zhHans: '完成',
          zhHant: '完成',
          en: 'Done',
          ja: '完了',
          ko: '완료',
        );

    final body = Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        widget.embedded ? 12 : 20,
        16,
        24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProfileSignatureInputField(
            controller: _controller,
            hintText: hint,
            maxLength: _usesByteLimit ? null : widget.maxLength,
            inputFormatters: _usesByteLimit
                ? [
                    Utf8ByteLimitingTextInputFormatter(widget.maxBytes!),
                  ]
                : null,
            // 弹窗内与周边同色，避免聚焦时灰底突兀。
            inputFill: widget.embedded ? pageBackground : inputFill,
            hintColor: hintColor,
            textColor: textColor,
            counterText: '$_counterValue/$_counterMax',
            compact: widget.embedded,
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                disabledBackgroundColor: primaryColor.withValues(alpha: 0.5),
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
      return ColoredBox(
        color: pageBackground,
        child: body,
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
      body: body,
    );
  }
}

/// 与个性签名编辑页一致的多行输入区，供群公告等场景复用。
class ProfileSignatureInputField extends StatelessWidget {
  const ProfileSignatureInputField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.inputFill,
    required this.hintColor,
    required this.textColor,
    required this.counterText,
    this.maxLength,
    this.inputFormatters,
    this.enabled = true,
    this.autofocus = false,
    this.onSubmitted,
    this.compact = false,
  });

  final TextEditingController controller;
  final String hintText;
  final Color inputFill;
  final Color hintColor;
  final Color textColor;
  final String counterText;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: compact ? 120 : 160),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: inputFill,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: controller,
            enabled: enabled,
            autofocus: autofocus,
            maxLength: maxLength,
            inputFormatters: inputFormatters,
            maxLines: compact ? 4 : 6,
            minLines: compact ? 3 : 5,
            style: TextStyle(fontSize: 16, color: textColor, height: 1.4),
            cursorColor: Theme.of(context).colorScheme.primary,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(fontSize: 16, color: hintColor),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              // 与外层同色，Web 聚焦时也不另刷灰/白底。
              filled: true,
              fillColor: inputFill,
              hoverColor: inputFill,
              counterText: '',
              isCollapsed: true,
              contentPadding: const EdgeInsets.all(4),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: onSubmitted,
          ),
        ),
        Positioned(
          right: 8,
          bottom: 8,
          child: Text(
            counterText,
            style: TextStyle(fontSize: 14, color: hintColor),
          ),
        ),
      ],
    );
  }
}

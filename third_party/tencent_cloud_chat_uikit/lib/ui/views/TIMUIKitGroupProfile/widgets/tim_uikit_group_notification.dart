import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/pages/profile_signature_edit_page.dart';
import 'package:tencent_cloud_chat_demo/utils/utf8_byte_limiting_formatter.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_callback.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_group_profile_model.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

class GroupProfileNotification extends StatefulWidget {
  final bool isHavePermission;

  const GroupProfileNotification({Key? key, this.isHavePermission = false}) : super(key: key);

  @override
  State<StatefulWidget> createState() => GroupProfileNotificationState();
}

class GroupProfileNotificationState extends TIMUIKitState<GroupProfileNotification> {
  static const int _maxNoticeBytes = 400;

  bool isShowEditBox = false;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  String _rawNotification(TUIGroupProfileModel model) =>
      model.groupInfo?.notification ?? '';

  Future<void> _saveNotification(TUIGroupProfileModel model) async {
    final response = await model.setGroupNotification(_controller.text);
    if (!mounted) {
      return;
    }
    if (response?.code == 0) {
      onTIMCallback(TIMCallback(
        type: TIMCallbackType.INFO,
        infoRecommendText: TIM_t("修改成功"),
        infoCode: 6660210,
      ));
      setState(() {
        isShowEditBox = false;
      });
    }
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final TUITheme theme = value.theme;
    final isDesktopScreen = TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;

    final model = Provider.of<TUIGroupProfileModel>(context);
    final rawNotification = _rawNotification(model);
    final String notification = rawNotification.isNotEmpty
        ? rawNotification
        : TIM_t("暂无群公告");
    final inputFill = theme.inputFillColor ?? const Color(0xFFF3F3F4);
    final hintColor = theme.weakTextColor ?? const Color(0xFF999999);
    final textColor = theme.darkTextColor ?? Colors.black;
    final noticeBytes = utf8.encode(_controller.text).length;

    final itemBackgroundColor =
        theme.conversationItemBgColor ?? theme.wideBackgroundColor ?? Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: itemBackgroundColor,
          border: isDesktopScreen
              ? null
              : Border(bottom: BorderSide(color: theme.weakDividerColor ?? CommonColor.weakDividerColor))),
      child: InkWell(
        onTap: !widget.isHavePermission
            ? null
            : (() {
                if (!isDesktopScreen) {
                  ProfileSignatureEditPage.pushGroupNotice(
                    context,
                    model: model,
                    initialNotification: rawNotification,
                  );
                  return;
                }
                setState(() {
                  isShowEditBox = !isShowEditBox;
                  if (isShowEditBox) {
                    _controller.text = rawNotification;
                  }
                });
              }),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    TIM_t("群公告"),
                    style: TextStyle(color: theme.darkTextColor, fontSize: isDesktopScreen ? 14 : 16),
                  ),
                ),
                if (widget.isHavePermission)
                  AnimatedRotation(
                    turns: isShowEditBox ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_right, color: theme.weakTextColor),
                  )
              ],
            ),
            if (!isShowEditBox)
              Padding(
                padding: EdgeInsets.only(top: isDesktopScreen ? 4 : 0),
                child: SelectableText(notification,
                    style: TextStyle(color: theme.weakTextColor, fontSize: 12)),
              ),
            if (isShowEditBox) ...[
              const SizedBox(height: 10),
              ProfileSignatureInputField(
                controller: _controller,
                hintText: TIM_t("填写群公告"),
                inputFill: inputFill,
                hintColor: hintColor,
                textColor: textColor,
                counterText: '$noticeBytes/$_maxNoticeBytes',
                inputFormatters: [
                  Utf8ByteLimitingTextInputFormatter(_maxNoticeBytes),
                ],
                autofocus: true,
                onSubmitted: (_) => _saveNotification(model),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                      onPressed: () => _saveNotification(model),
                      child: Text(
                        TIM_t("保存"),
                        style: TextStyle(fontSize: 13, color: theme.primaryColor),
                      ))
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

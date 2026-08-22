import 'package:flutter/material.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/enum/friend_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_operation_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/life_cycle/add_friend_life_cycle.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_self_info_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/friendShip/friendship_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/friend_add_source.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

class SendApplication extends StatefulWidget {
  final V2TimUserFullInfo friendInfo;
  final TUISelfInfoViewModel model;
  final bool? isShowDefaultGroup;
  final AddFriendLifeCycle? lifeCycle;
  final String? addSource;

  const SendApplication({
    Key? key,
    this.lifeCycle,
    required this.friendInfo,
    required this.model,
    this.isShowDefaultGroup = false,
    this.addSource,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _SendApplicationState();
}

class _SendApplicationState extends TIMUIKitState<SendApplication> {
  final TextEditingController _verficationController = TextEditingController();
  final TextEditingController _nickNameController = TextEditingController();
  bool _sending = false;

  static const int _addFriendPendingApprovalCode = 30539;

  bool _shouldPopAfterAddFriend(
      V2TimValueCallback<V2TimFriendOperationResult> result) {
    if (result.code != 0) {
      return false;
    }
    final operationCode = result.data?.resultCode ?? 0;
    return operationCode == 0 ||
        operationCode == _addFriendPendingApprovalCode;
  }


  void _showTip(String text) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null || text.trim().isEmpty) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1300),
        ),
      );
  }

  @override
  void initState() {
    super.initState();
    final showName = TencentUtils.checkString(widget.model.loginInfo?.nickName) ??
        TencentUtils.checkString(widget.model.loginInfo?.userID) ??
        '';
    _verficationController.text = showName.isEmpty ? '我是' : '我是：$showName';
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final TUITheme theme = value.theme;
    final FriendshipServices _friendshipServices = serviceLocator<FriendshipServices>();
    final Color panelColor = theme.conversationItemBgColor ??
        theme.weakBackgroundColor ??
        theme.white ??
        Colors.white;
    final Color backgroundColor = theme.weakBackgroundColor ??
        theme.wideBackgroundColor ??
        theme.white ??
        Colors.white;
    final cursorColor = backgroundColor.computeLuminance() < 0.2
        ? Colors.white
        : theme.primaryColor ?? const Color(0xFF1E90FF);

    final faceUrl = widget.friendInfo.faceUrl ?? "";
    final userID = widget.friendInfo.userID ?? "";
    final String showName = ((widget.friendInfo.nickName != null && widget.friendInfo.nickName!.isNotEmpty)
            ? widget.friendInfo.nickName
            : userID) ??
        "";
    final option2 = widget.friendInfo.selfSignature ?? "";

    Widget sendApplicationBody() {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: panelColor,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    margin: const EdgeInsets.only(right: 12),
                    child: Avatar(faceUrl: faceUrl, showName: showName),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        showName,
                        style: TextStyle(color: theme.darkTextColor, fontSize: 18),
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        "ID: $userID",
                        style: TextStyle(fontSize: 13, color: theme.weakTextColor),
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      if (TencentUtils.checkString(option2) != null)
                        Text(
                          TIM_t_para("个性签名: {{option2}}", "个性签名: $option2")(option2: option2),
                          style: TextStyle(fontSize: 13, color: theme.weakTextColor),
                        ),
                    ],
                  )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Text(
                TIM_t("填写验证信息"),
                style: TextStyle(fontSize: 16, color: theme.darkTextColor),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 6, bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              color: panelColor,
              child: TextField(
                // minLines: 1,
                maxLines: 4,
                controller: _verficationController,
                cursorColor: cursorColor,
                style: TextStyle(color: theme.darkTextColor),
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: theme.textgrey),
                  hintText: '',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Text(
                TIM_t("请填写备注"),
                style: TextStyle(fontSize: 16, color: theme.darkTextColor),
              ),
            ),
            Container(
              color: panelColor,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.only(top: 6),
              child: TextField(
                controller: _nickNameController,
                cursorColor: cursorColor,
                style: TextStyle(color: theme.darkTextColor),
                decoration: InputDecoration(
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: theme.textgrey,
                  ),
                  hintText: TIM_t("备注"),
                ),
              ),
            ),
            Divider(
              height: 1,
              color: theme.weakDividerColor,
            ),
            if (widget.isShowDefaultGroup == true)
              Container(
                color: panelColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      TIM_t("分组"),
                      style: TextStyle(color: theme.darkTextColor, fontSize: 16),
                    ),
                    Text(
                      TIM_t("我的好友"),
                      style: TextStyle(color: theme.darkTextColor, fontSize: 16),
                    )
                  ],
                ),
              ),
            Container(
              color: panelColor,
              width: double.infinity,
              margin: const EdgeInsets.only(top: 10),
              child: TextButton(
                  onPressed: _sending
                      ? null
                      : () async {
                          final remark = _nickNameController.text;
                          final addWording = FriendAddSource.embedInWording(
                            widget.addSource,
                            _verficationController.text,
                          );
                          final friendGroup = TIM_t("我的好友");

                          if (widget.lifeCycle?.shouldAddFriend != null &&
                              await widget.lifeCycle!.shouldAddFriend(
                                    userID,
                                    remark,
                                    friendGroup,
                                    addWording,
                                    context,
                                  ) ==
                                  false) {
                            return;
                          }

                          setState(() => _sending = true);
                          try {
                            final result = await _friendshipServices.addFriend(
                              userID: userID,
                              addType: FriendTypeEnum.V2TIM_FRIEND_TYPE_BOTH,
                              remark: remark,
                              addWording: addWording,
                              friendGroup: friendGroup,
                              addSource: widget.addSource,
                            );

                            if (!context.mounted) return;
                            if (_shouldPopAfterAddFriend(result)) {
                              final operationCode = result.data?.resultCode ?? 0;
                              final pending =
                                  operationCode == _addFriendPendingApprovalCode;
                              _showTip(pending ? TIM_t("好友申请已发送") : TIM_t("添加成功"));
                              Navigator.of(context).pop(true);
                              return;
                            }
                            _showTip(result.desc.isNotEmpty
                                ? result.desc
                                : TIM_t("发送失败"));
                          } finally {
                            if (mounted) {
                              setState(() => _sending = false);
                            }
                          }
                        },
                  child: Text(_sending ? TIM_t("发送中...") : TIM_t("发送"))),
            )
          ],
        ),
      );
    }

    return TUIKitScreenUtils.getDeviceWidget(
        context: context,
        desktopWidget: Container(
          padding: const EdgeInsets.only(top: 10),
          color: theme.weakBackgroundColor,
          child: sendApplicationBody(),
        ),
        defaultWidget: Scaffold(
          backgroundColor: theme.weakBackgroundColor,
          appBar: AppBar(
            title: Text(
              TIM_t("添加好友"),
              style: TextStyle(color: theme.appbarTextColor, fontSize: 17),
            ),
            surfaceTintColor: Colors.transparent,
            shadowColor: theme.weakDividerColor,
            backgroundColor: theme.appbarBgColor ?? theme.primaryColor,
            iconTheme: IconThemeData(
              color: theme.primaryColor ?? const Color(0xFF1E90FF),
            ),
          ),
          body: sendApplicationBody(),
        ));
  }
}

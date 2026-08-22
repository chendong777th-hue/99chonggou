import 'package:flutter/material.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_group_profile_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/widgets/tim_ui_group_member_search.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/group_member_list.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/core_services_implements.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

GlobalKey<_SelectNewGroupOwner> selectNewGroupOwnerKey = GlobalKey();

class SelectNewGroupOwner extends StatefulWidget {
  final String? groupID;
  final TUIGroupProfileModel model;
  final ValueChanged<List<V2TimGroupMemberFullInfo>>? onSelectedMember;

  const SelectNewGroupOwner({
    this.groupID,
    Key? key,
    required this.model,
    this.onSelectedMember,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _SelectNewGroupOwner();
}

class _SelectNewGroupOwner extends TIMUIKitState<SelectNewGroupOwner> {
  final CoreServicesImpl _coreServicesImpl = serviceLocator<CoreServicesImpl>();
  List<V2TimGroupMemberFullInfo> selectedMember = [];
  String _keyword = '';

  void _handleSearchText(String text) {
    final next = text.trim().toLowerCase();
    if (next == _keyword) {
      return;
    }
    setState(() => _keyword = next);
  }

  List<V2TimGroupMemberFullInfo?> _visibleMembers() {
    final selfId = _coreServicesImpl.loginInfo.userID;
    final base = widget.model.groupMemberList
        .where((element) => element?.userID != selfId)
        .toList();
    return filterGroupMembersByKeyword(base, _keyword);
  }

  onSubmit() {
    if (widget.onSelectedMember != null) {
      widget.onSelectedMember!(selectedMember);
    }
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final TUITheme theme = value.theme;

    Widget memberBody() {
      return GroupProfileMemberList(
        customTopArea: PlatformUtils().isWeb
            ? null
            : GroupMemberSearchTextField(
                onTextChange: _handleSearchText,
              ),
        memberList: _visibleMembers(),
        canSlideDelete: false,
        canSelectMember: true,
        maxSelectNum: 1,
        onSelectedMemberChange: (member) {
          selectedMember = member;
          setState(() {});
        },
        touchBottomCallBack: () {},
      );
    }

    return TUIKitScreenUtils.getDeviceWidget(
        context: context,
        defaultWidget: Scaffold(
            appBar: AppBar(
              shadowColor: theme.weakBackgroundColor,
              iconTheme: IconThemeData(
                color: theme.appbarTextColor,
              ),
              backgroundColor: theme.appbarBgColor ?? theme.primaryColor,
              title: Text(
                TIM_t("转让群主"),
                style: TextStyle(
                  color: theme.appbarTextColor,
                  fontSize: 17,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    onSubmit();
                    Navigator.pop(context, selectedMember);
                  },
                  child: Text(
                    TIM_t("确定"),
                    style: TextStyle(
                      color: theme.appbarTextColor,
                      fontSize: 14,
                    ),
                  ),
                )
              ],
            ),
            body: memberBody()),
        desktopWidget: memberBody());
  }
}

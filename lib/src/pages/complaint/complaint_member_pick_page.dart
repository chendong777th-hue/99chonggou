import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/utils/group_at_mention.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_group_profile_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_self_info_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/widgets/tim_ui_group_member_search.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/group_member_list.dart';

/// 群投诉：先选被投诉成员，再进入原因页。
class ComplaintMemberPickPage extends StatefulWidget {
  const ComplaintMemberPickPage({
    super.key,
    required this.model,
  });

  final TUIGroupProfileModel model;

  static Future<V2TimGroupMemberFullInfo?> open(
    BuildContext context, {
    required TUIGroupProfileModel model,
  }) {
    return Navigator.of(context).push<V2TimGroupMemberFullInfo>(
      AppMaterialPageRoute(
        builder: (_) => ComplaintMemberPickPage(model: model),
      ),
    );
  }

  @override
  State<ComplaintMemberPickPage> createState() =>
      _ComplaintMemberPickPageState();
}

class _ComplaintMemberPickPageState extends State<ComplaintMemberPickPage> {
  String _keyword = '';

  void _handleSearchText(String text) {
    final next = text.trim().toLowerCase();
    if (next == _keyword) {
      return;
    }
    setState(() => _keyword = next);
  }

  List<V2TimGroupMemberFullInfo?> _visibleMembers() {
    final selfId =
        serviceLocator<TUISelfInfoViewModel>().loginInfo?.userID?.trim() ?? '';
    final base = widget.model.groupMemberList
        .whereType<V2TimGroupMemberFullInfo>()
        .where((m) => m.userID.trim().isNotEmpty && m.userID.trim() != selfId)
        .map<V2TimGroupMemberFullInfo?>((m) => m)
        .toList();
    return filterGroupMembersByKeyword(base, _keyword);
  }

  void _onPick(V2TimGroupMemberFullInfo member) {
    Navigator.of(context).pop(member);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final isDark = Provider.of<DefaultThemeData>(context, listen: false)
            .currentThemeType ==
        ThemeType.dark;
    final i18n = AppI18n.of(context);
    final bg = theme.appbarBgColor ?? AppColors.card(dark: isDark);
    final textColor = theme.darkTextColor ?? AppColors.text(dark: isDark);

    return Scaffold(
      backgroundColor: theme.weakBackgroundColor ??
          (isDark ? AppColors.darkBackground : const Color(0xFFF1F1F1)),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: theme.primaryColor ?? AppColors.primaryBlue,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          i18n.t(
            zhHans: '选择投诉对象',
            zhHant: '選擇投訴對象',
            en: 'Select User to Report',
            ja: '通報対象を選択',
            ko: '신고 대상 선택',
          ),
          style: TextStyle(
            color: textColor,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: GroupProfileMemberList(
        customTopArea: GroupMemberSearchTextField(
          onTextChange: _handleSearchText,
        ),
        memberList: _visibleMembers(),
        canSlideDelete: false,
        canSelectMember: false,
        onTapMemberItem: (member, _) => _onPick(member),
        touchBottomCallBack: () {},
      ),
    );
  }
}

/// 展示名：群名片 / 昵称 / userId。
String complaintMemberDisplayName(V2TimGroupMemberFullInfo member) {
  return GroupAtMention.showName(member);
}

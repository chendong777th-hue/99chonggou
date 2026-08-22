import 'dart:async';
import 'dart:io';
import 'package:tencent_cloud_chat_demo/src/platform/permission_guard.dart';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/api/upload_api.dart';
import 'package:tencent_cloud_chat_demo/src/pages/profile_nickname_edit_page.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/services/app_gallery_picker.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_membership_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_tip_custom_sender.dart';
import 'package:tencent_cloud_chat_demo/src/tencent_page.dart';
import 'package:tencent_cloud_chat_demo/utils/dio_error_message.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_group_profile_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_conversation_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/group_role_policy.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';

class GroupInfoDetailPage extends StatefulWidget {
  final V2TimGroupInfo groupInfo;
  final TUIGroupProfileModel? model;

  const GroupInfoDetailPage({
    Key? key,
    required this.groupInfo,
    this.model,
  }) : super(key: key);

  @override
  State<GroupInfoDetailPage> createState() => _GroupInfoDetailPageState();
}

class _GroupInfoDetailPageState extends State<GroupInfoDetailPage> {
  String _groupName = "";
  String _faceUrl = "";
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _groupName = widget.groupInfo.groupName ?? widget.groupInfo.groupID;
    _faceUrl = widget.groupInfo.faceUrl ?? "";
  }

  bool _canManage() {
    return GroupRolePolicy.isManagerRole(widget.groupInfo.role);
  }

  TUIGroupProfileModel? _getModel(BuildContext context) {
    return widget.model ??
        Provider.of<TUIGroupProfileModel?>(context, listen: false);
  }

  String _dioMsg(DioError e) {
    final data = e.response?.data;
    if (data is Map) {
      final code = data['code']?.toString();
      if (code == 'NOT_GROUP_OWNER_OR_ADMIN') {
        return TIM_t("只有群主或管理员可以修改群头像");
      }
    }
    return DioErrorMessage.forApp(e);
  }

  Future<void> _uploadAvatar(String imagePath) async {
    if (_uploading) return;
    setState(() => _uploading = true);
    try {
      final result = await UploadApi.instance.uploadGroupAvatar(
        groupId: widget.groupInfo.groupID,
        file: File(imagePath),
      );
      final thumbUrl = result.thumbUrl.trim();
      if (thumbUrl.isEmpty) {
        throw StateError('MISSING_THUMB_URL');
      }
      await GroupMembershipSyncService.instance.upsertGroupAvatar(
        groupId: widget.groupInfo.groupID,
        avatarUrl: thumbUrl,
      );
      unawaited(
        GroupTipCustomSender.instance.send(
          groupId: widget.groupInfo.groupID,
          action: 'group_avatar_changed',
          detail: <String, dynamic>{
            'avatarUrl': thumbUrl,
          },
        ),
      );
      if (!mounted) return;
      debugPrint("group avatar thumbUrl: $thumbUrl");
      setState(() => _faceUrl = thumbUrl);
      widget.groupInfo.faceUrl = thumbUrl;
      final model = _getModel(context);
      if (model != null) {
        model.groupInfo?.faceUrl = thumbUrl;
      }
      if (!mounted) return;
      ToastUtils.toast(TIM_t("修改成功"));
    } on DioError catch (e) {
      ToastUtils.toast(_dioMsg(e));
    } catch (e) {
      ToastUtils.toast(DioErrorMessage.forApp(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickAvatarFromGallery() async {
    final picked = await AppGalleryPicker.pickSingleImage(context);
    if (!mounted) return;
    final imagePath = picked?.path;
    if (imagePath == null || imagePath.isEmpty) return;
    await _uploadAvatar(imagePath);
  }

  Future<void> _pickAvatarFromCamera() async {
    final allowed = await PermissionGuard.cameraForPhoto(context);
    if (!allowed || !mounted) return;
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    final imagePath = picked?.path;
    if (imagePath == null || imagePath.isEmpty || !mounted) {
      return;
    }
    await _uploadAvatar(imagePath);
  }

  Future<void> _openEditGroupName(BuildContext context) async {
    final model = _getModel(context);
    if (model == null) {
      ToastUtils.toast(TIM_t("当前无法修改群聊名称"));
      return;
    }
    final result = await ProfileNicknameEditPage.pushGroupChatName(
      context,
      initialName: _groupName,
      onSave: (String newName) async {
        final response = await model.setGroupName(newName.trim());
        if (response?.code != 0) {
          ToastUtils.toast(
            DioErrorMessage.sanitizeUserText(
              response?.desc,
              fallback: TIM_t("修改群聊名称失败"),
            ),
          );
          return false;
        }
        return true;
      },
    );
    if (result != null && result.isNotEmpty && mounted) {
      widget.groupInfo.groupName = result;
      serviceLocator<TUIConversationViewModel>().updateGroupShowName(
        widget.groupInfo.groupID,
        result,
      );
      setState(() {
        _groupName = result;
      });
      ToastUtils.toast(TIM_t("修改成功"));
    }
  }

  Widget _buildAvatarRow({
    required dynamic theme,
    required String title,
    required String groupName,
    required Color backgroundColor,
    required Color titleTextColor,
    required Color valueTextColor,
  }) {
    final canManage = _canManage();
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: canManage && !_uploading
                  ? () => _showAvatarManageSheet(context, theme)
                  : null,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: titleTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          if (_uploading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            SizedBox(
              width: 56,
              height: 56,
              child: Avatar(
                faceUrl: _faceUrl,
                showName: groupName,
                type: 2,
                isShowBigWhenClick: true,
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          const SizedBox(width: 10),
          if (canManage)
            InkWell(
              onTap: _uploading
                  ? null
                  : () => _showAvatarManageSheet(context, theme),
              child: Icon(
                Icons.keyboard_arrow_right,
                color: valueTextColor,
                size: 22,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAvatarManageSheet(
    BuildContext context,
    dynamic theme,
  ) async {
    final result = await showCupertinoModalPopup<String>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          cancelButton: CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context, "cancel");
            },
            child: Text(TIM_t("取消")),
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context, "camera");
              },
              child: Text(
                TIM_t("拍照"),
                style: TextStyle(
                  color: theme.primaryColor ?? const Color(0xFF1E90FF),
                ),
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context, "gallery");
              },
              child: Text(
                TIM_t("从手机相册选择"),
                style: TextStyle(
                  color: theme.primaryColor ?? const Color(0xFF1E90FF),
                ),
              ),
            ),
          ],
        );
      },
    );
    if (result == "camera") {
      await _pickAvatarFromCamera();
    } else if (result == "gallery") {
      await _pickAvatarFromGallery();
    }
  }

  Widget _buildTextRow({
    required dynamic theme,
    required String title,
    required String value,
    required Color backgroundColor,
    required Color titleTextColor,
    required Color valueTextColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: backgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: titleTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        color: valueTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.keyboard_arrow_right,
                    color: valueTextColor,
                    size: 22,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    const lightPageBg = Color(0xFFF5F5F5);
    const darkPageBg = Color(0xFF0F0F0F);
    const darkCellBg = Color(0xFF171717);
    const darkDivider = Color(0xFF252525);
    const darkTitleText = Color(0xFFD6D6D6);
    const darkValueText = Color(0xFF8A8A8A);
    final pageBackgroundColor = theme.weakBackgroundColor ?? lightPageBg;
    final isDarkBackground =
        ThemeData.estimateBrightnessForColor(pageBackgroundColor) ==
            Brightness.dark;
    final itemBackgroundColor = isDarkBackground
        ? darkCellBg
        : (theme.conversationItemBgColor ??
            theme.wideBackgroundColor ??
            Colors.white);
    final scaffoldBackgroundColor = isDarkBackground ? darkPageBg : lightPageBg;
    final dividerColor = isDarkBackground
        ? darkDivider
        : (theme.weakDividerColor ?? const Color(0xFFF0F0F0));
    final titleTextColor = isDarkBackground
        ? darkTitleText
        : (theme.darkTextColor ?? Colors.black);
    final valueTextColor = isDarkBackground
        ? darkValueText
        : (theme.weakTextColor ?? const Color(0xFF999999));
    return TencentPage(
      name: 'groupInfoDetail',
      child: Scaffold(
        backgroundColor: scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            TIM_t("群资料"),
            style: TextStyle(
              color: theme.appbarTextColor ?? theme.darkTextColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          iconTheme: IconThemeData(
            color: theme.primaryColor ?? const Color(0xFF1E90FF),
          ),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          shadowColor: Colors.transparent,
          backgroundColor: scaffoldBackgroundColor,
        ),
        body: Column(
          children: [
            SizedBox(height: isDarkBackground ? 8 : 0),
            _buildAvatarRow(
              theme: theme,
              title: TIM_t("群头像"),
              groupName: _groupName,
              backgroundColor: itemBackgroundColor,
              titleTextColor: titleTextColor,
              valueTextColor: valueTextColor,
            ),
            Container(
              height: 1,
              margin: const EdgeInsets.only(left: 16),
              color: dividerColor,
            ),
            _buildTextRow(
              theme: theme,
              title: TIM_t("群聊名称"),
              value: _groupName,
              backgroundColor: itemBackgroundColor,
              titleTextColor: titleTextColor,
              valueTextColor: valueTextColor,
              onTap: _canManage() ? () => _openEditGroupName(context) : null,
            ),
          ],
        ),
      ),
    );
  }
}

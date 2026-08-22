import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/friend_application_helper.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/friend_request_record.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_add_source.dart';
import 'package:tencent_cloud_chat_demo/utils/navigation_routes.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_user_avatar.dart';

class FriendRequestAuditPage extends StatefulWidget {
  const FriendRequestAuditPage({
    Key? key,
    required this.record,
  }) : super(key: key);

  final FriendRequestRecord record;

  static Route<bool> route(FriendRequestRecord record) {
    return NavigationRoutes.cupertino<bool>(
      builder: (_) => FriendRequestAuditPage(record: record),
    );
  }

  @override
  State<FriendRequestAuditPage> createState() => _FriendRequestAuditPageState();
}

class _FriendRequestAuditPageState extends State<FriendRequestAuditPage> {
  bool _loadingUserInfo = true;
  bool _processing = false;
  V2TimUserFullInfo? _userInfo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadUserInfo();
    });
  }

  Future<void> _loadUserInfo() async {
    final userID = widget.record.userID.trim();
    if (userID.isEmpty) {
      if (mounted) setState(() => _loadingUserInfo = false);
      return;
    }
    try {
      final res = await TIMUIKitCore.getSDKInstance()
          .getUsersInfo(userIDList: [userID]);
      if (res.code == 0 && res.data != null && res.data!.isNotEmpty) {
        _userInfo = res.data!.first;
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _loadingUserInfo = false);
    }
  }

  String _getShowName() {
    final nick = TencentUtils.checkString(_userInfo?.nickName);
    if (nick != null && nick.isNotEmpty) return nick;
    final recordNick = widget.record.nickname.trim();
    if (recordNick.isNotEmpty) return recordNick;
    return widget.record.userID;
  }

  String _getFaceUrl() {
    final recordFace = widget.record.faceUrl.trim();
    if (recordFace.isNotEmpty &&
        UserAvatarHelper.resolveDisplayUrl(recordFace) != null) {
      return recordFace;
    }
    final face = TencentUtils.checkString(_userInfo?.faceUrl);
    if (face != null && face.isNotEmpty) {
      return face;
    }
    return recordFace;
  }

  String _getGenderLabel() {
    switch (_userInfo?.gender) {
      case 1:
        return AppI18n.of(context).t(
          zhHans: '男',
          zhHant: '男',
          en: 'Male',
          ja: '男性',
          ko: '남성',
        );
      case 2:
        return AppI18n.of(context).t(
          zhHans: '女',
          zhHant: '女',
          en: 'Female',
          ja: '女性',
          ko: '여성',
        );
      default:
        return AppI18n.of(context).t(
          zhHans: '保密',
          zhHant: '保密',
          en: 'Private',
          ja: '非公開',
          ko: '비공개',
        );
    }
  }

  String _buildVerifyMessage() {
    final i18n = AppI18n.of(context);
    final fallbackName = _getShowName().trim();
    final wording = FriendAddSource
        .stripFromWording(widget.record.addWording)
        .replaceAll('{name}', fallbackName)
        .replaceAll('{option1}', fallbackName)
        .replaceAll('name)', fallbackName)
        .replaceAll('（name）', fallbackName)
        .replaceAll('(name)', fallbackName);
    if (wording.isEmpty) {
      return i18n.format(
        zhHans: '验证：{option1}',
        zhHant: '驗證：{option1}',
        en: 'Verification: {option1}',
        ja: '認証：{option1}',
        ko: '인증: {option1}',
        vars: {
          'option1': i18n.t(
            zhHans: '请求添加你为好友',
            zhHant: '請求新增你為好友',
            en: 'Wants to add you as a friend',
            ja: '友達追加をリクエスト',
            ko: '친구 추가 요청',
          ),
        },
      );
    }
    if (wording.startsWith('我是') || wording.startsWith('验证')) {
      return wording;
    }
    return i18n.format(
      zhHans: '验证：{option1}',
      zhHant: '驗證：{option1}',
      en: 'Verification: {option1}',
      ja: '認証：{option1}',
      ko: '인증: {option1}',
      vars: {'option1': wording},
    );
  }

  Widget _buildInfoRow({
    required String title,
    required String value,
    required Color titleColor,
    required Color valueColor,
    required Color backgroundColor,
  }) {
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title, style: TextStyle(fontSize: 16, color: titleColor)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAccept() async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      final success = await FriendApplicationHelper.acceptRecord(widget.record);
      if (success && mounted) Navigator.of(context).pop(true);
    } catch (_) {
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '操作失败',
        zhHant: '操作失敗',
        en: 'Operation failed',
        ja: '操作に失敗',
        ko: '작업 실패',
      ));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _handleReject() async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      final success = await FriendApplicationHelper.rejectRecord(widget.record);
      if (success && mounted) Navigator.of(context).pop(true);
    } catch (_) {
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '操作失败',
        zhHant: '操作失敗',
        en: 'Operation failed',
        ja: '操作に失敗',
        ko: '작업 실패',
      ));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Widget _buildBottomActions({
    required Color cardBackgroundColor,
    required Color dividerColor,
    required Color primaryColor,
  }) {
    final i18n = AppI18n.of(context);
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: cardBackgroundColor,
          border: Border(top: BorderSide(color: dividerColor, width: 0.6)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _processing ? null : _handleReject,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(i18n.t(
                  zhHans: '拒绝',
                  zhHant: '拒絕',
                  en: 'Decline',
                  ja: '拒否',
                  ko: '거절',
                )),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _processing ? null : _handleAccept,
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _processing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(i18n.t(
                        zhHans: '同意',
                        zhHant: '同意',
                        en: 'Accept',
                        ja: '承認',
                        ko: '수락',
                      )),
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
    const lightPageBackgroundColor = Color(0xFFF5F6F8);
    final appBarBaseColor =
        theme.appbarBgColor ?? theme.wideBackgroundColor ?? Colors.white;
    final isDarkBackground =
        ThemeData.estimateBrightnessForColor(appBarBaseColor) ==
            Brightness.dark;
    final pageBackgroundColor = isDarkBackground
        ? (theme.weakBackgroundColor ??
            theme.wideBackgroundColor ??
            const Color(0xFF0F0F0F))
        : lightPageBackgroundColor;
    final cardBackgroundColor = isDarkBackground
        ? (theme.conversationItemBgColor ??
            theme.wideBackgroundColor ??
            const Color(0xFF171717))
        : Colors.white;
    final titleColor = theme.darkTextColor ?? Colors.black;
    final valueColor = theme.weakTextColor ?? const Color(0xFF999999);
    final dividerColor = theme.weakDividerColor ?? const Color(0xFFEDEDED);
    final primaryColor = theme.primaryColor ?? const Color(0xFF1E90FF);
    final showName = _getShowName();
    final sourceLabel = FriendAddSource.displayLabel(
      widget.record.addSource,
      addWording: widget.record.addWording,
    );

    return Scaffold(
      backgroundColor: pageBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: primaryColor, size: 22),
        ),
        backgroundColor: theme.appbarBgColor ?? cardBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      bottomNavigationBar: _loadingUserInfo
          ? null
          : _buildBottomActions(
              cardBackgroundColor: cardBackgroundColor,
              dividerColor: dividerColor,
              primaryColor: primaryColor,
            ),
      body: _loadingUserInfo
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Container(
                  color: cardBackgroundColor,
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              showName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: titleColor,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              sourceLabel,
                              style: TextStyle(
                                fontSize: 14,
                                color: valueColor,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: AppUserAvatar(
                          faceUrl: _getFaceUrl(),
                          showName: showName,
                          size: 72,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  title: AppI18n.of(context).t(
                    zhHans: 'ID号',
                    zhHant: 'ID號',
                    en: 'ID',
                    ja: 'ID',
                    ko: 'ID',
                  ),
                  value: widget.record.userID,
                  titleColor: titleColor,
                  valueColor: valueColor,
                  backgroundColor: cardBackgroundColor,
                ),
                Container(height: 1, color: dividerColor),
                _buildInfoRow(
                  title: AppI18n.of(context).t(
                    zhHans: '性别',
                    zhHant: '性別',
                    en: 'Gender',
                    ja: '性別',
                    ko: '성별',
                  ),
                  value: _getGenderLabel(),
                  titleColor: titleColor,
                  valueColor: valueColor,
                  backgroundColor: cardBackgroundColor,
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  decoration: BoxDecoration(
                    color: cardBackgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppI18n.of(context).t(
                          zhHans: '系统提示：请求添加好友',
                          zhHant: '系統提示：請求新增好友',
                          en: 'System: friend request',
                          ja: 'システム：友達追加リクエスト',
                          ko: '시스템: 친구 추가 요청',
                        ),
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _buildVerifyMessage(),
                        style: TextStyle(
                          color: valueColor,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

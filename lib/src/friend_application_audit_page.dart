import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_application.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_application.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_demo/src/friend_application_helper.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/friend_add_source.dart';
import 'package:tencent_cloud_chat_uikit/data_services/friendShip/friendship_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';

class FriendApplicationAuditPage extends StatefulWidget {
  final V2TimFriendApplication application;

  const FriendApplicationAuditPage({
    Key? key,
    required this.application,
  }) : super(key: key);

  static AppMaterialPageRoute<bool> route(V2TimFriendApplication application) {
    return AppMaterialPageRoute<bool>(
      builder: (_) => FriendApplicationAuditPage(application: application),
    );
  }

  @override
  State<FriendApplicationAuditPage> createState() =>
      _FriendApplicationAuditPageState();
}

class _FriendApplicationAuditPageState extends State<FriendApplicationAuditPage> {
  final FriendshipServices _friendshipServices =
      serviceLocator<FriendshipServices>();
  V2TimUserFullInfo? _userInfo;
  bool _loadingUserInfo = true;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final userID = widget.application.userID;
    if (userID.isEmpty) {
      if (mounted) {
        setState(() => _loadingUserInfo = false);
      }
      return;
    }
    final users = await _friendshipServices.getUsersInfo(userIDList: [userID]);
    if (!mounted) {
      return;
    }
    setState(() {
      _userInfo = (users != null && users.isNotEmpty) ? users.first : null;
      _loadingUserInfo = false;
    });
  }

  String _getShowName() {
    final nickname = TencentUtils.checkString(widget.application.nickname);
    if (nickname != null && nickname.isNotEmpty) {
      return nickname;
    }
    final profileNick = TencentUtils.checkString(_userInfo?.nickName);
    if (profileNick != null && profileNick.isNotEmpty) {
      return profileNick;
    }
    return widget.application.userID;
  }

  String _getFaceUrl() {
    return widget.application.faceUrl ?? _userInfo?.faceUrl ?? '';
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
        .stripFromWording(widget.application.addWording)
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
    final iAmPrefix = i18n.t(
      zhHans: '我是',
      zhHant: '我是',
      en: 'I am',
      ja: '私は',
      ko: '저는',
    );
    final verifyPrefix = i18n.t(
      zhHans: '验证',
      zhHant: '驗證',
      en: 'Verification',
      ja: '認証',
      ko: '인증',
    );
    if (wording.startsWith(iAmPrefix) ||
        wording.startsWith('我是') ||
        wording.startsWith(verifyPrefix)) {
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
          Text(
            title,
            style: TextStyle(fontSize: 16, color: titleColor),
          ),
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
    if (_processing) {
      return;
    }
    setState(() => _processing = true);
    try {
      final success =
          await FriendApplicationHelper.accept(widget.application);
      if (!success) {
        return;
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '操作失败',
        zhHant: '操作失敗',
        en: 'Operation failed',
        ja: '操作に失敗',
        ko: '작업 실패',
      ));
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<void> _handleReject() async {
    if (_processing) {
      return;
    }
    setState(() => _processing = true);
    try {
      final success =
          await FriendApplicationHelper.reject(widget.application);
      if (!success) {
        return;
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '操作失败',
        zhHant: '操作失敗',
        en: 'Operation failed',
        ja: '操作に失敗',
        ko: '작업 실패',
      ));
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
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
      widget.application.addSource,
      addWording: widget.application.addWording,
    );

    return Scaffold(
      backgroundColor: pageBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: primaryColor,
            size: 22,
          ),
        ),
        backgroundColor: theme.appbarBgColor ?? cardBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _loadingUserInfo
          ? const Center(child: CircularProgressIndicator())
          : Column(
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
                        child: Avatar(
                          faceUrl: _getFaceUrl(),
                          showName: showName,
                          borderRadius: BorderRadius.circular(36),
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
                  value: widget.application.userID,
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
                Container(height: 1, color: dividerColor),
                _buildInfoRow(
                  title: AppI18n.of(context).t(
        zhHans: '个性签名',
        zhHant: '個性簽名',
        en: 'Bio',
        ja: '自己紹介',
        ko: '상태 메시지',
      ),
                  value: _userInfo?.selfSignature?.trim().isNotEmpty == true
                      ? _userInfo!.selfSignature!.trim()
                      : AppI18n.of(context).t(
        zhHans: '对方什么都没有写',
        zhHant: '對方什麼都沒有寫',
        en: 'No bio yet',
        ja: '自己紹介はありません',
        ko: '소개 없음',
      ),
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
                          fontSize: 14,
                          color: valueColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _buildVerifyMessage(),
                        style: TextStyle(
                          fontSize: 16,
                          color: titleColor,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed:
                          (_processing || _loadingUserInfo) ? null : _handleAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _processing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              AppI18n.of(context).t(
        zhHans: '通过验证',
        zhHant: '通過驗證',
        en: 'Accept',
        ja: '承認',
        ko: '승인',
      ),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _processing ? null : _handleReject,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: dividerColor),
                        backgroundColor: cardBackgroundColor,
                        foregroundColor: titleColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        AppI18n.of(context).t(
        zhHans: '拒绝',
        zhHant: '拒絕',
        en: 'Decline',
        ja: '拒否',
        ko: '거절',
      ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

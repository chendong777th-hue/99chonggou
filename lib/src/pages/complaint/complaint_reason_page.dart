import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/api/complaint_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/pages/complaint/complaint_form_page.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/ui/utils/desktop_modal_layout.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_wide_modal_operation_key.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/wide_popup.dart';

/// 投诉原因文案（与后端 reason 枚举一一对应）。
String complaintReasonLabel(AppI18n i18n, ComplaintReason reason) {
  switch (reason) {
    case ComplaintReason.spam:
      return i18n.t(
        zhHans: '垃圾信息',
        zhHant: '垃圾資訊',
        en: 'Spam',
        ja: 'スパム',
        ko: '스팸',
      );
    case ComplaintReason.harassment:
      return i18n.t(
        zhHans: '骚扰辱骂',
        zhHant: '騷擾辱罵',
        en: 'Harassment',
        ja: '嫌がらせ・罵倒',
        ko: '괴롭힘·욕설',
      );
    case ComplaintReason.fraud:
      return i18n.t(
        zhHans: '诈骗',
        zhHant: '詐騙',
        en: 'Fraud',
        ja: '詐欺',
        ko: '사기',
      );
    case ComplaintReason.pornography:
      return i18n.t(
        zhHans: '色情低俗',
        zhHant: '色情低俗',
        en: 'Pornography',
        ja: 'わいせつ・低俗',
        ko: '음란·저속',
      );
    case ComplaintReason.violence:
      return i18n.t(
        zhHans: '暴力威胁',
        zhHant: '暴力威脅',
        en: 'Violence / Threats',
        ja: '暴力・脅迫',
        ko: '폭력·위협',
      );
    case ComplaintReason.illegal:
      return i18n.t(
        zhHans: '违法违规',
        zhHant: '違法違規',
        en: 'Illegal activity',
        ja: '違法行為',
        ko: '위법 행위',
      );
    case ComplaintReason.other:
      return i18n.t(
        zhHans: '其他',
        zhHant: '其他',
        en: 'Other',
        ja: 'その他',
        ko: '기타',
      );
  }
}

/// 投诉原因选择页。
class ComplaintReasonPage extends StatelessWidget {
  const ComplaintReasonPage({
    super.key,
    required this.reportedUserId,
    this.reportedUserName,
    this.groupId,
    this.msgKey,
    this.msgSeq,
    this.onClose,
  });

  /// 被投诉用户 ID（单聊对方 / 群成员）。
  final String reportedUserId;
  final String? reportedUserName;

  /// 非空时走群聊投诉接口。
  final String? groupId;

  final String? msgKey;
  final int? msgSeq;

  /// 宽屏弹窗外层关闭（根页返回时关掉弹窗）。
  final VoidCallback? onClose;

  static ComplaintReasonPage _buildPage({
    required String reportedUserId,
    String? reportedUserName,
    String? groupId,
    String? msgKey,
    int? msgSeq,
    VoidCallback? onClose,
  }) {
    return ComplaintReasonPage(
      reportedUserId: reportedUserId,
      reportedUserName: reportedUserName,
      groupId: groupId,
      msgKey: msgKey,
      msgSeq: msgSeq,
      onClose: onClose,
    );
  }

  /// Web / 桌面：居中弹窗 + 内嵌 Navigator（原因 → 表单）；移动端全页。
  static Future<void> _open(
    BuildContext context, {
    required String reportedUserId,
    String? reportedUserName,
    String? groupId,
    String? msgKey,
    int? msgSeq,
  }) async {
    if (!DesktopModalLayout.isDesktop(context)) {
      await Navigator.of(context).push<void>(
        AppMaterialPageRoute(
          builder: (_) => _buildPage(
            reportedUserId: reportedUserId,
            reportedUserName: reportedUserName,
            groupId: groupId,
            msgKey: msgKey,
            msgSeq: msgSeq,
          ),
        ),
      );
      return;
    }

    // 已在其它宽屏弹窗内：局部 push，避免 isShow 互斥或再盖一层全屏。
    if (TUIKitWidePopup.isShow) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => _buildPage(
            reportedUserId: reportedUserId,
            reportedUserName: reportedUserName,
            groupId: groupId,
            msgKey: msgKey,
            msgSeq: msgSeq,
          ),
        ),
      );
      return;
    }

    final size = DesktopModalLayout.medium(context);
    await TUIKitWidePopup.showPopupWindow(
      operationKey: TUIKitWideModalOperationKey.custom,
      context: context,
      width: size.width,
      height: size.height,
      borderRadius: const BorderRadius.all(Radius.circular(20)),
      // 标题由内页 AppBar 自管，避免与表单页双头。
      child: (closeFunc) => Navigator(
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => _buildPage(
              reportedUserId: reportedUserId,
              reportedUserName: reportedUserName,
              groupId: groupId,
              msgKey: msgKey,
              msgSeq: msgSeq,
              onClose: closeFunc,
            ),
          );
        },
      ),
    );
  }

  /// 单聊投诉入口。
  static Future<void> openC2c(
    BuildContext context, {
    required String reportedUserId,
    String? reportedUserName,
    String? msgKey,
    int? msgSeq,
  }) {
    return _open(
      context,
      reportedUserId: reportedUserId,
      reportedUserName: reportedUserName,
      msgKey: msgKey,
      msgSeq: msgSeq,
    );
  }

  /// 群聊投诉入口（须已选定被投诉成员）。
  static Future<void> openGroup(
    BuildContext context, {
    required String groupId,
    required String reportedUserId,
    String? reportedUserName,
    String? msgKey,
    int? msgSeq,
  }) {
    return _open(
      context,
      groupId: groupId,
      reportedUserId: reportedUserId,
      reportedUserName: reportedUserName,
      msgKey: msgKey,
      msgSeq: msgSeq,
    );
  }

  void _handleBack(BuildContext context) {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    onClose?.call();
  }

  Future<void> _openForm(BuildContext context, ComplaintReason reason) async {
    final submitted = await Navigator.of(context).push<bool>(
      AppMaterialPageRoute(
        builder: (_) => ComplaintFormPage(
          reportedUserId: reportedUserId,
          reportedUserName: reportedUserName,
          groupId: groupId,
          reason: reason,
          msgKey: msgKey,
          msgSeq: msgSeq,
        ),
      ),
    );
    if (submitted == true && context.mounted) {
      if (onClose != null) {
        onClose!();
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final isDark = Provider.of<DefaultThemeData>(context, listen: false)
            .currentThemeType ==
        ThemeType.dark;
    final i18n = AppI18n.of(context);
    // 页底与列表卡片分层：深色用 background/surface，浅色用灰底/白卡。
    final pageBg = isDark
        ? AppColors.background(dark: true)
        : const Color(0xFFF1F1F1);
    final cardBg = isDark ? AppColors.card(dark: true) : Colors.white;
    final appBarBg = isDark
        ? (theme.appbarBgColor ?? cardBg)
        : (theme.appbarBgColor ?? Colors.white);
    final line = isDark
        ? AppColors.line(dark: true)
        : (theme.weakDividerColor ?? AppColors.line(dark: false));
    final textColor = theme.darkTextColor ?? AppColors.text(dark: isDark);
    final weakColor = theme.weakTextColor ?? AppColors.subText(dark: isDark);
    final primary = theme.primaryColor ?? AppColors.primaryBlue;
    final reasons = ComplaintReason.values;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: appBarBg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: primary,
          onPressed: () => _handleBack(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.6),
          child: Container(height: 0.6, color: line),
        ),
        title: Text(
          i18n.t(
            zhHans: '投诉原因',
            zhHant: '投訴原因',
            en: 'Complaint Reason',
            ja: '通報理由',
            ko: '신고 사유',
          ),
          style: TextStyle(
            color: textColor,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 10, bottom: 24),
        children: [
          Container(
            color: cardBg,
            child: Column(
              children: List.generate(reasons.length * 2 - 1, (index) {
                if (index.isOdd) {
                  return Divider(
                    height: 0.6,
                    thickness: 0.6,
                    indent: 16,
                    color: line,
                  );
                }
                final reason = reasons[index ~/ 2];
                return InkWell(
                  onTap: () => _openForm(context, reason),
                  child: SizedBox(
                    height: 56,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              complaintReasonLabel(i18n, reason),
                              style: TextStyle(
                                fontSize: 16,
                                color: textColor,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: weakColor,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

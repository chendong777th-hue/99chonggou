import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_join_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_join_option.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_tip_custom_sender.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

/// 管理群页：自建 Public / Meeting / Community 的加群方式（REST）。
class GroupJoinOptionsHeader extends StatefulWidget {
  final String groupId;
  final TUITheme theme;

  const GroupJoinOptionsHeader({
    super.key,
    required this.groupId,
    required this.theme,
  });

  @override
  State<GroupJoinOptionsHeader> createState() => _GroupJoinOptionsHeaderState();
}

class _GroupJoinOptionsHeaderState extends State<GroupJoinOptionsHeader> {
  GroupJoinOptions? _options;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final options = await GroupJoinApi.instance.fetchJoinOptions(widget.groupId);
      if (!mounted) return;
      setState(() {
        _options = options;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _pickOption({
    required String title,
    required GroupJoinOption current,
    required Future<void> Function(GroupJoinOption selected) onSelected,
  }) async {
    final i18n = AppI18n.of(context);
    final choices = GroupJoinOption.values;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: Text(title),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: Text(i18n.t(
              zhHans: '取消',
              zhHant: '取消',
              en: 'Cancel',
              ja: 'キャンセル',
              ko: '취소',
            )),
          ),
          actions: choices
              .map(
                (option) => CupertinoActionSheetAction(
                  onPressed: () async {
                    Navigator.pop(context);
                    await onSelected(option);
                  },
                  child: Text(
                    option.localizedLabel(i18n),
                    style: TextStyle(
                      color: option == current
                          ? widget.theme.primaryColor
                          : null,
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Future<bool> _confirmDisableJoinSwitch({
    required String title,
    required String message,
  }) {
    final i18n = AppI18n.of(context);
    return AppDialog.confirm(
      title: title,
      message: message,
      confirmText: i18n.t(
        zhHans: '关闭',
        zhHant: '關閉',
        en: 'Turn Off',
        ja: 'オフにする',
        ko: '끄기',
      ),
      destructive: true,
    );
  }

  Future<void> _updateOptions(GroupJoinOptions next) async {
    final before = _options;
    try {
      final saved = await GroupJoinApi.instance.updateJoinOptions(
        widget.groupId,
        next,
      );
      if (!mounted) return;
      setState(() => _options = saved);
      if (before != null) {
        unawaited(
          GroupTipCustomSender.instance.sendJoinOptionsDiff(
            groupId: widget.groupId,
            before: before,
            after: saved,
          ),
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppI18n.of(context).t(
            zhHans: '修改成功',
            zhHant: '修改成功',
            en: 'Updated',
            ja: '更新しました',
            ko: '수정되었습니다',
          )),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1300),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppI18n.of(context).t(
            zhHans: '修改失败',
            zhHant: '修改失敗',
            en: 'Update failed',
            ja: '更新に失敗しました',
            ko: '수정 실패',
          )),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onAllowJoinByQrCodeChanged(
    GroupJoinOptions options,
    bool value,
  ) async {
    if (!value && options.allowJoinByQrCode) {
      final i18n = AppI18n.of(context);
      final confirmed = await _confirmDisableJoinSwitch(
        title: i18n.t(
          zhHans: '关闭群二维码加群',
          zhHant: '關閉群 QR 碼加群',
          en: 'Disable QR Join',
          ja: 'QR参加をオフ',
          ko: 'QR 가입 끄기',
        ),
        message: i18n.t(
          zhHans: '关闭后，将无法通过群二维码加入本群。确定关闭吗？',
          zhHant: '關閉後，將無法通過群 QR 碼加入本群。確定關閉嗎？',
          en: 'After turning off, users cannot join via group QR code. Continue?',
          ja: 'オフにすると、グループQRコードからの参加ができなくなります。よろしいですか？',
          ko: '끄면 그룹 QR 코드로 가입할 수 없습니다. 계속할까요?',
        ),
      );
      if (!confirmed || !mounted) return;
    }
    await _updateOptions(options.copyWith(allowJoinByQrCode: value));
  }

  Future<void> _onAllowJoinByAliasChanged(
    GroupJoinOptions options,
    bool value,
  ) async {
    if (!value && options.allowJoinByAlias) {
      final i18n = AppI18n.of(context);
      final confirmed = await _confirmDisableJoinSwitch(
        title: i18n.t(
          zhHans: '关闭群别名加群',
          zhHant: '關閉群別名加群',
          en: 'Disable Alias Join',
          ja: '別名参加をオフ',
          ko: '별명 가입 끄기',
        ),
        message: i18n.t(
          zhHans: '关闭后，将无法通过群别名加入本群。确定关闭吗？',
          zhHant: '關閉後，將無法通過群別名加入本群。確定關閉嗎？',
          en: 'After turning off, users cannot join via group alias. Continue?',
          ja: 'オフにすると、グループ別名からの参加ができなくなります。よろしいですか？',
          ko: '끄면 그룹 별명으로 가입할 수 없습니다. 계속할까요?',
        ),
      );
      if (!confirmed || !mounted) return;
    }
    await _updateOptions(options.copyWith(allowJoinByAlias: value));
  }

  Widget _row({
    required String title,
    required String value,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    final surface = widget.theme.conversationItemBgColor ??
        widget.theme.wideBackgroundColor ??
        Colors.white;
    final divider = widget.theme.weakDividerColor ?? const Color(0xFFE5E5E5);
    return Material(
      color: surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: showDivider
                ? Border(bottom: BorderSide(color: divider, width: 0.5))
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    color: widget.theme.darkTextColor,
                  ),
                ),
              ),
              Text(
                _loading ? '...' : value,
                style: TextStyle(
                  fontSize: 15,
                  color: widget.theme.weakTextColor,
                ),
              ),
              Icon(
                Icons.keyboard_arrow_right,
                color: widget.theme.weakTextColor,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _switchRow({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool showDivider = true,
  }) {
    final surface = widget.theme.conversationItemBgColor ??
        widget.theme.wideBackgroundColor ??
        Colors.white;
    final divider = widget.theme.weakDividerColor ?? const Color(0xFFE5E5E5);
    return Material(
      color: surface,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(bottom: BorderSide(color: divider, width: 0.5))
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: widget.theme.darkTextColor,
                ),
              ),
            ),
            Switch.adaptive(
              value: _loading ? false : value,
              onChanged: _loading ? null : onChanged,
              activeColor: widget.theme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final options = _options ??
        const GroupJoinOptions(
          applyJoinOption: GroupJoinOption.needPermission,
          inviteJoinOption: GroupJoinOption.needPermission,
        );

    return Column(
      children: [
        _row(
          title: i18n.t(
            zhHans: '申请加群',
            zhHant: '申請加群',
            en: 'Join Requests',
            ja: '参加申請',
            ko: '가입 신청',
          ),
          value: options.applyJoinOption.localizedLabel(i18n),
          onTap: () => _pickOption(
            title: i18n.t(
              zhHans: '申请加群方式',
              zhHant: '申請加群方式',
              en: 'Join Request Policy',
              ja: '参加申請の方式',
              ko: '가입 신청 방식',
            ),
            current: options.applyJoinOption,
            onSelected: (selected) => _updateOptions(
              options.copyWith(applyJoinOption: selected),
            ),
          ),
        ),
        _row(
          title: i18n.t(
            zhHans: '成员邀请好友',
            zhHant: '成員邀請好友',
            en: 'Member Invites',
            ja: 'メンバー招待',
            ko: '멤버 초대',
          ),
          value: options.inviteJoinOption.localizedLabel(i18n),
          onTap: () => _pickOption(
            title: i18n.t(
              zhHans: '成员邀请方式',
              zhHant: '成員邀請方式',
              en: 'Member Invite Policy',
              ja: 'メンバー招待の方式',
              ko: '멤버 초대 방식',
            ),
            current: options.inviteJoinOption,
            onSelected: (selected) => _updateOptions(
              options.copyWith(inviteJoinOption: selected),
            ),
          ),
        ),
        _switchRow(
          title: i18n.t(
            zhHans: '允许通过群二维码加群',
            zhHant: '允許通過群 QR 碼加群',
            en: 'Allow join via group QR code',
            ja: 'グループQRコードからの参加を許可',
            ko: '그룹 QR 코드 가입 허용',
          ),
          value: options.allowJoinByQrCode,
          onChanged: (value) => _onAllowJoinByQrCodeChanged(options, value),
        ),
        _switchRow(
          title: i18n.t(
            zhHans: '允许通过群别名加群',
            zhHant: '允許通過群別名加群',
            en: 'Allow join via group alias',
            ja: 'グループ別名からの参加を許可',
            ko: '그룹 별명 가입 허용',
          ),
          value: options.allowJoinByAlias,
          showDivider: false,
          onChanged: (value) => _onAllowJoinByAliasChanged(options, value),
        ),
      ],
    );
  }
}

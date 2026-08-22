import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_demo/src/api/sangong_admin_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/sangong_my_config.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/settings_widgets.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/utils/dio_error_message.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';


/// 三公成员管理：群主添加帮工（走 `/admin/my-config/members`，不拼群 ID）。
class SangongMembersPage extends StatefulWidget {
  const SangongMembersPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push<void>(
      AppMaterialPageRoute(
        settings: const RouteSettings(name: 'sangong_members'),
        builder: (_) => const SangongMembersPage(),
      ),
    );
  }

  /// 配置保存成功后替换当前页，直接进入加帮工。
  static Future<void> openReplace(BuildContext context) {
    return Navigator.of(context).pushReplacement(
      AppMaterialPageRoute(
        settings: const RouteSettings(name: 'sangong_members'),
        builder: (_) => const SangongMembersPage(),
      ),
    );
  }

  @override
  State<SangongMembersPage> createState() => _SangongMembersPageState();
}

class _SangongMembersPageState extends State<SangongMembersPage> {
  bool _loading = true;
  bool _busy = false;
  String? _errorMessage;
  List<SangongTenantAccessMember> _members = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final members = await SangongAdminApi.instance.fetchMyConfigMembers();
      if (!mounted) return;
      int rank(SangongTenantAccessMember m) {
        if (m.isOwner) return 0;
        if (m.isAdmin) return 1;
        return 2;
      }

      members.sort((a, b) {
        final byRole = rank(a).compareTo(rank(b));
        if (byRole != 0) return byRole;
        return a.imUserId.compareTo(b.imUserId);
      });
      setState(() {
        _members = members;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = DioErrorMessage.forApp(error);
      });
    }
  }

  String _roleLabel(AppI18n i18n, SangongTenantAccessMember member) {
    if (member.isOwner) {
      return i18n.t(zhHans: '群主', zhHant: '群主', en: 'Owner');
    }
    if (member.isAdmin) {
      return i18n.t(zhHans: '帮工', zhHant: '幫工', en: 'Helper');
    }
    return member.role;
  }

  Future<void> _showAddHelperDialog() async {
    if (_busy) return;
    final i18n = AppI18n.of(context);
    final imUserId = await AppDialog.prompt(
      title: i18n.t(zhHans: '添加帮工', zhHant: '添加幫工', en: 'Add helper'),
      message: i18n.t(
        zhHans: '对方须为特权用户。添加后可在本下注群操作台上下分、跑局，不能改配置。',
        zhHant: '對方須為特權用戶。添加後可在本下注群操作台上下分、跑局，不能改配置。',
        en: 'Helper must be privileged. They can operate but not edit config.',
      ),
      placeholder: i18n.t(
        zhHans: '对方用户 ID',
        zhHant: '對方用戶 ID',
        en: 'User ID',
      ),
      cancelText: i18n.t(zhHans: '取消', zhHant: '取消', en: 'Cancel'),
      confirmText: i18n.t(zhHans: '添加', zhHant: '添加', en: 'Add'),
      inputFormatters: [
        FilteringTextInputFormatter.deny(RegExp(r'\s')),
      ],
    );
    if (imUserId == null || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await SangongAdminApi.instance.upsertMyConfigMember(
        imUserId: imUserId,
        role: 'admin',
      );
      if (!mounted) return;
      ToastUtils.toast(
        i18n.t(zhHans: '已添加帮工', zhHant: '已添加幫工', en: 'Helper added'),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ToastUtils.toast(DioErrorMessage.forApp(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _removeMember(SangongTenantAccessMember member) async {
    if (_busy || member.imUserId.isEmpty) return;
    final i18n = AppI18n.of(context);
    if (member.isOwner) {
      ToastUtils.toast(
        i18n.t(
          zhHans: '不能直接移除群主',
          zhHant: '不能直接移除群主',
          en: 'Cannot remove owner',
        ),
      );
      return;
    }
    final ok = await AppDialog.confirm(
      title: i18n.t(zhHans: '移除帮工', zhHant: '移除幫工', en: 'Remove helper'),
      message: i18n.t(
        zhHans: '确定移除 ${member.imUserId}？移除后对方将看不到本群三公入口。',
        zhHant: '確定移除 ${member.imUserId}？移除後對方將看不到本群三公入口。',
        en: 'Remove ${member.imUserId}? They will lose access.',
      ),
      confirmText: i18n.t(zhHans: '移除', zhHant: '移除', en: 'Remove'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await SangongAdminApi.instance.removeMyConfigMember(
        imUserId: member.imUserId,
      );
      if (!mounted) return;
      ToastUtils.toast(
        i18n.t(zhHans: '已移除', zhHant: '已移除', en: 'Removed'),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ToastUtils.toast(DioErrorMessage.forApp(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final dark = settingsIsDark(context);
    final title = i18n.t(
      zhHans: '成员管理',
      zhHant: '成員管理',
      en: 'Members',
    );

    if (_loading) {
      return SettingsScaffold(
        title: title,
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      );
    }

    if (_errorMessage != null && _members.isEmpty) {
      return SettingsScaffold(
        title: title,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Text(
              _errorMessage!,
              style: TextStyle(color: AppColors.subText(dark: dark)),
            ),
          ),
          SettingsPrimaryButton(
            text: i18n.t(zhHans: '重试', zhHant: '重試', en: 'Retry'),
            onPressed: _load,
          ),
        ],
      );
    }

    return SettingsScaffold(
      title: title,
      bottom: SettingsPrimaryButton(
        text: _busy
            ? i18n.t(zhHans: '处理中...', zhHant: '處理中...', en: 'Working...')
            : i18n.t(zhHans: '添加帮工', zhHant: '添加幫工', en: 'Add helper'),
        onPressed: _busy ? () {} : _showAddHelperDialog,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            i18n.t(
              zhHans: '帮工必须同样是特权用户。添加后进入本下注群即可使用操作台。',
              zhHant: '幫工必須同樣是特權用戶。添加後進入本下注群即可使用操作台。',
              en: 'Helpers must also be privileged users.',
            ),
            style: TextStyle(
              color: AppColors.subText(dark: dark),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ),
        if (_members.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Text(
              i18n.t(
                zhHans: '暂无成员',
                zhHant: '暫無成員',
                en: 'No members yet',
              ),
              style: TextStyle(color: AppColors.subText(dark: dark)),
            ),
          )
        else
          SettingsGroup(
            children: [
              for (var i = 0; i < _members.length; i++)
                SettingsCell(
                  title: _members[i].imUserId,
                  value: _roleLabel(i18n, _members[i]),
                  showArrow: !_members[i].isOwner,
                  showDivider: i < _members.length - 1,
                  onTap: _members[i].isOwner
                      ? null
                      : () => unawaited(_removeMember(_members[i])),
                ),
            ],
          ),
      ],
    );
  }
}

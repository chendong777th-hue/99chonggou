import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_privacy_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_tip_custom_sender.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/utils/group_privacy_guard.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/utils/user_api_error_message.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

class GroupPrivacySettingsRow extends StatefulWidget {
  final String groupId;
  final bool canEdit;
  final TUITheme theme;

  const GroupPrivacySettingsRow({
    Key? key,
    required this.groupId,
    required this.canEdit,
    required this.theme,
  }) : super(key: key);

  @override
  State<GroupPrivacySettingsRow> createState() =>
      _GroupPrivacySettingsRowState();
}

class _GroupPrivacySettingsRowState extends State<GroupPrivacySettingsRow> {
  bool? _value;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final settings = await GroupPrivacyApi.instance.fetch(widget.groupId);
      GroupPrivacyCache.set(
        widget.groupId,
        settings.privacyProtectionEnabled,
      );
      if (!mounted) return;
      setState(() {
        _value = settings.privacyProtectionEnabled;
        _loading = false;
      });
    } on DioError catch (e) {
      if (!mounted) return;
      final code = _errorCode(e);
      setState(() {
        _loadError = code == 'NOT_GROUP_MEMBER'
            ? AppI18n.current.t(
                zhHans: '无权限查看',
                zhHant: '無權限查看',
                en: 'No permission to view',
                ja: 'No permission to view',
                ko: 'No permission to view',
              )
            : UserApiErrorMessage.fromGroupPrivacy(e);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = AppI18n.current.t(
          zhHans: '加载失败',
          zhHant: '載入失敗',
          en: 'Failed to load',
          ja: 'Failed to load',
          ko: 'Failed to load',
        );
        _loading = false;
      });
    }
  }

  String? _errorCode(DioError e) {
    final data = e.response?.data;
    if (data is Map) {
      final code = data['code'] ?? data['errorCode'] ?? data['errCode'];
      return code?.toString().trim();
    }
    return null;
  }

  Future<void> _onChanged(bool next) async {
    if (!widget.canEdit || _saving) return;
    final previous = _value ?? false;
    if (!next && previous) {
      final i18n = AppI18n.of(context);
      final confirmed = await AppDialog.confirm(
        title: i18n.t(
          zhHans: '关闭群隐私保护',
          zhHant: '關閉群隱私保護',
          en: 'Disable Privacy Protection',
          ja: 'プライバシー保護をオフ',
          ko: '개인정보 보호 끄기',
        ),
        message: i18n.t(
          zhHans: '关闭后，群成员可按默认规则查看资料。确定关闭吗？',
          zhHant: '關閉後，群成員可按預設規則查看資料。確定關閉嗎？',
          en: 'After turning off, members can view profiles under default rules. Continue?',
          ja: 'オフにすると、メンバーは既定ルールで資料を閲覧できます。よろしいですか？',
          ko: '끄면 멤버가 기본 규칙으로 자료를 볼 수 있습니다. 계속할까요?',
        ),
        confirmText: i18n.t(
          zhHans: '关闭',
          zhHant: '關閉',
          en: 'Turn Off',
          ja: 'オフにする',
          ko: '끄기',
        ),
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }
    setState(() {
      _value = next;
      _saving = true;
    });
    try {
      final saved = await GroupPrivacyApi.instance.save(widget.groupId, next);
      GroupPrivacyCache.set(
        widget.groupId,
        saved.privacyProtectionEnabled,
      );
      if (!mounted) return;
      setState(() {
        _value = saved.privacyProtectionEnabled;
        _saving = false;
      });
      unawaited(
        GroupTipCustomSender.instance.sendPrivacyChanged(
          groupId: widget.groupId,
          enabled: saved.privacyProtectionEnabled,
        ),
      );
    } on DioError catch (e) {
      if (!mounted) return;
      setState(() {
        _value = previous;
        _saving = false;
      });
      ToastUtils.toast(UserApiErrorMessage.fromGroupPrivacy(e));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _value = previous;
        _saving = false;
      });
      ToastUtils.toast(AppI18n.current.t(
        zhHans: '保存失败',
        zhHant: '儲存失敗',
        en: 'Failed to save',
        ja: 'Failed to save',
        ko: 'Failed to save',
      ));
    }
  }

  String _subtitle(bool enabled) {
    if (enabled) {
      return AppI18n.current.t(
        zhHans: '已开启，将限制群内资料与添加方式',
        zhHant: '已開啟，將限制群內資料與添加方式',
        en: 'Enabled. Group profile and add methods are restricted.',
        ja: 'Enabled. Group profile and add methods are restricted.',
        ko: 'Enabled. Group profile and add methods are restricted.',
      );
    }
    return AppI18n.current.t(
      zhHans: '关闭后，群成员可按默认规则查看资料',
      zhHant: '關閉後，群成員可按預設規則查看資料',
      en: 'When off, members can view profiles under default rules.',
      ja: 'When off, members can view profiles under default rules.',
      ko: 'When off, members can view profiles under default rules.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    if (_loadError != null) {
      return const SizedBox.shrink();
    }
    if (_loading || _value == null) {
      return SizedBox(
        height: 72,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.theme.primaryColor,
            ),
          ),
        ),
      );
    }

    final enabled = _value!;
    final switchEnabled = widget.canEdit && !_saving;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  i18n.t(
                    zhHans: '群隐私保护',
                    zhHant: '群隱私保護',
                    en: 'Group Privacy Protection',
                    ja: 'Group Privacy Protection',
                    ko: 'Group Privacy Protection',
                  ),
                  style: TextStyle(
                    fontSize: 15,
                    color: widget.theme.darkTextColor ?? Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _subtitle(enabled),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: widget.theme.weakTextColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Transform.scale(
            scale: 0.92,
            child: CupertinoSwitch(
              value: enabled,
              onChanged: switchEnabled ? _onChanged : null,
              activeTrackColor: widget.theme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

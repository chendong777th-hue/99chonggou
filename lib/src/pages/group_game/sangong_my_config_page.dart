import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/api/sangong_admin_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/sangong_game_http.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/sangong_my_config.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/settings_widgets.dart';
import 'package:tencent_cloud_chat_demo/src/pages/group_game/sangong_members_page.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_game/sangong_my_config_service.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/dio_error_message.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';

/// 三公「我的配置」：绑定下注群 / 结账群 / 机器人（仅群主可改）。
class SangongMyConfigPage extends StatefulWidget {
  const SangongMyConfigPage({
    super.key,
    this.initialGameGroupId = '',
    this.onSaved,
  });

  /// 从当前聊天进入时预填下注群。
  final String initialGameGroupId;
  final ValueChanged<SangongMyConfig>? onSaved;

  static Future<SangongMyConfig?> open(
    BuildContext context, {
    String initialGameGroupId = '',
    ValueChanged<SangongMyConfig>? onSaved,
  }) {
    return Navigator.of(context).push<SangongMyConfig>(
      AppMaterialPageRoute(
        settings: const RouteSettings(name: 'sangong_my_config'),
        builder: (_) => SangongMyConfigPage(
          initialGameGroupId: initialGameGroupId,
          onSaved: onSaved,
        ),
      ),
    );
  }

  @override
  State<SangongMyConfigPage> createState() => _SangongMyConfigPageState();
}

class _SangongMyConfigPageState extends State<SangongMyConfigPage> {
  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;
  SangongMyConfig _config = const SangongMyConfig();

  late final TextEditingController _nameController;
  late final TextEditingController _gameGroupController;
  late final TextEditingController _statsGroupController;
  late final TextEditingController _botController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _gameGroupController = TextEditingController(
      text: ChatIdFormat.normalizeGroupId(widget.initialGameGroupId),
    );
    _statsGroupController = TextEditingController();
    _botController = TextEditingController();
    unawaited(_load());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _gameGroupController.dispose();
    _statsGroupController.dispose();
    _botController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cached = SangongMyConfigService.instance.hasCachedConfig
        ? SangongMyConfigService.instance.config
        : null;
    if (cached != null) {
      _applyConfig(cached);
      setState(() {
        _config = cached;
        _loading = false;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }
    try {
      final config = await SangongMyConfigService.instance.refreshFromNetwork();
      if (!mounted) return;
      _applyConfig(config);
      setState(() {
        _config = config;
        _loading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      if (cached != null) {
        setState(() => _loading = false);
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage = DioErrorMessage.forApp(error);
      });
    }
  }

  void _applyConfig(SangongMyConfig config) {
    if (config.configured) {
      _nameController.text = config.name;
      _gameGroupController.text = config.imGroupGameId;
      _statsGroupController.text = config.imGroupAdminStatsId;
      _botController.text = config.imBotUserId;
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      _nameController.text = '一号厅';
    }
    final preset = ChatIdFormat.normalizeGroupId(widget.initialGameGroupId);
    if (_gameGroupController.text.trim().isEmpty && preset.isNotEmpty) {
      _gameGroupController.text = preset;
    }
  }

  bool get _canEdit {
    if (!_config.configured) {
      return true;
    }
    return _config.canEditConfig || _config.isOwner;
  }

  Future<void> _save() async {
    if (_saving || !_canEdit) {
      return;
    }
    final i18n = AppI18n.of(context);
    final name = _nameController.text.trim();
    final gameGroup =
        ChatIdFormat.normalizeGroupId(_gameGroupController.text.trim());
    final statsGroup =
        ChatIdFormat.normalizeGroupId(_statsGroupController.text.trim());
    final bot = _botController.text.trim();

    if (name.isEmpty) {
      ToastUtils.toast(
        i18n.t(zhHans: '请填写厅名', zhHant: '請填寫廳名', en: 'Enter a name'),
      );
      return;
    }
    if (gameGroup.isEmpty) {
      ToastUtils.toast(
        i18n.t(
          zhHans: '请填写下注群 ID',
          zhHant: '請填寫下注群 ID',
          en: 'Enter game group ID',
        ),
      );
      return;
    }
    if (statsGroup.isEmpty) {
      ToastUtils.toast(
        i18n.t(
          zhHans: '请填写结账群 ID',
          zhHant: '請填寫結賬群 ID',
          en: 'Enter settle group ID',
        ),
      );
      return;
    }
    if (bot.isEmpty) {
      ToastUtils.toast(
        i18n.t(
          zhHans: '请填写机器人 IM 号',
          zhHant: '請填寫機器人 IM 號',
          en: 'Enter bot user ID',
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final saved = await SangongAdminApi.instance.saveMyConfig(
        name: name,
        imGroupGameId: gameGroup,
        imGroupAdminStatsId: statsGroup,
        imBotUserId: bot,
      );
      if (!mounted) return;
      final wasFirstSetup = !_config.configured;
      final normalized = saved.configured
          ? saved
          : saved.copyWith(configured: true, canEditConfig: true);
      await SangongMyConfigService.instance.applySaved(normalized);
      if (!mounted) return;
      final tenant = normalized.tenantId.isNotEmpty
          ? normalized.tenantId
          : normalized.imGroupGameId;
      if (tenant.isNotEmpty) {
        SangongGameHttp.setTenantId(tenant);
      }
      final canManageMembers =
          normalized.canManageMembers || normalized.isOwner;
      setState(() {
        _config = normalized;
        _saving = false;
      });
      widget.onSaved?.call(_config);
      ToastUtils.toast(
        i18n.t(zhHans: '已保存', zhHant: '已保存', en: 'Saved'),
      );
      if (!mounted) return;
      // 首次绑定成功后进成员页加帮工（走 /my-config/members，不拼群 ID）。
      if (wasFirstSetup && canManageMembers) {
        await SangongMembersPage.openReplace(context);
      } else {
        Navigator.of(context).pop(_config);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ToastUtils.toast(DioErrorMessage.forApp(error));
    }
  }

  void _fillCurrentChatAsGameGroup() {
    final preset = ChatIdFormat.normalizeGroupId(widget.initialGameGroupId);
    if (preset.isEmpty) {
      return;
    }
    setState(() => _gameGroupController.text = preset);
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final dark = settingsIsDark(context);
    final title = i18n.t(
      zhHans: '我的配置',
      zhHant: '我的配置',
      en: 'My Config',
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

    if (_errorMessage != null && !_config.configured) {
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

    final readOnly = !_canEdit;
    return SettingsScaffold(
      title: title,
      dismissKeyboardOnOutsideTap: true,
      bottom: _canEdit
          ? SettingsPrimaryButton(
              text: _saving
                  ? i18n.t(zhHans: '保存中...', zhHant: '保存中...', en: 'Saving...')
                  : i18n.t(zhHans: '保存', zhHant: '保存', en: 'Save'),
              onPressed: _saving ? () {} : _save,
            )
          : null,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            _config.configured
                ? i18n.t(
                    zhHans: _canEdit
                        ? '保存后，只有绑定的下注群聊天里才会出现三公入口。结账群用于管理账单。'
                        : '你是帮工，只能在操作台上下分跑局，不能改配置。',
                    zhHant: _canEdit
                        ? '保存後，只有綁定的下注群聊天裡才會出現三公入口。結賬群用於管理帳單。'
                        : '你是幫工，只能在操作台上下分跑局，不能改配置。',
                    en: _canEdit
                        ? 'After saving, the entry only appears in the bound game group.'
                        : 'Helpers can operate rounds but cannot edit config.',
                  )
                : i18n.t(
                    zhHans: '首次配置：绑定本厅的下注群、结账群和机器人。保存后你将成为该群群主。',
                    zhHant: '首次配置：綁定本廳的下注群、結賬群和機器人。保存後你將成為該群群主。',
                    en: 'Bind game group, settle group and bot. You become owner after save.',
                  ),
            style: TextStyle(
              color: AppColors.subText(dark: dark),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ),
        if (_config.configured)
          SettingsGroup(
            children: [
              SettingsCell(
                title: i18n.t(zhHans: '我的角色', zhHant: '我的角色', en: 'Role'),
                value: _config.isOwner
                    ? i18n.t(zhHans: '群主', zhHant: '群主', en: 'Owner')
                    : _config.isAdmin
                        ? i18n.t(zhHans: '帮工', zhHant: '幫工', en: 'Helper')
                        : _config.myRole,
                showArrow: false,
                showDivider: false,
              ),
            ],
          ),
        SettingsGroup(
          children: [
            SettingsInputCell(
              label: i18n.t(zhHans: '厅名', zhHant: '廳名', en: 'Name'),
              hint: i18n.t(zhHans: '一号厅', zhHant: '一號廳', en: 'Hall 1'),
              controller: _nameController,
              readOnly: readOnly,
            ),
            SettingsInputCell(
              label: i18n.t(zhHans: '下注群', zhHant: '下注群', en: 'Game group'),
              hint: '@TGS#...',
              controller: _gameGroupController,
              readOnly: readOnly || _config.configured,
            ),
            SettingsInputCell(
              label: i18n.t(zhHans: '结账群', zhHant: '結賬群', en: 'Settle group'),
              hint: '@TGS#...',
              controller: _statsGroupController,
              readOnly: readOnly,
            ),
            SettingsInputCell(
              label: i18n.t(zhHans: '机器人', zhHant: '機器人', en: 'Bot'),
              hint: i18n.t(
                zhHans: 'IM UserID',
                zhHant: 'IM UserID',
                en: 'IM UserID',
              ),
              controller: _botController,
              readOnly: readOnly,
            ),
          ],
        ),
        if (_canEdit &&
            !_config.configured &&
            widget.initialGameGroupId.trim().isNotEmpty)
          SettingsGroup(
            children: [
              SettingsCell(
                title: i18n.t(
                  zhHans: '使用当前聊天群作为下注群',
                  zhHant: '使用當前聊天群作為下注群',
                  en: 'Use current chat as game group',
                ),
                showDivider: false,
                onTap: _fillCurrentChatAsGameGroup,
              ),
            ],
          ),
      ],
    );
  }
}

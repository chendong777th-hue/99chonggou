import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';

/// 加群 / 邀请入群方式（与 99chat-server `GroupJoinOption` 对齐）。
enum GroupJoinOption {
  freeAccess('free_access'),
  needPermission('need_permission'),
  disabled('disabled');

  const GroupJoinOption(this.storageValue);

  final String storageValue;

  static GroupJoinOption fromStorage(String? raw) {
    final normalized = raw?.trim().toLowerCase();
    switch (normalized) {
      case 'free_access':
        return GroupJoinOption.freeAccess;
      case 'disabled':
        return GroupJoinOption.disabled;
      case 'need_permission':
      default:
        return GroupJoinOption.needPermission;
    }
  }
}

class GroupJoinOptions {
  const GroupJoinOptions({
    required this.applyJoinOption,
    required this.inviteJoinOption,
    this.allowJoinByQrCode = true,
    this.allowJoinByAlias = true,
  });

  final GroupJoinOption applyJoinOption;
  final GroupJoinOption inviteJoinOption;
  final bool allowJoinByQrCode;
  final bool allowJoinByAlias;

  GroupJoinOptions copyWith({
    GroupJoinOption? applyJoinOption,
    GroupJoinOption? inviteJoinOption,
    bool? allowJoinByQrCode,
    bool? allowJoinByAlias,
  }) {
    return GroupJoinOptions(
      applyJoinOption: applyJoinOption ?? this.applyJoinOption,
      inviteJoinOption: inviteJoinOption ?? this.inviteJoinOption,
      allowJoinByQrCode: allowJoinByQrCode ?? this.allowJoinByQrCode,
      allowJoinByAlias: allowJoinByAlias ?? this.allowJoinByAlias,
    );
  }

  factory GroupJoinOptions.fromJson(Map<String, dynamic> json) {
    return GroupJoinOptions(
      applyJoinOption: GroupJoinOption.fromStorage(
        _readString(json, const [
          'applyJoinOption',
          'apply_join_option',
        ]),
      ),
      inviteJoinOption: GroupJoinOption.fromStorage(
        _readString(json, const [
          'inviteJoinOption',
          'invite_join_option',
        ]),
      ),
      allowJoinByQrCode: _readBool(
        json,
        const [
          'allowJoinByQrCode',
          'allow_join_by_qr_code',
        ],
        fallback: true,
      ),
      allowJoinByAlias: _readBool(
        json,
        const [
          'allowJoinByAlias',
          'allow_join_by_alias',
        ],
        fallback: true,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'applyJoinOption': applyJoinOption.storageValue,
        'inviteJoinOption': inviteJoinOption.storageValue,
        'allowJoinByQrCode': allowJoinByQrCode,
        'allowJoinByAlias': allowJoinByAlias,
      };

  static bool _readBool(
    Map<String, dynamic> json,
    List<String> keys, {
    required bool fallback,
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) {
        continue;
      }
      if (value is bool) {
        return value;
      }
      if (value is num) {
        return value != 0;
      }
      final text = value.toString().trim().toLowerCase();
      if (text.isEmpty) {
        continue;
      }
      if (text == 'true' || text == '1' || text == 'yes' || text == 'on') {
        return true;
      }
      if (text == 'false' || text == '0' || text == 'no' || text == 'off') {
        return false;
      }
    }
    return fallback;
  }

  static String? _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }
}

extension GroupJoinOptionUi on GroupJoinOption {
  String localizedLabel(AppI18n i18n) {
    switch (this) {
      case GroupJoinOption.freeAccess:
        return i18n.t(
          zhHans: '自动审批',
          zhHant: '自動審批',
          en: 'Auto Approve',
          ja: '自動承認',
          ko: '자동 승인',
        );
      case GroupJoinOption.needPermission:
        return i18n.t(
          zhHans: '管理员审批',
          zhHant: '管理員審批',
          en: 'Admin Approval',
          ja: '管理者承認',
          ko: '관리자 승인',
        );
      case GroupJoinOption.disabled:
        return i18n.t(
          zhHans: '禁止',
          zhHant: '禁止',
          en: 'Disabled',
          ja: '禁止',
          ko: '금지',
        );
    }
  }
}

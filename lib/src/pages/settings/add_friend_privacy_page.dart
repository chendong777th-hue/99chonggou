import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/api/user_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/settings_widgets.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/utils/user_api_error_message.dart';

class AddFriendPrivacyPage extends StatefulWidget {
  const AddFriendPrivacyPage({super.key});

  @override
  State<AddFriendPrivacyPage> createState() => _AddFriendPrivacyPageState();
}

class _AddFriendPrivacyPageState extends State<AddFriendPrivacyPage> {
  AddFriendPrivacySettings? _settings;
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
      final settings = await UserApi.instance.fetchPrivacy();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _loading = false;
      });
    } on DioError catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = UserApiErrorMessage.fromPrivacy(e);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = AppI18n.current.t(
          zhHans: '加载失败',
          zhHant: '載入失敗',
          en: 'Failed to load.',
          ja: '読み込みに失敗しました。',
          ko: '불러오기에 실패했습니다.',
        );
        _loading = false;
      });
    }
  }

  Future<void> _updateValue(
    void Function(AddFriendPrivacySettings settings) updater,
  ) async {
    final current = _settings;
    if (current == null || _saving) return;

    final previous = current.copyWith();
    setState(() {
      updater(current);
      _saving = true;
    });

    try {
      final saved = await UserApi.instance.updatePrivacy(current);
      if (!mounted) return;
      setState(() {
        _settings = saved;
        _saving = false;
      });
    } on DioError catch (e) {
      if (!mounted) return;
      setState(() {
        _settings = previous;
        _saving = false;
      });
      ToastUtils.toast(UserApiErrorMessage.fromPrivacy(e));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _settings = previous;
        _saving = false;
      });
      ToastUtils.toast(AppI18n.current.t(
        zhHans: '保存失败',
        zhHant: '儲存失敗',
        en: 'Failed to save.',
        ja: '保存に失敗しました。',
        ko: '저장에 실패했습니다.',
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = settingsIsDark(context);
    final helperColor = AppColors.subText(dark: dark);
    final i18n = AppI18n.of(context);

    return SettingsScaffold(
      title: i18n.t(
        zhHans: '添加我的方式',
        zhHant: '添加我的方式',
        en: 'How to Add Me',
        ja: '友だち追加の方法',
        ko: '나를 추가하는 방법',
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Text(
            i18n.t(
              zhHans: '管理别人可以通过哪些方式找到你并添加你为好友。关闭后，对应入口将不再对你生效。',
              zhHant: '管理他人可透過哪些方式找到你並加你為好友。關閉後，對應入口將不再對你生效。',
              en: 'Choose how others can find you and send friend requests. When disabled, that entry point will no longer work for you.',
              ja: '他のユーザーがあなたを見つけて友だち追加できる方法を管理します。オフにすると、その方法は利用できなくなります。',
              ko: '다른 사람이 나를 찾아 친구로 추가할 수 있는 방법을 관리합니다. 끄면 해당 경로는 더 이상 사용할 수 없습니다.',
            ),
            style: TextStyle(
              color: helperColor,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
        if (_loading)
          const _PrivacyLoadingBox()
        else if (_loadError != null)
          _PrivacyErrorBox(
            message: _loadError!,
            onRetry: _load,
          )
        else ...[
          SettingsGroup(
            margin: EdgeInsets.zero,
            children: [
              _PrivacySwitchCell(
                title: i18n.t(
                  zhHans: '二维码',
                  zhHant: '二維碼',
                  en: 'QR Code',
                  ja: 'QRコード',
                  ko: 'QR 코드',
                ),
                subtitle: i18n.t(
                  zhHans: '允许通过我的二维码添加',
                  zhHant: '允許透過我的二維碼添加',
                  en: 'Allow adding me via my QR code',
                  ja: '自分のQRコードから追加を許可',
                  ko: '내 QR 코드로 추가 허용',
                ),
                value: _settings!.allowViaQrCode,
                onChanged: (v) => _updateValue((s) => s.allowViaQrCode = v),
              ),
              _PrivacySwitchCell(
                title: i18n.t(
                  zhHans: '名片',
                  zhHant: '名片',
                  en: 'Contact Card',
                  ja: '名刺',
                  ko: '명함',
                ),
                subtitle: i18n.t(
                  zhHans: '允许通过名片转发添加',
                  zhHant: '允許透過名片轉發添加',
                  en: 'Allow adding me via shared contact cards',
                  ja: '名刺の転送から追加を許可',
                  ko: '명함 공유로 추가 허용',
                ),
                value: _settings!.allowViaCard,
                onChanged: (v) => _updateValue((s) => s.allowViaCard = v),
              ),
              _PrivacySwitchCell(
                title: i18n.t(
                  zhHans: '群聊',
                  zhHant: '群聊',
                  en: 'Group Chat',
                  ja: 'グループチャット',
                  ko: '그룹 채팅',
                ),
                subtitle: i18n.t(
                  zhHans: '允许群成员从群聊中添加',
                  zhHant: '允許群成員從群聊中添加',
                  en: 'Allow group members to add me from group chats',
                  ja: 'グループメンバーがグループチャットから追加することを許可',
                  ko: '그룹 멤버가 그룹 채팅에서 나를 추가하도록 허용',
                ),
                value: _settings!.allowViaGroup,
                onChanged: (v) => _updateValue((s) => s.allowViaGroup = v),
              ),
              _PrivacySwitchCell(
                title: i18n.t(
                  zhHans: '手机号',
                  zhHant: '手機號',
                  en: 'Phone Number',
                  ja: '電話番号',
                  ko: '휴대전화 번호',
                ),
                subtitle: i18n.t(
                  zhHans: '允许通过手机号搜索添加',
                  zhHant: '允許透過手機號搜尋添加',
                  en: 'Allow adding me by phone number search',
                  ja: '電話番号検索から追加を許可',
                  ko: '휴대전화 번호 검색으로 추가 허용',
                ),
                value: _settings!.allowViaPhone,
                onChanged: (v) => _updateValue((s) => s.allowViaPhone = v),
              ),
              _PrivacySwitchCell(
                title: i18n.t(
                  zhHans: 'UID',
                  zhHant: 'UID',
                  en: 'UID',
                  ja: 'UID',
                  ko: 'UID',
                ),
                subtitle: i18n.t(
                  zhHans: '允许通过 UID 搜索添加',
                  zhHant: '允許透過 UID 搜尋添加',
                  en: 'Allow adding me by UID search',
                  ja: 'UID検索から追加を許可',
                  ko: 'UID 검색으로 추가 허용',
                ),
                value: _settings!.allowViaUid,
                onChanged: (v) => _updateValue((s) => s.allowViaUid = v),
                showDivider: false,
              ),
            ],
          ),
          if (_saving)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryBlue,
                      backgroundColor: AppColors.line(dark: dark),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    i18n.t(
                      zhHans: '保存中',
                      zhHant: '儲存中',
                      en: 'Saving...',
                      ja: '保存中...',
                      ko: '저장 중...',
                    ),
                    style: TextStyle(
                      color: helperColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _PrivacySwitchCell extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final bool showDivider;
  final ValueChanged<bool>? onChanged;

  const _PrivacySwitchCell({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final dark = settingsIsDark(context);

    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: AppColors.line(dark: dark),
                  width: 0.7,
                ),
              )
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.text(dark: dark),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.subText(dark: dark),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SettingsPlatformSwitch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _PrivacyLoadingBox extends StatelessWidget {
  const _PrivacyLoadingBox();

  @override
  Widget build(BuildContext context) {
    final dark = settingsIsDark(context);
    return SettingsGroup(
      margin: EdgeInsets.zero,
      children: [
        Container(
          height: 108,
          alignment: Alignment.center,
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppColors.primaryBlue,
              backgroundColor: AppColors.line(dark: dark),
            ),
          ),
        ),
      ],
    );
  }
}

class _PrivacyErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _PrivacyErrorBox({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final dark = settingsIsDark(context);
    final i18n = AppI18n.of(context);
    return SettingsGroup(
      margin: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
          child: Column(
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.subText(dark: dark),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryBlue,
                ),
                child: Text(i18n.t(
                  zhHans: '重试',
                  zhHant: '重試',
                  en: 'Retry',
                  ja: '再試行',
                  ko: '다시 시도',
                )),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

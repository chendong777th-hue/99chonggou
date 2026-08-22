import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/message_notification_sound.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/settings_widgets.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/services/in_app_notification_sound.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';

class MessageNotificationSoundPickerPage extends StatelessWidget {
  const MessageNotificationSoundPickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localSetting = Provider.of<LocalSetting>(context);
    final i18n = AppI18n.of(context);
    final selectedId = localSetting.messageNotificationSoundId;

    return SettingsScaffold(
      title: i18n.t(
        zhHans: '消息提示音',
        zhHant: '訊息提示音',
        en: 'Message Sound',
        ja: 'メッセージ通知音',
        ko: '메시지 알림음',
      ),
      children: [
        SettingsGroup(
          margin: EdgeInsets.zero,
          children: [
            for (var i = 0; i < MessageNotificationSound.options.length; i++)
              _SoundOptionCell(
                option: MessageNotificationSound.options[i],
                selected: MessageNotificationSound.options[i].id == selectedId,
                showDivider: i < MessageNotificationSound.options.length - 1,
                onTap: () {
                  final option = MessageNotificationSound.options[i];
                  if (option.id == selectedId) {
                    InAppNotificationSound.playSound(option.id, force: true);
                    return;
                  }
                  localSetting.messageNotificationSoundId = option.id;
                  InAppNotificationSound.playSound(option.id, force: true);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _SoundOptionCell extends StatelessWidget {
  final MessageNotificationSound option;
  final bool selected;
  final bool showDivider;
  final VoidCallback onTap;

  const _SoundOptionCell({
    required this.option,
    required this.selected,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = settingsIsDark(context);
    final i18n = AppI18n.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
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
            children: [
              Expanded(
                child: Text(
                  option.localizedLabel(i18n),
                  style: TextStyle(
                    color: AppColors.text(dark: dark),
                    fontSize: 16,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_rounded,
                  color: AppColors.primaryBlue,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
